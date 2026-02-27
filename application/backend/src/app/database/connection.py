"""Database connection and session management."""

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.config import get_settings

logger = logging.getLogger(__name__)


def _migrate_verification_tokens_target_value(sync_conn):
    """
    Add target_value column to verification_tokens if missing (PostgreSQL).
    Used for profile email/phone change flows (eml_chg, phn_chg token types).
    """
    # Check if table exists and column is missing (idempotent)
    r = sync_conn.execute(
        text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = 'verification_tokens' AND column_name = 'target_value'"
        )
    )
    if r.scalar() is not None:
        return
    r = sync_conn.execute(
        text(
            "SELECT 1 FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = 'verification_tokens'"
        )
    )
    if r.scalar() is None:
        return
    sync_conn.execute(text("ALTER TABLE verification_tokens ADD COLUMN target_value VARCHAR(255) NULL"))
    logger.info("Added column verification_tokens.target_value")


async def _migrate_user_mfa_methods_backfill(engine):
    """
    Backfill user_mfa_methods from users.mfa_method and users.totp_secret.
    Idempotent: only inserts if user has legacy MFA and no row exists yet.
    """
    from sqlalchemy import select
    from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession

    from app.database.models import User, UserMFAMethod

    session_factory = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
    async with session_factory() as session:
        result = await session.execute(
            select(User).where(
                (User.mfa_method.isnot(None)) & (User.mfa_method != "")
            )
        )
        users = result.scalars().all()
        for user in users:
            # Check if this user already has any mfa_methods row
            existing = await session.execute(
                select(UserMFAMethod).where(UserMFAMethod.user_id == user.id)
            )
            if existing.scalars().first() is not None:
                continue
            if user.mfa_method == "totp" and user.totp_secret:
                session.add(
                    UserMFAMethod(
                        user_id=user.id,
                        method="totp",
                        totp_secret=user.totp_secret,
                    )
                )
            elif user.mfa_method == "sms":
                session.add(
                    UserMFAMethod(
                        user_id=user.id,
                        method="sms",
                        phone_country_code=user.phone_country_code,
                        phone_number=user.phone_number,
                    )
                )
        await session.commit()
        if users:
            logger.info("Backfilled user_mfa_methods for %d user(s)", len(users))


# Global engine and session factory
_engine = None
AsyncSessionLocal: async_sessionmaker[AsyncSession] | None = None


async def init_db() -> None:
    """Initialize database connection and create tables."""
    global _engine, AsyncSessionLocal

    settings = get_settings()

    logger.info("Initializing database connection to: %s", settings.database_url.split('@')[-1])

    _engine = create_async_engine(
        settings.database_url,
        echo=settings.debug,
        poolclass=NullPool,  # Use NullPool for async
    )

    AsyncSessionLocal = async_sessionmaker(
        bind=_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )

    # Create tables
    from app.database.models import Base

    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(_migrate_verification_tokens_target_value)

    await _migrate_user_mfa_methods_backfill(_engine)

    logger.info("Database initialized successfully")


async def close_db() -> None:
    """Close database connection."""
    global _engine, AsyncSessionLocal

    if _engine:
        await _engine.dispose()
        _engine = None
        AsyncSessionLocal = None
        logger.info("Database connection closed")


async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
    """Get an async database session."""
    if AsyncSessionLocal is None:
        raise RuntimeError("Database not initialized. Call init_db() first.")

    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


@asynccontextmanager
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Context manager for database sessions."""
    if AsyncSessionLocal is None:
        raise RuntimeError("Database not initialized. Call init_db() first.")

    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
