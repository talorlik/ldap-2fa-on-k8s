"""API routes for 2FA authentication."""

import logging
import time
from enum import Enum
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field, field_validator

from app.config import get_settings
from app.ldap import LDAPClient
from app.mfa import TOTPManager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["authentication"])


class MFAMethod(str, Enum):
    """Supported MFA methods."""

    TOTP = "totp"
    SMS = "sms"


# In-memory storage for user data (in production, use a proper database)
# Structure: {username: {"mfa_method": "totp|sms", "totp_secret": "...", "phone_number": "...", "subscription_arn": "..."}}
_user_mfa_data: dict[str, dict] = {}

# In-memory storage for SMS verification codes
# Structure: {username: {"code": "...", "expires_at": timestamp, "phone_number": "..."}}
_sms_codes: dict[str, dict] = {}


class HealthResponse(BaseModel):
    """Health check response model."""

    status: str = Field(..., description="Health status")
    service: str = Field(..., description="Service name")
    sms_enabled: bool = Field(..., description="Whether SMS 2FA is enabled")


class EnrollRequest(BaseModel):
    """Enrollment request model."""

    username: str = Field(..., min_length=1, description="LDAP username")
    password: str = Field(..., min_length=1, description="LDAP password")
    mfa_method: MFAMethod = Field(
        default=MFAMethod.TOTP, description="MFA method: totp or sms"
    )
    phone_number: Optional[str] = Field(
        None, description="Phone number for SMS (E.164 format, required if mfa_method is sms)"
    )

    @field_validator("phone_number")
    @classmethod
    def validate_phone_for_sms(cls, v, info):
        """Validate phone number is provided for SMS method."""
        # Note: Full validation happens in the endpoint
        return v


class EnrollResponse(BaseModel):
    """Enrollment response model."""

    success: bool = Field(..., description="Whether enrollment was successful")
    message: str = Field(..., description="Response message")
    mfa_method: MFAMethod = Field(..., description="Enrolled MFA method")
    otpauth_uri: Optional[str] = Field(
        None, description="otpauth:// URI for QR code generation (TOTP only)"
    )
    secret: Optional[str] = Field(
        None, description="TOTP secret (base32 encoded) for manual entry (TOTP only)"
    )
    phone_number: Optional[str] = Field(
        None, description="Masked phone number (SMS only)"
    )


class LoginRequest(BaseModel):
    """Login request model."""

    username: str = Field(..., min_length=1, description="LDAP username")
    password: str = Field(..., min_length=1, description="LDAP password")
    verification_code: str = Field(
        ..., min_length=6, max_length=6, description="6-digit verification code"
    )


class LoginResponse(BaseModel):
    """Login response model."""

    success: bool = Field(..., description="Whether login was successful")
    message: str = Field(..., description="Response message")


class SMSSendCodeRequest(BaseModel):
    """Request to send SMS verification code."""

    username: str = Field(..., min_length=1, description="LDAP username")
    password: str = Field(..., min_length=1, description="LDAP password")


class SMSSendCodeResponse(BaseModel):
    """Response after sending SMS code."""

    success: bool = Field(..., description="Whether code was sent")
    message: str = Field(..., description="Response message")
    phone_number: Optional[str] = Field(None, description="Masked phone number")
    expires_in_seconds: Optional[int] = Field(
        None, description="Seconds until code expires"
    )


class MFAMethodsResponse(BaseModel):
    """Response with available MFA methods."""

    methods: list[str] = Field(..., description="List of available MFA methods")
    sms_enabled: bool = Field(..., description="Whether SMS is enabled")


class UserMFAStatusResponse(BaseModel):
    """Response with user's MFA enrollment status."""

    enrolled: bool = Field(..., description="Whether user is enrolled for MFA")
    mfa_method: Optional[str] = Field(None, description="Enrolled MFA method")
    phone_number: Optional[str] = Field(None, description="Masked phone number (SMS only)")


def _mask_phone_number(phone: str) -> str:
    """Mask phone number for display, showing only last 4 digits."""
    if len(phone) > 4:
        return "*" * (len(phone) - 4) + phone[-4:]
    return phone


def _get_sms_client():
    """Get SMS client (lazy import to avoid issues when SMS is disabled)."""
    from app.sms import SMSClient

    return SMSClient()


@router.get("/healthz", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Liveness/readiness probe endpoint.

    Returns health status of the service.
    """
    settings = get_settings()
    return HealthResponse(
        status="healthy",
        service=settings.app_name,
        sms_enabled=settings.enable_sms_2fa,
    )


@router.get("/mfa/methods", response_model=MFAMethodsResponse)
async def get_mfa_methods() -> MFAMethodsResponse:
    """
    Get available MFA methods.

    Returns list of MFA methods that can be used for enrollment.
    """
    settings = get_settings()
    methods = ["totp"]
    if settings.enable_sms_2fa:
        methods.append("sms")

    return MFAMethodsResponse(
        methods=methods,
        sms_enabled=settings.enable_sms_2fa,
    )


@router.get("/mfa/status/{username}", response_model=UserMFAStatusResponse)
async def get_mfa_status(username: str) -> UserMFAStatusResponse:
    """
    Get user's MFA enrollment status.

    Args:
        username: LDAP username

    Returns:
        User's MFA enrollment status
    """
    user_data = _user_mfa_data.get(username)

    if not user_data:
        return UserMFAStatusResponse(enrolled=False)

    mfa_method = user_data.get("mfa_method")
    phone_number = None

    if mfa_method == "sms" and user_data.get("phone_number"):
        phone_number = _mask_phone_number(user_data["phone_number"])

    return UserMFAStatusResponse(
        enrolled=True,
        mfa_method=mfa_method,
        phone_number=phone_number,
    )


@router.post(
    "/auth/enroll",
    response_model=EnrollResponse,
    responses={
        400: {"description": "Bad request (e.g., missing phone for SMS)"},
        401: {"description": "Invalid LDAP credentials"},
        500: {"description": "Internal server error"},
    },
)
async def enroll(request: EnrollRequest) -> EnrollResponse:
    """
    Enroll a user for MFA.

    Validates LDAP credentials and enrolls for the selected MFA method:
    - TOTP: Generates secret and returns otpauth:// URI for QR code
    - SMS: Validates phone number and sends test verification code

    Args:
        request: Enrollment request with username, password, and MFA method

    Returns:
        Enrollment response with method-specific data
    """
    settings = get_settings()
    ldap_client = LDAPClient()

    # Validate SMS is enabled if requested
    if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    # Validate phone number for SMS
    if request.mfa_method == MFAMethod.SMS:
        if not request.phone_number:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number is required for SMS enrollment",
            )

        sms_client = _get_sms_client()
        is_valid, error = sms_client.validate_phone_number(request.phone_number)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error,
            )

    # Authenticate against LDAP
    auth_success, auth_message = ldap_client.authenticate(
        request.username, request.password
    )

    if not auth_success:
        logger.warning(f"Enrollment failed for user {request.username}: {auth_message}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=auth_message,
        )

    # Handle TOTP enrollment
    if request.mfa_method == MFAMethod.TOTP:
        totp_manager = TOTPManager()
        secret = totp_manager.generate_secret()
        otpauth_uri = totp_manager.generate_otpauth_uri(
            secret=secret,
            username=request.username,
        )

        # Store user MFA data
        _user_mfa_data[request.username] = {
            "mfa_method": "totp",
            "totp_secret": secret,
        }

        logger.info(f"User {request.username} enrolled for TOTP MFA")

        return EnrollResponse(
            success=True,
            message="MFA enrollment successful. Scan the QR code with your authenticator app.",
            mfa_method=MFAMethod.TOTP,
            otpauth_uri=otpauth_uri,
            secret=secret,
        )

    # Handle SMS enrollment
    else:
        sms_client = _get_sms_client()

        # Subscribe phone number to SNS topic (optional, for future notifications)
        subscription_arn = None
        if settings.sns_topic_arn:
            success, message, subscription_arn = sms_client.subscribe_phone_number(
                request.phone_number
            )
            if not success:
                logger.warning(f"Failed to subscribe phone number: {message}")
                # Continue anyway - direct SMS will still work

        # Store user MFA data
        _user_mfa_data[request.username] = {
            "mfa_method": "sms",
            "phone_number": request.phone_number,
            "subscription_arn": subscription_arn,
        }

        # Send a test verification code
        code = sms_client.generate_verification_code(settings.sms_code_length)
        success, message, _ = sms_client.send_verification_code(
            request.phone_number, code
        )

        if not success:
            # Rollback enrollment
            del _user_mfa_data[request.username]
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to send verification SMS: {message}",
            )

        # Store the code for verification
        _sms_codes[request.username] = {
            "code": code,
            "expires_at": time.time() + settings.sms_code_expiry_seconds,
            "phone_number": request.phone_number,
        }

        logger.info(f"User {request.username} enrolled for SMS MFA")

        return EnrollResponse(
            success=True,
            message="MFA enrollment successful. A verification code has been sent to your phone.",
            mfa_method=MFAMethod.SMS,
            phone_number=_mask_phone_number(request.phone_number),
        )


@router.post(
    "/auth/sms/send-code",
    response_model=SMSSendCodeResponse,
    responses={
        401: {"description": "Invalid LDAP credentials"},
        403: {"description": "User not enrolled for SMS MFA"},
        500: {"description": "Failed to send SMS"},
    },
)
async def send_sms_code(request: SMSSendCodeRequest) -> SMSSendCodeResponse:
    """
    Send SMS verification code to enrolled user.

    Validates LDAP credentials and sends a new verification code.

    Args:
        request: Request with username and password

    Returns:
        Response indicating success and expiry time
    """
    settings = get_settings()
    ldap_client = LDAPClient()

    if not settings.enable_sms_2fa:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SMS 2FA is not enabled",
        )

    # Authenticate against LDAP
    auth_success, auth_message = ldap_client.authenticate(
        request.username, request.password
    )

    if not auth_success:
        logger.warning(f"SMS send failed for user {request.username}: {auth_message}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    # Check if user is enrolled for SMS
    user_data = _user_mfa_data.get(request.username)
    if not user_data or user_data.get("mfa_method") != "sms":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not enrolled for SMS MFA. Please enroll first.",
        )

    phone_number = user_data.get("phone_number")
    if not phone_number:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Phone number not found",
        )

    # Generate and send code
    sms_client = _get_sms_client()
    code = sms_client.generate_verification_code(settings.sms_code_length)

    success, message, _ = sms_client.send_verification_code(phone_number, code)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send verification SMS: {message}",
        )

    # Store the code
    _sms_codes[request.username] = {
        "code": code,
        "expires_at": time.time() + settings.sms_code_expiry_seconds,
        "phone_number": phone_number,
    }

    logger.info(f"SMS code sent to user {request.username}")

    return SMSSendCodeResponse(
        success=True,
        message="Verification code sent",
        phone_number=_mask_phone_number(phone_number),
        expires_in_seconds=settings.sms_code_expiry_seconds,
    )


@router.post(
    "/auth/login",
    response_model=LoginResponse,
    responses={
        401: {"description": "Invalid credentials or verification code"},
        403: {"description": "User not enrolled for MFA"},
        500: {"description": "Internal server error"},
    },
)
async def login(request: LoginRequest) -> LoginResponse:
    """
    Authenticate a user with LDAP credentials and verification code.

    Supports both TOTP and SMS verification codes based on user's enrollment.

    Args:
        request: Login request with username, password, and verification code

    Returns:
        Login response indicating success or failure
    """
    ldap_client = LDAPClient()

    # Authenticate against LDAP
    auth_success, auth_message = ldap_client.authenticate(
        request.username, request.password
    )

    if not auth_success:
        logger.warning(
            f"Login failed for user {request.username} (LDAP): {auth_message}"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    # Check if user is enrolled for MFA
    user_data = _user_mfa_data.get(request.username)
    if not user_data:
        logger.warning(f"User {request.username} not enrolled for MFA")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not enrolled for MFA. Please enroll first.",
        )

    mfa_method = user_data.get("mfa_method")

    # Verify TOTP code
    if mfa_method == "totp":
        secret = user_data.get("totp_secret")
        if not secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="TOTP secret not found",
            )

        totp_manager = TOTPManager()
        if not totp_manager.verify_totp(secret, request.verification_code):
            logger.warning(
                f"Login failed for user {request.username} (TOTP): Invalid code"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )

    # Verify SMS code
    elif mfa_method == "sms":
        sms_code_data = _sms_codes.get(request.username)

        if not sms_code_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No verification code sent. Please request a new code.",
            )

        # Check expiry
        if time.time() > sms_code_data["expires_at"]:
            del _sms_codes[request.username]
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Verification code expired. Please request a new code.",
            )

        # Verify code (constant-time comparison)
        import hmac

        if not hmac.compare_digest(
            request.verification_code, sms_code_data["code"]
        ):
            logger.warning(
                f"Login failed for user {request.username} (SMS): Invalid code"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid verification code",
            )

        # Clear used code
        del _sms_codes[request.username]

    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unknown MFA method",
        )

    logger.info(f"User {request.username} logged in successfully via {mfa_method}")

    return LoginResponse(
        success=True,
        message="Login successful",
    )
