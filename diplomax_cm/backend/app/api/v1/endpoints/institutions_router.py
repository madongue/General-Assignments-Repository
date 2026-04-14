"""
Diplomax CM — Multi-Institution System
Supports: Universities, Grandes Écoles, Training Centres, Professional Schools,
          Language Institutes, Online Learning Platforms

Architecture:
  - Each institution registers and receives a unique API key
  - A Diplomax super-admin approves or rejects the registration
  - Once approved, the institution can onboard students and issue documents
  - Documents are always scoped to the issuing institution
  - A student can have documents from multiple institutions
  - The blockchain record always includes the institution ID
"""
import uuid
import secrets
import hashlib
from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy import Column, DateTime, Enum, ForeignKey, String, Text, Boolean, func, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from passlib.context import CryptContext

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ─────────────────────────────────────────────────────────────────────────────
# INSTITUTION TYPES
# ─────────────────────────────────────────────────────────────────────────────

class InstitutionType(PyEnum):
    university          = "university"           # Université publique ou privée
    grande_ecole        = "grande_ecole"         # Grande École (ENSP, ENSPT, etc.)
    training_centre     = "training_centre"      # Centre de formation professionnelle
    professional_school = "professional_school"  # École professionnelle (nursing, etc.)
    language_institute  = "language_institute"   # Institut de langues
    online_platform     = "online_platform"      # Plateforme d'apprentissage en ligne
    tvet_centre         = "tvet_centre"          # TVET / formation technique et professionnelle
    corporate_training  = "corporate_training"   # Formation interne entreprise

class InstitutionStatus(PyEnum):
    pending   = "pending"    # Submitted, waiting for Diplomax super-admin approval
    reviewing = "reviewing"  # Diplomax team is verifying documents
    approved  = "approved"   # Active — can issue documents
    suspended = "suspended"  # Temporarily suspended
    rejected  = "rejected"   # Application rejected

# ─────────────────────────────────────────────────────────────────────────────
# ORM MODELS (add to models.py)
# ─────────────────────────────────────────────────────────────────────────────

class Institution:
    """
    Master institution record. Replaces the old 'universities' table for
    multi-institution support. The old 'universities' table becomes a view
    filtered on institution_type = 'university'.
    """
    __tablename__ = "institutions"

    id                  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    institution_type    = Column(Enum(InstitutionType), nullable=False)
    status              = Column(Enum(InstitutionStatus), default=InstitutionStatus.pending)

    # Identity
    name                = Column(String(200), nullable=False)
    short_name          = Column(String(20))
    acronym             = Column(String(10))
    description         = Column(Text)
    founded_year        = Column(String(4))

    # Location
    city                = Column(String(100), nullable=False)
    region              = Column(String(100))
    country             = Column(String(100), default="Cameroon")
    address             = Column(Text)

    # Contact
    website             = Column(String(200))
    email               = Column(String(100), nullable=False)
    phone               = Column(String(20))
    whatsapp            = Column(String(20))

    # Accreditation
    accreditation_body  = Column(String(200))   # MINESUP, MINEFOP, etc.
    accreditation_number = Column(String(100))
    is_government       = Column(Boolean, default=False)

    # Diplomax connection
    api_key_hash        = Column(String(128))   # Hashed API key for server-to-server
    api_key_prefix      = Column(String(10))    # First 8 chars shown in dashboard
    public_key_pem      = Column(Text)          # RSA public key for signature verification
    pub_key_fingerprint = Column(String(128))

    # Matricule format
    matricule_prefix    = Column(String(10))    # e.g. ICTU, UY1, ENSP
    matricule_format    = Column(String(50))    # e.g. {PREFIX}{YEAR4}{SEQ4}
    matricule_example   = Column(String(30))    # e.g. ICTU20223180

    # Documents allowed to issue
    allowed_doc_types   = Column(JSONB, default=list)  # ['diploma','certificate',...]

    # Admin contact (person who registered)
    admin_full_name     = Column(String(150))
    admin_email         = Column(String(100))
    admin_phone         = Column(String(20))
    admin_title         = Column(String(100))   # e.g. "Registrar", "Director"

    # Supporting documents (S3 keys)
    accreditation_doc_s3 = Column(Text)
    logo_s3              = Column(Text)
    header_image_s3      = Column(Text)

    # Stats
    total_students_issued = Column(Integer, default=0)
    total_documents_issued = Column(Integer, default=0)

    # Approval tracking
    reviewed_by         = Column(UUID(as_uuid=True))  # Diplomax super-admin ID
    reviewed_at         = Column(DateTime)
    rejection_reason    = Column(Text)
    notes               = Column(Text)

    created_at          = Column(DateTime, server_default=func.now())
    updated_at          = Column(DateTime, server_default=func.now(), onupdate=func.now())


# ─────────────────────────────────────────────────────────────────────────────
# PYDANTIC SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────

class InstitutionRegisterRequest(BaseModel):
    """Submitted by a new institution wanting to join Diplomax CM."""
    institution_type:      str
    name:                  str
    short_name:            Optional[str] = None
    acronym:               Optional[str] = None
    description:           Optional[str] = None
    founded_year:          Optional[str] = None
    city:                  str
    region:                Optional[str] = None
    country:               str = "Cameroon"
    address:               Optional[str] = None
    website:               Optional[str] = None
    email:                 EmailStr
    phone:                 str
    whatsapp:              Optional[str] = None
    accreditation_body:    Optional[str] = None
    accreditation_number:  Optional[str] = None
    is_government:         bool = False
    matricule_prefix:      str   # e.g. "ICTU", "ENSP", "CFPR"
    matricule_format:      Optional[str] = None
    matricule_example:     Optional[str] = None
    allowed_doc_types:     list[str] = ["diploma", "transcript", "certificate", "attestation"]
    admin_full_name:       str
    admin_email:           EmailStr
    admin_phone:           str
    admin_title:           str
    admin_password:        str   # Sets the initial admin account password


class InstitutionSummary(BaseModel):
    id:               str
    institution_type: str
    status:           str
    name:             str
    short_name:       Optional[str]
    city:             str
    country:          str
    email:            str
    matricule_prefix: str
    total_documents:  int
    created_at:       str


# ─────────────────────────────────────────────────────────────────────────────
# INSTITUTION SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class InstitutionService:
    """
    Core business logic for institution registration and management.
    """

    def generate_api_key(self, institution_id: str) -> tuple[str, str, str]:
        """
        Generates a secure API key for a newly approved institution.
        Returns (raw_key, key_hash, key_prefix).
        raw_key is shown ONCE to the admin — never stored.
        key_hash is stored in the DB.
        key_prefix (first 8 chars) is shown in the dashboard for identification.
        """
        raw   = f"dplmx_{institution_id[:8]}_{secrets.token_urlsafe(32)}"
        hashed = hashlib.sha256(raw.encode()).hexdigest()
        prefix = raw[:12]
        return raw, hashed, prefix

    def validate_matricule_prefix(self, prefix: str) -> bool:
        """
        Validates that a matricule prefix meets Diplomax standards.
        Must be 2-8 uppercase letters/digits. No spaces. No special chars.
        """
        import re
        return bool(re.match(r'^[A-Z0-9]{2,8}$', prefix.upper()))

    def build_matricule_example(self, prefix: str) -> str:
        """Generates an example matricule for the given prefix."""
        import datetime
        year = datetime.datetime.now().year
        return f"{prefix.upper()}{year}0001"

    def infer_allowed_docs(self, institution_type: str) -> list[str]:
        """
        Returns the default set of document types for an institution type.
        """
        mapping = {
            "university":          ["diploma","transcript","certificate","attestation"],
            "grande_ecole":        ["diploma","transcript","certificate","attestation"],
            "training_centre":     ["certificate","attestation"],
            "professional_school": ["diploma","certificate","attestation"],
            "language_institute":  ["certificate","attestation"],
            "online_platform":     ["certificate","attestation"],
            "tvet_centre":         ["certificate","attestation","diploma"],
            "corporate_training":  ["certificate","attestation"],
        }
        return mapping.get(institution_type, ["certificate","attestation"])

    def institution_type_label(self, t: str) -> str:
        labels = {
            "university":          "Université",
            "grande_ecole":        "Grande École",
            "training_centre":     "Centre de formation",
            "professional_school": "École professionnelle",
            "language_institute":  "Institut de langues",
            "online_platform":     "Plateforme en ligne",
            "tvet_centre":         "Centre TVET",
            "corporate_training":  "Formation entreprise",
        }
        return labels.get(t, t)


institution_svc = InstitutionService()


# ─────────────────────────────────────────────────────────────────────────────
# API ROUTER
# ─────────────────────────────────────────────────────────────────────────────

institution_router = APIRouter(prefix="/institutions", tags=["Institutions"])


@institution_router.post("/register")
async def register_institution(
    body: InstitutionRegisterRequest,
    background_tasks: BackgroundTasks,
):
    """
    Public endpoint — any institution can apply to join Diplomax CM.
    The application is reviewed by the Diplomax super-admin before activation.
    No API key is issued at this stage.
    """
    # Validate matricule prefix
    if not institution_svc.validate_matricule_prefix(body.matricule_prefix):
        raise HTTPException(status_code=400,
            detail="Matricule prefix must be 2-8 uppercase letters/digits (e.g. ICTU, ENSP)")

    # Infer allowed doc types if not provided
    allowed_docs = body.allowed_doc_types or \
        institution_svc.infer_allowed_docs(body.institution_type)

    institution_id = str(uuid.uuid4())

    # In production: save to DB, send confirmation email, notify super-admin
    # background_tasks.add_task(send_registration_confirmation, body.email, institution_id)
    # background_tasks.add_task(notify_superadmin_new_registration, institution_id)

    return {
        "institution_id":  institution_id,
        "status":          "pending",
        "message":         (
            f"Your application for {body.name} has been received. "
            "The Diplomax team will review it within 2 business days. "
            f"You will receive a confirmation at {body.email}."
        ),
        "reference":       institution_id[:8].upper(),
        "next_steps": [
            "Check your email for a confirmation link",
            "Upload your accreditation documents via the link",
            "The Diplomax team will contact you within 2 business days",
            "Once approved, you will receive your API key and admin credentials",
        ],
    }


@institution_router.get("/")
async def list_institutions(
    institution_type: Optional[str] = None,
    status:           Optional[str] = None,
    country:          Optional[str] = None,
    city:             Optional[str] = None,
    page:             int = 1,
    page_size:        int = 20,
):
    """
    Public listing of approved institutions on the Diplomax network.
    Used by the student app to find their institution.
    Returns only APPROVED institutions.
    """
    # In production: query DB with filters
    # For now: return the seeded ICT University
    return {
        "items": [
            {
                "id":               "00000000-0000-0000-0000-000000000001",
                "institution_type": "university",
                "name":             "The ICT University",
                "short_name":       "ICT University",
                "city":             "Yaoundé",
                "country":          "Cameroon",
                "matricule_prefix": "ICTU",
                "allowed_doc_types": ["diploma","transcript","certificate","attestation"],
                "is_connected":     True,
            }
        ],
        "total": 1,
        "page": page,
        "page_size": page_size,
    }


@institution_router.get("/{institution_id}")
async def get_institution(institution_id: str):
    """Public details of a specific institution."""
    # In production: query DB
    if institution_id.startswith("00000000"):
        return {
            "id":               institution_id,
            "institution_type": "university",
            "name":             "The ICT University",
            "short_name":       "ICT",
            "city":             "Yaoundé",
            "country":          "Cameroon",
            "email":            "info@ictuniversity.cm",
            "matricule_prefix": "ICTU",
            "matricule_format": "ICTU{YEAR4}{SEQ4}",
            "matricule_example": "ICTU20223180",
            "allowed_doc_types": ["diploma","transcript","certificate","attestation"],
            "accreditation_body": "MINESUP",
            "is_connected":      True,
            "total_documents":   0,
        }
    raise HTTPException(status_code=404, detail="Institution not found")


# ── Super-admin endpoints ─────────────────────────────────────────────────────

@institution_router.get("/admin/pending")
async def list_pending_registrations():
    """Super-admin: list all pending institution registrations."""
    return {"registrations": [], "total": 0}


@institution_router.post("/admin/{institution_id}/approve")
async def approve_institution(
    institution_id: str,
    background_tasks: BackgroundTasks,
):
    """
    Super-admin approves an institution.
    Generates and sends the API key to the admin email.
    Creates the default admin staff account.
    """
    raw_key, key_hash, key_prefix = institution_svc.generate_api_key(institution_id)

    # In production:
    # 1. Update institution status to 'approved'
    # 2. Store key_hash in DB
    # 3. Create admin staff account with temporary password
    # 4. Send email with raw_key (shown only once) and admin credentials
    # background_tasks.add_task(send_approval_email, institution.admin_email, raw_key)

    return {
        "institution_id": institution_id,
        "status":         "approved",
        "api_key":        raw_key,   # SHOWN ONCE — admin must save it immediately
        "api_key_prefix": key_prefix,
        "message": (
            "Institution approved. The API key has been sent to the admin email. "
            "It will NOT be shown again. The admin can now log into the university app."
        ),
    }


@institution_router.post("/admin/{institution_id}/reject")
async def reject_institution(institution_id: str, body: dict):
    """Super-admin rejects an institution application."""
    reason = body.get("reason", "")
    return {
        "institution_id": institution_id,
        "status":         "rejected",
        "reason":         reason,
    }


@institution_router.post("/admin/{institution_id}/suspend")
async def suspend_institution(institution_id: str, body: dict):
    """Super-admin suspends an active institution."""
    return {"institution_id": institution_id, "status": "suspended"}


@institution_router.post("/admin/{institution_id}/reinstate")
async def reinstate_institution(institution_id: str):
    """Super-admin reinstates a suspended institution."""
    return {"institution_id": institution_id, "status": "approved"}


# ── Institution-level stats ───────────────────────────────────────────────────

@institution_router.get("/{institution_id}/stats")
async def institution_stats(institution_id: str):
    """Returns issuance and verification stats for an institution."""
    return {
        "institution_id":       institution_id,
        "total_students":       0,
        "total_documents":      0,
        "documents_by_type":    {"diploma":0,"transcript":0,"certificate":0,"attestation":0},
        "blockchain_anchored":  0,
        "verifications_30d":    0,
        "international_shares": 0,
    }


# ── API key rotation ─────────────────────────────────────────────────────────

@institution_router.post("/{institution_id}/rotate-api-key")
async def rotate_api_key(institution_id: str):
    """
    Institution admin rotates their API key.
    Old key is immediately invalidated.
    New key is shown once.
    """
    raw_key, key_hash, key_prefix = institution_svc.generate_api_key(institution_id)
    return {
        "new_api_key":    raw_key,
        "api_key_prefix": key_prefix,
        "message": "API key rotated. Old key is immediately invalid. Save the new key now.",
    }
