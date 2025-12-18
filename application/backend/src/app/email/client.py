"""AWS SES email client for sending verification emails."""

import logging
from typing import Optional

import boto3
from botocore.exceptions import ClientError

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class EmailClient:
    """Client for sending emails via AWS SES."""

    def __init__(self, settings: Optional[Settings] = None):
        """Initialize email client with settings."""
        self.settings = settings or get_settings()
        self._client = None

    @property
    def client(self):
        """Get or create SES client."""
        if self._client is None:
            self._client = boto3.client(
                "ses",
                region_name=self.settings.aws_region,
            )
        return self._client

    def send_verification_email(
        self,
        to_email: str,
        token: str,
        username: str,
        first_name: str,
    ) -> tuple[bool, str]:
        """
        Send email verification link.

        Args:
            to_email: Recipient email address
            token: Verification token (UUID)
            username: User's username
            first_name: User's first name for personalization

        Returns:
            Tuple of (success: bool, message: str)
        """
        verification_link = (
            f"{self.settings.app_url}/verify-email?token={token}&username={username}"
        )

        subject = f"Verify your email - {self.settings.totp_issuer}"

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
        <h1 style="color: white; margin: 0; font-size: 28px;">Email Verification</h1>
    </div>
    <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
        <p style="font-size: 16px;">Hello <strong>{first_name}</strong>,</p>
        <p style="font-size: 16px;">Thank you for signing up! Please verify your email address by clicking the button below:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{verification_link}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
                Verify Email Address
            </a>
        </div>
        <p style="font-size: 14px; color: #666;">Or copy and paste this link into your browser:</p>
        <p style="font-size: 12px; color: #888; word-break: break-all; background: #fff; padding: 10px; border-radius: 5px; border: 1px solid #e0e0e0;">
            {verification_link}
        </p>
        <p style="font-size: 14px; color: #666; margin-top: 30px;">
            This link will expire in <strong>{self.settings.email_verification_expiry_hours} hours</strong>.
        </p>
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
        <p style="font-size: 12px; color: #999; text-align: center;">
            If you didn't create an account, you can safely ignore this email.
        </p>
    </div>
</body>
</html>
"""

        text_body = f"""
Hello {first_name},

Thank you for signing up! Please verify your email address by visiting the link below:

{verification_link}

This link will expire in {self.settings.email_verification_expiry_hours} hours.

If you didn't create an account, you can safely ignore this email.
"""

        try:
            response = self.client.send_email(
                Source=self.settings.ses_sender_email,
                Destination={"ToAddresses": [to_email]},
                Message={
                    "Subject": {"Data": subject, "Charset": "UTF-8"},
                    "Body": {
                        "Text": {"Data": text_body, "Charset": "UTF-8"},
                        "Html": {"Data": html_body, "Charset": "UTF-8"},
                    },
                },
            )
            message_id = response.get("MessageId", "unknown")
            logger.info(f"Verification email sent to {to_email}, MessageId: {message_id}")
            return True, f"Verification email sent successfully"

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(f"Failed to send email to {to_email}: {error_code} - {error_message}")
            return False, f"Failed to send email: {error_message}"

        except Exception as e:
            logger.error(f"Unexpected error sending email to {to_email}: {e}")
            return False, f"Failed to send email: {str(e)}"

    def send_welcome_email(
        self,
        to_email: str,
        username: str,
        first_name: str,
    ) -> tuple[bool, str]:
        """
        Send welcome email after admin activation.

        Args:
            to_email: Recipient email address
            username: User's username
            first_name: User's first name

        Returns:
            Tuple of (success: bool, message: str)
        """
        login_link = f"{self.settings.app_url}"

        subject = f"Your account has been activated - {self.settings.totp_issuer}"

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
        <h1 style="color: white; margin: 0; font-size: 28px;">Account Activated!</h1>
    </div>
    <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
        <p style="font-size: 16px;">Hello <strong>{first_name}</strong>,</p>
        <p style="font-size: 16px;">Great news! Your account has been approved and activated by an administrator.</p>
        <p style="font-size: 16px;">You can now log in using your username <strong>{username}</strong> and the password you created during signup.</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{login_link}" style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
                Login Now
            </a>
        </div>
        <p style="font-size: 14px; color: #666;">
            Remember to have your authenticator app ready for two-factor authentication.
        </p>
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
        <p style="font-size: 12px; color: #999; text-align: center;">
            If you have any questions, please contact your system administrator.
        </p>
    </div>
</body>
</html>
"""

        text_body = f"""
Hello {first_name},

Great news! Your account has been approved and activated by an administrator.

You can now log in using your username ({username}) and the password you created during signup.

Login here: {login_link}

Remember to have your authenticator app ready for two-factor authentication.

If you have any questions, please contact your system administrator.
"""

        try:
            response = self.client.send_email(
                Source=self.settings.ses_sender_email,
                Destination={"ToAddresses": [to_email]},
                Message={
                    "Subject": {"Data": subject, "Charset": "UTF-8"},
                    "Body": {
                        "Text": {"Data": text_body, "Charset": "UTF-8"},
                        "Html": {"Data": html_body, "Charset": "UTF-8"},
                    },
                },
            )
            message_id = response.get("MessageId", "unknown")
            logger.info(f"Welcome email sent to {to_email}, MessageId: {message_id}")
            return True, "Welcome email sent successfully"

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(f"Failed to send welcome email to {to_email}: {error_code} - {error_message}")
            return False, f"Failed to send email: {error_message}"

        except Exception as e:
            logger.error(f"Unexpected error sending welcome email to {to_email}: {e}")
            return False, f"Failed to send email: {str(e)}"
