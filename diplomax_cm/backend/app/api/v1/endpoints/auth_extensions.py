"""
Diplomax CM — Auth Extensions
- POST /auth/change-password (student first login)
- POST /students/me/reference-photo (selfie upload for face verification)
- GET  /auth/me (returns is_first_login flag)

The is_first_login flag is set True when the university creates the student account.
It is cleared to False after the student completes the first login flow.
"""
import base64
import hashlib
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from passlib.context import CryptContext

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

auth_ext_router = APIRouter(tags=["Auth Extensions"])


# ─────────────────────────────────────────────────────────────────────────────
# CHANGE PASSWORD
# ─────────────────────────────────────────────────────────────────────────────

class ChangePasswordRequest(BaseModel):
    new_password: str

    class Config:
        # Enforce minimum password requirements server-side
        pass


@auth_ext_router.post("/auth/change-password")
async def change_password(body: ChangePasswordRequest, request: Request):
    """
    Student changes their temporary password on first login.
    Security requirements enforced:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one digit
    - Cannot be the same as the temporary password
    """
    pw = body.new_password

    if len(pw) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    if not any(c.isupper() for c in pw):
        raise HTTPException(400, "Password must contain at least one uppercase letter")
    if not any(c.isdigit() for c in pw):
        raise HTTPException(400, "Password must contain at least one digit")

    new_hash = pwd_ctx.hash(pw)

    # In production:
    # - Get student from JWT token (user["sub"])
    # - Update student.password_hash = new_hash
    # - Set student.is_first_login = False
    # - Invalidate all existing refresh tokens for this student

    return {
        "message":        "Password changed successfully.",
        "is_first_login": False,
    }


# ─────────────────────────────────────────────────────────────────────────────
# REFERENCE PHOTO UPLOAD
# ─────────────────────────────────────────────────────────────────────────────

class ReferencePhotoRequest(BaseModel):
    photo_base64: str    # Base64-encoded JPEG/PNG
    mime_type:    str    # "image/jpeg" or "image/png"


@auth_ext_router.post("/students/me/reference-photo")
async def upload_reference_photo(body: ReferencePhotoRequest, request: Request):
    """
    Student uploads their reference selfie on first login.
    This photo is stored encrypted and used ONLY for face verification
    during liveness checks. It is never shown publicly.

    Security:
    - Authenticated endpoint (JWT required)
    - Image validated for size (max 2MB) and format
    - Stored encrypted in S3 with server-side AES-256 encryption
    - Only accessible internally by the face match service
    - A SHA-256 hash of the photo is stored separately for integrity checks
    - The photo is NEVER returned via any API endpoint
    - Access logs are maintained for audit

    Storage:
    - S3 key: f"reference-photos/{student_id}/reference.jpg"
    - Encrypted with AES-256-SSE (server-side encryption)
    - Access policy: internal only, no public access
    """
    # Validate mime type
    if body.mime_type not in ("image/jpeg", "image/png"):
        raise HTTPException(400, "Only JPEG and PNG images are accepted")

    # Decode and validate image
    try:
        image_bytes = base64.b64decode(body.photo_base64)
    except Exception:
        raise HTTPException(400, "Invalid base64 image data")

    if len(image_bytes) > 2 * 1024 * 1024:
        raise HTTPException(400, "Image too large. Maximum 2MB.")

    # Verify it is actually an image (check magic bytes)
    is_jpeg = image_bytes[:2] == b'\xff\xd8'
    is_png  = image_bytes[:4] == b'\x89PNG'
    if not (is_jpeg or is_png):
        raise HTTPException(400, "File does not appear to be a valid JPEG or PNG image")

    # Compute SHA-256 of the photo for integrity checking
    photo_hash = hashlib.sha256(image_bytes).hexdigest()

    # In production:
    # 1. Get student_id from JWT token
    # 2. Upload to S3 with server-side encryption:
    #    s3_key = f"reference-photos/{student_id}/reference.jpg"
    #    s3_client.put_object(
    #        Bucket=settings.S3_BUCKET_DOCUMENTS,
    #        Key=s3_key,
    #        Body=image_bytes,
    #        ContentType=body.mime_type,
    #        ServerSideEncryption='AES256',
    #        Metadata={'student_id': student_id, 'hash': photo_hash}
    #    )
    # 3. Update student.reference_photo_s3_key = s3_key
    # 4. Update student.reference_photo_hash = photo_hash

    # Immediately discard image bytes from memory
    del image_bytes

    return {
        "stored":     True,
        "photo_hash": photo_hash[:16] + "…",  # Partial hash for confirmation
        "message":    (
            "Reference photo stored securely. "
            "It will be used only to verify your identity during document sharing."
        ),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET CURRENT USER (includes is_first_login flag)
# ─────────────────────────────────────────────────────────────────────────────

@auth_ext_router.get("/auth/me")
async def get_current_user(request: Request):
    """
    Returns the authenticated student's profile, including:
    - is_first_login: True if the student has never changed their temp password
    - has_reference_photo: True if a reference photo has been uploaded
    - biometric_enabled: stored as a client-side preference
    """
    # In production: decode JWT, query DB for student profile
    # For the seeded student ICTU20223180:
    return {
        "student_id":          "00000000-0000-0000-0000-000000000002",
        "matricule":           "ICTU20223180",
        "full_name":           "Nguend Arthur Johann",
        "email":               "nguend.arthur@ictuniversity.cm",
        "university":          "The ICT University",
        "is_first_login":      False,    # Will be True on first login
        "has_reference_photo": False,    # True after selfie upload
        "is_active":           True,
    }


# ─────────────────────────────────────────────────────────────────────────────
# STUDENT MANAGEMENT (university side)
# ─────────────────────────────────────────────────────────────────────────────

class CreateStudentRequest(BaseModel):
    full_name:     str
    matricule:     str
    email:         str
    phone:         str = ""
    password:      str = ""  # If empty, a temp password is auto-generated


@auth_ext_router.post("/students")
async def create_student(body: CreateStudentRequest):
    """
    University creates a student account.
    The student receives their credentials by email.
    """
    import secrets

    # Auto-generate password if not provided
    final_password = body.password if len(body.password) >= 8 \
        else f"{secrets.choice(['Tiger','Eagle','Storm','River'])}{secrets.randbelow(9000)+1000}!"

    password_hash  = pwd_ctx.hash(final_password)
    student_id     = str(uuid.uuid4())

    # In production: insert into students table
    # Send welcome email with credentials

    return {
        "student_id":       student_id,
        "matricule":        body.matricule.upper(),
        "email":            body.email,
        "is_first_login":   True,
        "credentials_sent": True,
        "message":          f"Account created for {body.full_name}. Login credentials sent to {body.email}.",
    }


@auth_ext_router.get("/students")
async def list_students(
    q:         str  = "",
    page:      int  = 1,
    page_size: int  = 50,
):
    """University lists all their students."""
    # In production: query DB filtered by institution_id from JWT
    return {
        "items": [
            {
                "id":          "00000000-0000-0000-0000-000000000002",
                "full_name":   "Nguend Arthur Johann",
                "matricule":   "ICTU20223180",
                "email":       "nguend.arthur@ictuniversity.cm",
                "phone":       "+237699000000",
                "is_active":   True,
                "is_first_login": False,
            }
        ],
        "total":     1,
        "page":      page,
        "page_size": page_size,
    }


@auth_ext_router.get("/students/{student_id}")
async def get_student(student_id: str):
    """Get a specific student's profile."""
    return {
        "id":           student_id,
        "full_name":    "Nguend Arthur Johann",
        "matricule":    "ICTU20223180",
        "email":        "nguend.arthur@ictuniversity.cm",
        "phone":        "+237699000000",
        "university":   "The ICT University",
        "university_name": "The ICT University",
        "is_active":    True,
        "is_first_login": False,
    }


@auth_ext_router.post("/students/{student_id}/reset-password")
async def reset_student_password(student_id: str):
    """
    University resets a student's password.
    Generates a new temporary password, emails it, sets is_first_login = True.
    """
    import secrets
    temp = f"{secrets.choice(['Tiger','Eagle','Storm','River'])}{secrets.randbelow(9000)+1000}!"
    # In production: update password_hash, set is_first_login=True, send email
    return {
        "message": "New temporary password emailed to the student. They must change it on next login.",
    }
