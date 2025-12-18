"""Configuration module for the 2FA Backend API."""

import os
from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # LDAP Configuration
    ldap_host: str = os.getenv("LDAP_HOST", "openldap-stack-ha.ldap.svc.cluster.local")
    ldap_port: int = int(os.getenv("LDAP_PORT", "389"))
    ldap_use_ssl: bool = os.getenv("LDAP_USE_SSL", "false").lower() == "true"
    ldap_base_dn: str = os.getenv("LDAP_BASE_DN", "dc=ldap,dc=talorlik,dc=internal")
    ldap_admin_dn: str = os.getenv(
        "LDAP_ADMIN_DN", "cn=admin,dc=ldap,dc=talorlik,dc=internal"
    )
    ldap_admin_password: str = os.getenv("LDAP_ADMIN_PASSWORD", "")
    ldap_user_search_base: str = os.getenv("LDAP_USER_SEARCH_BASE", "ou=users")
    ldap_user_search_filter: str = os.getenv("LDAP_USER_SEARCH_FILTER", "(uid={0})")
    ldap_admin_group_dn: str = os.getenv(
        "LDAP_ADMIN_GROUP_DN", "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal"
    )
    ldap_group_search_base: str = os.getenv("LDAP_GROUP_SEARCH_BASE", "ou=groups")
    ldap_users_gid: int = int(os.getenv("LDAP_USERS_GID", "500"))
    ldap_uid_start: int = int(os.getenv("LDAP_UID_START", "10000"))

    # MFA/TOTP Configuration
    totp_issuer: str = os.getenv("TOTP_ISSUER", "LDAP-2FA-App")
    totp_digits: int = int(os.getenv("TOTP_DIGITS", "6"))
    totp_interval: int = int(os.getenv("TOTP_INTERVAL", "30"))
    totp_algorithm: str = os.getenv("TOTP_ALGORITHM", "SHA1")

    # SMS/SNS Configuration
    enable_sms_2fa: bool = os.getenv("ENABLE_SMS_2FA", "false").lower() == "true"
    aws_region: str = os.getenv("AWS_REGION", "us-east-1")
    sns_topic_arn: str = os.getenv("SNS_TOPIC_ARN", "")
    sms_sender_id: str = os.getenv("SMS_SENDER_ID", "2FA")
    sms_type: str = os.getenv("SMS_TYPE", "Transactional")
    sms_code_length: int = int(os.getenv("SMS_CODE_LENGTH", "6"))
    sms_code_expiry_seconds: int = int(os.getenv("SMS_CODE_EXPIRY_SECONDS", "300"))
    sms_message_template: str = os.getenv(
        "SMS_MESSAGE_TEMPLATE",
        "Your verification code is: {code}. It expires in 5 minutes."
    )

    # Redis Configuration (for SMS OTP storage)
    redis_enabled: bool = os.getenv("REDIS_ENABLED", "false").lower() == "true"
    redis_host: str = os.getenv("REDIS_HOST", "redis-master.redis.svc.cluster.local")
    redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
    redis_password: str = os.getenv("REDIS_PASSWORD", "")
    redis_db: int = int(os.getenv("REDIS_DB", "0"))
    redis_ssl: bool = os.getenv("REDIS_SSL", "false").lower() == "true"
    redis_key_prefix: str = os.getenv("REDIS_KEY_PREFIX", "sms_otp:")

    # Database Configuration (PostgreSQL)
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://ldap2fa:ldap2fa@localhost:5432/ldap2fa"
    )

    # Email/SES Configuration
    enable_email_verification: bool = os.getenv(
        "ENABLE_EMAIL_VERIFICATION", "true"
    ).lower() == "true"
    ses_sender_email: str = os.getenv("SES_SENDER_EMAIL", "noreply@example.com")
    email_verification_expiry_hours: int = int(
        os.getenv("EMAIL_VERIFICATION_EXPIRY_HOURS", "24")
    )
    app_url: str = os.getenv("APP_URL", "http://localhost:8080")

    # Application Configuration
    app_name: str = os.getenv("APP_NAME", "LDAP 2FA Backend API")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    # JWT Configuration
    jwt_secret_key: str = os.getenv("JWT_SECRET_KEY", "change-me-in-production-use-secure-random-key")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    jwt_expiry_minutes: int = int(os.getenv("JWT_EXPIRY_MINUTES", "60"))
    jwt_refresh_expiry_days: int = int(os.getenv("JWT_REFRESH_EXPIRY_DAYS", "7"))

    # CORS Configuration (for local development)
    cors_origins: list[str] = os.getenv("CORS_ORIGINS", "").split(",") if os.getenv(
        "CORS_ORIGINS"
    ) else []

    class Config:
        """Pydantic settings configuration."""

        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
