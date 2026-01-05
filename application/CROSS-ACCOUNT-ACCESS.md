# Cross-Account Access Configuration

This document describes the cross-account access requirements between the
**State Account** (where Route53 hosted zone and ACM certificate reside) and the
**Deployment Account** (where EKS cluster, ALB, and application resources are deployed).

## Overview

The application infrastructure requires access to Route53 hosted zones and ACM
certificates that reside in the State Account, while deploying resources in the
Deployment Account (development or production).

## Cross-Account Access Requirements

### 1. Route53 Hosted Zone Access

**State Account → Deployment Account:**

- Route53 hosted zone is queried from State Account using `data.aws_route53_zone`
- Route53 records are created in State Account using `aws_route53_record` resources
- All Route53 operations use the `aws.state_account` provider alias

**Required Permissions (State Account Role):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. ACM Certificate Access

**State Account → Deployment Account:**

- ACM certificate is queried from State Account using `data.aws_acm_certificate`
- Certificate ARN is passed to ALB and Ingress resources in Deployment Account
- ALB in Deployment Account can use ACM certificate from State Account
(same region required)

**Required Permissions (State Account Role):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

**Important Notes:**

- ALB can use ACM certificates from different accounts **in the same region**
- AWS ALB service automatically has permissions to use certificates from any account
- No additional IAM permissions needed for ALB to use cross-account certificates
- Certificate must be validated and in `ISSUED` status

### 3. ALB Certificate Usage

**Deployment Account ALB → State Account Certificate:**

- ALB is created in Deployment Account by EKS Auto Mode
- ALB uses ACM certificate ARN from State Account via IngressClassParams
- Certificate ARN is passed to Kubernetes IngressClassParams resource
- EKS Auto Mode handles ALB creation and certificate attachment automatically

**Configuration Flow:**

1. Terraform queries ACM certificate from State Account
(using `aws.state_account` provider)
2. Certificate ARN is passed to ALB module
3. ALB module creates IngressClassParams with `certificateARNs` field
4. EKS Auto Mode creates ALB and attaches certificate from State Account
5. ALB listener uses certificate for HTTPS/TLS termination

### 4. Route53 Record Creation

**Deployment Account → State Account:**

- Route53 A (alias) records are created in State Account
- Records point to ALB DNS name in Deployment Account
- All Route53 record resources use `aws.state_account` provider

**Record Types Created:**

- `phpldapadmin.<domain>` → ALB DNS name (alias record)
- `passwd.<domain>` → ALB DNS name (alias record)
- `app.<domain>` → ALB DNS name (alias record)
- SES verification records (if domain verification enabled)
- SES DKIM records (if domain verification enabled)

## Provider Configuration

### State Account Provider

The `aws.state_account` provider alias is configured in `providers.tf`:

```hcl
provider "aws" {
  alias  = "state_account"
  region = var.region

  dynamic "assume_role" {
    for_each = var.state_account_role_arn != null ? [1] : []
    content {
      role_arn = var.state_account_role_arn
      # Note: ExternalId is not used for state account role assumption (by design)
    }
  }
}
```

### Resources Using State Account Provider

**Data Sources:**

- `data.aws_route53_zone.this` - Queries hosted zone from State Account
- `data.aws_acm_certificate.this` - Queries ACM certificate from State Account

**Resources:**

- `aws_route53_record.twofa_app` - Creates A record in State Account
- `aws_route53_record.phpldapadmin` (in openldap module) - Creates A record in
State Account
- `aws_route53_record.ltb_passwd` (in openldap module) - Creates A record in
State Account
- `aws_route53_record.ses_verification` (in ses module) - Creates TXT record in
State Account
- `aws_route53_record.ses_dkim` (in ses module) - Creates CNAME records in
State Account

## State Account Role Trust Relationship

The State Account role must trust the Deployment Account role (or GitHub Actions
OIDC provider):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::DEPLOYMENT_ACCOUNT_ID:role/github-role"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": null
        }
      }
    }
  ]
}
```

**Note:** ExternalId is **not required** for State Account role assumption (by design).

> [!IMPORTANT]
>
> **Self-Assumption Requirement**: If the State Account role is the same as the
> role being assumed (e.g., when `state_account_role_arn` points to the same role
> in the same account), the trust policy must allow the role to assume itself.
> Add the following statement to the trust policy:
>
> ```json
> {
>   "Effect": "Allow",
>   "Principal": {
>     "AWS": "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
>   },
>   "Action": "sts:AssumeRole"
> }
> ```
>
> This is required when Terraform providers need to assume the same role that was
> already assumed by the initial authentication (e.g., when GitHub Actions assumes
> a role and then Terraform tries to assume the same role again via
> `assume_role` in `providers.tf`).

## Verification Checklist

- [x] Route53 hosted zone data source uses `aws.state_account` provider
- [x] ACM certificate data source uses `aws.state_account` provider
- [x] All Route53 record resources use `aws.state_account` provider
- [x] State account role ARN is automatically injected by scripts
- [x] State account role has Route53 permissions
- [x] State account role has ACM read permissions
- [x] ALB can use ACM certificate from State Account (same region)
- [x] Route53 records point to ALB in Deployment Account
- [x] Certificate ARN is passed correctly to ALB module
- [x] Certificate ARN is passed correctly to OpenLDAP module

## Troubleshooting

### Issue: "Empty result" when querying Route53 hosted zone

**Solution:** Ensure `state_account_role_arn` is set and the role has
`route53:GetHostedZone` permission.

### Issue: "Empty result" when querying ACM certificate

**Solution:** Ensure `state_account_role_arn` is set and the role has
`acm:ListCertificates` permission.

### Issue: ALB cannot use certificate from State Account

**Solution:**

- Verify certificate is in the same region as ALB
- Verify certificate is validated and in `ISSUED` status
- Verify certificate ARN is correctly passed to IngressClassParams

### Issue: Route53 records cannot be created

**Solution:** Ensure State Account role has `route53:ChangeResourceRecordSets`
permission on the hosted zone.
