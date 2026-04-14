"""
Diplomax CM Backend — FastAPI Application Entry Point
"""
from contextlib import asynccontextmanager
import logging
from typing import AsyncGenerator

import redis.asyncio as redis
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import set_request_db_session, reset_request_db_session
from app.models.models import Base
from app.api.v1.endpoints.router import router as api_router

settings = get_settings()
logger = logging.getLogger(__name__)

# ─── Database Engine ──────────────────────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    poolclass=NullPool,
    pool_pre_ping=True,
)
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

# ─── Redis ────────────────────────────────────────────────────────────────────
redis_pool: redis.Redis = None


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator:
    """Startup and shutdown events."""
    global redis_pool
    # Best-effort startup: keep the API bootable even if backing services are temporarily unreachable.
    try:
        # Create all tables when the database is reachable.
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            # Backward-compatible self-healing for old recruiter table schemas.
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS phone VARCHAR(20)"
            ))
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS subscription_plan VARCHAR(50) DEFAULT 'free'"
            ))
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS sub_expires_at TIMESTAMP"
            ))
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE"
            ))
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS fcm_token TEXT"
            ))
            await conn.execute(text(
                "ALTER TABLE IF EXISTS recruiters "
                "ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT now()"
            ))
    except Exception as exc:
        logger.warning("Database initialization skipped during startup: %s", exc)

    try:
        # Connect Redis only if the endpoint is reachable.
        redis_pool = redis.from_url(settings.REDIS_URL, decode_responses=True)
        await redis_pool.ping()
    except Exception as exc:
        logger.warning("Redis initialization skipped during startup: %s", exc)
        redis_pool = None

    try:
        # Seed ICT University only when the database is available.
        async with AsyncSessionLocal() as db:
            await _seed_ict_university(db)
    except Exception as exc:
        logger.warning("Database seeding skipped during startup: %s", exc)

    yield

    # Shutdown
    if redis_pool is not None:
        await redis_pool.aclose()
    await engine.dispose()


# ─── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Diplomax CM — Secure Academic Certification Platform for Cameroon",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# ─── Middleware ───────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=[
        "api.diplomax.cm",
        "diplomax-backend.onrender.com",
        "*.onrender.com",
        "localhost",
        "127.0.0.1",
    ],
)


@app.middleware("http")
async def request_db_session_middleware(request: Request, call_next):
    session = AsyncSessionLocal()
    token = set_request_db_session(session)
    try:
        response = await call_next(request)
        return response
    finally:
        reset_request_db_session(token)
        await session.close()


# ─── DB Dependency ────────────────────────────────────────────────────────────
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ─── Routers ──────────────────────────────────────────────────────────────────
app.include_router(api_router, prefix="/v1")


# ─── Health check ─────────────────────────────────────────────────────────────
@app.get("/healthz")
async def health():
    return {"status": "ok", "version": settings.APP_VERSION}


@app.get("/")
async def root():
    return {"service": "Diplomax CM API", "version": settings.APP_VERSION,
            "docs": "/docs" if settings.DEBUG else "disabled in production"}


# ─── Global exception handler ─────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    if settings.DEBUG:
        raise exc
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


# ─── Seed ─────────────────────────────────────────────────────────────────────
async def _seed_ict_university(db: AsyncSession):
    """Creates the ICT University record if it doesn't exist."""
    from sqlalchemy import select
    from app.models.models import University
    result = await db.execute(
        select(University).where(University.id == settings.ICT_UNIVERSITY_ID))
    if result.scalar_one_or_none():
        return
    from passlib.context import CryptContext
    from app.models.models import UniversityStaff, Student
    import uuid

    pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

    if not settings.DEFAULT_ICT_ADMIN_PASSWORD or not settings.DEFAULT_STUDENT_PASSWORD:
        raise RuntimeError(
            "DEFAULT_ICT_ADMIN_PASSWORD and DEFAULT_STUDENT_PASSWORD must be set explicitly"
        )

    univ = University(
        id          = uuid.UUID("00000000-0000-0000-0000-000000000001"),
        name        = "The ICT University",
        short_name  = "ICT",
        city        = "Yaoundé",
        is_connected = True,
    )
    db.add(univ)

    # Default admin staff
    staff = UniversityStaff(
        university_id = univ.id,
        full_name     = "ICT Admin",
        email         = "admin@ictuniversity.cm",
        password_hash = pwd_ctx.hash(settings.DEFAULT_ICT_ADMIN_PASSWORD),
        role          = "admin",
    )
    db.add(staff)

    # Reference student: Nguend Arthur Johann — ICTU20223180
    student = Student(
        university_id = univ.id,
        full_name     = "Nguend Arthur Johann",
        matricule     = "ICTU20223180",
        email         = "nguend.arthur@ictuniversity.cm",
        password_hash = pwd_ctx.hash(settings.DEFAULT_STUDENT_PASSWORD),
        phone         = "+237699000000",
        is_active     = True,
    )
    db.add(student)

    await db.commit()


# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=settings.DEBUG)
