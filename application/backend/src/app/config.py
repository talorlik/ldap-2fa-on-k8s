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

    # Application Configuration
    app_name: str = os.getenv("APP_NAME", "LDAP 2FA Backend API")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

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
