"""Redis client for SMS OTP operations.

Provides a centralized, TTL-aware storage for SMS verification codes,
replacing the in-memory dictionary approach.
"""

import json
import logging
from functools import lru_cache
from typing import Optional

import redis

from app.config import get_settings

logger = logging.getLogger(__name__)


class RedisOTPClient:
    """Redis client for SMS OTP operations.

    Provides methods for storing, retrieving, and managing SMS OTP codes
    with automatic TTL-based expiration.
    """

    def __init__(self) -> None:
        """Initialize the Redis OTP client."""
        self._settings = get_settings()
        self._client: Optional[redis.Redis] = None
        self._connected = False

        if self._settings.redis_enabled:
            self._initialize_client()

    def _initialize_client(self) -> None:
        """Initialize the Redis client connection."""
        try:
            self._client = redis.Redis(
                host=self._settings.redis_host,
                port=self._settings.redis_port,
                password=self._settings.redis_password or None,
                db=self._settings.redis_db,
                ssl=self._settings.redis_ssl,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
            )
            # Test connection
            self._client.ping()
            self._connected = True
            logger.info(
                "Redis connected successfully to %s:%s",
                self._settings.redis_host,
                self._settings.redis_port,
            )
        except redis.ConnectionError as e:
            logger.error("Failed to connect to Redis: %s", e)
            self._connected = False
            self._client = None
        except redis.AuthenticationError as e:
            logger.error("Redis authentication failed: %s", e)
            self._connected = False
            self._client = None

    @property
    def is_enabled(self) -> bool:
        """Check if Redis is enabled in settings."""
        return self._settings.redis_enabled

    @property
    def is_connected(self) -> bool:
        """Check if Redis client is connected."""
        if not self._connected or not self._client:
            return False
        try:
            self._client.ping()
            return True
        except (redis.ConnectionError, redis.TimeoutError):
            self._connected = False
            return False

    def _get_key(self, username: str) -> str:
        """Generate the Redis key for a username."""
        return f"{self._settings.redis_key_prefix}{username}"

    def store_code(
        self,
        username: str,
        code: str,
        phone_number: str,
        ttl_seconds: Optional[int] = None,
    ) -> bool:
        """Store OTP code with automatic TTL expiration.

        Args:
            username: The username to store the code for
            code: The verification code
            phone_number: The phone number (for reference)
            ttl_seconds: Time-to-live in seconds (defaults to settings value)

        Returns:
            True if successful, False otherwise
        """
        if not self.is_enabled:
            logger.debug("Redis not enabled, skipping store_code")
            return False

        if not self.is_connected:
            logger.error("Redis not connected, cannot store code")
            return False

        try:
            key = self._get_key(username)
            value = json.dumps({
                "code": code,
                "phone_number": phone_number,
            })
            ttl = ttl_seconds or self._settings.sms_code_expiry_seconds

            self._client.setex(key, ttl, value)
            logger.debug("Stored OTP code for %s with TTL %ss", username, ttl)
            return True
        except redis.RedisError as e:
            logger.error("Failed to store OTP code: %s", e)
            return False

    def get_code(self, username: str) -> Optional[dict]:
        """Retrieve OTP code data if not expired.

        Args:
            username: The username to retrieve the code for

        Returns:
            Dictionary with 'code' and 'phone_number' keys, or None if not found
        """
        if not self.is_enabled:
            logger.debug("Redis not enabled, skipping get_code")
            return None

        if not self.is_connected:
            logger.error("Redis not connected, cannot get code")
            return None

        try:
            key = self._get_key(username)
            value = self._client.get(key)

            if value is None:
                logger.debug("No OTP code found for %s", username)
                return None

            data = json.loads(value)
            logger.debug("Retrieved OTP code for %s", username)
            return data
        except redis.RedisError as e:
            logger.error("Failed to retrieve OTP code: %s", e)
            return None
        except json.JSONDecodeError as e:
            logger.error("Failed to decode OTP data: %s", e)
            return None

    def delete_code(self, username: str) -> bool:
        """Delete OTP code after successful verification.

        Args:
            username: The username to delete the code for

        Returns:
            True if successful, False otherwise
        """
        if not self.is_enabled:
            logger.debug("Redis not enabled, skipping delete_code")
            return False

        if not self.is_connected:
            logger.error("Redis not connected, cannot delete code")
            return False

        try:
            key = self._get_key(username)
            deleted = self._client.delete(key)
            logger.debug("Deleted OTP code for %s: %s", username, deleted > 0)
            return deleted > 0
        except redis.RedisError as e:
            logger.error("Failed to delete OTP code: %s", e)
            return False

    def code_exists(self, username: str) -> bool:
        """Check if valid OTP code exists for user.

        Args:
            username: The username to check

        Returns:
            True if code exists, False otherwise
        """
        if not self.is_enabled:
            return False

        if not self.is_connected:
            return False

        try:
            key = self._get_key(username)
            return self._client.exists(key) > 0
        except redis.RedisError as e:
            logger.error("Failed to check OTP code existence: %s", e)
            return False

    def get_ttl(self, username: str) -> int:
        """Get remaining TTL for a user's OTP code.

        Args:
            username: The username to check

        Returns:
            TTL in seconds, -1 if no expiry, -2 if key doesn't exist
        """
        if not self.is_enabled or not self.is_connected:
            return -2

        try:
            key = self._get_key(username)
            return self._client.ttl(key)
        except redis.RedisError as e:
            logger.error("Failed to get TTL: %s", e)
            return -2

    def health_check(self) -> dict:
        """Perform health check on Redis connection.

        Returns:
            Dictionary with health status information
        """
        if not self.is_enabled:
            return {
                "enabled": False,
                "connected": False,
                "status": "disabled",
            }

        try:
            if self._client and self._client.ping():
                info = self._client.info("server")
                return {
                    "enabled": True,
                    "connected": True,
                    "status": "healthy",
                    "redis_version": info.get("redis_version", "unknown"),
                }
        except redis.RedisError as e:
            return {
                "enabled": True,
                "connected": False,
                "status": "unhealthy",
                "error": str(e),
            }

        return {
            "enabled": True,
            "connected": False,
            "status": "disconnected",
        }


# In-memory fallback storage when Redis is disabled
_inmemory_sms_codes: dict[str, dict] = {}


class InMemoryOTPStorage:
    """In-memory fallback storage for SMS OTP codes.

    Used when Redis is disabled, maintaining backward compatibility.
    """

    @staticmethod
    def store_code(
        username: str,
        code: str,
        phone_number: str,
        expires_at: float,
    ) -> bool:
        """Store code in memory with expiration timestamp."""
        _inmemory_sms_codes[username] = {
            "code": code,
            "phone_number": phone_number,
            "expires_at": expires_at,
        }
        return True

    @staticmethod
    def get_code(username: str) -> Optional[dict]:
        """Get code from memory."""
        return _inmemory_sms_codes.get(username)

    @staticmethod
    def delete_code(username: str) -> bool:
        """Delete code from memory."""
        if username in _inmemory_sms_codes:
            del _inmemory_sms_codes[username]
            return True
        return False

    @staticmethod
    def code_exists(username: str) -> bool:
        """Check if code exists in memory."""
        return username in _inmemory_sms_codes


@lru_cache
def get_otp_client() -> RedisOTPClient:
    """Get cached Redis OTP client instance."""
    return RedisOTPClient()
