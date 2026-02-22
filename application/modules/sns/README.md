# SNS Module for SMS-based 2FA Verification

This module creates AWS SNS resources for sending SMS verification codes as part
of the 2FA application.

## Features

- **SNS Topic**: Central topic for SMS notifications
- **IAM Role (IRSA)**: Enables EKS pods to publish to SNS using service account
- **Direct SMS Support**: Allows publishing SMS directly to phone numbers
- **Subscription Management**: Supports subscribing/unsubscribing phone numbers

## Architecture

```text
┌─────────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Backend Pod        │────▶│  SNS Topic       │────▶│  SMS Gateway    │
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

  sns_topic_name            = "2fa-sms"
  sns_display_name          = "2FA Verification"
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

Send directly to a phone number without subscription:

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
        }
    }
)
```

### 2. Topic-based SMS (For Notifications)

Subscribe phone numbers to the topic:

```python
# Subscribe
sns.subscribe(
    TopicArn='arn:aws:sns:region:account:topic',
    Protocol='sms',
    Endpoint='+1234567890'
)

# Publish to topic (all subscribers receive)
sns.publish(
    TopicArn='arn:aws:sns:region:account:topic',
    Message='Notification message'
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
| sns_topic_name | Name component for the SNS topic | `string` | `"2fa-sms"` | no |
| sns_display_name | Display name for the SNS topic | `string` | `"2FA Verification"` | no |
| iam_role_name | Name component for the IAM role | `string` | `"2fa-sns-publisher"` | no |
| service_account_namespace | Kubernetes namespace for the service account | `string` | `"2fa-app"` | no |
| service_account_name | Name of the Kubernetes service account | `string` | `"ldap-2fa-backend"` | no |
| configure_sms_preferences | Whether to configure account-level SMS preferences | `bool` | `false` | no |
| sms_sender_id | Default sender ID for SMS (max 11 alphanumeric) | `string` | `"2FA"` | no |
| sms_type | Default SMS type: Promotional or Transactional | `string` | `"Transactional"` | no |
| sms_monthly_spend_limit | Monthly spend limit for SMS in USD | `number` | `10` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Output | Description |
| -------- | ------------- |
| `sns_topic_arn` | ARN of the SNS topic |
| `sns_topic_name` | Name of the SNS topic |
| `iam_role_arn` | ARN of the IAM role for IRSA |
| `iam_role_name` | Name of the IAM role |
| `service_account_annotation` | Annotation map for Kubernetes service account |

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
