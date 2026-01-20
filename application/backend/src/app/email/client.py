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
            logger.info("Verification email sent to %s, MessageId: %s", to_email, message_id)
            return True, f"Verification email sent successfully"

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("Failed to send email to %s: %s - %s", to_email, error_code, error_message)
            return False, f"Failed to send email: {error_message}"

        except Exception as e:
            logger.error("Unexpected error sending email to %s: %s", to_email, e)
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
            logger.info("Welcome email sent to %s, MessageId: %s", to_email, message_id)
            return True, "Welcome email sent successfully"

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("Failed to send welcome email to %s: %s - %s", to_email, error_code, error_message)
            return False, f"Failed to send email: {error_message}"

        except Exception as e:
            logger.error("Unexpected error sending welcome email to %s: %s", to_email, e)
            return False, f"Failed to send email: {str(e)}"

    def send_admin_notification_email(
        self,
        admin_emails: list[str],
        new_user: dict,
    ) -> tuple[bool, str]:
        """
        Send notification email to admins when a new user signs up.

        Args:
            admin_emails: List of admin email addresses
            new_user: Dictionary with new user details:
                - username: str
                - full_name: str
                - email: str
                - phone: str
                - signup_time: str (ISO format)

        Returns:
            Tuple of (success: bool, message: str)
        """
        if not admin_emails:
            logger.warning("No admin emails to send notification to")
            return True, "No admin emails configured"

        admin_dashboard_link = f"{self.settings.app_url}/#admin"

        subject = f"New User Signup - {new_user.get('username', 'Unknown')} - {self.settings.totp_issuer}"

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
        <h1 style="color: white; margin: 0; font-size: 28px;">New User Registration</h1>
    </div>
    <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
        <p style="font-size: 16px;">A new user has registered and is awaiting approval.</p>

        <div style="background: #fff; padding: 20px; border-radius: 8px; border: 1px solid #e0e0e0; margin: 20px 0;">
            <h3 style="margin: 0 0 15px 0; color: #333; font-size: 18px;">User Details</h3>
            <table style="width: 100%; border-collapse: collapse;">
                <tr>
                    <td style="padding: 8px 0; color: #666; width: 120px;">Username:</td>
                    <td style="padding: 8px 0; font-weight: bold;">{new_user.get('username', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; color: #666;">Full Name:</td>
                    <td style="padding: 8px 0; font-weight: bold;">{new_user.get('full_name', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; color: #666;">Email:</td>
                    <td style="padding: 8px 0; font-weight: bold;">{new_user.get('email', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; color: #666;">Phone:</td>
                    <td style="padding: 8px 0; font-weight: bold;">{new_user.get('phone', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; color: #666;">Signup Time:</td>
                    <td style="padding: 8px 0; font-weight: bold;">{new_user.get('signup_time', 'N/A')}</td>
                </tr>
            </table>
        </div>

        <p style="font-size: 14px; color: #666;">
            Once the user completes email and phone verification, you can approve or reject their account from the admin dashboard.
        </p>

        <div style="text-align: center; margin: 30px 0;">
            <a href="{admin_dashboard_link}" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
                Review in Admin Dashboard
            </a>
        </div>

        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
        <p style="font-size: 12px; color: #999; text-align: center;">
            This is an automated notification from {self.settings.totp_issuer}.
        </p>
    </div>
</body>
</html>
"""

        text_body = f"""
New User Registration

A new user has registered and is awaiting approval.

User Details:
- Username: {new_user.get('username', 'N/A')}
- Full Name: {new_user.get('full_name', 'N/A')}
- Email: {new_user.get('email', 'N/A')}
- Phone: {new_user.get('phone', 'N/A')}
- Signup Time: {new_user.get('signup_time', 'N/A')}

Once the user completes email and phone verification, you can approve or reject their account from the admin dashboard.

Review in Admin Dashboard: {admin_dashboard_link}

This is an automated notification from {self.settings.totp_issuer}.
"""

        try:
            # Send to all admin emails
            response = self.client.send_email(
                Source=self.settings.ses_sender_email,
                Destination={"ToAddresses": admin_emails},
                Message={
                    "Subject": {"Data": subject, "Charset": "UTF-8"},
                    "Body": {
                        "Text": {"Data": text_body, "Charset": "UTF-8"},
                        "Html": {"Data": html_body, "Charset": "UTF-8"},
                    },
                },
            )
            message_id = response.get("MessageId", "unknown")
            logger.info("Admin notification email sent to %s admins, MessageId: %s", len(admin_emails), message_id)
            return True, "Admin notification email sent successfully"

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("Failed to send admin notification email: %s - %s", error_code, error_message)
            return False, f"Failed to send email: {error_message}"

        except Exception as e:
            logger.error("Unexpected error sending admin notification email: %s", e)
            return False, f"Failed to send email: {str(e)}"
