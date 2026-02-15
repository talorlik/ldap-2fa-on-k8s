"""Main entry point for the 2FA Backend API."""

import asyncio
import logging
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import router
from app.config import get_settings
from app.database import init_db, close_db
from app.utils.security import redact_connection_strings

# Startup retry: wait for PostgreSQL to be reachable (DNS and pod ready; Postgres can take 30–60s to accept connections)
DB_STARTUP_RETRIES = 3
DB_STARTUP_RETRY_DELAY_SEC = 5

# Configure logging
settings = get_settings()
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logger = logging.getLogger(__name__)

# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    description="Two-Factor Authentication API with LDAP, TOTP, and user signup support",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# Add CORS middleware if origins are configured (for local development)
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    logger.info("CORS enabled for origins: %s", settings.cors_origins)

# Include API routes
app.include_router(router)


@app.on_event("startup")
async def startup_event():
    """Initialize application on startup."""
    logger.info("Starting %s", settings.app_name)

    # Initialize database (retry with backoff so we tolerate PostgreSQL starting after backend)
    last_error = None
    for attempt in range(1, DB_STARTUP_RETRIES + 1):
        try:
            await init_db()
            logger.info("Database connection established")
            break
        except Exception as e:
            last_error = e
            # Never log raw exception message; it may contain the connection URL or password
            logger.warning(
                "Database init attempt %s/%s failed: %s - %s",
                attempt,
                DB_STARTUP_RETRIES,
                type(e).__name__,
                redact_connection_strings(str(e)),
            )
            if attempt < DB_STARTUP_RETRIES:
                logger.info("Retrying in %s seconds...", DB_STARTUP_RETRY_DELAY_SEC)
                await asyncio.sleep(DB_STARTUP_RETRY_DELAY_SEC)
            else:
                logger.error(
                    "Failed to initialize database after %s attempts: %s - %s",
                    DB_STARTUP_RETRIES,
                    type(last_error).__name__,
                    redact_connection_strings(str(last_error)),
                )
                raise

    logger.info("LDAP Host: %s:%s", settings.ldap_host, settings.ldap_port)
    logger.info("TOTP Issuer: %s", settings.totp_issuer)
    logger.info("Email verification: %s", 'enabled' if settings.enable_email_verification else 'disabled')
    logger.info("SMS 2FA: %s", 'enabled' if settings.enable_sms_2fa else 'disabled')
    logger.info("Debug mode: %s", settings.debug)


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    logger.info("Shutting down %s", settings.app_name)

    # Close database connection
    await close_db()
    logger.info("Database connection closed")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
    )
