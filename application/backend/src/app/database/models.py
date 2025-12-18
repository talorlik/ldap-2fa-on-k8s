"""Database models for user management."""

import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    String,
    Text,
    ForeignKey,
    Index,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    """Base class for all database models."""

    pass


class ProfileStatus(str, Enum):
    """User profile status states."""

    PENDING = "pending"  # Signup complete, verification incomplete
    COMPLETE = "complete"  # Email + Phone verified, awaiting admin approval
    ACTIVE = "active"  # Admin activated, user exists in LDAP


class MFAMethodType(str, Enum):
    """Supported MFA methods."""

    TOTP = "totp"
    SMS = "sms"


class User(Base):
    """User model for storing signup and profile information."""

    __tablename__ = "users"

    # Primary key
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # Basic profile information
    username: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False,
        index=True,
    )
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
    )
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)

    # Phone number (split into country code and number)
    phone_country_code: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
    )  # e.g., "+1", "+44"
    phone_number: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )  # e.g., "5551234567"

    # Password (bcrypt hash, used when creating LDAP user)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)

    # Verification status
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # Profile status
    status: Mapped[str] = mapped_column(
        String(20),
        default=ProfileStatus.PENDING.value,
        index=True,
    )

    # MFA settings
    mfa_method: Mapped[str] = mapped_column(
        String(10),
        default=MFAMethodType.TOTP.value,
    )
    totp_secret: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Admin activation
    activated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    activated_by: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
    )  # Admin username who activated

    # Relationships
    verification_tokens: Mapped[list["VerificationToken"]] = relationship(
        "VerificationToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    # Indexes
    __table_args__ = (
        Index("ix_users_status_created", "status", "created_at"),
        Index("ix_users_phone", "phone_country_code", "phone_number"),
    )

    @property
    def full_name(self) -> str:
        """Get user's full name."""
        return f"{self.first_name} {self.last_name}"

    @property
    def full_phone_number(self) -> str:
        """Get full phone number with country code."""
        return f"{self.phone_country_code}{self.phone_number}"

    @property
    def masked_phone(self) -> str:
        """Get masked phone number for display."""
        full = self.full_phone_number
        if len(full) > 4:
            return "*" * (len(full) - 4) + full[-4:]
        return full

    @property
    def masked_email(self) -> str:
        """Get masked email for display."""
        if "@" not in self.email:
            return self.email
        local, domain = self.email.split("@", 1)
        if len(local) > 2:
            masked_local = local[0] + "*" * (len(local) - 2) + local[-1]
        else:
            masked_local = "*" * len(local)
        return f"{masked_local}@{domain}"

    def is_verification_complete(self) -> bool:
        """Check if all verifications are complete."""
        return self.email_verified and self.phone_verified

    def update_status_if_complete(self) -> bool:
        """Update status to COMPLETE if all verifications done."""
        if self.is_verification_complete() and self.status == ProfileStatus.PENDING.value:
            self.status = ProfileStatus.COMPLETE.value
            return True
        return False


class VerificationTokenType(str, Enum):
    """Types of verification tokens."""

    EMAIL = "email"
    PHONE = "phone"


class VerificationToken(Base):
    """Verification token model for email and phone verification."""

    __tablename__ = "verification_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    token_type: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )  # "email" or "phone"

    token: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )  # UUID for email, 6-digit code for phone

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    used: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="verification_tokens")

    def is_expired(self) -> bool:
        """Check if token is expired."""
        return datetime.now(self.expires_at.tzinfo) > self.expires_at

    def is_valid(self) -> bool:
        """Check if token is valid (not used and not expired)."""
        return not self.used and not self.is_expired()
