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
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.database import get_async_session, User, VerificationToken, ProfileStatus, Group, UserGroup
from app.email import EmailClient
from app.ldap import LDAPClient
from app.mfa import TOTPManager
from app.redis import get_otp_client, RedisOTPClient
from app.redis.client import InMemoryOTPStorage

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["authentication"])


# ============================================================================
# Enums and Constants
# ============================================================================

class MFAMethod(str, Enum):
    """Supported MFA methods."""
    TOTP = "totp"
    SMS = "sms"


# In-memory fallback storage for SMS verification codes (used when Redis is disabled)
# Structure: {username: {"code": "...", "expires_at": timestamp, "phone_number": "..."}}
# Note: When Redis is enabled, codes are stored in Redis with automatic TTL expiration


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
    mfa_method: MFAMethod = Field(default=MFAMethod.TOTP, description="MFA method")

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
    """Login request model."""
    username: str = Field(..., min_length=1, description="Username")
    password: str = Field(..., min_length=1, description="Password")
    verification_code: str = Field(..., min_length=6, max_length=6, description="6-digit code")


class LoginResponse(BaseModel):
    """Login response model."""
    success: bool = Field(..., description="Whether login was successful")
    message: str = Field(..., description="Response message")
    is_admin: bool = Field(False, description="Whether user is admin")
    token: Optional[str] = Field(None, description="JWT access token")
    username: Optional[str] = Field(None, description="Logged in username")


class SMSSendCodeRequest(BaseModel):
    """Request to send SMS verification code."""
    username: str = Field(..., min_length=1, description="Username")
    password: str = Field(..., min_length=1, description="Password")


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
    mfa_method: Optional[str] = Field(None, description="Enrolled MFA method")
    phone_number: Optional[str] = Field(None, description="Masked phone")


# Admin models
class AdminUserListResponse(BaseModel):
    """Admin user list response."""
    users: list[dict] = Field(..., description="List of users")
    total: int = Field(..., description="Total count")


class AdminActivateRequest(BaseModel):
    """Admin user activation request (supports both JWT and legacy auth)."""
    admin_username: Optional[str] = Field(None, description="Admin username (legacy auth, optional if JWT provided)")
    admin_password: Optional[str] = Field(None, description="Admin password (legacy auth, optional if JWT provided)")
    group_ids: list[str] = Field(default_factory=list, description="List of group IDs to assign during activation")


class AdminActivateResponse(BaseModel):
    """Admin activation response."""
    success: bool = Field(..., description="Whether activation was successful")
    message: str = Field(..., description="Response message")


# Profile Models
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
    mfa_method: str = Field(..., description="MFA method")
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


async def _create_verification_token(
    session: AsyncSession,
    user_id: uuid.UUID,
    token_type: str,
    expiry_hours: int = 24,
) -> str:
    """Create a verification token."""
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
    if token_type == "email":
        token = str(uuid.uuid4())
    else:
        token = _generate_verification_code(6)

    verification_token = VerificationToken(
        user_id=user_id,
        token_type=token_type,
        token=token,
        expires_at=datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
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

    # Validate SMS method is enabled if selected
    if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    # Generate TOTP secret if needed
    totp_secret = None
    if request.mfa_method == MFAMethod.TOTP:
        totp_manager = TOTPManager()
        totp_secret = totp_manager.generate_secret()

    # Create user
    user = User(
        username=request.username.lower(),
        email=request.email.lower(),
        first_name=request.first_name,
        last_name=request.last_name,
        phone_country_code=request.phone_country_code,
        phone_number=request.phone_number,
        password_hash=_hash_password(request.password),
        mfa_method=request.mfa_method.value,
        totp_secret=totp_secret,
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
    """Verify user's email address."""
    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.email_verified:
        return VerificationResponse(
            success=True,
            message="Email already verified",
            profile_status=user.status,
        )

    # Find valid token
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.user_id == user.id,
            VerificationToken.token_type == "email",
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

    # Mark as verified
    token.used = True
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
    """Verify user's phone number."""
    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.phone_verified:
        return VerificationResponse(
            success=True,
            message="Phone already verified",
            profile_status=user.status,
        )

    # Find valid token
    result = await session.execute(
        select(VerificationToken).where(
            VerificationToken.user_id == user.id,
            VerificationToken.token_type == "phone",
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

    # Constant-time comparison
    if not hmac.compare_digest(request.code, token.token):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )

    # Mark as verified
    token.used = True
    user.phone_verified = True
    user.update_status_if_complete()

    await session.commit()

    logger.info("User %s verified phone", user.username)

    return VerificationResponse(
        success=True,
        message="Phone verified successfully",
        profile_status=user.status,
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
    user = await _get_user_by_username(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return ProfileStatusResponse(
        username=user.username,
        email=_mask_email(user.email),
        phone=user.masked_phone,
        status=user.status,
        email_verified=user.email_verified,
        phone_verified=user.phone_verified,
        mfa_method=user.mfa_method,
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
    user = await _get_user_by_username(session, username)
    if not user:
        return UserMFAStatusResponse(enrolled=False)

    phone_number = None
    if user.mfa_method == "sms":
        phone_number = user.masked_phone

    return UserMFAStatusResponse(
        enrolled=user.totp_secret is not None or user.mfa_method == "sms",
        mfa_method=user.mfa_method,
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
    Enroll or re-enroll for MFA (for active users only).
    """
    settings = get_settings()

    user = await _get_user_by_username(session, request.username)
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

        user.mfa_method = "totp"
        user.totp_secret = secret
        await session.commit()

        logger.info("User %s re-enrolled for TOTP MFA", user.username)

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

        user.mfa_method = "sms"
        if request.phone_number:
            # Parse the new phone number
            if request.phone_number.startswith("+"):
                # Extract country code (assume 1-4 digits after +)
                match = re.match(r"^(\+\d{1,4})(\d+)$", request.phone_number)
                if match:
                    user.phone_country_code = match.group(1)
                    user.phone_number = match.group(2)

        await session.commit()

        logger.info("User %s re-enrolled for SMS MFA", user.username)

        return EnrollResponse(
            success=True,
            message="MFA enrollment updated for SMS.",
            mfa_method=MFAMethod.SMS,
            phone_number=user.masked_phone,
        )


# ============================================================================
# Login
# ============================================================================

@router.post(
    "/auth/login",
    response_model=LoginResponse,
    responses={
        401: {"description": "Invalid credentials"},
        403: {"description": "Profile incomplete or not activated"},
    },
)
async def login(
    request: LoginRequest,
    session: AsyncSession = Depends(get_async_session),
) -> LoginResponse:
    """
    Authenticate user with username, password, and verification code.
    """
    user = await _get_user_by_username(session, request.username)

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

    # Verify MFA code
    if user.mfa_method == "totp":
        if not user.totp_secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="TOTP not configured",
            )

        totp_manager = TOTPManager()
        if not totp_manager.verify_totp(user.totp_secret, request.verification_code):
            logger.warning("Login failed for %s: Invalid TOTP", request.username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )

    elif user.mfa_method == "sms":
        # Verify SMS code (from Redis or in-memory fallback)
        otp_client = get_otp_client()
        sms_code_data = None

        if otp_client.is_enabled and otp_client.is_connected:
            # Use Redis for OTP retrieval
            sms_code_data = otp_client.get_code(request.username)

            if not sms_code_data:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="No verification code sent. Please request a code first.",
                )

            # Redis handles TTL expiration automatically, but we still get None if expired
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

            # Delete code after successful verification
            otp_client.delete_code(request.username)
        else:
            # Fallback to in-memory storage
            sms_code_data = InMemoryOTPStorage.get_code(request.username)

            if not sms_code_data:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="No verification code sent. Please request a code first.",
                )

            if time.time() > sms_code_data["expires_at"]:
                InMemoryOTPStorage.delete_code(request.username)
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Verification code expired. Please request a new one.",
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

            InMemoryOTPStorage.delete_code(request.username)

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
        403: {"description": "User not enrolled for SMS"},
    },
)
async def send_sms_code(
    request: SMSSendCodeRequest,
    session: AsyncSession = Depends(get_async_session),
) -> SMSSendCodeResponse:
    """Send SMS verification code for login."""
    settings = get_settings()

    if not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    user = await _get_user_by_username(session, request.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # For active users, verify against LDAP
    if user.status == ProfileStatus.ACTIVE.value:
        ldap_client = LDAPClient()
        auth_success, _ = ldap_client.authenticate(request.username, request.password)
        if not auth_success:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )
    else:
        # For non-active users, verify against stored password
        if not _verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )

    if user.mfa_method != "sms":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not enrolled for SMS MFA",
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

    # Store code for verification (Redis or in-memory fallback)
    otp_client = get_otp_client()
    if otp_client.is_enabled and otp_client.is_connected:
        # Use Redis for OTP storage
        stored = otp_client.store_code(
            username=request.username,
            code=code,
            phone_number=user.full_phone_number,
            ttl_seconds=settings.sms_code_expiry_seconds,
        )
        if not stored:
            logger.error("Failed to store OTP code in Redis for %s", request.username)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Failed to store verification code. Please try again.",
            )
    else:
        # Fallback to in-memory storage
        InMemoryOTPStorage.store_code(
            username=request.username,
            code=code,
            phone_number=user.full_phone_number,
            expires_at=time.time() + settings.sms_code_expiry_seconds,
        )

    logger.info("SMS code sent to user %s", request.username)

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
    query = select(User)
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
            "mfa_method": u.mfa_method,
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

    # Assign user to groups if provided
    if request.group_ids:
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
                logger.info("User %s assigned to group %s during activation", user.username, group.name)

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

    user = await _get_user_by_username(session, username)
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
        mfa_method=user.mfa_method,
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

    - Users can only update their own profile
    - Email can only be changed if not verified
    - Phone can only be changed if not verified
    """
    current = await _get_current_user(authorization, session)

    # Check authorization - users can only update their own profile
    if current["username"] != username.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only update your own profile",
        )

    user = await _get_user_by_username(session, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Update allowed fields
    if request.first_name is not None:
        user.first_name = request.first_name

    if request.last_name is not None:
        user.last_name = request.last_name

    # Email can only be changed if not verified
    if request.email is not None:
        if user.email_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Email cannot be changed after verification",
            )
        # Check if email is already taken
        existing = await _get_user_by_email(session, request.email)
        if existing and existing.id != user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use",
            )
        user.email = request.email.lower()

    # Phone can only be changed if not verified
    if request.phone_country_code is not None or request.phone_number is not None:
        if user.phone_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Phone cannot be changed after verification",
            )
        if request.phone_country_code is not None:
            user.phone_country_code = request.phone_country_code
        if request.phone_number is not None:
            user.phone_number = request.phone_number

    await session.commit()

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
        mfa_method=user.mfa_method,
        status=user.status,
        created_at=user.created_at.isoformat() if user.created_at else "",
        groups=groups,
    )


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
                ldap_client.remove_user_from_group(user.username, ug.group.ldap_dn)

    # Delete all current assignments
    for ug in current_assignments:
        await session.delete(ug)

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
    if user.status == ProfileStatus.ACTIVE.value and user_group.group:
        ldap_client = LDAPClient()
        ldap_client.remove_user_from_group(user.username, user_group.group.ldap_dn)

    group_name = user_group.group.name if user_group.group else "Unknown"
    await session.delete(user_group)
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
        selectinload(User.user_groups).selectinload(UserGroup.group)
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
            "mfa_method": u.mfa_method,
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
