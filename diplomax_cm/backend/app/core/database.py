"""
Diplomax CM — Database session management.
Provides the async SQLAlchemy session factory and the FastAPI dependency.
"""
from contextvars import ContextVar, Token
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession, async_sessionmaker, create_async_engine
)
from sqlalchemy.pool import NullPool

from app.core.config import get_settings

settings = get_settings()

request_db_session: ContextVar[AsyncSession | None] = ContextVar("request_db_session", default=None)

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
    autoflush=False,
    autocommit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI dependency — injects a database session into each request.
    Usage: db: AsyncSession = Depends(get_db)
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


def set_request_db_session(session: AsyncSession) -> Token[AsyncSession | None]:
    return request_db_session.set(session)


def reset_request_db_session(token: Token[AsyncSession | None]) -> None:
    request_db_session.reset(token)


def get_request_db_session() -> AsyncSession:
    session = request_db_session.get()
    if session is None:
        raise RuntimeError("Request-scoped database session is not available")
    return session
