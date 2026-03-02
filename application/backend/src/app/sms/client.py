"""SMS client for sending verification codes via AWS SNS.

Uses Direct SMS: sns.publish(PhoneNumber=..., Message=..., MessageAttributes=...).
No SNS topic is required. See:
- Publish API: https://docs.aws.amazon.com/sns/latest/api/API_Publish.html
- SMS to phone: https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html
- Message attributes (SMSType, SenderID): https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html
"""

import logging
import random
import re
import string
from typing import Optional
import hashlib

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class SMSClient:
    """Client for SMS operations using AWS SNS."""

    # E.164 phone number format regex
    E164_PATTERN = re.compile(r"^\+[1-9]\d{1,14}$")

    def __init__(self, settings: Optional[Settings] = None):
        """Initialize SMS client with settings."""
        self.settings = settings or get_settings()
        self._sns_client = None

    @property
    def sns_client(self):
        """Get or create SNS client."""
        if self._sns_client is None:
            self._sns_client = boto3.client(
                "sns",
                region_name=self.settings.aws_region,
            )
        return self._sns_client

    def validate_phone_number(self, phone_number: str) -> tuple[bool, str]:
        """
        Validate phone number format (E.164).

        Args:
            phone_number: Phone number to validate

        Returns:
            Tuple of (is_valid, error_message)
        """
        if not phone_number:
            return False, "Phone number is required"

        # Check E.164 format
        if not self.E164_PATTERN.match(phone_number):
            return False, (
                "Invalid phone number format. "
                "Use E.164 format: +[country code][number] (e.g., +14155552671)"
            )

        return True, ""

    def generate_verification_code(self, length: int = 6) -> str:
        """
        Generate a random numeric verification code.

        Args:
            length: Length of the code (default: 6)

        Returns:
            Verification code string
        """
        return "".join(random.choices(string.digits, k=length))

    def send_verification_code(
        self,
        phone_number: str,
        code: str,
        sender_id: Optional[str] = None,
    ) -> tuple[bool, str, Optional[str]]:
        """
        Send a verification code via SMS.

        Args:
            phone_number: Recipient phone number (E.164 format)
            code: Verification code to send
            sender_id: Optional sender ID override

        Returns:
            Tuple of (success, message, message_id)
        """
        # Validate phone number
        is_valid, error = self.validate_phone_number(phone_number)
        if not is_valid:
            return False, error, None

        # Format message (AWS SNS: max 140 chars per segment, 1600 per Publish)
        message = self.settings.sms_message_template.format(code=code)
        if len(message) > 1600:
            return False, "SMS message exceeds maximum length (1600 characters)", None
        if len(message) > 140:
            logger.info(
                "SMS message length %d exceeds 140 chars; SNS will send as multiple segments",
                len(message),
            )

        try:
            # Reserved SMS message attributes per AWS (DataType String, StringValue)
            message_attributes = {
                "AWS.SNS.SMS.SMSType": {
                    "DataType": "String",
                    "StringValue": self.settings.sms_type,
                }
            }
            effective_sender_id = sender_id or self.settings.sms_sender_id
            if effective_sender_id:
                message_attributes["AWS.SNS.SMS.SenderID"] = {
                    "DataType": "String",
                    "StringValue": effective_sender_id,
                }

            # Direct SMS: PhoneNumber (E.164), Message, MessageAttributes (no TopicArn)
            response = self.sns_client.publish(
                PhoneNumber=phone_number,
                Message=message,
                MessageAttributes=message_attributes,
            )

            message_id = response.get("MessageId")
            logger.info(
                "SMS sent successfully. MessageId: %s", message_id
            )

            return True, "Verification code sent", message_id

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("SNS ClientError sending SMS: %s - %s", error_code, error_message)

            # Handle specific error codes
            if error_code == "InvalidParameter":
                return False, "Invalid phone number", None
            elif error_code == "OptedOut":
                return False, "Phone number has opted out of SMS", None
            elif error_code == "InternalError":
                return False, "SMS service temporarily unavailable", None
            else:
                return False, f"Failed to send SMS: {error_message}", None

        except BotoCoreError as e:
            error_type = type(e).__name__
            logger.error(
                "BotoCoreError sending SMS: %s - %s (check AWS credentials, "
                "IRSA, VPC endpoint for SNS, and network connectivity)",
                error_type,
                e,
                exc_info=True,
            )
            return False, "SMS service error", None

        except Exception as e:
            logger.error("Unexpected error sending SMS: %s", e)
            return False, "Failed to send verification code", None

    def check_opt_out_status(self, phone_number: str) -> tuple[bool, bool]:
        """
        Check if a phone number has opted out of SMS.

        Args:
            phone_number: Phone number to check

        Returns:
            Tuple of (success, is_opted_out)
        """
        try:
            response = self.sns_client.check_if_phone_number_is_opted_out(
                phoneNumber=phone_number
            )
            return True, response.get("isOptedOut", False)

        except Exception as e:
            logger.error("Error checking opt-out status: %s", e)
            return False, False

    def opt_in_phone_number(self, phone_number: str) -> tuple[bool, str]:
        """
        Opt in a phone number that was previously opted out.

        Args:
            phone_number: Phone number to opt in

        Returns:
            Tuple of (success, message)
        """
        try:
            self.sns_client.opt_in_phone_number(phoneNumber=phone_number)
            phone_hash = hashlib.sha256(phone_number.encode("utf-8")).hexdigest()[:8]
            logger.info("Phone number opted in (hash=%s)", phone_hash)
            return True, "Phone number opted in successfully"

        except ClientError as e:
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("SNS opt-in error: %s", error_message)
            return False, f"Failed to opt in: {error_message}"

        except Exception as e:
            logger.error("Unexpected error opting in phone: %s", e)
            return False, "Failed to opt in phone number"
