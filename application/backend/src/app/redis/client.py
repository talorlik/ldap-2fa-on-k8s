"""Redis client for shared storage (SMS OTP and login challenges).

All backend storage is in Redis so that single- and multi-replica deployments
behave the same. In-memory storage is not used.
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
        """Initialize the Redis client (always attempt connection; Redis is required)."""
        self._settings = get_settings()
        self._client: Optional[redis.Redis] = None
        self._connected = False
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

    def _get_login_challenge_key(self, challenge_token: str) -> str:
        """Redis key for a login challenge (shared across replicas)."""
        return f"{self._settings.redis_key_prefix}login_challenge:{challenge_token}"

    _LOGIN_CHALLENGE_TTL_SECONDS = 300  # 5 minutes

    def store_login_challenge(
        self,
        challenge_token: str,
        user_id: str,
        username: str,
        remember_me: bool = False,
    ) -> bool:
        """Store login challenge for two-step auth (shared across backend replicas)."""
        if not self.is_connected:
            return False
        try:
            key = self._get_login_challenge_key(challenge_token)
            value = json.dumps({
                "user_id": user_id,
                "username": username,
                "remember_me": remember_me,
            })
            self._client.setex(key, self._LOGIN_CHALLENGE_TTL_SECONDS, value)
            logger.debug("Stored login challenge for %s", username)
            return True
        except redis.RedisError as e:
            logger.error("Failed to store login challenge: %s", e)
            return False

    def get_login_challenge(self, challenge_token: str) -> Optional[dict]:
        """Get login challenge data if not expired."""
        if not self.is_connected:
            return None
        try:
            key = self._get_login_challenge_key(challenge_token)
            value = self._client.get(key)
            if value is None:
                return None
            data = json.loads(value)
            return data
        except redis.RedisError as e:
            logger.error("Failed to get login challenge: %s", e)
            return None
        except json.JSONDecodeError as e:
            logger.error("Failed to decode login challenge: %s", e)
            return None

    def delete_login_challenge(self, challenge_token: str) -> bool:
        """Remove login challenge after successful verify."""
        if not self.is_connected:
            return False
        try:
            key = self._get_login_challenge_key(challenge_token)
            deleted = self._client.delete(key)
            return deleted > 0
        except redis.RedisError as e:
            logger.error("Failed to delete login challenge: %s", e)
            return False

    def code_exists(self, username: str) -> bool:
        """Check if valid OTP code exists for user.

        Args:
            username: The username to check

        Returns:
            True if code exists, False otherwise
        """
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
        if not self.is_connected:
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
                "connected": False,
                "status": "unhealthy",
                "error": str(e),
            }

        return {
            "connected": False,
            "status": "disconnected",
        }


def store_login_challenge(
    challenge_token: str,
    user_id: str,
    username: str,
    remember_me: bool = False,
) -> bool:
    """Store login challenge in Redis. Returns True if stored, False if Redis unavailable."""
    client = get_otp_client()
    return client.store_login_challenge(
        challenge_token, user_id, username, remember_me
    )


def get_login_challenge(challenge_token: str) -> Optional[dict]:
    """Get login challenge from Redis. Returns None if not found or Redis unavailable."""
    client = get_otp_client()
    return client.get_login_challenge(challenge_token)


def delete_login_challenge(challenge_token: str) -> bool:
    """Delete login challenge from Redis. Returns True if deleted or key absent."""
    client = get_otp_client()
    return client.delete_login_challenge(challenge_token)


@lru_cache
def get_otp_client() -> RedisOTPClient:
    """Get cached Redis OTP client instance."""
    return RedisOTPClient()
