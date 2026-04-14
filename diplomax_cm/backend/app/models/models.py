"""
Diplomax CM — SQLAlchemy ORM Models
Full schema covering all entities.
"""
import uuid
from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import (
    Boolean, Column, Date, DateTime, Enum, ForeignKey,
    Integer, Numeric, String, Text, SmallInteger, func, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


# ─── Enums ────────────────────────────────────────────────────────────────────

class DocType(PyEnum):
    diploma      = "diploma"
    transcript   = "transcript"
    certificate  = "certificate"
    attestation  = "attestation"

class UserRole(PyEnum):
    student    = "student"
    university = "university"
    recruiter  = "recruiter"
    admin      = "admin"

class PayStatus(PyEnum):
    pending    = "pending"
    successful = "successful"
    failed     = "failed"
    cancelled  = "cancelled"

class VerifMode(PyEnum):
    none     = "none"
    zkp_only = "zkp_only"
    liveness = "liveness"

class IntlShareStatus(PyEnum):
    active   = "active"
    expired  = "expired"
    revoked  = "revoked"
    viewed   = "viewed"


class RequestStatus(PyEnum):
    pending = "pending"
    reviewing = "reviewing"
    approved = "approved"
    rejected = "rejected"
    ready = "ready"
    collected = "collected"


# ─── University ───────────────────────────────────────────────────────────────

class University(Base):
    __tablename__ = "universities"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name            = Column(String(200), nullable=False)
    short_name      = Column(String(20), nullable=False)
    city            = Column(String(100), nullable=False)
    country         = Column(String(100), default="Cameroon")
    api_endpoint    = Column(Text)
    is_connected    = Column(Boolean, default=False)
    # RSA public key fingerprint — uploaded when university sets up signing
    public_key_pem  = Column(Text)
    pub_key_fingerprint = Column(String(128))
    created_at      = Column(DateTime, server_default=func.now())

    students    = relationship("Student",          back_populates="university")
    documents   = relationship("AcademicDocument", back_populates="university")
    staff       = relationship("UniversityStaff",  back_populates="university")


# ─── University Staff ─────────────────────────────────────────────────────────

class UniversityStaff(Base):
    __tablename__ = "university_staff"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    university_id = Column(UUID(as_uuid=True), ForeignKey("universities.id"), nullable=False)
    full_name     = Column(String(150), nullable=False)
    email         = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(128), nullable=False)
    role          = Column(String(50), default="registrar")  # registrar | admin
    is_active     = Column(Boolean, default=True)
    fcm_token     = Column(Text)
    created_at    = Column(DateTime, server_default=func.now())

    university = relationship("University", back_populates="staff")


# ─── Student ──────────────────────────────────────────────────────────────────

class Student(Base):
    __tablename__ = "students"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    university_id = Column(UUID(as_uuid=True), ForeignKey("universities.id"), nullable=False)
    full_name     = Column(String(150), nullable=False)
    matricule     = Column(String(30), unique=True, nullable=False, index=True)
    email         = Column(String(100), unique=True, nullable=False)
    phone         = Column(String(20))
    date_of_birth = Column(Date)
    photo_url     = Column(Text)
    password_hash = Column(String(128), nullable=False)
    # Biometric public template hash — we only store the hash, not the biometric
    biometric_hash = Column(String(128))
    fcm_token      = Column(Text)
    is_active      = Column(Boolean, default=True)
    created_at     = Column(DateTime, server_default=func.now())
    last_login     = Column(DateTime)

    university       = relationship("University",        back_populates="students")
    documents        = relationship("AcademicDocument",  back_populates="student")
    payments         = relationship("Payment",           back_populates="student")
    share_links      = relationship("ShareLink",         back_populates="student")
    intl_shares      = relationship("IntlShare",         back_populates="student")


# ─── Academic Document ────────────────────────────────────────────────────────

class AcademicDocument(Base):
    __tablename__ = "academic_documents"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id      = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False)
    university_id   = Column(UUID(as_uuid=True), ForeignKey("universities.id"), nullable=False)
    issued_by       = Column(UUID(as_uuid=True), ForeignKey("university_staff.id"))
    doc_type        = Column(Enum(DocType), nullable=False)
    title           = Column(String(255), nullable=False)
    degree          = Column(String(100))
    field           = Column(String(150))
    mention         = Column(String(50))
    issue_date      = Column(Date, nullable=False)
    # Cryptographic fields
    hash_sha256     = Column(String(64), unique=True, nullable=False, index=True)
    rsa_signature   = Column(Text)        # University's RSA-SHA256 signature (hex)
    blockchain_tx   = Column(String(128)) # Fabric transaction ID
    blockchain_block = Column(Integer)    # Fabric block number
    is_verified     = Column(Boolean, default=False)
    is_blockchain_anchored = Column(Boolean, default=False)
    # NFC
    nfc_uid         = Column(String(64))  # NFC chip UID if physical diploma has one
    # Encrypted storage
    encrypted_content = Column(Text)      # AES-256-GCM encrypted document JSON
    pdf_s3_key      = Column(Text)        # S3 key for the generated PDF
    created_at      = Column(DateTime, server_default=func.now())

    student      = relationship("Student",      back_populates="documents")
    university   = relationship("University",   back_populates="documents")
    grades       = relationship("CourseGrade",  back_populates="document", cascade="all, delete-orphan")
    share_links  = relationship("ShareLink",    back_populates="document")
    intl_shares  = relationship("IntlShare",    back_populates="document")
    payments     = relationship("Payment",      back_populates="document")
    verif_logs   = relationship("VerificationLog", back_populates="document")


# ─── Course Grade ─────────────────────────────────────────────────────────────

class CourseGrade(Base):
    __tablename__ = "course_grades"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    document_id = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"), nullable=False)
    course_code = Column(String(20), nullable=False)
    course_name = Column(String(150), nullable=False)
    grade       = Column(Numeric(4, 2), nullable=False)
    credits     = Column(SmallInteger, nullable=False)
    semester    = Column(String(10), nullable=False)
    mention     = Column(String(30))

    document = relationship("AcademicDocument", back_populates="grades")


# ─── Share Link ───────────────────────────────────────────────────────────────

class ShareLink(Base):
    __tablename__ = "share_links"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    document_id      = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"), nullable=False)
    student_id       = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False)
    token            = Column(String(128), unique=True, nullable=False, index=True)
    expires_at       = Column(DateTime, nullable=False)
    zkp_mode         = Column(Boolean, default=False)
    validity_hours   = Column(SmallInteger, default=48)
    verification_mode = Column(Enum(VerifMode), default=VerifMode.liveness)
    view_count       = Column(Integer, default=0)
    is_revoked       = Column(Boolean, default=False)
    created_at       = Column(DateTime, server_default=func.now())

    document = relationship("AcademicDocument", back_populates="share_links")
    student  = relationship("Student",          back_populates="share_links")
    verif_logs = relationship("VerificationLog", back_populates="share_link")


# ─── International Share ──────────────────────────────────────────────────────

class IntlShare(Base):
    """
    Secure document package for abroad institutions.
    Generates a tamper-proof, embassy-ready PDF with blockchain proof,
    accessible via a time-limited unique URL.
    """
    __tablename__ = "intl_shares"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    document_id     = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"), nullable=False)
    student_id      = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False)
    token           = Column(String(128), unique=True, nullable=False, index=True)
    # Recipient info
    institution_name  = Column(String(200))   # e.g. "University of Paris"
    institution_email = Column(String(100))   # Optional — auto-send on creation
    institution_country = Column(String(100))
    purpose           = Column(String(200))   # e.g. "Visa application", "Master's admission"
    # Access control
    expires_at        = Column(DateTime, nullable=False)
    status            = Column(Enum(IntlShareStatus), default=IntlShareStatus.active)
    password_hash     = Column(String(128))   # Optional extra password for the package
    # What is included
    include_grades    = Column(Boolean, default=True)
    include_blockchain_proof = Column(Boolean, default=True)
    include_university_letter = Column(Boolean, default=False)
    # The generated PDF S3 key
    package_pdf_s3_key = Column(Text)
    # Usage tracking
    view_count        = Column(Integer, default=0)
    last_viewed_at    = Column(DateTime)
    last_viewed_ip    = Column(String(45))
    created_at        = Column(DateTime, server_default=func.now())

    document = relationship("AcademicDocument", back_populates="intl_shares")
    student  = relationship("Student",          back_populates="intl_shares")


# ─── Liveness Session ─────────────────────────────────────────────────────────

class LivenessSession(Base):
    """
    Tracks an active liveness verification challenge.
    Created when a recruiter scans a QR code that requires liveness.
    Expires in 10 minutes.
    """
    __tablename__ = "liveness_sessions"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    share_token  = Column(String(128), nullable=False, index=True)
    # Challenge sequence: list of axes the student must move
    challenge_1  = Column(String(10), default="y_right")
    challenge_2  = Column(String(10), default="y_left")
    challenge_3  = Column(String(10), default="x_down")
    # Progress
    challenges_passed = Column(SmallInteger, default=0)
    is_passed    = Column(Boolean, default=False)
    expires_at   = Column(DateTime, nullable=False)
    created_at   = Column(DateTime, server_default=func.now())


# ─── Recruiter ────────────────────────────────────────────────────────────────

class Recruiter(Base):
    __tablename__ = "recruiters"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_name      = Column(String(200), nullable=False)
    email             = Column(String(100), unique=True, nullable=False)
    password_hash     = Column(String(128), nullable=False)
    phone             = Column(String(20))
    subscription_plan = Column(String(50), default="free")  # free | monthly | annual
    sub_expires_at    = Column(DateTime)
    is_active         = Column(Boolean, default=True)
    fcm_token         = Column(Text)
    created_at        = Column(DateTime, server_default=func.now())

    verif_logs = relationship("VerificationLog", back_populates="recruiter")
    payments   = relationship("Payment",         back_populates="recruiter")


# ─── Verification Log ─────────────────────────────────────────────────────────

class VerificationLog(Base):
    __tablename__ = "verification_logs"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    recruiter_id   = Column(UUID(as_uuid=True), ForeignKey("recruiters.id"))
    document_id    = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"), nullable=False)
    share_link_id  = Column(UUID(as_uuid=True), ForeignKey("share_links.id"))
    intl_share_id  = Column(UUID(as_uuid=True), ForeignKey("intl_shares.id"))
    method         = Column(String(20), nullable=False)  # qr | nfc | link | intl
    result         = Column(Boolean, nullable=False)
    liveness_passed = Column(Boolean)
    verified_at    = Column(DateTime, server_default=func.now())
    ip_address     = Column(String(45))
    user_agent     = Column(String(300))

    recruiter  = relationship("Recruiter",        back_populates="verif_logs")
    document   = relationship("AcademicDocument", back_populates="verif_logs")
    share_link = relationship("ShareLink",        back_populates="verif_logs")


# ─── Payment ──────────────────────────────────────────────────────────────────

class Payment(Base):
    __tablename__ = "payments"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id      = Column(UUID(as_uuid=True), ForeignKey("students.id"))
    recruiter_id    = Column(UUID(as_uuid=True), ForeignKey("recruiters.id"))
    document_id     = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"))
    amount_fcfa     = Column(Integer, nullable=False)
    provider        = Column(String(20), nullable=False)  # mtn | orange
    phone_number    = Column(String(20), nullable=False)
    product         = Column(String(50), nullable=False)
    status          = Column(Enum(PayStatus), default=PayStatus.pending)
    external_id     = Column(String(128), unique=True, nullable=False)
    operator_tx_ref = Column(String(128))
    transaction_ref = Column(String(100), unique=True)
    failure_reason  = Column(Text)
    paid_at         = Column(DateTime)
    created_at      = Column(DateTime, server_default=func.now())

    student   = relationship("Student",          back_populates="payments")
    recruiter = relationship("Recruiter",        back_populates="payments")
    document  = relationship("AcademicDocument", back_populates="payments")


# ─── University Document Request Pricing ─────────────────────────────────────

class UniversityRequestPrice(Base):
    __tablename__ = "university_request_prices"
    __table_args__ = (
        UniqueConstraint("university_id", "doc_type", name="uq_university_doc_type_price"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    university_id = Column(UUID(as_uuid=True), ForeignKey("universities.id"), nullable=False)
    doc_type = Column(Enum(DocType), nullable=False)
    base_fee_fcfa = Column(Integer, nullable=False)
    is_active = Column(Boolean, default=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    created_at = Column(DateTime, server_default=func.now())


# ─── Student Document Requests ───────────────────────────────────────────────

class DocumentRequest(Base):
    __tablename__ = "document_requests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False)
    university_id = Column(UUID(as_uuid=True), ForeignKey("universities.id"), nullable=False)

    doc_type = Column(Enum(DocType), nullable=False)
    purpose = Column(String(200), nullable=False)
    destination = Column(String(200))
    urgency = Column(String(20), default="normal")
    notes = Column(Text)

    status = Column(Enum(RequestStatus), default=RequestStatus.pending)
    admin_notes = Column(Text)
    assigned_to = Column(UUID(as_uuid=True), ForeignKey("university_staff.id"))

    document_id = Column(UUID(as_uuid=True), ForeignKey("academic_documents.id"))
    payment_id = Column(UUID(as_uuid=True), ForeignKey("payments.id"))
    fee_fcfa = Column(Integer, nullable=False)
    fee_paid = Column(Boolean, default=False)

    submitted_at = Column(DateTime, server_default=func.now())
    reviewed_at = Column(DateTime)
    issued_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
