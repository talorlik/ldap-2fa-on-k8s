"""SMS client for sending verification codes via AWS SNS."""

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

        # Format message
        message = self.settings.sms_message_template.format(code=code)

        try:
            # Set message attributes
            message_attributes = {
                "AWS.SNS.SMS.SMSType": {
                    "DataType": "String",
                    "StringValue": self.settings.sms_type,
                }
            }

            # Add sender ID if provided or configured
            effective_sender_id = sender_id or self.settings.sms_sender_id
            if effective_sender_id:
                message_attributes["AWS.SNS.SMS.SenderID"] = {
                    "DataType": "String",
                    "StringValue": effective_sender_id,
                }

            # Send SMS directly to phone number
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
            logger.error("BotoCoreError sending SMS: %s", e)
            return False, "SMS service error", None

        except Exception as e:
            logger.error("Unexpected error sending SMS: %s", e)
            return False, "Failed to send verification code", None

    def subscribe_phone_number(
        self,
        phone_number: str,
        topic_arn: Optional[str] = None,
    ) -> tuple[bool, str, Optional[str]]:
        """
        Subscribe a phone number to the SNS topic.

        Args:
            phone_number: Phone number to subscribe (E.164 format)
            topic_arn: Optional topic ARN override

        Returns:
            Tuple of (success, message, subscription_arn)
        """
        # Validate phone number
        is_valid, error = self.validate_phone_number(phone_number)
        if not is_valid:
            return False, error, None

        effective_topic_arn = topic_arn or self.settings.sns_topic_arn
        if not effective_topic_arn:
            return False, "SNS topic not configured", None

        try:
            response = self.sns_client.subscribe(
                TopicArn=effective_topic_arn,
                Protocol="sms",
                Endpoint=phone_number,
                ReturnSubscriptionArn=True,
            )

            subscription_arn = response.get("SubscriptionArn")
            logger.info("Phone number subscribed with ARN: %s", subscription_arn)

            return True, "Phone number subscribed successfully", subscription_arn

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("SNS subscribe error: %s - %s", error_code, error_message)
            return False, f"Failed to subscribe: {error_message}", None

        except Exception as e:
            logger.error("Unexpected error subscribing phone: %s", e)
            return False, "Failed to subscribe phone number", None

    def unsubscribe(self, subscription_arn: str) -> tuple[bool, str]:
        """
        Unsubscribe from the SNS topic.

        Args:
            subscription_arn: Subscription ARN to unsubscribe

        Returns:
            Tuple of (success, message)
        """
        try:
            self.sns_client.unsubscribe(SubscriptionArn=subscription_arn)
            logger.info("Unsubscribed: %s", subscription_arn)
            return True, "Unsubscribed successfully"

        except ClientError as e:
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error("SNS unsubscribe error: %s", error_message)
            return False, f"Failed to unsubscribe: {error_message}"

        except Exception as e:
            logger.error("Unexpected error unsubscribing: %s", e)
            return False, "Failed to unsubscribe"

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
