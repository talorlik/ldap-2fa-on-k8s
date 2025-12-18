"""Email package for sending verification emails via AWS SES."""

from app.email.client import EmailClient

__all__ = ["EmailClient"]
