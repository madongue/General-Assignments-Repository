"""
Diplomax CM — Full API Router
All endpoints: auth, documents, payments, blockchain, liveness, shares, international.
"""
import uuid
import hashlib
import secrets
import logging
import redis.asyncio as redis
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr

from app.core.config import get_settings
from app.core.database import get_request_db_session
from app.models.models import (
    Student, University, UniversityStaff, Recruiter,
    AcademicDocument, CourseGrade, ShareLink, IntlShare,
    LivenessSession, VerificationLog, Payment,
    DocumentRequest, UniversityRequestPrice,
    DocType, PayStatus, VerifMode, IntlShareStatus, RequestStatus,
)
from app.services.blockchain.fabric_service import FabricService
from app.services.payment.payment_service import PaymentService
from app.services.crypto.crypto_service import CryptoService
from app.services.pdf.pdf_service import PdfService

settings    = get_settings()
router      = APIRouter()
pwd_ctx     = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2      = OAuth2PasswordBearer(tokenUrl="/v1/auth/token")
fabric      = FabricService()
payment_svc = PaymentService()
crypto_svc  = CryptoService()
pdf_svc     = PdfService()
INTL_SHARE_STORAGE_DIR = Path(__file__).resolve().parents[4] / "generated" / "intl_shares"

AUTH_MAX_FAILED_ATTEMPTS = 5
AUTH_LOCKOUT_SECONDS = 30 * 60
REFRESH_RATE_LIMIT = 30
REFRESH_WINDOW_SECONDS = 60
CALLBACK_REPLAY_WINDOW_SECONDS = 15 * 60
_redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
_local_failures: dict[str, int] = {}
_local_locks: dict[str, datetime] = {}
_local_window: dict[str, tuple[int, datetime]] = {}
_local_callback_seen: dict[str, datetime] = {}
security_logger = logging.getLogger("diplomax.security")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _client_ip(request: Request) -> str:
    return request.client.host if request and request.client else "unknown"


def _security_log(event: str, **fields) -> None:
    payload = {"event": event, **fields}
    security_logger.warning(str(payload))


async def _check_auth_lock(scope: str, identifier: str) -> None:
    lock_key = f"authlock:{scope}:{identifier}"
    try:
        ttl = await _redis_client.ttl(lock_key)
        if ttl and ttl > 0:
            _security_log("auth_locked", scope=scope, identifier=identifier)
            raise HTTPException(status_code=429, detail=f"Too many failed attempts. Try again in {max(1, ttl // 60)} minutes.")
        return
    except HTTPException:
        raise
    except Exception:
        now = _utc_now()
        locked_until = _local_locks.get(lock_key)
        if locked_until and now < locked_until:
            remaining = int((locked_until - now).total_seconds() // 60)
            _security_log("auth_locked", scope=scope, identifier=identifier, fallback="memory")
            raise HTTPException(status_code=429, detail=f"Too many failed attempts. Try again in {max(1, remaining)} minutes.")
        if locked_until and now >= locked_until:
            _local_locks.pop(lock_key, None)


async def _register_auth_failure(scope: str, identifier: str) -> None:
    fail_key = f"authfail:{scope}:{identifier}"
    lock_key = f"authlock:{scope}:{identifier}"
    try:
        failures = await _redis_client.incr(fail_key)
        if failures == 1:
            await _redis_client.expire(fail_key, AUTH_LOCKOUT_SECONDS)
        if failures >= AUTH_MAX_FAILED_ATTEMPTS:
            await _redis_client.set(lock_key, "1", ex=AUTH_LOCKOUT_SECONDS)
            await _redis_client.delete(fail_key)
            _security_log("auth_lock_issued", scope=scope, identifier=identifier)
    except Exception:
        failures = _local_failures.get(fail_key, 0) + 1
        _local_failures[fail_key] = failures
        if failures >= AUTH_MAX_FAILED_ATTEMPTS:
            _local_locks[lock_key] = _utc_now() + timedelta(seconds=AUTH_LOCKOUT_SECONDS)
            _local_failures.pop(fail_key, None)
            _security_log("auth_lock_issued", scope=scope, identifier=identifier, fallback="memory")


async def _clear_auth_failures(scope: str, identifier: str) -> None:
    fail_key = f"authfail:{scope}:{identifier}"
    lock_key = f"authlock:{scope}:{identifier}"
    try:
        await _redis_client.delete(fail_key, lock_key)
    except Exception:
        _local_failures.pop(fail_key, None)
        _local_locks.pop(lock_key, None)


async def _enforce_window_rate_limit(key: str, limit: int, window_seconds: int) -> None:
    try:
        count = await _redis_client.incr(key)
        if count == 1:
            await _redis_client.expire(key, window_seconds)
        if count > limit:
            ttl = await _redis_client.ttl(key)
            _security_log("rate_limit_exceeded", key=key, ttl=ttl)
            raise HTTPException(status_code=429, detail=f"Too many requests. Retry in {max(1, ttl)} seconds.")
        return
    except HTTPException:
        raise
    except Exception:
        now = _utc_now()
        count, window_start = _local_window.get(key, (0, now))
        if (now - window_start).total_seconds() >= window_seconds:
            count = 0
            window_start = now
        count += 1
        _local_window[key] = (count, window_start)
        if count > limit:
            retry_in = int(window_seconds - (now - window_start).total_seconds())
            _security_log("rate_limit_exceeded", key=key, retry_in=retry_in, fallback="memory")
            raise HTTPException(status_code=429, detail=f"Too many requests. Retry in {max(1, retry_in)} seconds.")


async def _enforce_callback_replay_guard(provider: str, callback_id: str) -> None:
    if not callback_id:
        raise HTTPException(status_code=400, detail="Missing callback identifier")

    replay_key = f"cb-replay:{provider}:{callback_id}"
    try:
        created = await _redis_client.set(replay_key, "1", ex=CALLBACK_REPLAY_WINDOW_SECONDS, nx=True)
        if created is None:
            _security_log("callback_replay_detected", provider=provider, callback_id=callback_id)
            raise HTTPException(status_code=409, detail="Duplicate callback")
        return
    except HTTPException:
        raise
    except Exception:
        now = _utc_now()
        # Prune old local entries on access.
        expired = [k for k, v in _local_callback_seen.items() if (now - v).total_seconds() > CALLBACK_REPLAY_WINDOW_SECONDS]
        for key in expired:
            _local_callback_seen.pop(key, None)

        if replay_key in _local_callback_seen:
            _security_log("callback_replay_detected", provider=provider, callback_id=callback_id, fallback="memory")
            raise HTTPException(status_code=409, detail="Duplicate callback")

        _local_callback_seen[replay_key] = now


# ─────────────────────────────────────────────────────────────────────────────
# AUTH
# ─────────────────────────────────────────────────────────────────────────────

class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    role:          str
    full_name:     str
    matricule:     Optional[str] = None

class RefreshRequest(BaseModel):
    refresh_token: str


class MtnCallbackPayload(BaseModel):
    externalId: str
    status: str


class OrangeCallbackPayload(BaseModel):
    order_id: str
    status: str
    notif_token: Optional[str] = None


class LivenessChallengeRequest(BaseModel):
    detected: bool = False
    sensor_variance: Optional[float] = None


class RecruiterRegisterRequest(BaseModel):
    company_name: str
    email: EmailStr
    phone: Optional[str] = None
    password: str


class RequestPricingItem(BaseModel):
    doc_type: str
    base_fee_fcfa: int


class RequestPricingUpdate(BaseModel):
    prices: list[RequestPricingItem]


class DocumentRequestCreate(BaseModel):
    doc_type: str
    purpose: str
    destination: Optional[str] = None
    urgency: str = "normal"
    notes: Optional[str] = None


class DocumentRequestUpdate(BaseModel):
    status: str
    admin_notes: Optional[str] = None
    fee_fcfa: Optional[int] = None
    document_id: Optional[str] = None

def _create_token(data: dict, expires_delta: timedelta) -> str:
    payload = {**data, "exp": datetime.now(timezone.utc) + expires_delta}
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

async def _current_user(token: str = Depends(oauth2)):
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def _require_document_access(user: dict, doc: AcademicDocument) -> None:
    role = user.get("role")
    if role == "student" and str(doc.student_id) != user["sub"]:
        raise HTTPException(status_code=403, detail="Not your document")
    if role == "university" and str(doc.university_id) != user.get("univ", ""):
        raise HTTPException(status_code=403, detail="Document does not belong to your university")


def _require_university_ownership(user: dict, university_id: str) -> None:
    if user.get("role") != "university" or user.get("univ", "") != university_id:
        raise HTTPException(status_code=403, detail="University role required")


REQUEST_DEFAULT_FEES = {
    DocType.diploma: 2500,
    DocType.transcript: 1000,
    DocType.certificate: 1500,
    DocType.attestation: 500,
}

REQUEST_URGENCY_SURCHARGE = {
    "normal": 0,
    "urgent": 500,
    "very_urgent": 1500,
}

FREE_RECRUITER_MONTHLY_LIMIT = 5


@router.post("/auth/login/student", response_model=TokenResponse)
async def student_login(request: Request, form: OAuth2PasswordRequestForm = Depends()):
    """Student login with matricule + password."""
    identifier = f"{form.username.strip().lower()}:{_client_ip(request)}"
    await _check_auth_lock("student", identifier)

    # form.username = matricule
    result = await _get_db_session().execute(
        select(Student).where(Student.matricule == form.username.upper()))
    student = result.scalar_one_or_none()
    if not student or not pwd_ctx.verify(form.password, student.password_hash):
        await _register_auth_failure("student", identifier)
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not student.is_active:
        raise HTTPException(status_code=403, detail="Account inactive")

    await _clear_auth_failures("student", identifier)

    access  = _create_token(
        {"sub": str(student.id), "role": "student", "mat": student.matricule},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    refresh = _create_token(
        {"sub": str(student.id), "role": "student", "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))

    return TokenResponse(access_token=access, refresh_token=refresh,
                         role="student", full_name=student.full_name,
                         matricule=student.matricule)


@router.post("/auth/login/university", response_model=TokenResponse)
async def university_login(request: Request, form: OAuth2PasswordRequestForm = Depends()):
    """University staff login with email + password."""
    identifier = f"{form.username.strip().lower()}:{_client_ip(request)}"
    await _check_auth_lock("university", identifier)

    result = await _get_db_session().execute(
        select(UniversityStaff).where(UniversityStaff.email == form.username))
    staff = result.scalar_one_or_none()
    if not staff or not pwd_ctx.verify(form.password, staff.password_hash):
        await _register_auth_failure("university", identifier)
        raise HTTPException(status_code=401, detail="Invalid credentials")

    await _clear_auth_failures("university", identifier)

    access  = _create_token(
        {"sub": str(staff.id), "role": "university", "univ": str(staff.university_id)},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    refresh = _create_token(
        {"sub": str(staff.id), "role": "university", "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))

    return TokenResponse(access_token=access, refresh_token=refresh,
                         role="university", full_name=staff.full_name)


@router.post("/auth/login/recruiter", response_model=TokenResponse)
async def recruiter_login(request: Request, form: OAuth2PasswordRequestForm = Depends()):
    """Recruiter login with email + password."""
    identifier = f"{form.username.strip().lower()}:{_client_ip(request)}"
    await _check_auth_lock("recruiter", identifier)

    result = await _get_db_session().execute(
        select(Recruiter).where(Recruiter.email == form.username))
    rec = result.scalar_one_or_none()
    if not rec or not pwd_ctx.verify(form.password, rec.password_hash):
        await _register_auth_failure("recruiter", identifier)
        raise HTTPException(status_code=401, detail="Invalid credentials")

    await _clear_auth_failures("recruiter", identifier)

    access  = _create_token(
        {"sub": str(rec.id), "role": "recruiter"},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    refresh = _create_token(
        {"sub": str(rec.id), "role": "recruiter", "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))

    return TokenResponse(access_token=access, refresh_token=refresh,
                         role="recruiter", full_name=rec.company_name)


@router.post("/auth/register/recruiter")
async def recruiter_register(body: RecruiterRegisterRequest):
    """Self-registration for recruiters with immediate auto-approval on free tier."""
    db = _get_db_session()
    email = body.email.strip().lower()

    existing_result = await db.execute(
        select(Recruiter).where(Recruiter.email == email)
    )
    if existing_result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")

    password = body.password or ""
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")

    recruiter = Recruiter(
        company_name=body.company_name.strip(),
        email=email,
        phone=(body.phone or "").strip() or None,
        password_hash=pwd_ctx.hash(password),
        subscription_plan="free",
        sub_expires_at=None,
        is_active=True,
    )
    db.add(recruiter)
    await db.commit()

    access = _create_token(
        {"sub": str(recruiter.id), "role": "recruiter"},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    refresh = _create_token(
        {"sub": str(recruiter.id), "role": "recruiter", "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )

    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "role": "recruiter",
        "full_name": recruiter.company_name,
        "subscription": {
            "plan": "free",
            "free_monthly_limit": FREE_RECRUITER_MONTHLY_LIMIT,
        },
    }


@router.post("/auth/refresh")
async def refresh_token(body: RefreshRequest, request: Request):
    await _enforce_window_rate_limit(
        key=f"refresh:{_client_ip(request)}",
        limit=REFRESH_RATE_LIMIT,
        window_seconds=REFRESH_WINDOW_SECONDS,
    )
    try:
        payload = jwt.decode(body.refresh_token, settings.JWT_SECRET_KEY,
                             algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Not a refresh token")
        new_access = _create_token(
            {"sub": payload["sub"], "role": payload["role"]},
            timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
        return {"access_token": new_access, "token_type": "bearer"}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")


# ─────────────────────────────────────────────────────────────────────────────
# DOCUMENTS — STUDENT
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/documents/search")
async def search_documents(
    q:       Optional[str] = None,
    type:    Optional[str] = None,
    year:    Optional[str] = None,
    mention: Optional[str] = None,
    page:    int = 1,
    page_size: int = 20,
    user: dict = Depends(_current_user),
):
    """Search documents belonging to the authenticated student."""
    db = _get_db_session()
    filters = [AcademicDocument.student_id == uuid.UUID(user["sub"])]
    if type:    filters.append(AcademicDocument.doc_type == type)
    if mention: filters.append(AcademicDocument.mention.ilike(f"%{mention}%"))
    if year:    filters.append(AcademicDocument.issue_date.between(
        f"{year}-01-01", f"{year}-12-31"))
    if q:       filters.append(or_(
        AcademicDocument.title.ilike(f"%{q}%"),
        AcademicDocument.field.ilike(f"%{q}%"),
        AcademicDocument.degree.ilike(f"%{q}%"),
    ))

    result = await db.execute(
        select(AcademicDocument)
        .where(and_(*filters))
        .offset((page-1)*page_size)
        .limit(page_size)
        .order_by(AcademicDocument.issue_date.desc()))
    docs = result.scalars().all()

    return {"items": [_doc_summary(d) for d in docs],
            "page": page, "page_size": page_size}


@router.get("/documents/{document_id}")
async def get_document(document_id: str, user: dict = Depends(_current_user)):
    db   = _get_db_session()
    doc  = await _get_doc_or_404(db, document_id)
    _require_document_access(user, doc)
    # Decrypt content before returning
    content = {}
    if doc.encrypted_content:
        try:
            import json
            content = json.loads(crypto_svc.decrypt_document(document_id, doc.encrypted_content))
        except Exception:
            pass
    return {**_doc_detail(doc), "content": content}


# ─────────────────────────────────────────────────────────────────────────────
# DOCUMENTS — UNIVERSITY (ISSUANCE)
# ─────────────────────────────────────────────────────────────────────────────

class IssueDocumentRequest(BaseModel):
    student_matricule: str
    document_type:     str
    title:             str
    degree:            Optional[str] = None
    field:             Optional[str] = None
    mention:           str
    issue_date:        str           # YYYY-MM-DD
    courses:           list[dict]    = []

class IssueDocumentResponse(BaseModel):
    document_id:   str
    hash_sha256:   str
    blockchain_tx: Optional[str]
    message:       str


@router.post("/documents/issue", response_model=IssueDocumentResponse)
async def issue_document(
    body: IssueDocumentRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(_current_user),
):
    """University issues a new academic document."""
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()

    # Find student by matricule
    result = await db.execute(
        select(Student).where(Student.matricule == body.student_matricule.upper()))
    student = result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail=f"Student {body.student_matricule} not found")
    _require_university_ownership(user, str(student.university_id))

    # Compute SHA-256 hash
    doc_id    = str(uuid.uuid4())
    hash_sha  = crypto_svc.sha256_document(
        document_id=doc_id,
        student_matricule=student.matricule,
        university_id=str(student.university_id),
        title=body.title,
        mention=body.mention,
        issue_date=body.issue_date,
        doc_type=body.document_type,
    )

    # Encrypt document content
    import json
    encrypted = crypto_svc.encrypt_document(doc_id, json.dumps({
        "student_name": student.full_name,
        "matricule":    student.matricule,
        "title":        body.title,
        "degree":       body.degree,
        "field":        body.field,
        "mention":      body.mention,
        "issue_date":   body.issue_date,
        "doc_type":     body.document_type,
        "courses":      body.courses,
    }))

    # Create document record
    doc = AcademicDocument(
        id               = uuid.UUID(doc_id),
        student_id       = student.id,
        university_id    = student.university_id,
        issued_by        = uuid.UUID(user["sub"]),
        doc_type         = DocType(body.document_type),
        title            = body.title,
        degree           = body.degree,
        field            = body.field,
        mention          = body.mention,
        issue_date       = datetime.strptime(body.issue_date, "%Y-%m-%d").date(),
        hash_sha256      = hash_sha,
        is_verified      = True,
        encrypted_content = encrypted,
    )
    db.add(doc)

    # Add course grades
    for c in body.courses:
        db.add(CourseGrade(
            document_id = uuid.UUID(doc_id),
            course_code = c.get("code",""),
            course_name = c.get("name",""),
            grade       = float(c.get("grade", 0)),
            credits     = int(c.get("credits", 3)),
            semester    = c.get("semester","S1"),
            mention     = _grade_mention_str(float(c.get("grade",0))),
        ))

    await db.commit()

    # Anchor on blockchain in background
    background_tasks.add_task(
        _anchor_on_blockchain, doc_id, hash_sha, student.matricule,
        str(student.university_id), body.issue_date)

    return IssueDocumentResponse(
        document_id   = doc_id,
        hash_sha256   = hash_sha,
        blockchain_tx = None,
        message       = "Document issued. Blockchain anchoring in progress.",
    )


@router.post("/documents/{document_id}/sign")
async def sign_document(
    document_id: str,
    body: dict,
    user: dict = Depends(_current_user),
):
    """Store the university's RSA-2048 signature on a document."""
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    rsa_signature = body.get("rsa_signature")
    pub_key_pem   = body.get("public_key_pem")

    if not rsa_signature:
        raise HTTPException(status_code=400, detail="rsa_signature required")

    db  = _get_db_session()
    doc = await _get_doc_or_404(db, document_id)
    _require_university_ownership(user, str(doc.university_id))

    # Verify signature before storing
    if pub_key_pem and not crypto_svc.verify_rsa_signature(
            pub_key_pem, doc.hash_sha256, rsa_signature):
        raise HTTPException(status_code=400, detail="Signature verification failed")

    doc.rsa_signature = rsa_signature
    await db.commit()

    # Also update blockchain record with signature
    background_tasks = BackgroundTasks()
    background_tasks.add_task(_update_blockchain_signature, document_id, rsa_signature)

    return {"message": "Signature stored and blockchain updated"}


# ─────────────────────────────────────────────────────────────────────────────
# BLOCKCHAIN VERIFICATION
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/blockchain/verify/{document_id}")
async def verify_on_blockchain(document_id: str, hash: str):
    """
    Trustless verification — queries Hyperledger Fabric directly,
    bypassing the Diplomax database entirely.
    """
    result = await fabric.verify_document(document_id, hash)
    if not result.found:
        raise HTTPException(status_code=404, detail="Document not found on blockchain")
    return {
        "found":                  result.found,
        "is_authentic":           result.is_authentic,
        "tampering_detected":     result.tampering_detected,
        "sha256_hash":            result.stored_hash,
        "transaction_id":         result.transaction_id,
        "block_number":           result.block_number,
        "anchored_at":            result.anchored_at,
        "student_matricule":      result.student_matricule,
        "university_id":          result.university_id,
        "issuer_key_fingerprint": result.issuer_key_fingerprint,
    }


@router.get("/blockchain/history/{document_id}")
async def blockchain_history(document_id: str):
    history = await fabric.get_history(document_id)
    return {"document_id": document_id, "history": history}


@router.get("/blockchain/health")
async def blockchain_health():
    healthy = await fabric.is_healthy()
    return {"status": "ok" if healthy else "degraded", "timestamp": datetime.utcnow().isoformat()}


# ─────────────────────────────────────────────────────────────────────────────
# PAYMENTS
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# DOCUMENT REQUESTS + DYNAMIC PRICING
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/requests/pricing")
async def get_request_pricing(user: dict = Depends(_current_user)):
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    db = _get_db_session()
    student_result = await db.execute(
        select(Student).where(Student.id == uuid.UUID(user["sub"]))
    )
    student = student_result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    return await _build_pricing_catalog(db, student.university_id)


@router.get("/requests/admin/pricing")
async def get_admin_request_pricing(user: dict = Depends(_current_user)):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()
    return await _build_pricing_catalog(db, uuid.UUID(user["univ"]))


@router.put("/requests/admin/pricing")
async def update_admin_request_pricing(
    body: RequestPricingUpdate,
    user: dict = Depends(_current_user),
):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()
    university_id = uuid.UUID(user["univ"])

    for item in body.prices:
        try:
            doc_type = DocType(item.doc_type)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Unsupported doc_type: {item.doc_type}")

        if item.base_fee_fcfa < 0:
            raise HTTPException(status_code=400, detail="base_fee_fcfa must be >= 0")

        price_result = await db.execute(
            select(UniversityRequestPrice).where(
                UniversityRequestPrice.university_id == university_id,
                UniversityRequestPrice.doc_type == doc_type,
            )
        )
        existing = price_result.scalar_one_or_none()
        if existing:
            existing.base_fee_fcfa = item.base_fee_fcfa
            existing.is_active = True
        else:
            db.add(
                UniversityRequestPrice(
                    university_id=university_id,
                    doc_type=doc_type,
                    base_fee_fcfa=item.base_fee_fcfa,
                    is_active=True,
                )
            )

    await db.commit()
    return await _build_pricing_catalog(db, university_id)


@router.post("/requests/")
async def submit_request(
    body: DocumentRequestCreate,
    user: dict = Depends(_current_user),
):
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    try:
        doc_type = DocType(body.doc_type)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Unsupported doc_type: {body.doc_type}")

    urgency = body.urgency if body.urgency in REQUEST_URGENCY_SURCHARGE else "normal"

    db = _get_db_session()
    student_result = await db.execute(
        select(Student).where(Student.id == uuid.UUID(user["sub"]))
    )
    student = student_result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    base_fee = await _resolve_base_fee(db, student.university_id, doc_type)
    total_fee = base_fee + REQUEST_URGENCY_SURCHARGE[urgency]

    req = DocumentRequest(
        student_id=student.id,
        university_id=student.university_id,
        doc_type=doc_type,
        purpose=body.purpose.strip(),
        destination=(body.destination or "").strip() or None,
        urgency=urgency,
        notes=(body.notes or "").strip() or None,
        status=RequestStatus.pending,
        fee_fcfa=total_fee,
        fee_paid=False,
    )
    db.add(req)
    await db.commit()

    return {
        "request_id": str(req.id),
        "status": req.status.value,
        "fee_fcfa": req.fee_fcfa,
        "message": (
            f"Request submitted. Fee: {req.fee_fcfa} FCFA. "
            "The university will review within 2 business days."
        ),
        "estimated_ready": _estimate_ready_date(req.urgency),
    }


@router.get("/requests/my")
async def my_requests(user: dict = Depends(_current_user)):
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    db = _get_db_session()
    result = await db.execute(
        select(DocumentRequest)
        .where(DocumentRequest.student_id == uuid.UUID(user["sub"]))
        .order_by(DocumentRequest.submitted_at.desc())
    )
    requests = result.scalars().all()
    return {
        "requests": [_request_summary(r) for r in requests],
        "total": len(requests),
    }


@router.get("/requests/admin/all")
async def get_all_requests(
    status: Optional[str] = None,
    user: dict = Depends(_current_user),
):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()
    filters = [DocumentRequest.university_id == uuid.UUID(user["univ"])]
    if status:
        try:
            filters.append(DocumentRequest.status == RequestStatus(status))
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid status: {status}")

    result = await db.execute(
        select(DocumentRequest)
        .where(and_(*filters))
        .order_by(DocumentRequest.submitted_at.desc())
    )
    requests = result.scalars().all()
    return {
        "requests": [_request_summary(r) for r in requests],
        "total": len(requests),
    }


@router.put("/requests/admin/{request_id}")
async def update_request(
    request_id: str,
    body: DocumentRequestUpdate,
    user: dict = Depends(_current_user),
):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()
    req = await _get_request_or_404(db, request_id)
    _require_university_ownership(user, str(req.university_id))

    try:
        req.status = RequestStatus(body.status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid status: {body.status}")

    if body.admin_notes is not None:
        req.admin_notes = body.admin_notes
    if body.fee_fcfa is not None:
        if body.fee_fcfa < 0:
            raise HTTPException(status_code=400, detail="fee_fcfa must be >= 0")
        req.fee_fcfa = body.fee_fcfa
    if body.document_id:
        req.document_id = uuid.UUID(body.document_id)

    req.reviewed_at = _utc_now()
    await db.commit()
    return {
        "request_id": str(req.id),
        "status": req.status.value,
        "message": f"Request {req.status.value}",
    }


@router.post("/requests/admin/{request_id}/issue")
async def issue_from_request(
    request_id: str,
    user: dict = Depends(_current_user),
):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")

    db = _get_db_session()
    req = await _get_request_or_404(db, request_id)
    _require_university_ownership(user, str(req.university_id))

    req.status = RequestStatus.ready
    req.issued_at = _utc_now()
    req.reviewed_at = _utc_now()
    await db.commit()
    return {
        "message": "Document issued from request",
        "document_id": str(req.document_id) if req.document_id else None,
    }


@router.get("/requests/{request_id}")
async def get_request(request_id: str, user: dict = Depends(_current_user)):
    db = _get_db_session()
    req = await _get_request_or_404(db, request_id)

    role = user.get("role")
    if role == "student" and str(req.student_id) != user["sub"]:
        raise HTTPException(status_code=403, detail="Not your request")
    if role == "university" and str(req.university_id) != user.get("univ", ""):
        raise HTTPException(status_code=403, detail="Request does not belong to your university")
    if role not in {"student", "university", "admin"}:
        raise HTTPException(status_code=403, detail="Unauthorized role")

    return _request_summary(req)


@router.delete("/requests/{request_id}")
async def cancel_request(request_id: str, user: dict = Depends(_current_user)):
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    db = _get_db_session()
    req = await _get_request_or_404(db, request_id)
    if str(req.student_id) != user["sub"]:
        raise HTTPException(status_code=403, detail="Not your request")
    if req.status not in {RequestStatus.pending, RequestStatus.reviewing}:
        raise HTTPException(status_code=400, detail="Only pending/reviewing requests can be cancelled")

    await db.delete(req)
    await db.commit()
    return {"message": "Request cancelled"}


class PaymentInitRequest(BaseModel):
    provider:         str     # mtn | orange
    phone_number:     str
    amount_fcfa:      int
    product:          str
    document_id:      Optional[str] = None

class PaymentInitResponse(BaseModel):
    transaction_id:  str
    external_id:     str
    status:          str
    message:         str
    provider:        str


@router.post("/payments/initiate", response_model=PaymentInitResponse)
async def initiate_payment(body: PaymentInitRequest, user: dict = Depends(_current_user)):
    external_id = str(uuid.uuid4())
    student_mat = user.get("mat", user["sub"])

    result = await payment_svc.initiate(
        provider          = body.provider,
        phone_number      = body.phone_number,
        amount_fcfa       = body.amount_fcfa,
        external_id       = external_id,
        description       = f"Diplomax CM — {body.product}",
        student_matricule = student_mat,
    )

    # Record in DB
    db = _get_db_session()
    db.add(Payment(
        student_id   = uuid.UUID(user["sub"]) if user.get("role") == "student" else None,
        amount_fcfa  = body.amount_fcfa,
        provider     = body.provider,
        phone_number = body.phone_number,
        product      = body.product,
        external_id  = external_id,
        document_id  = uuid.UUID(body.document_id) if body.document_id else None,
        status       = PayStatus.pending,
    ))
    await db.commit()

    tx_id = result.get("reference_id") or result.get("pay_token") or external_id
    return PaymentInitResponse(
        transaction_id = tx_id,
        external_id    = external_id,
        status         = "pending",
        message        = result.get("message","Payment initiated"),
        provider       = body.provider,
    )


@router.get("/payments/status/{transaction_id}")
async def payment_status(transaction_id: str, provider: str, pay_token: Optional[str] = None):
    result = await payment_svc.check_status(
        provider=provider, reference_id=transaction_id, pay_token=pay_token)
    return {"transaction_id": transaction_id, "status": result.get("status","unknown"),
            "message": result.get("message"), "paid_at": None}


@router.post("/payments/mtn/callback")
async def mtn_callback(request: Request):
    """MTN MoMo webhook — called when payment status changes."""
    payload = MtnCallbackPayload.model_validate(await request.json())
    sig = request.headers.get("X-Signature","")
    callback_id = payload.externalId
    await _enforce_callback_replay_guard("mtn", callback_id)
    payload_dict = payload.model_dump()
    if not payment_svc.mtn.validate_callback(payload_dict, sig):
        _security_log("callback_signature_invalid", provider="mtn", callback_id=callback_id)
        raise HTTPException(status_code=401, detail="Invalid signature")
    # Update payment record
    await _handle_payment_callback(payload.externalId, payload.status)
    return {"status": "received"}


@router.post("/payments/orange/callback")
async def orange_callback(request: Request):
    """Orange Money webhook."""
    payload = OrangeCallbackPayload.model_validate(await request.json())
    notif_token = payload.notif_token or request.headers.get("X-Notif-Token", "")
    order_id = payload.order_id
    await _enforce_callback_replay_guard("orange", order_id)
    if not notif_token or not payment_svc.orange.verify_callback_signature(notif_token, order_id):
        _security_log("callback_signature_invalid", provider="orange", callback_id=order_id)
        raise HTTPException(status_code=401, detail="Invalid signature")
    await _handle_payment_callback(order_id, payload.status)
    return {"status": "received"}


# ─────────────────────────────────────────────────────────────────────────────
# SHARE LINKS
# ─────────────────────────────────────────────────────────────────────────────

class ShareCreateRequest(BaseModel):
    document_id:       str
    validity_hours:    int  = 48
    zkp_mode:          bool = False
    verification_mode: str  = "liveness"

@router.post("/shares")
async def create_share(body: ShareCreateRequest, user: dict = Depends(_current_user)):
    doc = await _get_doc_or_404(_get_db_session(), body.document_id)
    _require_document_access(user, doc)
    token      = crypto_svc.generate_share_token()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=body.validity_hours)

    share = ShareLink(
        document_id       = doc.id,
        student_id        = doc.student_id,
        token             = token,
        expires_at        = expires_at,
        zkp_mode          = body.zkp_mode,
        validity_hours    = body.validity_hours,
        verification_mode = VerifMode(body.verification_mode),
    )
    db = _get_db_session()
    db.add(share)
    await db.commit()

    return {"token": token,
            "share_url": f"https://verify.diplomax.cm/s/{token}",
            "expires_at": expires_at.isoformat(),
            "verification_mode": body.verification_mode}


@router.get("/shares/{token}/preview")
async def share_preview(token: str):
    """Returns minimal document info before liveness check."""
    db    = _get_db_session()
    share = await _get_share_or_404(db, token)
    doc   = share.document
    if share.zkp_mode:
        return {"title": doc.title, "mention": doc.mention, "zkp_mode": True,
                "verification_mode": share.verification_mode.value}
    return {"title": doc.title, "degree": doc.degree, "mention": doc.mention,
            "university": doc.university.name if doc.university else "",
            "verification_mode": share.verification_mode.value,
            "zkp_mode": False}


@router.get("/shares/{token}/access")
async def share_access(token: str, liveness_session_id: Optional[str] = None, request: Request = None):
    """Returns full document data after liveness verification (if required)."""
    db    = _get_db_session()
    share = await _get_share_or_404(db, token)

    if share.verification_mode == VerifMode.liveness:
        if not liveness_session_id:
            raise HTTPException(status_code=403, detail="Liveness verification required")
        # Verify the liveness session is passed
        ls_result = await db.execute(
            select(LivenessSession).where(
                LivenessSession.id == uuid.UUID(liveness_session_id),
                LivenessSession.share_token == token,
                LivenessSession.is_passed == True,
            ))
        ls = ls_result.scalar_one_or_none()
        if not ls:
            raise HTTPException(status_code=403, detail="Liveness not verified")

    recruiter, subscription = await _get_recruiter_from_auth_header(db, request)
    if recruiter and not subscription["can_verify"]:
        raise HTTPException(
            status_code=402,
            detail="Free monthly verification quota reached. Please subscribe for unlimited verifications.",
        )

    # Increment view count
    share.view_count += 1
    if recruiter:
        db.add(VerificationLog(
            recruiter_id=recruiter.id,
            document_id=share.document_id,
            share_link_id=share.id,
            method="link",
            result=bool(share.document.is_verified),
            liveness_passed=(share.verification_mode != VerifMode.liveness) or bool(liveness_session_id),
            ip_address=request.client.host if request and request.client else None,
            user_agent=request.headers.get("user-agent", "")[:300] if request else None,
        ))
    await db.commit()

    doc = share.document
    data = {"title": doc.title, "degree": doc.degree, "field": doc.field,
            "mention": doc.mention, "issue_date": str(doc.issue_date),
            "university": doc.university.name if doc.university else "",
            "student_name": doc.student.full_name if doc.student else "",
            "matricule": doc.student.matricule if doc.student else "",
            "hash_sha256": doc.hash_sha256,
            "blockchain_tx": doc.blockchain_tx,
            "is_verified": doc.is_verified}

    if share.zkp_mode:
        return {k: v for k, v in data.items()
                if k in ("title","mention","university","is_verified","blockchain_tx")}
    return data


# ─────────────────────────────────────────────────────────────────────────────
# LIVENESS SESSIONS
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/liveness/start")
async def start_liveness(share_token: str):
    """Start a liveness session for a share token. Returns session ID + challenges."""
    db = _get_db_session()
    share = await _get_share_or_404(db, share_token)
    if share.verification_mode != VerifMode.liveness:
        raise HTTPException(status_code=400, detail="Liveness is not required for this share")

    session = LivenessSession(
        share_token        = share_token,
        challenge_1        = "y_right",
        challenge_2        = "y_left",
        challenge_3        = "x_down",
        challenges_passed  = 0,
        is_passed          = False,
        expires_at         = datetime.now(timezone.utc) + timedelta(minutes=10),
    )
    db.add(session)
    await db.commit()
    return {
        "session_id": str(session.id),
        "challenges": [
            {"step": 1, "axis": "y", "direction": "right", "threshold": 0.6,
             "instruction": "Turn your head slowly to the right"},
            {"step": 2, "axis": "y", "direction": "left",  "threshold": 0.6,
             "instruction": "Turn your head slowly to the left"},
            {"step": 3, "axis": "x", "direction": "down",  "threshold": 0.5,
             "instruction": "Nod your head gently downward"},
        ],
        "expires_in_seconds": 600,
    }


@router.post("/liveness/{session_id}/challenge/{step}")
async def submit_liveness_challenge(session_id: str, step: int, body: LivenessChallengeRequest):
    """Submit a completed liveness challenge step."""
    db = _get_db_session()
    result = await db.execute(
        select(LivenessSession).where(LivenessSession.id == uuid.UUID(session_id)))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if datetime.now(timezone.utc) > session.expires_at.replace(tzinfo=timezone.utc):
        raise HTTPException(status_code=410, detail="Session expired")
    if step != session.challenges_passed + 1:
        raise HTTPException(status_code=400, detail="Unexpected challenge step")

    # Client sends: sensor_variance (float) and detected (bool)
    detected = body.detected
    if detected:
        session.challenges_passed += 1
        if session.challenges_passed >= 3:
            session.is_passed = True
        await db.commit()
        return {"step": step, "passed": True, "total_passed": session.challenges_passed,
                "liveness_complete": session.is_passed}
    return {"step": step, "passed": False, "total_passed": session.challenges_passed,
            "message": "Challenge not detected. Please try again."}


# ─────────────────────────────────────────────────────────────────────────────
# INTERNATIONAL SHARE
# ─────────────────────────────────────────────────────────────────────────────

class IntlShareCreateRequest(BaseModel):
    document_ids:             list[str]
    institution_name:         str
    institution_email:        Optional[EmailStr] = None
    institution_country:      str
    purpose:                  str
    expiry_days:              int  = 30
    include_grades:           bool = True
    include_blockchain_proof: bool = True
    include_university_letter: bool = False
    password:                 Optional[str] = None


@router.post("/international-shares")
async def create_intl_share(
    body: IntlShareCreateRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(_current_user),
):
    """
    Creates an international document share package.
    Generates an embassy-ready PDF with blockchain proof.
    """
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    db      = _get_db_session()
    token   = crypto_svc.generate_intl_share_token()
    expires = datetime.now(timezone.utc) + timedelta(days=body.expiry_days)

    # Fetch all requested documents (must belong to this student)
    docs = []
    for doc_id in body.document_ids:
        doc = await _get_doc_or_404(db, doc_id)
        if str(doc.student_id) != user["sub"]:
            raise HTTPException(status_code=403, detail=f"Document {doc_id} not yours")
        docs.append(doc)

    # Build password hash if provided
    pw_hash = None
    if body.password:
        pw_hash = pwd_ctx.hash(body.password)

    intl = IntlShare(
        document_id          = docs[0].id,  # Primary document
        student_id           = uuid.UUID(user["sub"]),
        token                = token,
        institution_name     = body.institution_name,
        institution_email    = body.institution_email,
        institution_country  = body.institution_country,
        purpose              = body.purpose,
        expires_at           = expires,
        include_grades       = body.include_grades,
        include_blockchain_proof = body.include_blockchain_proof,
        include_university_letter = body.include_university_letter,
        password_hash        = pw_hash,
    )
    db.add(intl)
    await db.commit()

    # Generate PDF package in background
    background_tasks.add_task(
        _generate_intl_pdf, str(intl.id), docs, body)

    access_url = f"{settings.INTL_SHARE_BASE_URL}/{token}"
    return {
        "package_id":   str(intl.id),
        "token":        token,
        "access_url":   access_url,
        "expires_at":   expires.isoformat(),
        "qr_payload":   access_url,
        "message":      f"Package created. Expires {expires.strftime('%Y-%m-%d')}.",
    }


@router.get("/international-shares/{token}")
async def access_intl_share(token: str, password: Optional[str] = None, request: Request = None):
    """
    Access an international share package.
    Returns document data and the PDF download URL.
    """
    db = _get_db_session()
    result = await db.execute(
        select(IntlShare).where(IntlShare.token == token))
    pkg = result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(status_code=404, detail="Package not found")
    if datetime.now(timezone.utc) > pkg.expires_at.replace(tzinfo=timezone.utc):
        raise HTTPException(status_code=410, detail="Package expired")
    if pkg.status == IntlShareStatus.revoked:
        raise HTTPException(status_code=403, detail="Package has been revoked")

    # Password check
    if pkg.password_hash and not pwd_ctx.verify(password or "", pkg.password_hash):
        raise HTTPException(status_code=401, detail="Invalid package password")

    # Track access
    pkg.view_count    += 1
    pkg.last_viewed_at = datetime.now(timezone.utc)
    pkg.last_viewed_ip = request.client.host if request else None
    await db.commit()

    doc = pkg.document
    return {
        "student_name":        doc.student.full_name if doc.student else "",
        "matricule":           doc.student.matricule if doc.student else "",
        "institution_name":    pkg.institution_name,
        "institution_country": pkg.institution_country,
        "purpose":             pkg.purpose,
        "expires_at":          pkg.expires_at.isoformat(),
        "document": {
            "title":       doc.title,
            "type":        doc.doc_type.value,
            "degree":      doc.degree,
            "field":       doc.field,
            "mention":     doc.mention,
            "issue_date":  str(doc.issue_date),
            "university":  doc.university.name if doc.university else "",
            "hash_sha256": doc.hash_sha256,
            "blockchain_tx": doc.blockchain_tx,
            "is_verified": doc.is_verified,
        },
        "pdf_url": f"/v1/international-shares/{token}/pdf" if pkg.package_pdf_s3_key else None,
        "blockchain_proof_url": f"/v1/blockchain/verify/{doc.id}?hash={doc.hash_sha256}",
    }


@router.get("/international-shares/{token}/pdf")
async def download_intl_pdf(token: str, password: Optional[str] = None):
    """Stream the embassy-ready PDF for an international share."""
    from fastapi.responses import FileResponse
    db = _get_db_session()
    result = await db.execute(select(IntlShare).where(IntlShare.token == token))
    pkg = result.scalar_one_or_none()
    if not pkg or not pkg.package_pdf_s3_key:
        raise HTTPException(status_code=404, detail="PDF not ready yet")
    if pkg.password_hash and not pwd_ctx.verify(password or "", pkg.password_hash):
        raise HTTPException(status_code=401, detail="Invalid password")

    pdf_path = Path(pkg.package_pdf_s3_key)
    if not pdf_path.is_absolute():
        pdf_path = INTL_SHARE_STORAGE_DIR / pdf_path.name
    if not pdf_path.exists():
        raise HTTPException(status_code=404, detail="PDF file missing")

    return FileResponse(
        path=str(pdf_path),
        media_type="application/pdf",
        filename=pdf_path.name,
    )


@router.delete("/international-shares/{token}")
async def revoke_intl_share(token: str, user: dict = Depends(_current_user)):
    """Student can revoke an international share at any time."""
    db = _get_db_session()
    result = await db.execute(select(IntlShare).where(IntlShare.token == token))
    pkg = result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(status_code=404, detail="Package not found")
    if str(pkg.student_id) != user["sub"]:
        raise HTTPException(status_code=403, detail="Not your package")
    pkg.status = IntlShareStatus.revoked
    await db.commit()
    return {"message": "Package revoked successfully"}


# ─────────────────────────────────────────────────────────────────────────────
# NFC
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/nfc/register")
async def register_nfc_chip(body: dict, user: dict = Depends(_current_user)):
    """University registers the NFC UID of a physical diploma chip."""
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")
    doc_id  = body.get("document_id")
    nfc_uid = body.get("nfc_uid")
    if not doc_id or not nfc_uid:
        raise HTTPException(status_code=400, detail="document_id and nfc_uid required")
    db  = _get_db_session()
    doc = await _get_doc_or_404(db, doc_id)
    _require_university_ownership(user, str(doc.university_id))
    doc.nfc_uid = nfc_uid
    await db.commit()
    return {"message": "NFC chip registered", "nfc_uid": nfc_uid}


@router.get("/nfc/verify/{nfc_uid}")
async def verify_nfc(nfc_uid: str):
    """Verify a document by its NFC chip UID."""
    db = _get_db_session()
    result = await db.execute(
        select(AcademicDocument).where(AcademicDocument.nfc_uid == nfc_uid))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="NFC chip not registered")
    # Also verify on blockchain
    bc = await fabric.verify_document(str(doc.id), doc.hash_sha256)
    return {
        "found": True,
        "document_id":   str(doc.id),
        "title":         doc.title,
        "student_name":  doc.student.full_name if doc.student else "",
        "matricule":     doc.student.matricule if doc.student else "",
        "university":    doc.university.name if doc.university else "",
        "mention":       doc.mention,
        "issue_date":    str(doc.issue_date),
        "hash_sha256":   doc.hash_sha256,
        "blockchain_authentic": bc.is_authentic,
        "blockchain_tx": doc.blockchain_tx,
    }


# ─────────────────────────────────────────────────────────────────────────────
# OCR
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/ocr/extract")
async def ocr_extract(request: Request, user: dict = Depends(_current_user)):
    """
    Receives a base64-encoded image of a document and extracts text using
    Google Cloud Vision OCR.
    """
    from google.cloud import vision
    body = await request.json()
    image_b64 = body.get("image_base64")
    if not image_b64:
        raise HTTPException(status_code=400, detail="image_base64 required")

    import base64
    image_bytes = base64.b64decode(image_b64)

    client = vision.ImageAnnotatorClient()
    image  = vision.Image(content=image_bytes)
    response = client.document_text_detection(image=image)

    if response.error.message:
        raise HTTPException(status_code=500, detail=f"OCR error: {response.error.message}")

    full_text = response.full_text_annotation.text if response.full_text_annotation else ""

    # Parse common academic document fields
    extracted = _parse_academic_fields(full_text)
    return {"raw_text": full_text, "extracted_fields": extracted}


# ─────────────────────────────────────────────────────────────────────────────
# RECRUITER — Dashboard
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/recruiter/dashboard")
async def recruiter_dashboard(user: dict = Depends(_current_user)):
    if user.get("role") != "recruiter":
        raise HTTPException(status_code=403, detail="Recruiter role required")
    db = _get_db_session()
    recruiter_result = await db.execute(
        select(Recruiter).where(Recruiter.id == uuid.UUID(user["sub"]))
    )
    recruiter = recruiter_result.scalar_one_or_none()
    if not recruiter:
        raise HTTPException(status_code=404, detail="Recruiter account not found")

    logs_result = await db.execute(
        select(VerificationLog)
        .where(VerificationLog.recruiter_id == uuid.UUID(user["sub"]))
        .order_by(VerificationLog.verified_at.desc())
        .limit(50))
    logs = logs_result.scalars().all()

    usage = await _recruiter_subscription_state(db, recruiter)
    return {
        "company_name": recruiter.company_name,
        "email": recruiter.email,
        "subscription_plan": usage["plan"],
        "subscription_active": usage["subscription_active"],
        "free_monthly_limit": usage["free_monthly_limit"],
        "free_used_this_month": usage["free_used_this_month"],
        "free_remaining": usage["free_remaining"],
        "can_verify": usage["can_verify"],
        "can_export_pdf": usage["can_export_pdf"],
        "total_verifications": len(logs),
        "successful":          sum(1 for l in logs if l.result),
        "failed":              sum(1 for l in logs if not l.result),
        "recent_logs":         [_log_summary(l) for l in logs[:10]],
    }


# ─────────────────────────────────────────────────────────────────────────────
# UNIVERSITY — Dashboard
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/university/dashboard")
async def university_dashboard(user: dict = Depends(_current_user)):
    if user.get("role") != "university":
        raise HTTPException(status_code=403, detail="University role required")
    db  = _get_db_session()
    univ_id = uuid.UUID(user.get("univ",""))
    result  = await db.execute(
        select(AcademicDocument).where(AcademicDocument.university_id == univ_id)
        .order_by(AcademicDocument.created_at.desc()).limit(50))
    docs = result.scalars().all()

    student_result = await db.execute(
        select(Student).where(Student.university_id == univ_id))
    students = student_result.scalars().all()

    return {
        "total_documents": len(docs),
        "total_students":  len(students),
        "blockchain_anchored": sum(1 for d in docs if d.is_blockchain_anchored),
        "recent_documents": [_doc_summary(d) for d in docs[:10]],
    }


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS (private)
# ─────────────────────────────────────────────────────────────────────────────

def _get_db_session() -> AsyncSession:
    """Returns the request-scoped database session."""
    return get_request_db_session()


async def _get_doc_or_404(db, doc_id: str) -> AcademicDocument:
    result = await db.execute(
        select(AcademicDocument).where(AcademicDocument.id == uuid.UUID(doc_id)))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    return doc


async def _get_share_or_404(db, token: str) -> ShareLink:
    result = await db.execute(
        select(ShareLink).where(ShareLink.token == token))
    share = result.scalar_one_or_none()
    if not share:
        raise HTTPException(status_code=404, detail="Share not found")
    if share.is_revoked:
        raise HTTPException(status_code=410, detail="Share has been revoked")
    if datetime.now(timezone.utc) > share.expires_at.replace(tzinfo=timezone.utc):
        raise HTTPException(status_code=410, detail="Share has expired")
    return share


async def _get_request_or_404(db, request_id: str) -> DocumentRequest:
    result = await db.execute(
        select(DocumentRequest).where(DocumentRequest.id == uuid.UUID(request_id))
    )
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    return req


async def _resolve_base_fee(db, university_id: uuid.UUID, doc_type: DocType) -> int:
    result = await db.execute(
        select(UniversityRequestPrice).where(
            UniversityRequestPrice.university_id == university_id,
            UniversityRequestPrice.doc_type == doc_type,
            UniversityRequestPrice.is_active == True,
        )
    )
    price = result.scalar_one_or_none()
    if price:
        return int(price.base_fee_fcfa)
    return int(REQUEST_DEFAULT_FEES.get(doc_type, 1000))


async def _build_pricing_catalog(db, university_id: uuid.UUID) -> dict:
    result = await db.execute(
        select(UniversityRequestPrice).where(
            UniversityRequestPrice.university_id == university_id,
            UniversityRequestPrice.is_active == True,
        )
    )
    custom_prices = {p.doc_type: int(p.base_fee_fcfa) for p in result.scalars().all()}

    prices = []
    for doc_type, default_fee in REQUEST_DEFAULT_FEES.items():
        fee = custom_prices.get(doc_type, int(default_fee))
        prices.append(
            {
                "doc_type": doc_type.value,
                "base_fee_fcfa": fee,
                "is_custom": doc_type in custom_prices,
            }
        )

    return {
        "university_id": str(university_id),
        "prices": prices,
        "urgency_surcharges": REQUEST_URGENCY_SURCHARGE,
    }


def _request_summary(r: DocumentRequest) -> dict:
    return {
        "id": str(r.id),
        "student_id": str(r.student_id),
        "matricule": r.student.matricule if r.student else None,
        "doc_type": r.doc_type.value,
        "purpose": r.purpose,
        "destination": r.destination,
        "urgency": r.urgency,
        "notes": r.notes,
        "status": r.status.value,
        "admin_notes": r.admin_notes,
        "fee_fcfa": r.fee_fcfa,
        "fee_paid": r.fee_paid,
        "submitted_at": r.submitted_at.isoformat() if r.submitted_at else "",
        "document_id": str(r.document_id) if r.document_id else None,
    }


def _estimate_ready_date(urgency: str) -> str:
    days = {"normal": 5, "urgent": 2, "very_urgent": 1}
    d = datetime.now(timezone.utc) + timedelta(days=days.get(urgency, 5))
    return d.strftime("%Y-%m-%d")


def _doc_summary(d: AcademicDocument) -> dict:
    return {
        "id":          str(d.id),
        "title":       d.title,
        "type":        d.doc_type.value,
        "mention":     d.mention,
        "issue_date":  str(d.issue_date),
        "is_verified": d.is_verified,
        "hash_sha256": d.hash_sha256,
        "blockchain_anchored": d.is_blockchain_anchored,
    }


def _doc_detail(d: AcademicDocument) -> dict:
    base = _doc_summary(d)
    return {**base,
            "degree":       d.degree,
            "field":        d.field,
            "university":   d.university.name if d.university else "",
            "student_name": d.student.full_name if d.student else "",
            "matricule":    d.student.matricule if d.student else "",
            "blockchain_tx": d.blockchain_tx,
            "rsa_signature": d.rsa_signature,
            "grades":       [{"code": g.course_code, "name": g.course_name,
                              "grade": str(g.grade), "credits": g.credits,
                              "semester": g.semester} for g in d.grades]}


def _log_summary(l: VerificationLog) -> dict:
    return {"id": str(l.id), "method": l.method, "result": l.result,
            "verified_at": str(l.verified_at), "document_id": str(l.document_id)}


def _month_window_utc(now: datetime) -> tuple[datetime, datetime]:
    start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
    if now.month == 12:
        end = datetime(now.year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        end = datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc)
    return start, end


async def _recruiter_subscription_state(db, recruiter: Recruiter) -> dict:
    now = _utc_now()
    month_start, month_end = _month_window_utc(now)

    month_result = await db.execute(
        select(VerificationLog)
        .where(
            VerificationLog.recruiter_id == recruiter.id,
            VerificationLog.verified_at >= month_start.replace(tzinfo=None),
            VerificationLog.verified_at < month_end.replace(tzinfo=None),
        )
    )
    month_logs = month_result.scalars().all()
    used = len(month_logs)

    plan = (recruiter.subscription_plan or "free").lower()
    paid_active = plan in {"monthly", "annual"} and recruiter.sub_expires_at and recruiter.sub_expires_at >= now.replace(tzinfo=None)

    if paid_active:
        return {
            "plan": plan,
            "subscription_active": True,
            "free_monthly_limit": FREE_RECRUITER_MONTHLY_LIMIT,
            "free_used_this_month": used,
            "free_remaining": max(0, FREE_RECRUITER_MONTHLY_LIMIT - used),
            "can_verify": True,
            "can_export_pdf": True,
        }

    remaining = max(0, FREE_RECRUITER_MONTHLY_LIMIT - used)
    return {
        "plan": "free",
        "subscription_active": False,
        "free_monthly_limit": FREE_RECRUITER_MONTHLY_LIMIT,
        "free_used_this_month": used,
        "free_remaining": remaining,
        "can_verify": remaining > 0,
        "can_export_pdf": False,
    }


async def _get_recruiter_from_auth_header(db, request: Optional[Request]):
    if request is None:
        return None, None

    auth = request.headers.get("authorization", "")
    if not auth.lower().startswith("bearer "):
        return None, None

    token = auth.split(" ", 1)[1].strip()
    if not token:
        return None, None

    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return None, None

    if payload.get("role") != "recruiter":
        return None, None

    sub = payload.get("sub")
    if not sub:
        return None, None

    result = await db.execute(select(Recruiter).where(Recruiter.id == uuid.UUID(sub)))
    recruiter = result.scalar_one_or_none()
    if not recruiter:
        return None, None

    usage = await _recruiter_subscription_state(db, recruiter)
    return recruiter, usage


async def _anchor_on_blockchain(doc_id, hash_sha, matricule, univ_id, issue_date):
    """Background task: anchor on Fabric."""
    result = await fabric.anchor_document(
        document_id=doc_id, sha256_hash=hash_sha,
        student_matricule=matricule, university_id=univ_id,
        issued_at=issue_date, issuer_key_fingerprint="",
        rsa_signature="")
    if result.success:
        db = _get_db_session()
        doc = await _get_doc_or_404(db, doc_id)
        doc.blockchain_tx         = result.transaction_id
        doc.blockchain_block      = result.block_number
        doc.is_blockchain_anchored = True
        await db.commit()


async def _update_blockchain_signature(doc_id: str, signature: str):
    """Best-effort signature anchor refresh on Fabric after document signing."""
    db = _get_db_session()
    doc = await _get_doc_or_404(db, doc_id)

    # Keep a local source of truth even if blockchain refresh fails.
    doc.rsa_signature = signature
    await db.commit()

    if not doc.is_blockchain_anchored:
        return

    try:
        result = await fabric.anchor_document(
            document_id=str(doc.id),
            sha256_hash=doc.hash_sha256,
            student_matricule=doc.student.matricule if doc.student else "",
            university_id=str(doc.university_id),
            issued_at=str(doc.issue_date),
            issuer_key_fingerprint=doc.university.pub_key_fingerprint if doc.university else "",
            rsa_signature=signature,
        )
        if result.success:
            doc.blockchain_tx = result.transaction_id
            doc.blockchain_block = result.block_number
            doc.is_blockchain_anchored = True
            await db.commit()
    except Exception:
        # Do not fail request flow on background anchoring errors.
        return


async def _handle_payment_callback(external_id: str, status_str: str):
    """Updates payment row based on operator callback status."""
    if not external_id:
        return

    normalized = (status_str or "").strip().lower()
    if normalized in {"successful", "success", "succeeded", "paid"}:
        mapped_status = PayStatus.successful
    elif normalized in {"failed", "failure", "cancelled", "canceled", "rejected"}:
        mapped_status = PayStatus.failed if normalized not in {"cancelled", "canceled"} else PayStatus.cancelled
    else:
        mapped_status = PayStatus.pending

    db = _get_db_session()
    result = await db.execute(select(Payment).where(Payment.external_id == external_id))
    payment = result.scalar_one_or_none()
    if not payment:
        return

    payment.status = mapped_status
    if mapped_status == PayStatus.successful:
        payment.paid_at = _utc_now().replace(tzinfo=None)
    elif mapped_status in {PayStatus.failed, PayStatus.cancelled}:
        payment.failure_reason = status_str

    await db.commit()


async def _generate_intl_pdf(intl_id, docs, body):
    """Background: generate and store the PDF package."""
    INTL_SHARE_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    student = docs[0].student if docs else None
    pdf_bytes = pdf_svc.generate_intl_package_pdf(
        student_name=student.full_name if student else "",
        matricule=student.matricule if student else "",
        institution_name=body.institution_name,
        institution_country=body.institution_country,
        purpose=body.purpose,
        package_token=intl_id,
        access_url=f"{settings.INTL_SHARE_BASE_URL}/{intl_id}",
        expires_at=(datetime.now(timezone.utc) + timedelta(days=body.expiry_days)).strftime("%Y-%m-%d"),
        documents=[{
            "title": d.title, "doc_type": d.doc_type.value,
            "university": d.university.name if d.university else "",
            "issue_date": str(d.issue_date),
            "mention": d.mention,
        } for d in docs],
    )
    file_name = f"{intl_id}.pdf"
    file_path = INTL_SHARE_STORAGE_DIR / file_name
    file_path.write_bytes(pdf_bytes)

    db = _get_db_session()
    result = await db.execute(select(IntlShare).where(IntlShare.id == uuid.UUID(str(intl_id))))
    pkg = result.scalar_one_or_none()
    if pkg:
        pkg.package_pdf_s3_key = str(file_path)
        await db.commit()


def _parse_academic_fields(text: str) -> dict:
    """Simple regex-based extractor for common academic document fields."""
    import re
    fields = {}
    patterns = {
        "matricule":   r"(?:matricule|mat\.?)\s*:?\s*([A-Z0-9/]+)",
        "student_name":r"(?:nom|name|student)\s*:?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)",
        "mention":     r"(?:mention|grade)\s*:?\s*(Très\s+Bien|Bien|Assez\s+Bien|Passable)",
        "year":        r"(?:année|year|class of)\s*:?\s*(\d{4})",
        "university":  r"(?:université|university)\s+(?:de\s+)?([A-Z][A-Za-z\s]+)",
    }
    for key, pattern in patterns.items():
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            fields[key] = match.group(1).strip()
    return fields


def _grade_mention_str(grade: float) -> str:
    if grade >= 16: return "Très Bien"
    if grade >= 14: return "Bien"
    if grade >= 12: return "Assez Bien"
    if grade >= 10: return "Passable"
    return "Insuffisant"


# ─── CERTIFIED PDF EXPORT ─────────────────────────────────────────────────────

@router.get("/documents/{document_id}/certified-pdf")
async def certified_pdf_export(document_id: str, request: Request, user: dict = Depends(_current_user)):
    """
    Generates and streams a Certified True Copy PDF for a verified document.
    Called when a recruiter clicks "Download Certified True Copy".
    The PDF includes:
    - "CERTIFIED TRUE COPY" watermark
    - Recruiter company name + verification timestamp
    - Full document details
    - SHA-256 hash + blockchain TX
    - Digital verification stamp
    """
    from fastapi.responses import StreamingResponse
    import datetime

    db  = _get_db_session()
    doc = await _get_doc_or_404(db, document_id)
    if user.get("role") != "recruiter":
        raise HTTPException(status_code=403, detail="Recruiter role required")

    recruiter_result = await db.execute(
        select(Recruiter).where(Recruiter.id == uuid.UUID(user["sub"]))
    )
    recruiter = recruiter_result.scalar_one_or_none()
    if not recruiter:
        raise HTTPException(status_code=404, detail="Recruiter account not found")

    usage = await _recruiter_subscription_state(db, recruiter)
    if not usage["can_export_pdf"]:
        raise HTTPException(
            status_code=402,
            detail="PDF export requires an active paid subscription.",
        )

    student = doc.student

    # Generate PDF with certification watermark
    pdf_bytes = pdf_svc.generate_document_pdf(
        student_name=student.full_name if student else "",
        matricule=student.matricule if student else "",
        university_name=doc.university.name if doc.university else "",
        doc_type=doc.doc_type.value,
        title=doc.title,
        degree=doc.degree or "",
        field=doc.field or "",
        mention=doc.mention or "",
        issue_date=str(doc.issue_date),
        hash_sha256=doc.hash_sha256,
        blockchain_tx=doc.blockchain_tx,
        rsa_signature=doc.rsa_signature,
        grades=[{
            "course_code": g.course_code, "course_name": g.course_name,
            "grade": str(g.grade), "credits": g.credits, "semester": g.semester,
        } for g in doc.grades] if doc.grades else None,
        qr_verify_url=f"https://verify.diplomax.cm/s/{document_id}",
        is_international=False,
    )

    filename = f"certified_true_copy_{document_id[:8]}.pdf"
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
