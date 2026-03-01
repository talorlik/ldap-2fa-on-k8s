"""API routes for 2FA authentication with user signup and admin management."""

import hmac
import logging
import re
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional

import bcrypt
import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from sqlalchemy import select, or_, func, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.database import (
    get_async_session,
    User,
    UserMFAMethod,
    VerificationToken,
    ProfileStatus,
    Group,
    UserGroup,
)
from app.email import EmailClient
from app.ldap import LDAPClient
from app.mfa import TOTPManager
from app.redis import get_otp_client, RedisOTPClient
from app.redis.client import (
    delete_login_challenge,
    get_login_challenge,
    get_otp_client,
    store_login_challenge,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["authentication"])


# ============================================================================
# Enums and Constants
# ============================================================================

class MFAMethod(str, Enum):
    """Supported MFA methods."""
    TOTP = "totp"
    SMS = "sms"


# SMS OTP and login challenges are stored in Redis only (required; no in-memory fallback).
# See app/redis/client.py for RedisOTPClient and login challenge helpers.


# ============================================================================
# Request/Response Models
# ============================================================================

class HealthResponse(BaseModel):
    """Health check response model."""
    status: str = Field(..., description="Health status")
    service: str = Field(..., description="Service name")
    sms_enabled: bool = Field(..., description="Whether SMS 2FA is enabled")


class SignupRequest(BaseModel):
    """User signup request model."""
    username: str = Field(..., min_length=3, max_length=64, description="Username")
    email: EmailStr = Field(..., description="Email address")
    first_name: str = Field(..., min_length=1, max_length=100, description="First name")
    last_name: str = Field(..., min_length=1, max_length=100, description="Last name")
    phone_country_code: str = Field(..., description="Phone country code (e.g., +1)")
    phone_number: str = Field(..., min_length=5, max_length=20, description="Phone number")
    password: str = Field(..., min_length=8, description="Password")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v):
        """Validate username format."""
        if not re.match(r"^[a-zA-Z][a-zA-Z0-9_-]*$", v):
            raise ValueError("Username must start with a letter and contain only letters, numbers, underscores, and hyphens")
        return v.lower()

    @field_validator("phone_country_code")
    @classmethod
    def validate_country_code(cls, v):
        """Validate phone country code format."""
        if not re.match(r"^\+\d{1,4}$", v):
            raise ValueError("Country code must be in format +X or +XX (e.g., +1, +44)")
        return v

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, v):
        """Validate phone number format."""
        # Remove any spaces or dashes
        cleaned = re.sub(r"[\s-]", "", v)
        if not re.match(r"^\d{5,15}$", cleaned):
            raise ValueError("Phone number must contain 5-15 digits")
        return cleaned


class SignupResponse(BaseModel):
    """Signup response model."""
    success: bool = Field(..., description="Whether signup was successful")
    message: str = Field(..., description="Response message")
    user_id: Optional[str] = Field(None, description="User ID")
    email_verification_sent: bool = Field(False, description="Whether email verification was sent")
    phone_verification_sent: bool = Field(False, description="Whether phone verification was sent")


class VerifyEmailRequest(BaseModel):
    """Email verification request model."""
    token: str = Field(..., description="Email verification token")
    username: str = Field(..., description="Username")


class VerifyPhoneRequest(BaseModel):
    """Phone verification request model."""
    username: str = Field(..., description="Username")
    code: str = Field(..., min_length=6, max_length=6, description="6-digit verification code")


class VerificationResponse(BaseModel):
    """Verification response model."""
    success: bool = Field(..., description="Whether verification was successful")
    message: str = Field(..., description="Response message")
    profile_status: Optional[str] = Field(None, description="Updated profile status")


class ResendVerificationRequest(BaseModel):
    """Request to resend verification."""
    username: str = Field(..., description="Username")
    verification_type: str = Field(..., description="Type: 'email' or 'phone'")


class ForgotPasswordRequest(BaseModel):
    """Request to send password reset link."""
    email: str = Field(..., description="Account email address")


class ForgotPasswordResponse(BaseModel):
    """Response after forgot-password request."""
    success: bool = Field(..., description="Whether the request was processed")
    message: str = Field(..., description="Response message (generic for security)")


class ResetPasswordRequest(BaseModel):
    """Request to set new password with reset token."""
    token: str = Field(..., description="Password reset token from email link")
    username: str = Field(..., description="Username from email link")
    new_password: str = Field(..., min_length=8, description="New password")
    confirm_password: str = Field(..., min_length=8, description="Confirm new password")

    @model_validator(mode="after")
    def passwords_match(self):
        if self.new_password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self


class ResetPasswordResponse(BaseModel):
    """Response after reset-password."""
    success: bool = Field(..., description="Whether password was reset")
    message: str = Field(..., description="Response message")


class ProfileStatusResponse(BaseModel):
    """User profile status response model."""
    username: str = Field(..., description="Username")
    email: str = Field(..., description="Masked email")
    phone: str = Field(..., description="Masked phone")
    status: str = Field(..., description="Profile status")
    email_verified: bool = Field(..., description="Email verified")
    phone_verified: bool = Field(..., description="Phone verified")
    mfa_method: str = Field(..., description="MFA method")
    created_at: str = Field(..., description="Account creation date")


class EnrollRequest(BaseModel):
    """MFA enrollment request model (for active users)."""
    username: str = Field(..., min_length=1, description="Username")
    password: str = Field(..., min_length=1, description="Password")
    mfa_method: MFAMethod = Field(default=MFAMethod.TOTP, description="MFA method")
    phone_number: Optional[str] = Field(None, description="Phone for SMS")


class EnrollResponse(BaseModel):
    """Enrollment response model."""
    success: bool = Field(..., description="Whether enrollment was successful")
    message: str = Field(..., description="Response message")
    mfa_method: MFAMethod = Field(..., description="Enrolled MFA method")
    otpauth_uri: Optional[str] = Field(None, description="otpauth:// URI for QR code")
    secret: Optional[str] = Field(None, description="TOTP secret for manual entry")
    phone_number: Optional[str] = Field(None, description="Masked phone number")


class LoginRequest(BaseModel):
    """Login request model (legacy one-step login, kept for reference)."""
    username: str = Field(..., min_length=1, description="Username")
    password: str = Field(..., min_length=1, description="Password")
    verification_code: str = Field(..., min_length=6, max_length=6, description="6-digit code")


class LoginStartRequest(BaseModel):
    """Login step 1: username and password only."""
    username: str = Field(..., min_length=1, description="Username")
    password: str = Field(..., min_length=1, description="Password")
    remember_me: bool = Field(False, description="Use longer-lived session (remember me)")


class LoginStartResponse(BaseModel):
    """Response after successful username/password; MFA required."""
    challenge_token: str = Field(..., description="Token for MFA step")
    totp_enrolled: bool = Field(..., description="Whether user has Authenticator app set up")
    sms_available: bool = Field(..., description="Whether SMS option is available")


class LoginTotpSetupResponse(BaseModel):
    """Response with TOTP setup URI and secret (when not yet enrolled)."""
    otpauth_uri: str = Field(..., description="otpauth:// URI for QR code")
    secret: str = Field(..., description="TOTP secret for manual entry")


class LoginVerifyRequest(BaseModel):
    """Login step 2: MFA verification."""
    challenge_token: str = Field(..., description="Token from login start")
    mfa_method: MFAMethod = Field(..., description="totp or sms")
    verification_code: str = Field(..., min_length=6, max_length=6, description="6-digit code")


class LoginResponse(BaseModel):
    """Login response model."""
    success: bool = Field(..., description="Whether login was successful")
    message: str = Field(..., description="Response message")
    is_admin: bool = Field(False, description="Whether user is admin")
    token: Optional[str] = Field(None, description="JWT access token")
    username: Optional[str] = Field(None, description="Logged in username")


class SMSSendCodeRequest(BaseModel):
    """Request to send SMS verification code. Use either challenge_token (after login start) or username+password."""
    username: Optional[str] = Field(None, description="Username (when not using challenge_token)")
    password: Optional[str] = Field(None, description="Password (when not using challenge_token)")
    challenge_token: Optional[str] = Field(None, description="Token from login/start (preferred)")


class SMSSendCodeResponse(BaseModel):
    """Response after sending SMS code."""
    success: bool = Field(..., description="Whether code was sent")
    message: str = Field(..., description="Response message")
    phone_number: Optional[str] = Field(None, description="Masked phone number")
    expires_in_seconds: Optional[int] = Field(None, description="Seconds until expiry")


class MFAMethodsResponse(BaseModel):
    """Response with available MFA methods."""
    methods: list[str] = Field(..., description="Available MFA methods")
    sms_enabled: bool = Field(..., description="Whether SMS is enabled")


class UserMFAStatusResponse(BaseModel):
    """Response with user's MFA enrollment status."""
    enrolled: bool = Field(..., description="Whether user is enrolled")
    mfa_method: Optional[str] = Field(None, description="Enrolled MFA method (legacy/comma-separated)")
    mfa_methods: list[str] = Field(default_factory=list, description="List of enrolled methods: totp, sms")
    phone_number: Optional[str] = Field(None, description="Masked phone for SMS")


# Admin models
class AdminUserListResponse(BaseModel):
    """Admin user list response."""
    users: list[dict] = Field(..., description="List of users")
    total: int = Field(..., description="Total count")


class AdminActivateRequest(BaseModel):
    """Admin user activation request (supports both JWT and legacy auth)."""
    admin_username: Optional[str] = Field(None, description="Admin username (legacy auth, optional if JWT provided)")
    admin_password: Optional[str] = Field(None, description="Admin password (legacy auth, optional if JWT provided)")
    group_ids: list[str] = Field(..., min_length=1, description="List of group IDs to assign during activation (at least one required)")


class AdminActivateResponse(BaseModel):
    """Admin activation response."""
    success: bool = Field(..., description="Whether activation was successful")
    message: str = Field(..., description="Response message")


# Profile Models
class ProfileMFAMethodItem(BaseModel):
    """Single MFA method in profile."""
    id: str = Field(..., description="Method record ID")
    method: str = Field(..., description="totp or sms")
    phone_number: Optional[str] = Field(None, description="Masked phone for SMS method")


class ProfileResponse(BaseModel):
    """User profile response model."""
    id: str = Field(..., description="User ID")
    username: str = Field(..., description="Username")
    email: str = Field(..., description="Email address")
    first_name: str = Field(..., description="First name")
    last_name: str = Field(..., description="Last name")
    phone_country_code: str = Field(..., description="Phone country code")
    phone_number: str = Field(..., description="Phone number")
    email_verified: bool = Field(..., description="Email verified")
    phone_verified: bool = Field(..., description="Phone verified")
    mfa_method: str = Field(..., description="MFA method (legacy: comma-separated list)")
    mfa_methods: list[ProfileMFAMethodItem] = Field(
        default_factory=list,
        description="Enrolled 2FA methods",
    )
    status: str = Field(..., description="Profile status")
    created_at: str = Field(..., description="Creation date")
    groups: list[dict] = Field(default_factory=list, description="User's groups")


class ProfileUpdateRequest(BaseModel):
    """Profile update request model."""
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    email: Optional[EmailStr] = Field(None)
    phone_country_code: Optional[str] = Field(None)
    phone_number: Optional[str] = Field(None)
    current_password: Optional[str] = Field(None, min_length=1)
    new_password: Optional[str] = Field(None, min_length=8)
    confirm_password: Optional[str] = Field(None, min_length=8)

    @model_validator(mode="after")
    def password_change_valid(self):
        """When changing password, all three fields required and must match."""
        pw_fields = (self.current_password, self.new_password, self.confirm_password)
        if any(pw_fields) and not all(pw_fields):
            raise ValueError("Password change requires current_password, new_password, and confirm_password")
        if self.new_password and self.confirm_password and self.new_password != self.confirm_password:
            raise ValueError("New password and confirmation do not match")
        return self

    @field_validator("phone_country_code")
    @classmethod
    def validate_country_code(cls, v):
        if v is not None and not re.match(r"^\+\d{1,4}$", v):
            raise ValueError("Country code must be in format +X or +XX")
        return v

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, v):
        if v is not None:
            cleaned = re.sub(r"[\s-]", "", v)
            if not re.match(r"^\d{5,15}$", cleaned):
                raise ValueError("Phone number must contain 5-15 digits")
            return cleaned
        return v


class RequestEmailChangeRequest(BaseModel):
    """Request to change email; sends verification to the new address."""
    new_email: EmailStr = Field(..., description="New email address")


class ChangePasswordRequest(BaseModel):
    """Request to change password (authenticated user)."""
    current_password: str = Field(..., min_length=1, description="Current password")
    new_password: str = Field(..., min_length=8, description="New password")
    confirm_password: str = Field(..., min_length=8, description="Confirm new password")

    @model_validator(mode="after")
    def passwords_match(self):
        """Validate that new and confirm passwords match."""
        if self.new_password != self.confirm_password:
            raise ValueError("New password and confirmation do not match")
        return self


class ChangePasswordResponse(BaseModel):
    """Response after changing password."""
    success: bool = Field(..., description="Whether password was changed")
    message: str = Field(..., description="Response message")


class RequestPhoneChangeRequest(BaseModel):
    """Request to change phone; sends verification code to the new number."""
    phone_country_code: str = Field(..., description="Country code (e.g. +1)")
    phone_number: str = Field(..., min_length=5, max_length=15, description="Phone number")

    @field_validator("phone_country_code")
    @classmethod
    def validate_country_code(cls, v):
        if not re.match(r"^\+\d{1,4}$", v):
            raise ValueError("Country code must be in format +X or +XX")
        return v

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, v):
        cleaned = re.sub(r"[\s-]", "", v)
        if not re.match(r"^\d{5,15}$", cleaned):
            raise ValueError("Phone number must contain 5-15 digits")
        return cleaned


# Group Models
class GroupCreateRequest(BaseModel):
    """Group creation request."""
    name: str = Field(..., min_length=1, max_length=100, description="Group name")
    description: Optional[str] = Field(None, max_length=500, description="Group description")


class GroupUpdateRequest(BaseModel):
    """Group update request."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)


class GroupResponse(BaseModel):
    """Group response model."""
    id: str = Field(..., description="Group ID")
    name: str = Field(..., description="Group name")
    description: Optional[str] = Field(None, description="Group description")
    ldap_dn: str = Field(..., description="LDAP DN")
    member_count: int = Field(..., description="Number of members")
    created_at: str = Field(..., description="Creation date")


class GroupListResponse(BaseModel):
    """Group list response."""
    groups: list[GroupResponse] = Field(..., description="List of groups")
    total: int = Field(..., description="Total count")


class GroupDetailResponse(GroupResponse):
    """Group detail response with members."""
    members: list[dict] = Field(default_factory=list, description="Group members")


# User-Group Assignment Models
class UserGroupAssignRequest(BaseModel):
    """Request to assign user to groups."""
    group_ids: list[str] = Field(..., description="List of group IDs to assign")


class UserGroupResponse(BaseModel):
    """User's groups response."""
    user_id: str = Field(..., description="User ID")
    username: str = Field(..., description="Username")
    groups: list[dict] = Field(..., description="Assigned groups")


# Enhanced Admin User List
class AdminUserListRequest(BaseModel):
    """Admin user list query parameters."""
    status_filter: Optional[str] = Field(None, description="Filter by status")
    group_filter: Optional[str] = Field(None, description="Filter by group ID")
    search: Optional[str] = Field(None, description="Search term")
    sort_by: Optional[str] = Field("created_at", description="Sort field")
    sort_order: Optional[str] = Field("desc", description="Sort order (asc/desc)")


# ============================================================================
# Helper Functions
# ============================================================================

def _mask_phone_number(phone: str) -> str:
    """Mask phone number for display."""
    if len(phone) > 4:
        return "*" * (len(phone) - 4) + phone[-4:]
    return phone


def _mask_email(email: str) -> str:
    """Mask email for display."""
    if "@" not in email:
        return email
    local, domain = email.split("@", 1)
    if len(local) > 2:
        masked = local[0] + "*" * (len(local) - 2) + local[-1]
    else:
        masked = "*" * len(local)
    return f"{masked}@{domain}"


def _hash_password(password: str) -> str:
    """Hash password using bcrypt."""
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def _verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash."""
    return bcrypt.checkpw(password.encode(), hashed.encode())


def _get_sms_client():
    """Get SMS client (lazy import)."""
    from app.sms import SMSClient
    return SMSClient()


def _generate_verification_code(length: int = 6) -> str:
    """Generate a numeric verification code."""
    return "".join(secrets.choice("0123456789") for _ in range(length))


async def _get_user_by_username(session: AsyncSession, username: str) -> Optional[User]:
    """Get user by username."""
    result = await session.execute(
        select(User).where(User.username == username.lower())
    )
    return result.scalar_one_or_none()


async def _get_user_by_email(session: AsyncSession, email: str) -> Optional[User]:
    """Get user by email."""
    result = await session.execute(
        select(User).where(User.email == email.lower())
    )
    return result.scalar_one_or_none()


async def _get_user_by_id(session: AsyncSession, user_id: uuid.UUID) -> Optional[User]:
    """Get user by id."""
    result = await session.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def _get_user_with_mfa(
    session: AsyncSession, username: str
) -> Optional[User]:
    """Get user by username with mfa_methods loaded."""
    result = await session.execute(
        select(User)
        .where(User.username == username.lower())
        .options(selectinload(User.mfa_methods))
    )
    return result.scalar_one_or_none()


async def _get_user_by_id_with_mfa(
    session: AsyncSession, user_id: uuid.UUID
) -> Optional[User]:
    """Get user by id with mfa_methods loaded."""
    result = await session.execute(
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.mfa_methods))
    )
    return result.scalar_one_or_none()


def _user_totp_secret(user: User) -> Optional[str]:
    """Get first TOTP secret from user's MFA methods (or legacy field)."""
    if user.mfa_methods:
        for m in user.mfa_methods:
            if m.method == "totp" and m.totp_secret:
                return m.totp_secret
    if user.totp_secret:
        return user.totp_secret
    return None


def _user_has_sms(user: User) -> bool:
    """Whether user has SMS as an enrolled method."""
    if user.mfa_methods:
        return any(m.method == "sms" for m in user.mfa_methods)
    return user.mfa_method == "sms"


def _user_has_totp(user: User) -> bool:
    """Whether user has TOTP as an enrolled method."""
    if user.mfa_methods:
        return any(m.method == "totp" for m in user.mfa_methods)
    return bool(user.totp_secret)


def _user_mfa_methods_summary(user: User) -> list[str]:
    """List of enrolled method names (e.g. ['totp', 'sms'])."""
    if user.mfa_methods:
        return list(dict.fromkeys(m.method for m in user.mfa_methods))
    if user.mfa_method:
        return [user.mfa_method]
    return []


async def _create_verification_token(
    session: AsyncSession,
    user_id: uuid.UUID,
    token_type: str,
    expiry_hours: int = 24,
    target_value: Optional[str] = None,
) -> str:
    """Create a verification token. target_value used for email/phone change flows."""
    # Invalidate existing tokens of the same type
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.user_id == user_id,
            VerificationToken.token_type == token_type,
            VerificationToken.used == False,
        )
    )
    for old_token in result.scalars():
        old_token.used = True

    # Create new token
    if token_type in ("email", "password_reset", "eml_chg"):
        token = str(uuid.uuid4())
    else:
        token = _generate_verification_code(6)

    verification_token = VerificationToken(
        user_id=user_id,
        token_type=token_type,
        token=token,
        expires_at=datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
        target_value=target_value,
    )
    session.add(verification_token)
    await session.flush()

    return token


# ============================================================================
# JWT Helper Functions
# ============================================================================

def _create_jwt_token(
    user_id: str,
    username: str,
    is_admin: bool,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create a JWT token for authenticated sessions."""
    settings = get_settings()
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.jwt_expiry_minutes)

    expire = datetime.now(timezone.utc) + expires_delta
    payload = {
        "sub": user_id,
        "username": username,
        "is_admin": is_admin,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def _decode_jwt_token(token: str) -> dict:
    """Decode and validate a JWT token."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm]
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )


async def _get_current_user(
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> dict:
    """Get current user from JWT token."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )

    token = authorization.split(" ")[1]
    payload = _decode_jwt_token(token)

    user = await _get_user_by_username(session, payload["username"])
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return {
        "user": user,
        "user_id": payload["sub"],
        "username": payload["username"],
        "is_admin": payload["is_admin"],
    }


async def _require_admin(
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> dict:
    """Require admin privileges for an endpoint."""
    current = await _get_current_user(authorization, session)
    if not current["is_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )
    return current


async def _require_app_active(
    session: AsyncSession = Depends(get_async_session),
) -> None:
    """Raise 503 if the application is disabled or dependencies are unhealthy.

    Active is determined automatically by:
    - APP_ACTIVE env (default true): when false, always 503.
    - DB reachable: quick SELECT 1 check.
    - Redis reachable when REDIS_ENABLED: required for login challenge storage.
    - LDAP reachable: admin bind check (required for authentication).

    No manual toggle needed: when DB, Redis or LDAP is down, auth endpoints return 503.
    """
    settings = get_settings()
    if not settings.app_active:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Application is currently disabled. Please try again later.",
        )
    try:
        await session.execute(text("SELECT 1"))
    except Exception:
        logger.warning("App active check: database unreachable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Application is currently disabled. Please try again later.",
        )
    if settings.redis_enabled and not get_otp_client().is_connected:
        logger.warning("App active check: Redis unreachable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Application is currently disabled. Please try again later.",
        )
    try:
        ldap_client = LDAPClient()
        conn = ldap_client._get_admin_connection()
        conn.unbind()
    except Exception:
        logger.warning("App active check: LDAP unreachable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Application is currently disabled. Please try again later.",
        )


async def _send_admin_notification(user: User) -> None:
    """Send notification email to admins about new user signup."""
    try:
        ldap_client = LDAPClient()
        admin_emails = ldap_client.get_admin_emails()

        if not admin_emails:
            logger.warning("No admin emails found for notification")
            return

        email_client = EmailClient()
        new_user_data = {
            "username": user.username,
            "full_name": user.full_name,
            "email": user.email,
            "phone": user.full_phone_number,
            "signup_time": user.created_at.isoformat() if user.created_at else datetime.now(timezone.utc).isoformat(),
        }

        success, msg = email_client.send_admin_notification_email(admin_emails, new_user_data)
        if success:
            logger.info("Admin notification sent for new user %s", user.username)
        else:
            logger.error("Failed to send admin notification: %s", msg)
    except Exception as e:
        logger.error("Error sending admin notification: %s", e)


# ============================================================================
# Health Check
# ============================================================================

@router.get("/healthz", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Liveness/readiness probe endpoint."""
    settings = get_settings()
    return HealthResponse(
        status="healthy",
        service=settings.app_name,
        sms_enabled=settings.enable_sms_2fa,
    )


# ============================================================================
# Signup Endpoints
# ============================================================================

@router.post(
    "/auth/signup",
    response_model=SignupResponse,
    responses={
        400: {"description": "Validation error or user exists"},
        500: {"description": "Internal server error"},
    },
)
async def signup(
    request: SignupRequest,
    session: AsyncSession = Depends(get_async_session),
) -> SignupResponse:
    """
    Register a new user account.

    Creates user in PENDING state and sends verification emails/SMS.
    """
    settings = get_settings()

    # Check if username exists
    if await _get_user_by_username(session, request.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    # Check if email exists
    if await _get_user_by_email(session, request.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Create user (MFA method will be set during enrollment at login)
    user = User(
        username=request.username.lower(),
        email=request.email.lower(),
        first_name=request.first_name,
        last_name=request.last_name,
        phone_country_code=request.phone_country_code,
        phone_number=request.phone_number,
        password_hash=_hash_password(request.password),
        mfa_method=None,  # Will be set during MFA enrollment at login
        totp_secret=None,  # Will be set during MFA enrollment at login
        status=ProfileStatus.PENDING.value,
    )
    session.add(user)
    await session.flush()

    email_sent = False
    phone_sent = False

    # Send email verification
    if settings.enable_email_verification:
        try:
            email_token = await _create_verification_token(
                session, user.id, "email",
                settings.email_verification_expiry_hours
            )
            email_client = EmailClient()
            success, _ = email_client.send_verification_email(
                to_email=user.email,
                token=email_token,
                username=user.username,
                first_name=user.first_name,
            )
            email_sent = success
        except Exception as e:
            logger.error("Failed to send verification email: %s", e)

    # Send phone verification
    try:
        phone_token = await _create_verification_token(
            session, user.id, "phone",
            expiry_hours=1,  # Phone codes expire faster
        )
        sms_client = _get_sms_client()
        full_phone = f"{user.phone_country_code}{user.phone_number}"
        success, _, _ = sms_client.send_verification_code(full_phone, phone_token)
        phone_sent = success
    except Exception as e:
        logger.error("Failed to send verification SMS: %s", e)

    await session.commit()

    # Send admin notification asynchronously (don't block response)
    await _send_admin_notification(user)

    logger.info("User %s signed up successfully", user.username)

    return SignupResponse(
        success=True,
        message="Account created. Please verify your email and phone number.",
        user_id=str(user.id),
        email_verification_sent=email_sent,
        phone_verification_sent=phone_sent,
    )


# ============================================================================
# Verification Endpoints
# ============================================================================

@router.post(
    "/auth/verify-email",
    response_model=VerificationResponse,
    responses={
        400: {"description": "Invalid or expired token"},
        404: {"description": "User not found"},
    },
)
async def verify_email(
    request: VerifyEmailRequest,
    session: AsyncSession = Depends(get_async_session),
) -> VerificationResponse:
    """Verify user's email address (signup or profile email change)."""
    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Find valid token (signup "email" or profile "eml_chg")
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.user_id == user.id,
            VerificationToken.token_type.in_(["email", "eml_chg"]),
            VerificationToken.token == request.token,
            VerificationToken.used == False,
        )
    )
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification token",
        )

    if token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification token has expired. Please request a new one.",
        )

    token.used = True
    if token.token_type == "eml_chg" and token.target_value:
        user.email = token.target_value.lower()
    user.email_verified = True
    user.update_status_if_complete()

    await session.commit()

    logger.info("User %s verified email", user.username)

    return VerificationResponse(
        success=True,
        message="Email verified successfully",
        profile_status=user.status,
    )


@router.post(
    "/auth/verify-phone",
    response_model=VerificationResponse,
    responses={
        400: {"description": "Invalid or expired code"},
        404: {"description": "User not found"},
    },
)
async def verify_phone(
    request: VerifyPhoneRequest,
    session: AsyncSession = Depends(get_async_session),
) -> VerificationResponse:
    """Verify user's phone number (signup or profile phone change)."""
    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Find valid token (signup "phone" or profile "phn_chg") by code
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.user_id == user.id,
            VerificationToken.token_type.in_(["phone", "phn_chg"]),
            VerificationToken.used == False,
        ).order_by(VerificationToken.created_at.desc())
    )
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No verification code found. Please request a new one.",
        )

    if token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code has expired. Please request a new one.",
        )

    if not hmac.compare_digest(request.code, token.token):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )

    token.used = True
    if token.token_type == "phn_chg" and token.target_value and "|" in token.target_value:
        parts = token.target_value.split("|", 1)
        user.phone_country_code = parts[0].strip()
        user.phone_number = parts[1].strip()
    user.phone_verified = True
    user.update_status_if_complete()

    await session.commit()

    logger.info("User %s verified phone", user.username)

    return VerificationResponse(
        success=True,
        message="Phone verified successfully",
        profile_status=user.status,
    )


# ============================================================================
# Forgot / Reset Password
# ============================================================================

@router.post(
    "/auth/forgot-password",
    response_model=ForgotPasswordResponse,
    responses={200: {"description": "Always 200 with generic message (security)"}},
)
async def forgot_password(
    request: ForgotPasswordRequest,
    session: AsyncSession = Depends(get_async_session),
) -> ForgotPasswordResponse:
    """
    Request a password reset link by email. Always returns the same generic message
    to avoid revealing whether the email exists.
    """
    settings = get_settings()
    user = await _get_user_by_email(session, request.email.strip().lower())
    generic_message = (
        "If an account exists with this email address, you will receive a password reset link shortly."
    )
    if not user:
        logger.debug("Forgot password: no user for email %s", request.email)
        return ForgotPasswordResponse(success=True, message=generic_message)
    if user.status != ProfileStatus.ACTIVE.value:
        logger.debug("Forgot password: user %s not active", user.username)
        return ForgotPasswordResponse(success=True, message=generic_message)
    token = await _create_verification_token(
        session,
        user.id,
        "password_reset",
        settings.password_reset_expiry_hours,
    )
    await session.commit()
    email_client = EmailClient()
    success, _ = email_client.send_password_reset_email(
        to_email=user.email,
        reset_token=token,
        username=user.username,
        first_name=user.first_name,
    )
    if not success:
        logger.warning("Failed to send password reset email to %s", user.email)
    return ForgotPasswordResponse(success=True, message=generic_message)


@router.post(
    "/auth/reset-password",
    response_model=ResetPasswordResponse,
    responses={
        400: {"description": "Invalid or expired token, or validation error"},
        404: {"description": "User not found"},
    },
)
async def reset_password(
    request: ResetPasswordRequest,
    session: AsyncSession = Depends(get_async_session),
) -> ResetPasswordResponse:
    """Set new password using the token from the reset link."""
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.token_type == "password_reset",
            VerificationToken.token == request.token,
            VerificationToken.used == False,
        )
    )
    reset_token = result.scalar_one_or_none()
    if not reset_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset link. Please request a new password reset.",
        )
    if reset_token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reset link has expired. Please request a new password reset.",
        )
    user = await _get_user_by_id(session, reset_token.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    if user.username != request.username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reset link.",
        )
    ldap_client = LDAPClient()
    if not ldap_client.user_exists(user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not active. Please contact support.",
        )
    success, msg = ldap_client.change_password(user.username, request.new_password)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update password. Please try again or request a new link.",
        )
    reset_token.used = True
    user.password_hash = _hash_password(request.new_password)
    await session.commit()
    logger.info("Password reset completed for user %s", user.username)
    return ResetPasswordResponse(
        success=True,
        message="Your password has been reset. You can now log in with your new password.",
    )


@router.post(
    "/auth/resend-verification",
    response_model=VerificationResponse,
    responses={
        400: {"description": "Invalid request"},
        404: {"description": "User not found"},
    },
)
async def resend_verification(
    request: ResendVerificationRequest,
    session: AsyncSession = Depends(get_async_session),
) -> VerificationResponse:
    """Resend verification email or SMS."""
    settings = get_settings()

    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if request.verification_type == "email":
        if user.email_verified:
            return VerificationResponse(
                success=True,
                message="Email already verified",
                profile_status=user.status,
            )

        token = await _create_verification_token(
            session, user.id, "email",
            settings.email_verification_expiry_hours
        )
        email_client = EmailClient()
        success, msg = email_client.send_verification_email(
            to_email=user.email,
            token=token,
            username=user.username,
            first_name=user.first_name,
        )
        await session.commit()

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=msg,
            )

        return VerificationResponse(
            success=True,
            message="Verification email sent",
            profile_status=user.status,
        )

    elif request.verification_type == "phone":
        if user.phone_verified:
            return VerificationResponse(
                success=True,
                message="Phone already verified",
                profile_status=user.status,
            )

        token = await _create_verification_token(
            session, user.id, "phone", expiry_hours=1
        )
        sms_client = _get_sms_client()
        full_phone = f"{user.phone_country_code}{user.phone_number}"
        success, msg, _ = sms_client.send_verification_code(full_phone, token)
        await session.commit()

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=msg,
            )

        return VerificationResponse(
            success=True,
            message="Verification code sent",
            profile_status=user.status,
        )

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification type. Use 'email' or 'phone'.",
        )


# ============================================================================
# Profile Status
# ============================================================================

@router.get(
    "/profile/status/{username}",
    response_model=ProfileStatusResponse,
    responses={404: {"description": "User not found"}},
)
async def get_profile_status(
    username: str,
    session: AsyncSession = Depends(get_async_session),
) -> ProfileStatusResponse:
    """Get user's profile status."""
    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    methods_str = ", ".join(m.upper() for m in _user_mfa_methods_summary(user))
    return ProfileStatusResponse(
        username=user.username,
        email=_mask_email(user.email),
        phone=user.masked_phone,
        status=user.status,
        email_verified=user.email_verified,
        phone_verified=user.phone_verified,
        mfa_method=methods_str or (user.mfa_method or ""),
        created_at=user.created_at.isoformat(),
    )


# ============================================================================
# MFA Methods
# ============================================================================

@router.get("/mfa/methods", response_model=MFAMethodsResponse)
async def get_mfa_methods() -> MFAMethodsResponse:
    """Get available MFA methods."""
    settings = get_settings()
    methods = ["totp"]
    if settings.enable_sms_2fa:
        methods.append("sms")
    return MFAMethodsResponse(methods=methods, sms_enabled=settings.enable_sms_2fa)


@router.get("/mfa/status/{username}", response_model=UserMFAStatusResponse)
async def get_mfa_status(
    username: str,
    session: AsyncSession = Depends(get_async_session),
) -> UserMFAStatusResponse:
    """Get user's MFA enrollment status."""
    user = await _get_user_with_mfa(session, username)
    if not user:
        return UserMFAStatusResponse(enrolled=False)

    methods = _user_mfa_methods_summary(user)
    enrolled = len(methods) > 0
    phone_number = user.masked_phone if _user_has_sms(user) else None

    return UserMFAStatusResponse(
        enrolled=enrolled,
        mfa_method=", ".join(m.upper() for m in methods) if methods else None,
        mfa_methods=methods,
        phone_number=phone_number,
    )


# ============================================================================
# MFA Enrollment (for re-enrollment)
# ============================================================================

@router.post(
    "/auth/enroll",
    response_model=EnrollResponse,
    responses={
        400: {"description": "Bad request"},
        401: {"description": "Invalid credentials"},
        403: {"description": "User not active"},
    },
)
async def enroll(
    request: EnrollRequest,
    session: AsyncSession = Depends(get_async_session),
) -> EnrollResponse:
    """
    Enroll or re-enroll for MFA (for active users only). Adds a method to
    user_mfa_methods (or updates existing row for that method).
    """
    settings = get_settings()

    user = await _get_user_with_mfa(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Verify password
    if not _verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid password",
        )

    # Only active users can re-enroll
    if user.status != ProfileStatus.ACTIVE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only active users can update MFA enrollment",
        )

    # Validate SMS is enabled
    if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    if request.mfa_method == MFAMethod.TOTP:
        totp_manager = TOTPManager()
        secret = totp_manager.generate_secret()
        otpauth_uri = totp_manager.generate_otpauth_uri(
            secret=secret,
            username=user.username,
        )

        # Add or update TOTP row in user_mfa_methods
        existing_totp = next(
            (m for m in user.mfa_methods if m.method == "totp"),
            None,
        )
        if existing_totp:
            existing_totp.totp_secret = secret
        else:
            session.add(
                UserMFAMethod(
                    user_id=user.id,
                    method="totp",
                    totp_secret=secret,
                )
            )
        await session.commit()

        logger.info("User %s enrolled for TOTP MFA", user.username)

        return EnrollResponse(
            success=True,
            message="MFA enrollment updated. Scan the QR code.",
            mfa_method=MFAMethod.TOTP,
            otpauth_uri=otpauth_uri,
            secret=secret,
        )
    else:
        # SMS enrollment
        if not request.phone_number:
            phone = user.full_phone_number
        else:
            phone = request.phone_number

        sms_client = _get_sms_client()
        is_valid, error = sms_client.validate_phone_number(phone)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error,
            )

        phone_cc, phone_num = user.phone_country_code, user.phone_number
        if request.phone_number and request.phone_number.startswith("+"):
            match = re.match(r"^(\+\d{1,4})(\d+)$", request.phone_number)
            if match:
                phone_cc, phone_num = match.group(1), match.group(2)

        existing_sms = next(
            (m for m in user.mfa_methods if m.method == "sms"),
            None,
        )
        if existing_sms:
            existing_sms.phone_country_code = phone_cc
            existing_sms.phone_number = phone_num
        else:
            session.add(
                UserMFAMethod(
                    user_id=user.id,
                    method="sms",
                    phone_country_code=phone_cc,
                    phone_number=phone_num,
                )
            )
        await session.commit()

        logger.info("User %s enrolled for SMS MFA", user.username)

        return EnrollResponse(
            success=True,
            message="MFA enrollment updated for SMS.",
            mfa_method=MFAMethod.SMS,
            phone_number=user.masked_phone,
        )


# ============================================================================
# Login (two-step: start -> MFA -> verify)
# ============================================================================

@router.post(
    "/auth/login/start",
    response_model=LoginStartResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Profile incomplete or not activated"},
        503: {"description": "Application disabled or storage unavailable"},
    },
)
async def login_start(
    request: LoginStartRequest,
    session: AsyncSession = Depends(get_async_session),
    _: None = Depends(_require_app_active),
) -> LoginStartResponse:
    """
    Step 1: Validate username and password. Returns a challenge token and MFA options.
    """
    user = await _get_user_with_mfa(session, request.username)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not found. Please sign up first.",
        )

    if user.status == ProfileStatus.PENDING.value:
        missing = []
        if not user.email_verified:
            missing.append("email")
        if not user.phone_verified:
            missing.append("phone")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Profile incomplete. Please verify your: {', '.join(missing)}",
        )

    if user.status == ProfileStatus.COMPLETE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your profile is awaiting admin approval. Please wait for activation.",
        )

    ldap_client = LDAPClient()
    auth_success, auth_message = ldap_client.authenticate(
        request.username, request.password
    )
    if not auth_success:
        logger.warning("Login failed for %s: %s", request.username, auth_message)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    settings = get_settings()
    totp_enrolled = _user_has_totp(user)
    sms_available = bool(
        settings.enable_sms_2fa
        and _user_has_sms(user)
        and user.phone_country_code
        and user.phone_number
    )

    challenge_token = secrets.token_urlsafe(32)
    if not store_login_challenge(
        challenge_token,
        str(user.id),
        user.username,
        remember_me=getattr(request, "remember_me", False),
    ):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage unavailable. Please try again.",
        )

    return LoginStartResponse(
        challenge_token=challenge_token,
        totp_enrolled=totp_enrolled,
        sms_available=sms_available,
    )


class LoginTotpSetupRequest(BaseModel):
    """Request for TOTP setup (challenge only)."""
    challenge_token: str = Field(..., description="Token from login/start")


@router.post(
    "/auth/login/totp-setup",
    response_model=LoginTotpSetupResponse,
    responses={400: {"description": "TOTP already enrolled"}, 401: {"description": "Invalid or expired challenge"}},
)
async def login_totp_setup(
    request: LoginTotpSetupRequest,
    session: AsyncSession = Depends(get_async_session),
) -> LoginTotpSetupResponse:
    """
    Generate TOTP secret for a user who has not yet enrolled. Call after login/start when totp_enrolled is False.
    """
    challenge = get_login_challenge(request.challenge_token)
    if not challenge:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired login session. Please log in again.",
        )

    user = await _get_user_by_id_with_mfa(session, uuid.UUID(challenge["user_id"]))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    if _user_has_totp(user):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Authenticator app is already set up.",
        )

    totp_manager = TOTPManager()
    secret = totp_manager.generate_secret()
    otpauth_uri = totp_manager.generate_otpauth_uri(
        secret=secret,
        username=user.username,
    )
    session.add(
        UserMFAMethod(
            user_id=user.id,
            method="totp",
            totp_secret=secret,
        )
    )
    await session.commit()

    return LoginTotpSetupResponse(otpauth_uri=otpauth_uri, secret=secret)


@router.post(
    "/auth/login/verify",
    response_model=LoginResponse,
    responses={
        401: {"description": "Invalid or expired challenge or verification code"},
        503: {"description": "Application disabled or storage unavailable"},
    },
)
async def login_verify(
    request: LoginVerifyRequest,
    session: AsyncSession = Depends(get_async_session),
    _: None = Depends(_require_app_active),
) -> LoginResponse:
    """
    Step 2: Verify MFA code and return JWT. Consumes the challenge token.
    """
    challenge = get_login_challenge(request.challenge_token)
    if not challenge:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired login session. Please log in again.",
        )

    user = await _get_user_by_id_with_mfa(session, uuid.UUID(challenge["user_id"]))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    username = user.username
    totp_secret = _user_totp_secret(user)

    if request.mfa_method == MFAMethod.TOTP:
        if not totp_secret:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authenticator app not set up. Please complete setup first.",
            )
        totp_manager = TOTPManager()
        if not totp_manager.verify_totp(totp_secret, request.verification_code):
            logger.warning("Login verify failed for %s: Invalid TOTP", username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )
    elif request.mfa_method == MFAMethod.SMS:
        otp_client = get_otp_client()
        if not otp_client.is_connected:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage unavailable. Please try again.",
            )
        sms_code_data = otp_client.get_code(username)
        if not sms_code_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No verification code sent. Please request a code first.",
            )
        if not hmac.compare_digest(request.verification_code, sms_code_data["code"]):
            logger.warning("Login verify failed for %s: Invalid SMS code", username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )
        otp_client.delete_code(username)
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid mfa_method")

    remember_me = challenge.get("remember_me", False)
    delete_login_challenge(request.challenge_token)

    ldap_client = LDAPClient()
    is_admin = ldap_client.is_admin(username)

    settings = get_settings()
    expires_delta = None
    if remember_me:
        expires_delta = timedelta(days=settings.jwt_refresh_expiry_days)
    token = _create_jwt_token(
        user_id=str(user.id),
        username=username,
        is_admin=is_admin,
        expires_delta=expires_delta,
    )
    logger.info("User %s logged in successfully", username)
    return LoginResponse(
        success=True,
        message="Login successful",
        is_admin=is_admin,
        token=token,
        username=username,
    )


# ============================================================================
# Legacy one-step login (kept for backward compatibility; frontend uses two-step)
# ============================================================================

@router.post(
    "/auth/login",
    response_model=LoginResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Profile incomplete or not activated"},
        503: {"description": "Application disabled or storage unavailable"},
    },
)
async def login(
    request: LoginRequest,
    session: AsyncSession = Depends(get_async_session),
    _: None = Depends(_require_app_active),
) -> LoginResponse:
    """
    Authenticate user with username, password, and verification code (legacy one-step).
    """
    user = await _get_user_with_mfa(session, request.username)

    # Check if user exists
    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not found. Please sign up first.",
        )

    # Check profile status
    if user.status == ProfileStatus.PENDING.value:
        missing = []
        if not user.email_verified:
            missing.append("email")
        if not user.phone_verified:
            missing.append("phone")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Profile incomplete. Please verify your: {', '.join(missing)}",
        )

    if user.status == ProfileStatus.COMPLETE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your profile is awaiting admin approval. Please wait for activation.",
        )

    # Only ACTIVE users can login - verify against LDAP
    ldap_client = LDAPClient()
    auth_success, auth_message = ldap_client.authenticate(
        request.username, request.password
    )

    if not auth_success:
        logger.warning("Login failed for %s: %s", request.username, auth_message)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    # Verify MFA code (legacy one-step: try TOTP first if enrolled, else SMS)
    totp_secret = _user_totp_secret(user)
    if _user_has_totp(user):
        if not totp_secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="TOTP not configured",
            )
        totp_manager = TOTPManager()
        if not totp_manager.verify_totp(totp_secret, request.verification_code):
            logger.warning("Login failed for %s: Invalid TOTP", request.username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )
    elif _user_has_sms(user):
        # Verify SMS code (Redis only)
        otp_client = get_otp_client()
        if not otp_client.is_connected:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage unavailable. Please try again.",
            )
        sms_code_data = otp_client.get_code(request.username)
        if not sms_code_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No verification code sent. Please request a code first.",
            )
        if not hmac.compare_digest(
            request.verification_code, sms_code_data["code"]
        ):
            logger.warning(
                f"Login failed for {request.username}: Invalid SMS code"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )
        otp_client.delete_code(request.username)
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No MFA method enrolled. Please complete enrollment.",
        )

    # Check if user is admin
    is_admin = ldap_client.is_admin(request.username)

    # Generate JWT token
    token = _create_jwt_token(
        user_id=str(user.id),
        username=user.username,
        is_admin=is_admin,
    )

    logger.info("User %s logged in successfully", request.username)

    return LoginResponse(
        success=True,
        message="Login successful",
        is_admin=is_admin,
        token=token,
        username=user.username,
    )


@router.post(
    "/auth/sms/send-code",
    response_model=SMSSendCodeResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "User not enrolled for SMS or no phone"},
        400: {"description": "Provide either challenge_token or username+password"},
    },
)
async def send_sms_code(
    request: SMSSendCodeRequest,
    session: AsyncSession = Depends(get_async_session),
) -> SMSSendCodeResponse:
    """Send SMS verification code for login. Use challenge_token (after login/start) or username+password."""
    settings = get_settings()

    if not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    if request.challenge_token:
        challenge = get_login_challenge(request.challenge_token)
        if not challenge:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired login session. Please log in again.",
            )
        user = await _get_user_by_id_with_mfa(session, uuid.UUID(challenge["user_id"]))
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        if not (user.phone_country_code and user.phone_number):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No phone number on file for SMS.",
            )
        if not _user_has_sms(user):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User not enrolled for SMS MFA",
            )
        # User already passed step 1 (username + password); challenge is sufficient
    elif request.username and request.password:
        user = await _get_user_with_mfa(session, request.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        if user.status == ProfileStatus.ACTIVE.value:
            ldap_client = LDAPClient()
            auth_success, _ = ldap_client.authenticate(request.username, request.password)
            if not auth_success:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid username or password",
                )
        else:
            if not _verify_password(request.password, user.password_hash):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid username or password",
                )
        if not _user_has_sms(user):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User not enrolled for SMS MFA",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide either challenge_token or username and password.",
        )

    # Generate and send code
    sms_client = _get_sms_client()
    code = _generate_verification_code(settings.sms_code_length)

    success, message, _ = sms_client.send_verification_code(
        user.full_phone_number, code
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send SMS: {message}",
        )

    # Store code for verification (Redis only)
    otp_client = get_otp_client()
    if not otp_client.is_connected:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage unavailable. Please try again.",
        )
    stored = otp_client.store_code(
        username=user.username,
        code=code,
        phone_number=user.full_phone_number,
        ttl_seconds=settings.sms_code_expiry_seconds,
    )
    if not stored:
        logger.error("Failed to store OTP code for %s", user.username)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to store verification code. Please try again.",
        )

    logger.info("SMS code sent to user %s", user.username)

    return SMSSendCodeResponse(
        success=True,
        message="Verification code sent",
        phone_number=user.masked_phone,
        expires_in_seconds=settings.sms_code_expiry_seconds,
    )


# ============================================================================
# Admin Endpoints
# ============================================================================

@router.post(
    "/admin/login",
    response_model=LoginResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Not an admin"},
    },
)
async def admin_login(
    request: LoginRequest,
    session: AsyncSession = Depends(get_async_session),
) -> LoginResponse:
    """Admin login - same as regular login but verifies admin status."""
    # Use regular login flow
    response = await login(request, session)

    if not response.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Admin privileges required.",
        )

    return response


@router.get(
    "/admin/users",
    response_model=AdminUserListResponse,
    responses={401: {"description": "Invalid credentials"}, 403: {"description": "Not admin"}},
)
async def admin_list_users(
    admin_username: str,
    admin_password: str,
    status_filter: Optional[str] = None,
    session: AsyncSession = Depends(get_async_session),
) -> AdminUserListResponse:
    """List users (admin only)."""
    # Verify admin credentials
    ldap_client = LDAPClient()
    auth_success, _ = ldap_client.authenticate(admin_username, admin_password)
    if not auth_success:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
        )

    if not ldap_client.is_admin(admin_username):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )

    # Build query
    query = select(User).options(selectinload(User.mfa_methods))
    if status_filter:
        query = query.where(User.status == status_filter)
    query = query.order_by(User.created_at.desc())

    result = await session.execute(query)
    users = result.scalars().all()

    user_list = [
        {
            "id": str(u.id),
            "username": u.username,
            "email": u.email,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "phone": u.full_phone_number,
            "status": u.status,
            "email_verified": u.email_verified,
            "phone_verified": u.phone_verified,
            "mfa_method": ", ".join(m.upper() for m in _user_mfa_methods_summary(u)) or (u.mfa_method or ""),
            "created_at": u.created_at.isoformat(),
            "activated_at": u.activated_at.isoformat() if u.activated_at else None,
            "activated_by": u.activated_by,
        }
        for u in users
    ]

    return AdminUserListResponse(users=user_list, total=len(user_list))


@router.post(
    "/admin/users/{user_id}/activate",
    response_model=AdminActivateResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Not admin or user not ready"},
        404: {"description": "User not found"},
    },
)
async def admin_activate_user(
    user_id: str,
    request: AdminActivateRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> AdminActivateResponse:
    """Activate a user (create in LDAP)."""
    # Use JWT authentication if token provided, otherwise fall back to legacy admin credentials
    current = None
    admin_username = None

    if authorization and authorization.startswith("Bearer "):
        try:
            current = await _get_current_user(authorization, session)
            if not current["is_admin"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Admin privileges required",
                )
            admin_username = current["username"]
        except HTTPException as e:
            # If JWT fails, fall back to legacy auth (if provided)
            if not request.admin_username or not request.admin_password:
                raise e

    # Fall back to legacy admin credentials if JWT not provided or failed
    if not current:
        if not request.admin_username or not request.admin_password:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required. Provide JWT token or admin credentials.",
            )

        ldap_client = LDAPClient()
        auth_success, _ = ldap_client.authenticate(
            request.admin_username, request.admin_password
        )
        if not auth_success:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid admin credentials",
            )

        if not ldap_client.is_admin(request.admin_username):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required",
            )
        admin_username = request.admin_username

    # Get user
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.status != ProfileStatus.COMPLETE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"User cannot be activated. Current status: {user.status}",
        )

    # Group assignment is required for activation
    if not request.group_ids or len(request.group_ids) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one group must be assigned during activation",
        )

    # Create user in LDAP
    # We need to get the plain password, but we only have the hash
    # The admin will need to set a temporary password or we use a token-based approach
    # For now, we'll generate a temporary password and require the user to reset it

    temp_password = secrets.token_urlsafe(16)

    success, message = ldap_client.create_user(
        username=user.username,
        password=temp_password,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create LDAP user: {message}",
        )

    # Assign user to groups (required - at least one group must be assigned)
    assigned_groups = []
    for group_id in request.group_ids:
        try:
            group_uuid = uuid.UUID(group_id)
        except ValueError:
            logger.warning("Invalid group ID format: %s", group_id)
            continue

        # Get group
        result = await session.execute(select(Group).where(Group.id == group_uuid))
        group = result.scalar_one_or_none()
        if not group:
            logger.warning("Group not found: %s", group_id)
            continue

        # Add to LDAP group
        success, msg = ldap_client.add_user_to_group(user.username, group.ldap_dn)
        if not success:
            logger.warning("Failed to add %s to LDAP group %s: %s", user.username, group.name, msg)
        else:
            # Create database assignment
            user_group = UserGroup(
                user_id=user.id,
                group_id=group_uuid,
                assigned_by=admin_username,
            )
            session.add(user_group)
            assigned_groups.append(group.name)
            logger.info("User %s assigned to group %s during activation", user.username, group.name)

    if not assigned_groups:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to assign user to any groups. Please verify group IDs are valid.",
        )

    # Update user status
    user.status = ProfileStatus.ACTIVE.value
    user.activated_at = datetime.now(timezone.utc)
    user.activated_by = admin_username
    # Update password hash to match the temp password (user will use this until LDAP password reset)
    user.password_hash = _hash_password(temp_password)

    await session.commit()

    # Send welcome email
    try:
        email_client = EmailClient()
        email_client.send_welcome_email(
            to_email=user.email,
            username=user.username,
            first_name=user.first_name,
        )
    except Exception as e:
        logger.error("Failed to send welcome email: %s", e)

    logger.info("User %s activated by %s", user.username, admin_username)

    return AdminActivateResponse(
        success=True,
        message=f"User {user.username} activated successfully. A temporary password has been set.",
    )


@router.post(
    "/admin/users/{user_id}/reject",
    response_model=AdminActivateResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Not admin"},
        404: {"description": "User not found"},
    },
)
async def admin_reject_user(
    user_id: str,
    request: AdminActivateRequest,
    session: AsyncSession = Depends(get_async_session),
) -> AdminActivateResponse:
    """Reject and delete a user."""
    # Verify admin credentials
    ldap_client = LDAPClient()
    auth_success, _ = ldap_client.authenticate(
        request.admin_username, request.admin_password
    )
    if not auth_success:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
        )

    if not ldap_client.is_admin(request.admin_username):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )

    # Get user
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    username = user.username
    await session.delete(user)
    await session.commit()

    logger.info("User %s rejected/deleted by %s", username, request.admin_username)

    return AdminActivateResponse(
        success=True,
        message=f"User {username} has been rejected and removed.",
    )


# ============================================================================
# Profile Endpoints
# ============================================================================

@router.post(
    "/profile/request-email-change",
    response_model=VerificationResponse,
    responses={
        400: {"description": "Email already in use"},
        401: {"description": "Not authenticated"},
    },
)
async def request_email_change(
    request: RequestEmailChangeRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> VerificationResponse:
    """
    Request to change email. Sends a verification link to the new address.
    User must complete verification (click link), then the new email is applied.
    """
    current = await _get_current_user(authorization, session)
    user = await _get_user_by_username(session, current["username"])
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    new_email = request.new_email.strip().lower()
    if new_email == user.email:
        return VerificationResponse(
            success=True,
            message="Email unchanged",
            profile_status=user.status,
        )
    existing = await _get_user_by_email(session, new_email)
    if existing and existing.id != user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already in use",
        )

    settings = get_settings()
    if not settings.enable_email_verification:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email verification is not enabled",
        )
    try:
        email_token = await _create_verification_token(
            session, user.id, "eml_chg",
            settings.email_verification_expiry_hours,
            target_value=new_email,
        )
        email_client = EmailClient()
        success, msg = email_client.send_verification_email(
            to_email=new_email,
            token=email_token,
            username=user.username,
            first_name=user.first_name,
        )
        await session.commit()
        if not success:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=msg)
    except HTTPException:
        raise
    except Exception as e:
        logger.warning("Failed to send email change verification: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email",
        )
    return VerificationResponse(
        success=True,
        message="Verification email sent to your new address",
        profile_status=user.status,
    )


@router.post(
    "/profile/request-phone-change",
    response_model=VerificationResponse,
    responses={
        401: {"description": "Not authenticated"},
    },
)
async def request_phone_change(
    request: RequestPhoneChangeRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> VerificationResponse:
    """
    Request to change phone. Sends a verification code to the new number.
    User must submit the code via verify-phone, then the new phone is applied.
    """
    current = await _get_current_user(authorization, session)
    user = await _get_user_by_username(session, current["username"])
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    full_phone = f"{request.phone_country_code}{request.phone_number}"
    target_value = f"{request.phone_country_code}|{request.phone_number}"
    try:
        phone_token = await _create_verification_token(
            session, user.id, "phn_chg", expiry_hours=1, target_value=target_value,
        )
        sms_client = _get_sms_client()
        success, msg, _ = sms_client.send_verification_code(full_phone, phone_token)
        await session.commit()
        if not success:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=msg)
    except HTTPException:
        raise
    except Exception as e:
        logger.warning("Failed to send phone change verification: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification code",
        )
    return VerificationResponse(
        success=True,
        message="Verification code sent to your new number",
        profile_status=user.status,
    )


@router.get(
    "/profile/{username}",
    response_model=ProfileResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized"},
        404: {"description": "User not found"},
    },
)
async def get_profile(
    username: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> ProfileResponse:
    """Get user profile. Users can only view their own profile unless admin."""
    current = await _get_current_user(authorization, session)

    # Check authorization - users can only view their own profile
    if current["username"] != username.lower() and not current["is_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own profile",
        )

    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Get user's groups
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user.id).options(
            selectinload(UserGroup.group)
        )
    )
    user_groups = result.scalars().all()
    groups = [
        {"id": str(ug.group_id), "name": ug.group.name}
        for ug in user_groups if ug.group
    ]

    methods_summary = _user_mfa_methods_summary(user)
    mfa_methods_list = []
    for m in user.mfa_methods or []:
        phone_number = None
        if m.method == "sms":
            if m.phone_country_code and m.phone_number:
                full = f"{m.phone_country_code}{m.phone_number}"
                phone_number = "*" * max(0, len(full) - 4) + full[-4:] if len(full) > 4 else full
            else:
                phone_number = user.masked_phone
        mfa_methods_list.append(
            ProfileMFAMethodItem(
                id=str(m.id),
                method=m.method,
                phone_number=phone_number,
            )
        )

    return ProfileResponse(
        id=str(user.id),
        username=user.username,
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        phone_country_code=user.phone_country_code,
        phone_number=user.phone_number,
        email_verified=user.email_verified,
        phone_verified=user.phone_verified,
        mfa_method=", ".join(m.upper() for m in methods_summary) if methods_summary else (user.mfa_method or ""),
        mfa_methods=mfa_methods_list,
        status=user.status,
        created_at=user.created_at.isoformat() if user.created_at else "",
        groups=groups,
    )


@router.put(
    "/profile/{username}",
    response_model=ProfileResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized or field not editable"},
        404: {"description": "User not found"},
    },
)
async def update_profile(
    username: str,
    request: ProfileUpdateRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> ProfileResponse:
    """
    Update user profile.

    - Users can only update their own profile (when logged in).
    - Email and phone can only be changed when not yet verified (e.g. after signup).
    - To change email or phone after verification, use request-email-change /
      request-phone-change, complete verification, then submit the profile form again.
    """
    current = await _get_current_user(authorization, session)

    if current["username"] != username.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only update your own profile",
        )

    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if request.first_name is not None:
        user.first_name = request.first_name

    if request.last_name is not None:
        user.last_name = request.last_name

    # Password change: verify current, sync to LDAP and DB
    if request.current_password and request.new_password and request.confirm_password:
        if user.status != ProfileStatus.ACTIVE.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account must be active to change password",
            )
        ldap_client = LDAPClient()
        if not ldap_client.user_exists(user.username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Account is not active in LDAP. Please contact support.",
            )
        auth_ok, _ = ldap_client.authenticate(user.username, request.current_password)
        if not auth_ok:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect",
            )
        success, msg = ldap_client.change_password(user.username, request.new_password)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update password. Please try again.",
            )
        user.password_hash = _hash_password(request.new_password)

    # Email: only change if not verified; otherwise use request-email-change flow
    if request.email is not None:
        if user.email_verified and request.email.strip().lower() != user.email:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Verify your new email first using the link we sent, then save again.",
            )
        if not user.email_verified:
            new_email = request.email.strip().lower()
            if new_email != user.email:
                existing = await _get_user_by_email(session, new_email)
                if existing and existing.id != user.id:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Email already in use",
                    )
                user.email = new_email

    # Phone: only change if not verified; otherwise use request-phone-change flow
    if request.phone_country_code is not None or request.phone_number is not None:
        new_code = request.phone_country_code if request.phone_country_code is not None else user.phone_country_code
        new_number = request.phone_number if request.phone_number is not None else user.phone_number
        if user.phone_verified and (new_code != user.phone_country_code or new_number != user.phone_number):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Verify your new phone first with the code we sent, then save again.",
            )
        if not user.phone_verified:
            if request.phone_country_code is not None:
                user.phone_country_code = request.phone_country_code
            if request.phone_number is not None:
                user.phone_number = request.phone_number

    await session.commit()

    # Sync profile changes to LDAP for active users (LDAP has givenName, sn, mail)
    if user.status == ProfileStatus.ACTIVE.value:
        try:
            ldap_client = LDAPClient()
            success, msg = ldap_client.update_user(
                username=user.username,
                password=None,
                first_name=user.first_name,
                last_name=user.last_name,
                email=user.email,
            )
            if not success:
                logger.warning("Failed to sync profile to LDAP for %s: %s", user.username, msg)
        except Exception as e:
            logger.warning("LDAP sync failed for profile update: %s", type(e).__name__)

    # Get user's groups for response
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user.id).options(
            selectinload(UserGroup.group)
        )
    )
    user_groups = result.scalars().all()
    groups = [
        {"id": str(ug.group_id), "name": ug.group.name}
        for ug in user_groups if ug.group
    ]

    logger.info("Profile updated for user %s", username)

    methods_summary = _user_mfa_methods_summary(user)
    mfa_methods_list = []
    for m in user.mfa_methods or []:
        phone_number = None
        if m.method == "sms":
            if m.phone_country_code and m.phone_number:
                full = f"{m.phone_country_code}{m.phone_number}"
                phone_number = "*" * max(0, len(full) - 4) + full[-4:] if len(full) > 4 else full
            else:
                phone_number = user.masked_phone
        mfa_methods_list.append(
            ProfileMFAMethodItem(
                id=str(m.id),
                method=m.method,
                phone_number=phone_number,
            )
        )

    return ProfileResponse(
        id=str(user.id),
        username=user.username,
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        phone_country_code=user.phone_country_code,
        phone_number=user.phone_number,
        email_verified=user.email_verified,
        phone_verified=user.phone_verified,
        mfa_method=", ".join(m.upper() for m in methods_summary) if methods_summary else (user.mfa_method or ""),
        mfa_methods=mfa_methods_list,
        status=user.status,
        created_at=user.created_at.isoformat() if user.created_at else "",
        groups=groups,
    )


@router.post(
    "/profile/{username}/change-password",
    response_model=ChangePasswordResponse,
    responses={
        400: {"description": "Validation error (passwords do not match, etc.)"},
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized"},
        404: {"description": "User not found"},
    },
)
async def change_password(
    username: str,
    request: ChangePasswordRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> ChangePasswordResponse:
    """
    Change the authenticated user's password in OpenLDAP.

    Requires current password verification. New and confirm passwords must match.
    """
    current = await _get_current_user(authorization, session)

    if current["username"] != username.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only change your own password",
        )

    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    ldap_client = LDAPClient()
    if not ldap_client.user_exists(user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not active in LDAP. Please contact support.",
        )

    auth_success, _ = ldap_client.authenticate(user.username, request.current_password)
    if not auth_success:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect",
        )

    success, msg = ldap_client.change_password(user.username, request.new_password)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update password. Please try again.",
        )

    user.password_hash = _hash_password(request.new_password)
    await session.commit()

    logger.info("Password changed for user %s via profile", user.username)

    return ChangePasswordResponse(
        success=True,
        message="Your password has been changed successfully.",
    )


# ============================================================================
# Profile MFA methods (add/remove; at least one required)
# ============================================================================

class ProfileAddMFAMethodRequest(BaseModel):
    """Request to add an MFA method from profile (authenticated)."""
    mfa_method: MFAMethod = Field(..., description="totp or sms")
    phone_number: Optional[str] = Field(None, description="Phone for SMS (optional; uses profile phone)")


class ProfileAddMFAMethodResponse(BaseModel):
    """Response after adding TOTP (QR/secret) or SMS."""
    success: bool = Field(..., description="Whether the method was added")
    message: str = Field(..., description="Response message")
    mfa_method: str = Field(..., description="totp or sms")
    otpauth_uri: Optional[str] = Field(None, description="TOTP otpauth URI for QR")
    secret: Optional[str] = Field(None, description="TOTP secret for manual entry")
    phone_number: Optional[str] = Field(None, description="Masked phone for SMS")


@router.get(
    "/profile/{username}/mfa-methods",
    response_model=list[ProfileMFAMethodItem],
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized"},
        404: {"description": "User not found"},
    },
)
async def list_profile_mfa_methods(
    username: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> list[ProfileMFAMethodItem]:
    """List enrolled MFA methods for the user (same user or admin)."""
    current = await _get_current_user(authorization, session)
    if current["username"] != username.lower() and not current["is_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own MFA methods",
        )
    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    out = []
    for m in user.mfa_methods or []:
        phone_number = None
        if m.method == "sms":
            if m.phone_country_code and m.phone_number:
                full = f"{m.phone_country_code}{m.phone_number}"
                phone_number = "*" * max(0, len(full) - 4) + full[-4:] if len(full) > 4 else full
            else:
                phone_number = user.masked_phone
        out.append(
            ProfileMFAMethodItem(id=str(m.id), method=m.method, phone_number=phone_number)
        )
    return out


@router.post(
    "/profile/{username}/mfa-methods",
    response_model=ProfileAddMFAMethodResponse,
    responses={
        400: {"description": "Bad request (e.g. method already added)"},
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized"},
        404: {"description": "User not found"},
    },
)
async def add_profile_mfa_method(
    username: str,
    request: ProfileAddMFAMethodRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> ProfileAddMFAMethodResponse:
    """Add an MFA method from profile (authenticated). At least one method must remain when disabling others."""
    current = await _get_current_user(authorization, session)
    if current["username"] != username.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only manage your own MFA methods",
        )
    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    settings = get_settings()
    if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    existing = next((m for m in (user.mfa_methods or []) if m.method == request.mfa_method.value), None)
    if existing:
        if request.mfa_method == MFAMethod.TOTP:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Authenticator app is already added. Remove it first to re-enroll.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS is already added.",
        )

    if request.mfa_method == MFAMethod.TOTP:
        totp_manager = TOTPManager()
        secret = totp_manager.generate_secret()
        otpauth_uri = totp_manager.generate_otpauth_uri(
            secret=secret,
            username=user.username,
        )
        session.add(
            UserMFAMethod(
                user_id=user.id,
                method="totp",
                totp_secret=secret,
            )
        )
        await session.commit()
        logger.info("User %s added TOTP from profile", user.username)
        return ProfileAddMFAMethodResponse(
            success=True,
            message="Scan the QR code with your authenticator app.",
            mfa_method="totp",
            otpauth_uri=otpauth_uri,
            secret=secret,
        )
    else:
        # SMS: use profile phone
        if not (user.phone_country_code and user.phone_number):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Add a phone number in your profile first.",
            )
        session.add(
            UserMFAMethod(
                user_id=user.id,
                method="sms",
                phone_country_code=user.phone_country_code,
                phone_number=user.phone_number,
            )
        )
        await session.commit()
        logger.info("User %s added SMS from profile", user.username)
        return ProfileAddMFAMethodResponse(
            success=True,
            message="SMS 2FA added. Codes will be sent to your profile phone.",
            mfa_method="sms",
            phone_number=user.masked_phone,
        )


@router.delete(
    "/profile/{username}/mfa-methods/{method}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        400: {"description": "Cannot remove last method"},
        401: {"description": "Not authenticated"},
        403: {"description": "Not authorized"},
        404: {"description": "User or method not found"},
    },
)
async def remove_profile_mfa_method(
    username: str,
    method: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> None:
    """Remove an MFA method. At least one method must remain."""
    current = await _get_current_user(authorization, session)
    if current["username"] != username.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only manage your own MFA methods",
        )
    user = await _get_user_with_mfa(session, username)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    method_lower = method.lower()
    if method_lower not in ("totp", "sms"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Method must be totp or sms",
        )

    to_remove = next((m for m in (user.mfa_methods or []) if m.method == method_lower), None)
    if not to_remove:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="MFA method not enrolled",
        )

    if len(user.mfa_methods or []) <= 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one 2FA method must remain. Add another method before removing this one.",
        )

    await session.delete(to_remove)
    await session.commit()
    logger.info("User %s removed %s MFA method", user.username, method_lower)


# ============================================================================
# Group Management Endpoints (Admin)
# ============================================================================

@router.get(
    "/admin/groups",
    response_model=GroupListResponse,
    responses={401: {"description": "Not authenticated"}, 403: {"description": "Not admin"}},
)
async def admin_list_groups(
    search: Optional[str] = Query(None, description="Search term"),
    sort_by: Optional[str] = Query("name", description="Sort field"),
    sort_order: Optional[str] = Query("asc", description="Sort order"),
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> GroupListResponse:
    """List all groups (admin only)."""
    await _require_admin(authorization, session)

    query = select(Group)

    # Apply search
    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                Group.name.ilike(search_term),
                Group.description.ilike(search_term),
            )
        )

    # Apply sorting
    if sort_by == "name":
        order_col = Group.name
    elif sort_by == "created_at":
        order_col = Group.created_at
    else:
        order_col = Group.name

    if sort_order == "desc":
        query = query.order_by(order_col.desc())
    else:
        query = query.order_by(order_col.asc())

    result = await session.execute(query.options(selectinload(Group.user_groups)))
    groups = result.scalars().all()

    group_list = [
        GroupResponse(
            id=str(g.id),
            name=g.name,
            description=g.description,
            ldap_dn=g.ldap_dn,
            member_count=len(g.user_groups) if g.user_groups else 0,
            created_at=g.created_at.isoformat() if g.created_at else "",
        )
        for g in groups
    ]

    return GroupListResponse(groups=group_list, total=len(group_list))


@router.post(
    "/admin/groups",
    response_model=GroupResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        400: {"description": "Group already exists"},
    },
)
async def admin_create_group(
    request: GroupCreateRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> GroupResponse:
    """Create a new group (admin only)."""
    await _require_admin(authorization, session)

    # Check if group name exists
    existing = await session.execute(
        select(Group).where(Group.name == request.name)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group name already exists",
        )

    # Create LDAP group
    ldap_client = LDAPClient()
    success, message, ldap_dn = ldap_client.create_group(
        name=request.name,
        description=request.description or "",
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create LDAP group: {message}",
        )

    # Create database record
    group = Group(
        name=request.name,
        description=request.description,
        ldap_dn=ldap_dn,
    )
    session.add(group)
    await session.commit()

    logger.info("Group %s created", request.name)

    return GroupResponse(
        id=str(group.id),
        name=group.name,
        description=group.description,
        ldap_dn=group.ldap_dn,
        member_count=0,
        created_at=group.created_at.isoformat() if group.created_at else "",
    )


@router.get(
    "/admin/groups/{group_id}",
    response_model=GroupDetailResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "Group not found"},
    },
)
async def admin_get_group(
    group_id: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> GroupDetailResponse:
    """Get group details (admin only)."""
    await _require_admin(authorization, session)

    try:
        group_uuid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid group ID format",
        )

    result = await session.execute(
        select(Group).where(Group.id == group_uuid).options(
            selectinload(Group.user_groups).selectinload(UserGroup.user)
        )
    )
    group = result.scalar_one_or_none()

    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    members = [
        {
            "id": str(ug.user.id),
            "username": ug.user.username,
            "full_name": ug.user.full_name,
            "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
            "assigned_by": ug.assigned_by,
        }
        for ug in group.user_groups if ug.user
    ]

    return GroupDetailResponse(
        id=str(group.id),
        name=group.name,
        description=group.description,
        ldap_dn=group.ldap_dn,
        member_count=len(members),
        created_at=group.created_at.isoformat() if group.created_at else "",
        members=members,
    )


@router.put(
    "/admin/groups/{group_id}",
    response_model=GroupResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "Group not found"},
    },
)
async def admin_update_group(
    group_id: str,
    request: GroupUpdateRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> GroupResponse:
    """Update a group (admin only)."""
    await _require_admin(authorization, session)

    try:
        group_uuid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid group ID format",
        )

    result = await session.execute(
        select(Group).where(Group.id == group_uuid).options(
            selectinload(Group.user_groups)
        )
    )
    group = result.scalar_one_or_none()

    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    # Update LDAP group
    if request.description is not None:
        ldap_client = LDAPClient()
        success, message = ldap_client.update_group(
            group_dn=group.ldap_dn,
            description=request.description,
        )
        if not success:
            logger.warning("Failed to update LDAP group: %s", message)

    # Update database
    if request.name is not None:
        # Check if name already exists
        existing = await session.execute(
            select(Group).where(Group.name == request.name, Group.id != group_uuid)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Group name already exists",
            )
        group.name = request.name

    if request.description is not None:
        group.description = request.description

    await session.commit()

    logger.info("Group %s updated", group.name)

    return GroupResponse(
        id=str(group.id),
        name=group.name,
        description=group.description,
        ldap_dn=group.ldap_dn,
        member_count=len(group.user_groups) if group.user_groups else 0,
        created_at=group.created_at.isoformat() if group.created_at else "",
    )


@router.delete(
    "/admin/groups/{group_id}",
    response_model=AdminActivateResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "Group not found"},
    },
)
async def admin_delete_group(
    group_id: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> AdminActivateResponse:
    """Delete a group (admin only)."""
    await _require_admin(authorization, session)

    try:
        group_uuid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid group ID format",
        )

    result = await session.execute(select(Group).where(Group.id == group_uuid))
    group = result.scalar_one_or_none()

    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    group_name = group.name
    ldap_dn = group.ldap_dn

    # Delete from LDAP
    ldap_client = LDAPClient()
    success, message = ldap_client.delete_group(ldap_dn)
    if not success:
        logger.warning("Failed to delete LDAP group: %s", message)

    # Delete from database (cascades to user_groups)
    await session.delete(group)
    await session.commit()

    logger.info("Group %s deleted", group_name)

    return AdminActivateResponse(
        success=True,
        message=f"Group {group_name} deleted successfully",
    )


# ============================================================================
# User-Group Assignment Endpoints (Admin)
# ============================================================================

@router.get(
    "/admin/users/{user_id}/groups",
    response_model=UserGroupResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "User not found"},
    },
)
async def admin_get_user_groups(
    user_id: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> UserGroupResponse:
    """Get user's group assignments (admin only)."""
    await _require_admin(authorization, session)

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(
        select(User).where(User.id == user_uuid)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Get user's groups
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user_uuid).options(
            selectinload(UserGroup.group)
        )
    )
    user_groups = result.scalars().all()

    groups = [
        {
            "id": str(ug.group_id),
            "name": ug.group.name if ug.group else "",
            "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
            "assigned_by": ug.assigned_by,
        }
        for ug in user_groups
    ]

    return UserGroupResponse(
        user_id=str(user.id),
        username=user.username,
        groups=groups,
    )


@router.post(
    "/admin/users/{user_id}/groups",
    response_model=UserGroupResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "User or group not found"},
    },
)
async def admin_assign_user_groups(
    user_id: str,
    request: UserGroupAssignRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> UserGroupResponse:
    """Assign user to groups (admin only). Adds to existing assignments."""
    current = await _require_admin(authorization, session)

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    ldap_client = LDAPClient()

    for group_id in request.group_ids:
        try:
            group_uuid = uuid.UUID(group_id)
        except ValueError:
            continue

        # Get group
        result = await session.execute(select(Group).where(Group.id == group_uuid))
        group = result.scalar_one_or_none()
        if not group:
            continue

        # Check if already assigned
        result = await session.execute(
            select(UserGroup).where(
                UserGroup.user_id == user_uuid,
                UserGroup.group_id == group_uuid,
            )
        )
        if result.scalar_one_or_none():
            continue

        # Add to LDAP group (only for active users)
        if user.status == ProfileStatus.ACTIVE.value:
            success, msg = ldap_client.add_user_to_group(user.username, group.ldap_dn)
            if not success:
                logger.warning("Failed to add %s to LDAP group: %s", user.username, msg)

        # Add database assignment
        user_group = UserGroup(
            user_id=user_uuid,
            group_id=group_uuid,
            assigned_by=current["username"],
        )
        session.add(user_group)

    await session.commit()

    # Return updated groups
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user_uuid).options(
            selectinload(UserGroup.group)
        )
    )
    user_groups = result.scalars().all()

    groups = [
        {
            "id": str(ug.group_id),
            "name": ug.group.name if ug.group else "",
            "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
            "assigned_by": ug.assigned_by,
        }
        for ug in user_groups
    ]

    logger.info("Groups assigned to user %s", user.username)

    return UserGroupResponse(
        user_id=str(user.id),
        username=user.username,
        groups=groups,
    )


@router.put(
    "/admin/users/{user_id}/groups",
    response_model=UserGroupResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "User not found"},
    },
)
async def admin_replace_user_groups(
    user_id: str,
    request: UserGroupAssignRequest,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> UserGroupResponse:
    """Replace all user's group assignments (admin only)."""
    current = await _require_admin(authorization, session)

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    ldap_client = LDAPClient()

    # Get current assignments
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user_uuid).options(
            selectinload(UserGroup.group)
        )
    )
    current_assignments = result.scalars().all()

    # Remove from LDAP groups (for active users)
    if user.status == ProfileStatus.ACTIVE.value:
        for ug in current_assignments:
            if ug.group:
                success, msg = ldap_client.remove_user_from_group(
                    user.username, ug.group.ldap_dn
                )
                if not success:
                    logger.warning(
                        "Failed to remove %s from LDAP group: %s",
                        user.username,
                        msg,
                    )

    # Delete all current assignments
    for ug in current_assignments:
        await session.delete(ug)

    # If removing all groups: delete from LDAP and set status to COMPLETE
    # (user can no longer log in until admin re-assigns groups and re-activates)
    if not request.group_ids and user.status == ProfileStatus.ACTIVE.value:
        success, message = ldap_client.delete_user(user.username)
        if not success:
            logger.warning("Failed to delete LDAP user: %s", message)
        user.status = ProfileStatus.COMPLETE.value

    # Add new assignments
    for group_id in request.group_ids:
        try:
            group_uuid = uuid.UUID(group_id)
        except ValueError:
            continue

        result = await session.execute(select(Group).where(Group.id == group_uuid))
        group = result.scalar_one_or_none()
        if not group:
            continue

        # Add to LDAP group (for active users)
        if user.status == ProfileStatus.ACTIVE.value:
            ldap_client.add_user_to_group(user.username, group.ldap_dn)

        user_group = UserGroup(
            user_id=user_uuid,
            group_id=group_uuid,
            assigned_by=current["username"],
        )
        session.add(user_group)

    await session.commit()

    # Return updated groups
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user_uuid).options(
            selectinload(UserGroup.group)
        )
    )
    user_groups = result.scalars().all()

    groups = [
        {
            "id": str(ug.group_id),
            "name": ug.group.name if ug.group else "",
            "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
            "assigned_by": ug.assigned_by,
        }
        for ug in user_groups
    ]

    logger.info("Groups replaced for user %s", user.username)

    return UserGroupResponse(
        user_id=str(user.id),
        username=user.username,
        groups=groups,
    )


@router.delete(
    "/admin/users/{user_id}/groups/{group_id}",
    response_model=AdminActivateResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin"},
        404: {"description": "User or assignment not found"},
    },
)
async def admin_remove_user_from_group(
    user_id: str,
    group_id: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> AdminActivateResponse:
    """Remove user from a specific group (admin only)."""
    await _require_admin(authorization, session)

    try:
        user_uuid = uuid.UUID(user_id)
        group_uuid = uuid.UUID(group_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid ID format",
        )

    # Get user
    result = await session.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Get assignment
    result = await session.execute(
        select(UserGroup).where(
            UserGroup.user_id == user_uuid,
            UserGroup.group_id == group_uuid,
        ).options(selectinload(UserGroup.group))
    )
    user_group = result.scalar_one_or_none()

    if not user_group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not assigned to this group",
        )

    # Remove from LDAP (for active users)
    ldap_client = LDAPClient()
    if user.status == ProfileStatus.ACTIVE.value and user_group.group:
        success, msg = ldap_client.remove_user_from_group(
            user.username, user_group.group.ldap_dn
        )
        if not success:
            logger.warning(
                "Failed to remove %s from LDAP group: %s", user.username, msg
            )

    group_name = user_group.group.name if user_group.group else "Unknown"
    await session.delete(user_group)
    await session.flush()

    # If this was the last group: delete from LDAP and set status to COMPLETE
    # (user can no longer log in until admin re-assigns groups and re-activates)
    result = await session.execute(
        select(UserGroup).where(UserGroup.user_id == user_uuid)
    )
    remaining = result.scalars().all()
    if not remaining and user.status == ProfileStatus.ACTIVE.value:
        success, message = ldap_client.delete_user(user.username)
        if not success:
            logger.warning("Failed to delete LDAP user: %s", message)
        user.status = ProfileStatus.COMPLETE.value

    await session.commit()

    logger.info("User %s removed from group %s", user.username, group_name)

    return AdminActivateResponse(
        success=True,
        message=f"User removed from group {group_name}",
    )


# ============================================================================
# User Revoke Endpoint (Admin)
# ============================================================================

@router.post(
    "/admin/users/{user_id}/revoke",
    response_model=AdminActivateResponse,
    responses={
        401: {"description": "Not authenticated"},
        403: {"description": "Not admin or user not active"},
        404: {"description": "User not found"},
    },
)
async def admin_revoke_user(
    user_id: str,
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> AdminActivateResponse:
    """
    Revoke an active user.

    - Removes user from all LDAP groups
    - Deletes user from LDAP
    - Updates status to REVOKED
    """
    current = await _require_admin(authorization, session)

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format",
        )

    result = await session.execute(
        select(User).where(User.id == user_uuid).options(
            selectinload(User.user_groups).selectinload(UserGroup.group)
        )
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.status != ProfileStatus.ACTIVE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only active users can be revoked",
        )

    ldap_client = LDAPClient()

    # Remove from all LDAP groups
    for ug in user.user_groups:
        if ug.group:
            success, msg = ldap_client.remove_user_from_group(
                user.username, ug.group.ldap_dn
            )
            if not success:
                logger.warning("Failed to remove %s from LDAP group: %s", user.username, msg)

    # Delete from LDAP
    success, message = ldap_client.delete_user(user.username)
    if not success:
        logger.warning("Failed to delete LDAP user: %s", message)

    # Update status to revoked
    user.status = ProfileStatus.REVOKED.value

    # Remove all group assignments from database
    for ug in user.user_groups:
        await session.delete(ug)

    await session.commit()

    logger.info("User %s revoked by %s", user.username, current['username'])

    return AdminActivateResponse(
        success=True,
        message=f"User {user.username} has been revoked",
    )


# ============================================================================
# Enhanced Admin User List with Sorting/Filtering/Search
# ============================================================================

@router.get(
    "/admin/users/enhanced",
    response_model=AdminUserListResponse,
    responses={401: {"description": "Not authenticated"}, 403: {"description": "Not admin"}},
)
async def admin_list_users_enhanced(
    status_filter: Optional[str] = Query(None, description="Filter by status"),
    group_filter: Optional[str] = Query(None, description="Filter by group ID"),
    search: Optional[str] = Query(None, description="Search term"),
    sort_by: Optional[str] = Query("created_at", description="Sort field"),
    sort_order: Optional[str] = Query("desc", description="Sort order"),
    authorization: Optional[str] = Header(None),
    session: AsyncSession = Depends(get_async_session),
) -> AdminUserListResponse:
    """List users with sorting, filtering, and search (admin only)."""
    await _require_admin(authorization, session)

    query = select(User).options(
        selectinload(User.mfa_methods),
        selectinload(User.user_groups).selectinload(UserGroup.group),
    )

    # Apply status filter
    if status_filter:
        query = query.where(User.status == status_filter)

    # Apply search
    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                User.username.ilike(search_term),
                User.email.ilike(search_term),
                User.first_name.ilike(search_term),
                User.last_name.ilike(search_term),
            )
        )

    # Apply sorting
    if sort_by == "username":
        order_col = User.username
    elif sort_by == "email":
        order_col = User.email
    elif sort_by == "first_name":
        order_col = User.first_name
    elif sort_by == "status":
        order_col = User.status
    else:
        order_col = User.created_at

    if sort_order == "asc":
        query = query.order_by(order_col.asc())
    else:
        query = query.order_by(order_col.desc())

    result = await session.execute(query)
    users = result.scalars().all()

    # Filter by group if specified
    if group_filter:
        try:
            group_uuid = uuid.UUID(group_filter)
            users = [
                u for u in users
                if any(ug.group_id == group_uuid for ug in u.user_groups)
            ]
        except ValueError:
            pass

    user_list = [
        {
            "id": str(u.id),
            "username": u.username,
            "email": u.email,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "phone": u.full_phone_number,
            "status": u.status,
            "email_verified": u.email_verified,
            "phone_verified": u.phone_verified,
            "mfa_method": ", ".join(m.upper() for m in _user_mfa_methods_summary(u)) or (u.mfa_method or ""),
            "created_at": u.created_at.isoformat() if u.created_at else "",
            "activated_at": u.activated_at.isoformat() if u.activated_at else None,
            "activated_by": u.activated_by,
            "groups": [
                {"id": str(ug.group_id), "name": ug.group.name if ug.group else ""}
                for ug in u.user_groups
            ],
        }
        for u in users
    ]

    return AdminUserListResponse(users=user_list, total=len(user_list))
