"""SMS module for 2FA verification via AWS SNS."""

from app.sms.client import SMSClient

__all__ = ["SMSClient"]
