"""
Seed the first admin user for the 2FA application.

Uses the same username and password as the LDAP admin. Creates the LDAP user
(if missing), ensures they are in the admins group, and upserts the PostgreSQL
profile with email/phone pre-verified and status ACTIVE.

All sensitive values (password, email, phone, etc.) must be provided via
environment variables (e.g. from a Kubernetes secret). Never log or print them.

Run: python -m app.seed_admin
"""

import asyncio
import logging
import os
import sys
from datetime import datetime, timezone

import bcrypt

from app.config import get_settings
from app.database import AsyncSessionLocal, init_db, close_db
from app.database.models import User, ProfileStatus
from app.ldap.client import LDAPClient

# Log only high-level messages; never log secrets or PII
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


def _hash_password(password: str) -> str:
    """Hash password with bcrypt. Do not log the password."""
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def _get_seed_env() -> dict | None:
    """
    Read admin seed values from environment.
    Returns a dict of (key -> value) or None if any required key is missing.
    Never logs secret or PII values.
    """
    required = [
        "ADMIN_SEED_USERNAME",
        "ADMIN_SEED_EMAIL",
        "ADMIN_SEED_FIRST_NAME",
        "ADMIN_SEED_LAST_NAME",
        "ADMIN_SEED_PHONE_COUNTRY_CODE",
        "ADMIN_SEED_PHONE_NUMBER",
        "LDAP_ADMIN_PASSWORD",
    ]
    out = {}
    for key in required:
        val = os.environ.get(key)
        if not val or not str(val).strip():
            logger.error("Missing or empty required env: %s (do not set secrets in code)", key)
            return None
        out[key] = str(val).strip()
    # Normalize username to lowercase to match signup behavior
    out["ADMIN_SEED_USERNAME"] = out["ADMIN_SEED_USERNAME"].lower()
    return out


async def _ensure_ldap_admin_user(
    username: str,
    password: str,
    first_name: str,
    last_name: str,
    email: str,
) -> bool:
    """Create LDAP user if not exists and ensure they are in the admins group. Returns True on success."""
    ldap = LDAPClient()
    settings = get_settings()
    admin_group_dn = settings.ldap_admin_group_dn

    # Create user in LDAP (same password as LDAP admin for unified login)
    if ldap.user_exists(username):
        logger.info("LDAP user already exists: %s", username)
    else:
        success, msg = ldap.create_user(
            username=username,
            password=password,
            first_name=first_name,
            last_name=last_name,
            email=email,
        )
        if not success:
            logger.error("Failed to create LDAP user: %s", msg)
            return False
        logger.info("Created LDAP user: %s", username)

    # Ensure admins group exists and add user to it
    try:
        groups = ldap.list_groups()
        if not any((g.get("dn") or "").lower() == admin_group_dn.lower() for g in groups):
            created, create_msg, _ = ldap.create_group("admins", "Administrators")
            if not created and "already exists" not in (create_msg or "").lower():
                logger.warning("Could not create admins group: %s", create_msg)
        add_ok, add_msg = ldap.add_user_to_group(username, admin_group_dn)
        if add_ok:
            logger.info("User %s is in admin group", username)
        else:
            logger.warning("Could not add user to admin group: %s", add_msg)
    except Exception as e:
        logger.warning("Admin group check/add failed (non-fatal): %s", type(e).__name__)

    return True


async def _upsert_db_admin(
    username: str,
    password: str,
    email: str,
    first_name: str,
    last_name: str,
    phone_country_code: str,
    phone_number: str,
) -> bool:
    """Insert or update PostgreSQL user: pre-verified, ACTIVE. MFA is not seeded; admin follows same login/MFA flow as others."""
    from sqlalchemy import select

    password_hash = _hash_password(password)

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.username == username))
        user = result.scalar_one_or_none()

        if user:
            if user.status == ProfileStatus.ACTIVE.value:
                logger.info("Admin user already active, skipping DB update")
                return True
            # Update to ACTIVE and verified; do not set MFA (admin uses same login/MFA flow)
            user.email_verified = True
            user.phone_verified = True
            user.status = ProfileStatus.ACTIVE.value
            user.password_hash = password_hash
            user.totp_secret = None
            user.mfa_method = ""
            user.activated_at = datetime.now(timezone.utc)
            user.activated_by = "seed"
            user.first_name = first_name
            user.last_name = last_name
            user.email = email.lower()
            user.phone_country_code = phone_country_code
            user.phone_number = phone_number
            session.add(user)
        else:
            user = User(
                username=username,
                email=email.lower(),
                first_name=first_name,
                last_name=last_name,
                phone_country_code=phone_country_code,
                phone_number=phone_number,
                password_hash=password_hash,
                email_verified=True,
                phone_verified=True,
                status=ProfileStatus.ACTIVE.value,
                totp_secret=None,
                mfa_method="",
                activated_at=datetime.now(timezone.utc),
                activated_by="seed",
            )
            session.add(user)

        await session.commit()
    logger.info("Admin user seeded successfully (DB)")
    return True


async def run_seed() -> int:
    """Load env, ensure LDAP user + group, upsert DB. Returns 0 on success, 1 on failure."""
    env = _get_seed_env()
    if not env:
        return 1

    username = env["ADMIN_SEED_USERNAME"]
    password = env["LDAP_ADMIN_PASSWORD"]
    email = env["ADMIN_SEED_EMAIL"]
    first_name = env["ADMIN_SEED_FIRST_NAME"]
    last_name = env["ADMIN_SEED_LAST_NAME"]
    phone_country_code = env["ADMIN_SEED_PHONE_COUNTRY_CODE"]
    phone_number = env["ADMIN_SEED_PHONE_NUMBER"]

    logger.info("Seeding admin user: %s", username)

    try:
        await init_db()
    except Exception as e:
        logger.error("Database init failed: %s", type(e).__name__)
        return 1

    try:
        ok_ldap = await _ensure_ldap_admin_user(
            username=username,
            password=password,
            first_name=first_name,
            last_name=last_name,
            email=email,
        )
        if not ok_ldap:
            return 1

        ok_db = await _upsert_db_admin(
            username=username,
            password=password,
            email=email,
            first_name=first_name,
            last_name=last_name,
            phone_country_code=phone_country_code,
            phone_number=phone_number,
        )
        if not ok_db:
            return 1
        return 0
    finally:
        await close_db()


def main() -> int:
    return asyncio.run(run_seed())


if __name__ == "__main__":
    sys.exit(main())
