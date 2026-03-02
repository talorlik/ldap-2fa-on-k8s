# Amazon SNS SMS Sandbox

This document describes the **Amazon SNS SMS sandbox**: what it is, how it affects
sending SMS for the 2FA application, and how to either work within it or move to
production.

## What Is the SMS Sandbox?

The SMS sandbox is a protective environment that AWS places all new SNS SMS
accounts into by default. It is designed to:

- Ensure security for both AWS customers and recipients
- Mitigate the risk of fraud and abuse
- Provide a safe environment for testing and development

> [!IMPORTANT]
>
> If SMS 2FA is enabled, you must either **add and verify sandbox destination
> phone numbers** so users can receive codes, or **exit the SMS sandbox** (request
> production access). Until then, SMS can only be sent to verified numbers in
> sandbox, or to any number after sandbox exit.

## Sandbox Limitations

While your account is in the sandbox:

| Limitation | Detail |
| ---------- | ------ |
| **Verified recipients only** | You can send SMS only to **verified** destination phone numbers |
| **Maximum 10 numbers** | You can have up to 10 verified phone numbers |
| **24-hour deletion rule** | You can only delete a phone number 24 hours after it was verified |
| **Spending limit** | Default monthly spending threshold is $1.00 USD (can be increased via support) |
| **Rate limit** | Maximum of 20 messages per second |

Unverified numbers will not receive SMS in sandbox; the application may still
report success if SNS accepts the request, but delivery will not occur.

## How to Verify Destination Phone Numbers (Sandbox)

To send SMS to a phone number while in the sandbox, you must verify it first:

1. Open the [Amazon SNS console](https://console.aws.amazon.com/sns/)
2. In the left navigation, under **Text messaging (SMS)**, choose **Sandbox
   destination phone numbers**
3. Choose **Add phone number**
4. Enter the destination phone number in E.164 format (e.g., `+14155552671`)
5. Choose **Add phone number**
6. SNS sends a one-time password (OTP) to that number
7. Enter the OTP in the console (valid for 15 minutes)
8. The number status changes from **Pending** to **Verified**

After verification, the 2FA application can send SMS codes to that number. Repeat
for each user phone number you need to support in sandbox (up to 10).

## What Does "Exit SMS Sandbox" Mean?

Exiting the sandbox means moving to **production** mode:

- You can send SMS to **any** phone number (no verification step per number)
- No limit on the number of destination phone numbers
- Higher spending thresholds available
- All sandbox restrictions are removed

This is required for production use where many users receive SMS without
pre-verifying each number in the SNS console.

## How to Exit the SMS Sandbox

To move out of the sandbox and send SMS to any number:

1. **Test in sandbox first**: Add, verify, and test with destination phone
   numbers to ensure your use case works.
2. **Create an AWS Support case**: Submit a request through the [AWS Support Center](https://console.aws.amazon.com/support/).
3. **Provide details**: Include your use case, AWS regions, target countries,
   opt-in process, and message templates (e.g., 2FA verification codes).
4. **Wait for review**: AWS Support typically responds within 24 hours.
5. **Approval**: AWS reviews each request to prevent misuse. If denied, you can
   resubmit with more information.

> [!NOTE]
>
> Sandbox status is **per AWS region**. You must exit the sandbox separately for
> each region where you send SMS (e.g., `us-east-1`).

## Check Your Sandbox Status

- In the SNS console: **Text messaging (SMS)** shows whether the account is in
  sandbox or production.
- You can also use the AWS CLI or API to check sandbox-related attributes.

## Summary for 2FA Application Users

- **Development / testing**: Add and verify up to 10 destination phone numbers
  in **Sandbox destination phone numbers**. Those numbers can receive SMS codes.
- **Production**: Request **Exit SMS Sandbox** for the deployment account (and
  region) so any user phone number can receive SMS without pre-verification.

## References

- [Using the Amazon SNS SMS sandbox](https://docs.aws.amazon.com/sns/latest/dg/sns-sms-sandbox.html)
- [Moving out of the Amazon SNS SMS sandbox](https://docs.aws.amazon.com/sns/latest/dg/sns-sms-sandbox-moving-to-production.html)
- [Requesting support for Amazon SNS SMS messaging](https://docs.aws.amazon.com/sns/latest/dg/channels-sms-awssupport.html)
