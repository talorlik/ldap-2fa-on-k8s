# SES Module

Configures AWS SES for sending verification emails in the LDAP 2FA application.

## Features

- Email identity verification (individual email or domain)
- DKIM setup for domain verification
- IAM role with IRSA for secure pod access
- Optional Route53 integration for automatic DNS record creation

## Usage

### Individual Email Verification

```hcl
module "ses" {
  source = "./modules/ses"

  env          = "dev"
  region       = "us-east-1"
  prefix       = "ldap2fa"
  cluster_name = "my-eks-cluster"

  sender_email              = "noreply@example.com"
  service_account_namespace = "ldap-2fa"
  service_account_name      = "ldap-2fa-backend"
}
```

### Domain Verification (with Route53)

```hcl
module "ses" {
  source = "./modules/ses"

  env          = "dev"
  region       = "us-east-1"
  prefix       = "ldap2fa"
  cluster_name = "my-eks-cluster"

  sender_email    = "noreply@example.com"
  sender_domain   = "example.com"
  route53_zone_id = "Z1234567890ABC"

  service_account_namespace = "ldap-2fa"
  service_account_name      = "ldap-2fa-backend"
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| cluster_name | EKS cluster name for IRSA | `string` | n/a | yes |
| sender_email | Email address to send from | `string` | n/a | yes |
| sender_domain | Domain to verify (optional) | `string` | `null` | no |
| iam_role_name | IAM role name component | `string` | `"ses-sender"` | no |
| service_account_namespace | K8s namespace | `string` | `"ldap-2fa"` | no |
| service_account_name | K8s service account name | `string` | `"ldap-2fa-backend"` | no |
| route53_zone_id | Route53 zone for DNS records | `string` | `null` | no |

## Outputs

| Name | Description |
| ------ | ------------- |
| sender_email | Verified sender email |
| sender_domain | Verified domain (if configured) |
| iam_role_arn | IAM role ARN for IRSA |
| iam_role_name | IAM role name |
| email_identity_arn | SES identity ARN |
| verification_status | Verification instructions |

## IRSA Configuration

The IAM role is configured for IAM Roles for Service Accounts (IRSA). To use it:

1. The module creates an IAM role with SES send permissions
2. Add the annotation to your Kubernetes service account:

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ldap-2fa-backend
      namespace: ldap-2fa
      annotations:
        eks.amazonaws.com/role-arn: <iam_role_arn from outputs>
    ```

3. The backend application will automatically assume this role when making
AWS SDK calls to SES

## Email Types

The SES module supports sending various email types for the 2FA application:

- **Verification Emails**: Token-based verification links for email verification
  - Contains UUID token in verification link
  - 24-hour token expiry (configurable)
  - Sent when user registers or requests resend

- **Welcome Emails**: Sent when admin approves user activation
  - Confirms user account is active
  - Provides login instructions

- **Admin Notification Emails**: Sent to all admins when new user signs up
  - Notifies admins of pending user approval
  - Includes user details for review

For detailed email templates and sending logic, see the application backend code
in `application/backend/src/app/email/client.py`.

## Important Notes

1. **SES Sandbox**: New SES accounts are in sandbox mode and can only send to
verified addresses. Request production access for unrestricted sending.

2. **Email Verification**: If using individual email verification, check the
inbox for the verification link from AWS.

3. **Domain Verification**: If using domain verification without Route53 integration,
manually add the DNS records shown in the AWS console.

4. **Service Account**: The Kubernetes service account must have the annotation
`eks.amazonaws.com/role-arn` set to the IAM role ARN for IRSA to work.

5. **VPC Endpoints**: For SMS 2FA, ensure SNS VPC endpoint is enabled in backend_infra.
SES does not require a VPC endpoint (uses internet gateway or NAT gateway).

6. **Sending Limits**: SES has sending limits based on account reputation.
Monitor sending quotas and request limit increases if needed.
