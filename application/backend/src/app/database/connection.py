"""Database connection and session management."""

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.config import get_settings

logger = logging.getLogger(__name__)

# Global engine and session factory
_engine = None
AsyncSessionLocal: async_sessionmaker[AsyncSession] | None = None


async def init_db() -> None:
    """Initialize database connection and create tables."""
    global _engine, AsyncSessionLocal

    settings = get_settings()

    logger.info(f"Initializing database connection to: {settings.database_url.split('@')[-1]}")

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
