"""
Seed the first admin user for the 2FA application.

Uses the same username and password as the LDAP admin. Creates the LDAP user
(if missing), ensures they are in the admins group, and upserts the PostgreSQL
profile with email/phone pre-verified and status ACTIVE.

No MFA method is pre-entered. The admin selects their initial method(s) when
logging in for the first time (TOTP and/or SMS). They may enroll multiple
methods and choose which to use at each login.

When LDAP_REPLICA_COUNT > 0, the seed job connects to each StatefulSet pod
directly (using pod DNS names derived from LDAP_HOST) to ensure the admin user
and directory structure exist on every replica. This is necessary because
osixia/openldap multi-master replication does not reliably sync data.

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

from app.config import Settings, get_settings
from app.database import init_db, close_db
from sqlalchemy import delete

from app.database.models import User, UserMFAMethod, ProfileStatus, Group, UserGroup
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


def _get_pod_hostnames() -> list[str]:
    """
    Derive individual StatefulSet pod hostnames from LDAP_HOST and LDAP_REPLICA_COUNT.

    LDAP_HOST is the Kubernetes ClusterIP service name, e.g.:
        openldap-stack-ha.ldap.svc.cluster.local
    StatefulSet pod DNS names require the **headless** service and follow the pattern:
        {statefulset}-{i}.{headless-service}.{namespace}.svc.cluster.local

    The headless service host can be provided explicitly via LDAP_HEADLESS_HOST.
    If not set, it is derived from LDAP_HOST by appending "-headless" to the
    service name component (standard Helm naming convention).

    Returns empty list if LDAP_REPLICA_COUNT is 0 or unset.
    """
    replica_count = int(os.environ.get("LDAP_REPLICA_COUNT", "0"))
    if replica_count <= 0:
        return []

    settings = get_settings()
    service_host = settings.ldap_host  # e.g. openldap-stack-ha.ldap.svc.cluster.local
    # Extract service name (first component) and domain suffix
    service_name = service_host.split(".", 1)[0]
    domain = service_host.split(".", 1)[1]  # e.g. ldap.svc.cluster.local

    # StatefulSet pods are addressed via the headless service, not the ClusterIP service.
    headless_host = os.environ.get("LDAP_HEADLESS_HOST", "").strip()
    if not headless_host:
        # Derive from LDAP_HOST: standard Helm convention is {release}-headless
        headless_host = f"{service_name}-headless.{domain}"

    # Pod hostname: {service_name}-{i}.{headless_service_host}
    return [f"{service_name}-{i}.{headless_host}" for i in range(replica_count)]


def _create_ldap_client_for_host(host: str) -> LDAPClient:
    """Create an LDAPClient targeting a specific LDAP host (e.g. a single pod)."""
    settings = get_settings().model_copy(update={"ldap_host": host})
    return LDAPClient(settings=settings)


def _seed_ldap_on_host(
    ldap: LDAPClient,
    username: str,
    password: str,
    first_name: str,
    last_name: str,
    email: str,
) -> bool:
    """
    Ensure directory structure, create/update user, and add to admins group on a
    single LDAP host. Returns True on success.
    """
    host = ldap.settings.ldap_host
    admin_group_dn = ldap.settings.ldap_admin_group_dn

    # Step 1: Ensure ou=users and ou=groups exist
    ok, msg = ldap.ensure_directory_structure()
    if not ok:
        logger.error("[%s] Failed to ensure directory structure: %s", host, msg)
        return False
    logger.info("[%s] Directory structure OK", host)

    # Step 2: Create or update user
    ok, msg = ldap.create_or_update_user(
        username=username,
        password=password,
        first_name=first_name,
        last_name=last_name,
        email=email,
    )
    if not ok:
        logger.error("[%s] Failed to create/update LDAP user: %s", host, msg)
        return False
    logger.info("[%s] LDAP user ensured: %s (%s)", host, username, msg)

    # Step 3: Ensure admins and users groups exist, add user to admins
    users_group_dn = f"cn=users,{admin_group_dn.split(',', 1)[1]}"
    for group_name, group_dn, group_desc in [
        ("admins", admin_group_dn, "Administrator group"),
        ("users", users_group_dn, "Regular users group"),
    ]:
        try:
            groups = ldap.list_groups()
            if not any((g.get("dn") or "").lower() == group_dn.lower() for g in groups):
                created, create_msg, _ = ldap.create_group(group_name, group_desc)
                if not created and "already exists" not in (create_msg or "").lower():
                    logger.warning("[%s] Could not create %s group: %s", host, group_name, create_msg)
                else:
                    logger.info("[%s] %s group ensured", host, group_name)
        except Exception as e:
            logger.warning("[%s] %s group check/add failed (non-fatal): %s", host, group_name, type(e).__name__)

    try:
        add_ok, add_msg = ldap.add_user_to_group(username, admin_group_dn)
        if add_ok:
            logger.info("[%s] User %s is in admin group", host, username)
        else:
            logger.warning("[%s] Could not add user to admin group: %s", host, add_msg)
    except Exception as e:
        logger.warning("[%s] Admin group add failed (non-fatal): %s", host, type(e).__name__)

    return True


async def _ensure_ldap_admin_user(
    username: str,
    password: str,
    first_name: str,
    last_name: str,
    email: str,
) -> bool:
    """Create or update LDAP user and ensure they are in the admins group.

    When LDAP_REPLICA_COUNT > 0, seeds each pod directly. Otherwise uses the
    LDAP service (single connection).
    Returns True on success.
    """
    pod_hostnames = _get_pod_hostnames()

    if pod_hostnames:
        logger.info("Multi-pod seeding enabled for %d replicas", len(pod_hostnames))
        all_ok = True
        for host in pod_hostnames:
            logger.info("Seeding LDAP pod: %s", host)
            ldap = _create_ldap_client_for_host(host)
            if not _seed_ldap_on_host(ldap, username, password, first_name, last_name, email):
                logger.error("Failed to seed pod: %s", host)
                all_ok = False
        return all_ok
    else:
        # Single-host mode: connect via service
        logger.info("Single-host seeding via LDAP service")
        ldap = LDAPClient()
        return _seed_ldap_on_host(ldap, username, password, first_name, last_name, email)


async def _upsert_db_groups() -> bool:
    """Mirror admins and users groups from LDAP to PostgreSQL. Creates Group records if missing."""
    from sqlalchemy import select
    from app.database.connection import AsyncSessionLocal

    if AsyncSessionLocal is None:
        logger.error("Database session factory not initialized")
        return False

    settings = get_settings()
    admin_group_dn = settings.ldap_admin_group_dn
    users_group_dn = f"cn=users,{admin_group_dn.split(',', 1)[1]}"

    groups_to_sync = [
        ("admins", admin_group_dn, "Administrator group"),
        ("users", users_group_dn, "Regular users group"),
    ]

    async with AsyncSessionLocal() as session:
        for name, ldap_dn, description in groups_to_sync:
            result = await session.execute(select(Group).where(Group.ldap_dn == ldap_dn))
            group = result.scalar_one_or_none()
            if not group:
                group = Group(name=name, ldap_dn=ldap_dn, description=description)
                session.add(group)
                logger.info("Created Group in DB: %s", name)
            else:
                logger.debug("Group already exists in DB: %s", name)
        await session.commit()
    logger.info("Groups mirrored to PostgreSQL")
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
    from app.database.connection import AsyncSessionLocal

    if AsyncSessionLocal is None:
        logger.error("Database session factory not initialized")
        return False

    password_hash = _hash_password(password)

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.username == username))
        user = result.scalar_one_or_none()

        if user:
            if user.status == ProfileStatus.ACTIVE.value:
                logger.info("Admin user already active, skipping profile update")
            else:
                # Clear any existing MFA so admin can select method(s) at next login
                await session.execute(delete(UserMFAMethod).where(UserMFAMethod.user_id == user.id))
                user.email_verified = True
                user.phone_verified = True
                user.status = ProfileStatus.ACTIVE.value
                user.password_hash = password_hash
                user.totp_secret = None
                user.mfa_method = None
                user.activated_at = datetime.now(timezone.utc)
                user.activated_by = "seed"
                user.first_name = first_name
                user.last_name = last_name
                user.email = email.lower()
                user.phone_country_code = phone_country_code
                user.phone_number = phone_number
                session.add(user)
        else:
            # New admin: no MFA method set; they will choose at first login
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
                mfa_method=None,
                activated_at=datetime.now(timezone.utc),
                activated_by="seed",
            )
            session.add(user)

        await session.flush()

        # Ensure admin is in admins group (UserGroup mirror)
        settings = get_settings()
        admin_group_dn = settings.ldap_admin_group_dn
        result = await session.execute(select(Group).where(Group.ldap_dn == admin_group_dn))
        admins_group = result.scalar_one_or_none()
        if admins_group:
            ug_result = await session.execute(
                select(UserGroup).where(
                    UserGroup.user_id == user.id,
                    UserGroup.group_id == admins_group.id,
                )
            )
            if not ug_result.scalar_one_or_none():
                user_group = UserGroup(
                    user_id=user.id,
                    group_id=admins_group.id,
                    assigned_by="seed",
                )
                session.add(user_group)
                logger.info("Admin user assigned to admins group (DB)")

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

        ok_groups = await _upsert_db_groups()
        if not ok_groups:
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
