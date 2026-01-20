"""TOTP (Time-based One-Time Password) manager for MFA."""

import base64
import hashlib
import hmac
import logging
import secrets
import struct
import time
from typing import Optional
from urllib.parse import quote

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class TOTPManager:
    """Manager for TOTP operations."""

    def __init__(self, settings: Optional[Settings] = None):
        """Initialize TOTP manager with settings."""
        self.settings = settings or get_settings()

    def generate_secret(self) -> str:
        """
        Generate a new TOTP secret.

        Returns:
            Base32 encoded secret string
        """
        # Generate 20 bytes (160 bits) of random data
        secret_bytes = secrets.token_bytes(20)
        # Encode as base32 (standard for TOTP)
        secret = base64.b32encode(secret_bytes).decode("utf-8")
        logger.debug("Generated new TOTP secret")
        return secret

    def generate_otpauth_uri(
        self,
        secret: str,
        username: str,
        issuer: Optional[str] = None,
    ) -> str:
        """
        Generate an otpauth:// URI for QR code generation.

        Args:
            secret: The TOTP secret (base32 encoded)
            username: The username/account name
            issuer: Optional issuer name (defaults to settings)

        Returns:
            otpauth:// URI string
        """
        issuer = issuer or self.settings.totp_issuer
        # URL-encode the issuer and username
        encoded_issuer = quote(issuer, safe="")
        encoded_username = quote(username, safe="")

        # Build the otpauth URI
        uri = (
            f"otpauth://totp/{encoded_issuer}:{encoded_username}"
            f"?secret={secret}"
            f"&issuer={encoded_issuer}"
            f"&algorithm={self.settings.totp_algorithm}"
            f"&digits={self.settings.totp_digits}"
            f"&period={self.settings.totp_interval}"
        )

        logger.debug("Generated otpauth URI for user: %s", username)
        return uri

    def _get_algorithm(self) -> str:
        """Get the hash algorithm name for hashlib."""
        algorithm_map = {
            "SHA1": "sha1",
            "SHA256": "sha256",
            "SHA512": "sha512",
        }
        return algorithm_map.get(self.settings.totp_algorithm, "sha1")

    def _generate_hotp(self, secret: str, counter: int) -> str:
        """
        Generate HOTP value.

        Args:
            secret: Base32 encoded secret
            counter: Counter value

        Returns:
            HOTP code as string
        """
        # Decode the base32 secret
        key = base64.b32decode(secret.upper())

        # Pack the counter as big-endian 64-bit integer
        counter_bytes = struct.pack(">Q", counter)

        # Compute HMAC
        algorithm = self._get_algorithm()
        hmac_result = hmac.new(key, counter_bytes, algorithm).digest()

        # Dynamic truncation
        offset = hmac_result[-1] & 0x0F
        truncated = struct.unpack(">I", hmac_result[offset : offset + 4])[0]
        truncated &= 0x7FFFFFFF

        # Generate OTP
        otp = truncated % (10 ** self.settings.totp_digits)
        return str(otp).zfill(self.settings.totp_digits)

    def generate_totp(self, secret: str, timestamp: Optional[int] = None) -> str:
        """
        Generate current TOTP code.

        Args:
            secret: Base32 encoded secret
            timestamp: Optional Unix timestamp (defaults to current time)

        Returns:
            TOTP code as string
        """
        if timestamp is None:
            timestamp = int(time.time())

        counter = timestamp // self.settings.totp_interval
        return self._generate_hotp(secret, counter)

    def verify_totp(
        self,
        secret: str,
        code: str,
        window: int = 1,
    ) -> bool:
        """
        Verify a TOTP code.

        Args:
            secret: Base32 encoded secret
            code: The TOTP code to verify
            window: Number of intervals to check before and after current time

        Returns:
            True if code is valid, False otherwise
        """
        if not code or not code.isdigit():
            logger.warning("Invalid TOTP code format")
            return False

        # Normalize code length
        code = code.zfill(self.settings.totp_digits)

        current_time = int(time.time())
        current_counter = current_time // self.settings.totp_interval

        # Check codes within the window
        for offset in range(-window, window + 1):
            counter = current_counter + offset
            expected_code = self._generate_hotp(secret, counter)
            if hmac.compare_digest(code, expected_code):
                logger.debug("TOTP verification successful (offset: %s)", offset)
                return True

        logger.debug("TOTP verification failed")
        return False
