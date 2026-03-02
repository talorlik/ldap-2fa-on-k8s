# SMS Sender ID Setup (AWS End User Messaging)

This document describes how to set up an SMS Sender ID (Request originator) in
AWS End User Messaging for use with Amazon SNS when sending SMS verification
codes for the 2FA application.

> [!IMPORTANT]
>
> **SMS Sandbox**: If your SNS account is in the SMS sandbox (default), you must
> either add and verify destination phone numbers in **Sandbox destination phone
> numbers**, or request **Exit SMS Sandbox**, before users can receive SMS. See
> [SMS Sandbox](SMS_SANDBOX.md).

> [!IMPORTANT]
>
> Sender ID setup is **required per deployment account** that will send SMS via
> SNS. Each account (e.g., development, production) must have its own sender
> ID registered and configured.

## Why This Is Required

Amazon SNS has integrated with AWS End User Messaging for SMS delivery. To send
SMS messages with a branded sender ID (e.g., "TALO2FA" instead of a phone
number), you must:

1. Request a sender ID in AWS End User Messaging
2. Add a resource policy to share the sender ID with Amazon SNS
3. Ensure the sender ID string matches `sms_sender_id` in your Terraform
   configuration

Without this setup, SMS messages may fail to send or appear as "UNVERIFIED" or
"NOTICE" to recipients.

## Prerequisites

- Access to the AWS account that is the deployment account (Account B)
- The sender ID you plan to use (1-11 alphanumeric characters, must begin with
  a letter)
- Target country where your users receive SMS (sender ID support varies by
  country; see [Supported countries for SMS messaging](https://docs.aws.amazon.com/sms-voice/latest/userguide/phone-numbers-sms-by-country.html))

> [!NOTE]
>
> The United States, Canada, and China do not support sender IDs. Use a country
> where your recipients are located (e.g., Israel, Germany, United Kingdom).

## Step-by-Step Setup

### Step 1: Open the AWS End User Messaging SMS Console

1. Sign in to the AWS Management Console for your deployment account
2. Navigate to [AWS End User Messaging SMS](https://console.aws.amazon.com/sms-voice/)
3. Ensure you are in the correct region (e.g., `us-east-1` for US SMS)

### Step 2: Request a Sender ID (Request Originator)

1. In the navigation pane, under **Configurations**, choose **Sender ID**
2. Choose **Request originator**
3. On **Select country**, choose the destination country for your messages
4. Choose **Next**
5. On **Messaging use case**:
   - **Number capabilities**: Choose **Text messages (SMS)**
   - **Estimated monthly SMS volume** (optional): Enter your estimate
   - **Company headquarters**: Choose Local or International based on where your
     company is located relative to customers
   - **Two-way messaging**: Choose No for one-way verification codes
6. Choose **Next**
7. On **Originator type**, choose **Sender ID**
8. In **Sender ID**, enter your sender ID (e.g., `TALO2FA`):
   - 1-11 alphanumeric characters
   - Letters (A-Z), numbers (0-9), or hyphens (-)
   - Must begin with a letter
9. Under **Resource policy**, enable sharing with SNS:
   - Select **Simple Notification Service (Amazon SNS)** to allow SNS to use
     this sender ID
10. Choose **Next**
11. On **Review and request**, verify details and choose **Request**
12. Complete any **Registration Required** form if prompted (country-specific)

> [!IMPORTANT]
>
> You must add a Resource policy to share the sender ID with Amazon SNS even
> when using the same AWS account. Without this, SNS cannot use the sender ID.

### Step 3: Configure Resource Policy (If Not Done During Request)

If you did not enable SNS sharing during the request, add it afterward:

1. In **Configurations** > **Sender IDs**, select your sender ID
2. Open the **Resource policy** tab
3. Choose **Edit**
4. Add a statement that allows SNS to use the sender ID. Example (replace
   placeholders):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sms-voice:SendTextMessage",
      "Resource": "arn:aws:sms-voice:REGION:ACCOUNT_ID:sender-id/SENDER_ID/COUNTRY_CODE",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "ACCOUNT_ID"
        }
      }
    }
  ]
}
```

Replace:

- `REGION` - AWS region (e.g., `us-east-1`)
- `ACCOUNT_ID` - Your deployment account ID
- `SENDER_ID` - Your sender ID (e.g., `TALO2FA`)
- `COUNTRY_CODE` - ISO 3166-1 alpha-2 country code (e.g., `IL`, `DE`, `GB`)

### Step 4: Wait for Approval

- Some countries approve sender IDs automatically
- Others require manual review; AWS Support may contact you
- Check the sender ID status in the console; it must be active before use

### Step 5: Configure Terraform

Ensure your Terraform variables match the sender ID you registered:

- `sms_sender_id` - Must exactly match the sender ID you requested
- `sms_sender_country_code` - ISO 3166-1 alpha-2 code for the country you
  registered (e.g., `IL`, `DE`, `GB`)

## Verification

To verify your sender ID is available:

```bash
aws pinpoint-sms-voice-v2 describe-sender-ids \
  --sender-ids SenderId=YOUR_SENDER_ID,IsoCountryCode=XX \
  --region us-east-1
```

Replace `YOUR_SENDER_ID` and `XX` with your values. The response should include
`SenderIdArn` and status information.

## References

- [Publishing SMS to a phone number (direct SMS)](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [Publish API (PhoneNumber, Message, MessageAttributes)](https://docs.aws.amazon.com/sns/latest/api/API_Publish.html)
- [Request a sender ID - AWS End User Messaging SMS](https://docs.aws.amazon.com/sms-voice/latest/userguide/sender-id-request.html)
- [Sharing a sender ID with Amazon SNS](https://docs.aws.amazon.com/sms-voice/latest/userguide/shared-resources.html#sharing-share)
- [Origination identity registration](https://docs.aws.amazon.com/sms-voice/latest/userguide/registrations.html)
- [Supported countries and regions for SMS](https://docs.aws.amazon.com/sms-voice/latest/userguide/phone-numbers-sms-by-country.html)
