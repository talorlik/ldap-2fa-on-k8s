# SNS Module for SMS-based 2FA Verification

This module creates AWS SNS resources for sending SMS verification codes as part
of the 2FA application.

## Features

- **Direct SMS**: Sends SMS directly to phone numbers (no SNS topic required)
- **IAM Role (IRSA)**: Enables EKS pods to publish to SNS using service account

## Architecture

```text
┌─────────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Backend Pod        │────▶│  SNS (Direct SMS)│────▶│  SMS Gateway    │
│  (with IRSA)        │     │  (2FA Messages)  │     │                 │
└─────────────────────┘     └──────────────────┘     └─────────────────┘
        │                            │
        │ AssumeRoleWithWebIdentity  │ Direct Publish
        ▼                            ▼
┌─────────────────────┐     ┌──────────────────┐
│  IAM Role           │     │  Phone Number    │
│  (SNS Publisher)    │     │  (E.164 format)  │
└─────────────────────┘     └──────────────────┘
```

## Usage

```hcl
module "sns" {
  source = "./modules/sns"

  env          = var.env
  region       = var.region
  prefix       = var.prefix
  cluster_name = local.cluster_name

  service_account_namespace = "2fa-app"
  service_account_name      = "ldap-2fa-backend"

  tags = local.tags
}
```

## IRSA Configuration

The IAM role is configured for IAM Roles for Service Accounts (IRSA). To use it:

1. Add the annotation to your Kubernetes service account:

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
    name: ldap-2fa-backend
    namespace: 2fa-app
    annotations:
        eks.amazonaws.com/role-arn: <iam_role_arn from outputs>
    ```

2. The backend application will automatically assume this role when making
   AWS SDK calls.

## SMS Sending Methods

### 1. Direct SMS (Recommended for Verification Codes)

Send directly to a phone number. No SNS topic or subscription required.

- [Publish (API)](https://docs.aws.amazon.com/sns/latest/api/API_Publish.html):
  use `PhoneNumber` (E.164), `Message`, and optional `MessageAttributes`.
- [Publishing to a mobile phone](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html):
  SMS limits (140 chars per segment, 1600 per request).

```python
import boto3

sns = boto3.client('sns')
sns.publish(
    PhoneNumber='+1234567890',  # E.164 format
    Message='Your verification code is: 123456',
    MessageAttributes={
        'AWS.SNS.SMS.SMSType': {
            'DataType': 'String',
            'StringValue': 'Transactional'
        },
        'AWS.SNS.SMS.SenderID': {
            'DataType': 'String',
            'StringValue': 'MyApp'
        }
    }
)
```

## Phone Number Format

All phone numbers must be in E.164 format:

- Start with `+`
- Country code
- No spaces, dashes, or parentheses
- Examples: `+14155552671`, `+442071234567`

## SMS Types

- **Transactional**: Higher delivery priority, used for verification codes
- **Promotional**: Lower cost, used for marketing (may be filtered)

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment | `string` | n/a | yes |
| region | AWS region | `string` | n/a | yes |
| prefix | Prefix for resource names | `string` | n/a | yes |
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| iam_role_name | Name component for the IAM role | `string` | `"2fa-sns-publisher"` | no |
| service_account_namespace | Kubernetes namespace for the service account | `string` | `"2fa-app"` | no |
| service_account_name | Name of the Kubernetes service account | `string` | `"ldap-2fa-backend"` | no |
| configure_sms_preferences | Whether to configure account-level SMS preferences | `bool` | `false` | no |
| sms_sender_id | Default sender ID for SMS (max 11 alphanumeric) | `string` | `"2FA"` | no |
| sms_sender_country_code | ISO 3166-1 alpha-2 country code for sender ID (enables ARN lookup) | `string` | `""` | no |
| sms_type | Default SMS type: Promotional or Transactional | `string` | `"Transactional"` | no |
| sms_monthly_spend_limit | Monthly spend limit for SMS in USD | `number` | `10` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Output | Description |
| -------- | ------------- |
| `iam_role_arn` | ARN of the IAM role for IRSA |
| `iam_role_name` | Name of the IAM role |
| `service_account_annotation` | Annotation map for Kubernetes service account |
| `sms_sender_id_arn` | ARN of Sender ID from AWS End User Messaging (when country code set) |

## Prerequisites

When using SMS 2FA with a branded sender ID, you must request the sender ID in AWS End
User Messaging (Configurations > Sender ID > Request originator) per deployment
account and share it with Amazon SNS. Set `sms_sender_country_code` to the ISO
country code used during registration. See
[SMS Sender ID Setup](../../../docs/auxiliary/application_infra/guides/SMS_SENDER_ID_SETUP.md).

## Cost Considerations

- SMS pricing varies by destination country
- Set `sms_monthly_spend_limit` to control costs
- Transactional SMS costs slightly more than Promotional
- Consider implementing rate limiting in the application

## Security Considerations

- IAM role is scoped to specific service account via IRSA
- Phone numbers should be validated before sending
- Implement rate limiting to prevent abuse
- Consider opt-out compliance for your region
