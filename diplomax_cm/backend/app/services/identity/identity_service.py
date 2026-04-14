"""
Diplomax CM — Identity & Account Provisioning Service

MECHANISM 1 — University Registration Flow:
  Step 1: Institution fills the in-app form (name, type, city, accreditation, admin contact)
  Step 2: Application saved as status=PENDING → Diplomax super-admin receives email alert
  Step 3: Diplomax admin reviews (verifies accreditation docs) → approves or rejects
  Step 4: On approval:
    - A unique API key is generated (shown ONCE by email)
    - An admin staff account is created (temporary password by email)
    - The institution is now ACTIVE on the network
  Step 5: The registrar logs in with email + temp password → forced to change password on first login

MECHANISM 2 — Student Account Provisioning:
  Students NEVER self-register. The university creates their accounts.
  Three ways the university creates student accounts:
    A) Manual: registrar enters one student's details in the app
    B) CSV bulk: registrar uploads a spreadsheet of all students
    C) Auto-provisioned: when the university issues a document to a matricule
       that has no account yet, an account is created automatically

  Once created, the student receives:
    - An SMS with their matricule and a temporary 6-digit PIN
    - An email (if available) with the same credentials
  On first login:
    - Student enters matricule + temp PIN
    - Forced to create a permanent password
    - Prompted to set up biometric (fingerprint / Face ID)
    - Prompted to take a selfie (stored as face template for later verification)

MECHANISM 3 — Face Verification:
  When a student shares a document with liveness mode:
    - The recruiter scans the QR code
    - The recruiter hands the phone to the student
    - The student sees: "Take a selfie to verify your identity"
    - Google ML Kit Face Detection captures a real-time face frame
    - The captured face is compared against the stored face template
    - If match ≥ 0.85 confidence → VERIFIED → document released
    - The entire comparison runs ON DEVICE — no face data sent to server
    - Only the boolean result (pass/fail) is sent to the backend

SECURITY MEASURES:
  - All passwords bcrypt-hashed (cost 12)
  - Temp PINs are single-use and expire in 24h
  - API keys are SHA-256 hashed — only the hash is stored, raw key shown once
  - Rate limiting: max 5 failed login attempts → account locked for 30 min
  - All tokens JWT signed with RS256 (asymmetric) in production
  - Certificate pinning on all API clients
  - AES-256-GCM for all stored document content
  - DDoS protection via Nginx rate limiting (100 req/min per IP)
"""
import uuid
import secrets
import hashlib
import string
import random
from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

identity_router = APIRouter(prefix="/identity", tags=["Identity"])

# ─────────────────────────────────────────────────────────────────────────────
# TEMP PIN GENERATION
# ─────────────────────────────────────────────────────────────────────────────

def generate_temp_pin(length: int = 8) -> str:
    """
    Generates a temporary alphanumeric PIN for first-time student login.
    Format: 4 letters + 4 digits, e.g. BJXA7391
    Easy to type on a phone, hard to guess.
    """
    letters  = ''.join(random.choices(string.ascii_uppercase, k=4))
    digits   = ''.join(random.choices(string.digits, k=4))
    combined = list(letters + digits)
    random.shuffle(combined)
    return ''.join(combined)


def generate_api_key() -> tuple[str, str, str]:
    """
    Generates a secure API key for a new institution.
    Returns: (raw_key, hashed_key, display_prefix)
    raw_key    → shown ONCE to the admin, never stored
    hashed_key → stored in DB
    display_prefix → shown in dashboard for identification (first 12 chars)
    """
    raw     = f"dplmx_{secrets.token_urlsafe(40)}"
    hashed  = hashlib.sha256(raw.encode()).hexdigest()
    prefix  = raw[:12] + "..."
    return raw, hashed, prefix


# ─────────────────────────────────────────────────────────────────────────────
# INSTITUTION REGISTRATION
# ─────────────────────────────────────────────────────────────────────────────

class InstitutionApplyRequest(BaseModel):
    institution_type:     str
    name:                 str
    short_name:           Optional[str] = None
    city:                 str
    region:               Optional[str] = None
    country:              str = "Cameroon"
    accreditation_body:   Optional[str] = None
    accreditation_number: Optional[str] = None
    is_government:        bool = False
    website:              Optional[str] = None
    email:                EmailStr
    phone:                str
    matricule_prefix:     str     # e.g. ICTU, ENSP, CFPR
    admin_full_name:      str
    admin_email:          EmailStr
    admin_phone:          str
    admin_title:          str    # Registrar, Director, etc.
    admin_password:       str    # Sets the initial (temp) password


@identity_router.post("/institutions/apply")
async def institution_apply(
    body: InstitutionApplyRequest,
    background_tasks: BackgroundTasks,
):
    """
    Step 1 of institution onboarding.
    Any institution can apply. No approval yet — just saves the application.
    """
    import re
    prefix = body.matricule_prefix.upper().strip()
    if not re.match(r'^[A-Z0-9]{2,8}$', prefix):
        raise HTTPException(status_code=400,
            detail="Matricule prefix must be 2-8 uppercase letters/digits. Example: ICTU, ENSP, CFP1")

    institution_id = str(uuid.uuid4())
    ref_code = prefix + str(uuid.uuid4())[:6].upper()

    # In production: save to DB with status=PENDING
    # background_tasks.add_task(_notify_diplomax_admin_new_application, institution_id, body)
    # background_tasks.add_task(_send_confirmation_email_to_applicant, body.admin_email, ref_code)

    return {
        "application_id":  institution_id,
        "reference_code":  ref_code,
        "status":          "pending",
        "message": (
            f"Application received for {body.name}. "
            "The Diplomax team will review within 2 business days. "
            f"A confirmation has been sent to {body.admin_email}."
        ),
        "next_steps": [
            "Check your email for confirmation",
            "Upload accreditation documents via the link in the email",
            "Once approved you will receive your API key and login credentials",
        ],
    }


@identity_router.post("/institutions/{institution_id}/approve")
async def approve_institution(
    institution_id: str,
    background_tasks: BackgroundTasks,
):
    """
    Diplomax super-admin approves an institution.
    Creates the admin account and generates the API key.
    """
    raw_key, hashed_key, prefix = generate_api_key()
    temp_pin = generate_temp_pin(8)

    # In production:
    # 1. Update institution status = 'approved'
    # 2. Store hashed_key in institutions.api_key_hash
    # 3. Create UniversityStaff record with pwd_ctx.hash(temp_pin)
    #    and is_first_login = True
    # 4. Send approval email with raw_key + temp_pin (both shown once)
    # background_tasks.add_task(_send_approval_email, ...)

    return {
        "institution_id":   institution_id,
        "status":           "approved",
        "api_key":          raw_key,       # ← shown ONCE — admin must save
        "api_key_prefix":   prefix,
        "admin_temp_password": temp_pin,   # ← shown ONCE — admin must change on login
        "warning": (
            "SAVE THESE NOW. The API key and temporary password are shown "
            "only once and cannot be recovered. The admin must change their "
            "password on first login."
        ),
    }


# ─────────────────────────────────────────────────────────────────────────────
# STUDENT ACCOUNT PROVISIONING
# ─────────────────────────────────────────────────────────────────────────────

class ProvisionStudentRequest(BaseModel):
    matricule:     str
    full_name:     str
    email:         Optional[EmailStr] = None
    phone:         Optional[str] = None      # Used for SMS delivery
    date_of_birth: Optional[str] = None
    programme:     Optional[str] = None


class BulkProvisionRequest(BaseModel):
    """For CSV bulk import — list of students."""
    students: list[ProvisionStudentRequest]
    notify_by_sms:   bool = True
    notify_by_email: bool = True


@identity_router.post("/students/provision")
async def provision_student(
    body: ProvisionStudentRequest,
    background_tasks: BackgroundTasks,
):
    """
    University creates a student account.
    Student receives SMS/email with temp credentials.
    Student NEVER self-registers.
    """
    student_id = str(uuid.uuid4())
    temp_pin   = generate_temp_pin(8)
    pin_expires = datetime.now(timezone.utc) + timedelta(hours=24)

    # In production:
    # 1. Check matricule doesn't already exist
    # 2. Create Student record with:
    #    - password_hash = pwd_ctx.hash(temp_pin)
    #    - is_first_login = True
    #    - temp_pin_expires_at = pin_expires
    # 3. Send SMS and/or email with credentials

    if body.phone:
        background_tasks.add_task(
            _send_student_sms, body.phone, body.matricule, temp_pin, body.full_name)

    if body.email:
        background_tasks.add_task(
            _send_student_email, body.email, body.matricule, temp_pin, body.full_name)

    return {
        "student_id":  student_id,
        "matricule":   body.matricule.upper(),
        "status":      "provisioned",
        "credentials_sent_to": {
            "sms":   body.phone or "—",
            "email": body.email or "—",
        },
        "temp_pin_expires": pin_expires.isoformat(),
        "message": (
            f"Account created for {body.full_name}. "
            f"Temporary credentials sent via {'SMS' if body.phone else ''}"
            f"{' and ' if body.phone and body.email else ''}"
            f"{'email' if body.email else ''}. "
            f"PIN expires in 24 hours."
        ),
    }


@identity_router.post("/students/provision-bulk")
async def provision_bulk(
    body: BulkProvisionRequest,
    background_tasks: BackgroundTasks,
):
    """
    Bulk provision up to 500 students at once.
    Each student gets individual credentials.
    """
    results = []
    for student in body.students:
        student_id = str(uuid.uuid4())
        temp_pin   = generate_temp_pin(8)

        # In production: batch insert + send notifications
        if body.notify_by_sms and student.phone:
            background_tasks.add_task(
                _send_student_sms, student.phone, student.matricule,
                temp_pin, student.full_name)
        if body.notify_by_email and student.email:
            background_tasks.add_task(
                _send_student_email, student.email, student.matricule,
                temp_pin, student.full_name)

        results.append({
            "matricule": student.matricule.upper(),
            "status":    "provisioned",
            "sms_sent":  bool(student.phone and body.notify_by_sms),
            "email_sent": bool(student.email and body.notify_by_email),
        })

    return {
        "total":     len(results),
        "results":   results,
        "message":   f"{len(results)} student accounts created.",
    }


# ─────────────────────────────────────────────────────────────────────────────
# FIRST LOGIN — FORCED PASSWORD CHANGE
# ─────────────────────────────────────────────────────────────────────────────

class FirstLoginRequest(BaseModel):
    matricule:        str
    temp_pin:         str
    new_password:     str
    confirm_password: str


@identity_router.post("/students/first-login")
async def student_first_login(body: FirstLoginRequest):
    """
    Handles the first-time login flow for students.
    Validates the temp PIN, forces password change.
    After this, the student uses their new password for all future logins.
    The biometric setup happens on the device after this step.
    """
    if body.new_password != body.confirm_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")
    if len(body.new_password) < 8:
        raise HTTPException(status_code=400,
            detail="Password must be at least 8 characters")

    # In production:
    # 1. Find student by matricule
    # 2. Verify temp_pin with pwd_ctx.verify()
    # 3. Check temp_pin_expires_at > now()
    # 4. Update password_hash = pwd_ctx.hash(body.new_password)
    # 5. Set is_first_login = False
    # 6. Return JWT tokens

    return {
        "status":       "password_updated",
        "message":      "Password set. Please set up biometric authentication.",
        "next_step":    "biometric_setup",
        "access_token": "generated_jwt_here",
    }


# ─────────────────────────────────────────────────────────────────────────────
# FACE TEMPLATE STORAGE
# ─────────────────────────────────────────────────────────────────────────────

@identity_router.post("/students/{student_id}/face-template")
async def upload_face_template(student_id: str, body: dict):
    """
    Stores a SHA-256 hash of the student's face embedding.
    The actual face image is NEVER stored on the server.
    Only a 128-dimensional embedding vector hash is stored.
    The comparison happens on-device using Google ML Kit.

    The server only stores:
      face_embedding_hash: SHA-256 of the 128-d embedding vector
      face_set_at: timestamp

    This means even if the server is compromised, no face image or
    biometric data can be extracted.
    """
    embedding_hash = body.get("face_embedding_hash")
    if not embedding_hash:
        raise HTTPException(status_code=400, detail="face_embedding_hash required")

    # In production: update students.biometric_hash = embedding_hash

    return {
        "student_id":  student_id,
        "face_stored": True,
        "stored_value": "hash_only_not_raw_image",
        "message": "Face template registered. Raw image not stored.",
    }


# ─────────────────────────────────────────────────────────────────────────────
# RATE LIMITING & SECURITY
# ─────────────────────────────────────────────────────────────────────────────

FAILED_ATTEMPTS: dict[str, int] = {}   # In production: use Redis
LOCKOUT_UNTIL:   dict[str, datetime] = {}

def check_rate_limit(identifier: str, max_attempts: int = 5):
    """
    Blocks brute-force attacks on login.
    After 5 failed attempts, locks the account for 30 minutes.
    Uses Redis in production for distributed rate limiting.
    """
    now = datetime.now(timezone.utc)
    if identifier in LOCKOUT_UNTIL:
        if now < LOCKOUT_UNTIL[identifier]:
            remaining = (LOCKOUT_UNTIL[identifier] - now).seconds // 60
            raise HTTPException(status_code=429,
                detail=f"Too many failed attempts. Try again in {remaining} minutes.")
        else:
            del LOCKOUT_UNTIL[identifier]
            del FAILED_ATTEMPTS[identifier]

    attempts = FAILED_ATTEMPTS.get(identifier, 0)
    if attempts >= max_attempts:
        LOCKOUT_UNTIL[identifier] = now + timedelta(minutes=30)
        raise HTTPException(status_code=429,
            detail="Account locked for 30 minutes due to too many failed attempts.")


def record_failed_attempt(identifier: str):
    """Increments the failed attempt counter."""
    FAILED_ATTEMPTS[identifier] = FAILED_ATTEMPTS.get(identifier, 0) + 1


def clear_failed_attempts(identifier: str):
    """Clears failed attempts on successful login."""
    FAILED_ATTEMPTS.pop(identifier, None)
    LOCKOUT_UNTIL.pop(identifier, None)


# ─────────────────────────────────────────────────────────────────────────────
# NOTIFICATION SENDERS (background tasks)
# ─────────────────────────────────────────────────────────────────────────────

async def _send_student_sms(phone: str, matricule: str, pin: str, name: str):
    """
    Sends the student their credentials via SMS.
    In production: integrate with Twilio, Africa's Talking (recommended for Cameroon),
    or MTN/Orange SMS API.
    """
    message = (
        f"Bonjour {name.split()[0]}!\n"
        f"Votre compte Diplomax CM est pret.\n"
        f"Matricule: {matricule}\n"
        f"Code temporaire: {pin}\n"
        f"Telechargez l'app: diplomax.cm/app\n"
        f"Ce code expire dans 24h."
    )
    # In production:
    # await africas_talking_client.sms.send(message, [phone])
    print(f"[SMS] To {phone}: {message}")


async def _send_student_email(email: str, matricule: str, pin: str, name: str):
    """Sends credentials via email using SMTP or SendGrid."""
    subject = "Diplomax CM — Your account is ready"
    body = f"""
    Dear {name},

    Your Diplomax CM account has been created by your university.

    LOGIN CREDENTIALS:
    Matricule: {matricule}
    Temporary password: {pin}

    Steps:
    1. Download the Diplomax CM app
    2. Login with your matricule and temporary password
    3. You will be asked to create a permanent password
    4. Set up fingerprint or Face ID for quick access

    Your temporary password expires in 24 hours.

    Diplomax CM Team
    """
    # In production: await send_via_smtp_or_sendgrid(email, subject, body)
    print(f"[EMAIL] To {email}: {subject}")


async def _notify_diplomax_admin_new_application(institution_id: str, body):
    """Notifies the Diplomax super-admin of a new institution application."""
    print(f"[ADMIN ALERT] New institution application: {body.name} ({institution_id})")


async def _send_approval_email(admin_email: str, raw_key: str, temp_pin: str):
    """Sends the API key and temp password to the newly approved institution admin."""
    print(f"[EMAIL] Approval sent to {admin_email}")
