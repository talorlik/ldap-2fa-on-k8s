# Cross-Account Access Configuration

This document describes the cross-account access requirements between the
**State Account** (where Route53 hosted zone and Private CA reside) and the
**Deployment Account** (where EKS cluster, ALB, ACM certificates, and application
resources are deployed).

## Overview

The application infrastructure requires access to Route53 hosted zones from the
State Account, while deploying resources in the Deployment Account
(development or production).

### Certificate Architecture

The certificate architecture uses a **Private CA** approach:

1. **Private CA in State Account**: A Private Certificate Authority (PCA) is created
in the State Account
2. **Certificate Issuance**: The Private CA issues separate ACM certificates for
each deployment account (development, production)
3. **Certificate Storage**: Each certificate is stored in its respective deployment
account (not in the State Account)
4. **No Cross-Account Access**: Since each deployment account has its own certificate,
there's no need for cross-account certificate access
5. **EKS Auto Mode Compatibility**: This architecture satisfies EKS Auto Mode ALB
controller requirements (certificate must be in the same account as the ALB)

**Benefits:**

- ✅ Eliminates cross-account certificate access complexity
- ✅ Each account manages its own certificate lifecycle
- ✅ Centralized certificate authority (Private CA) in State Account
- ✅ No additional provider configuration or credentials needed for certificates
- ✅ Compatible with EKS Auto Mode ALB controller limitations

## Private CA Setup and Certificate Issuance

This section provides step-by-step AWS CLI commands to create the central
Private CA in the State Account and issue certificates for each deployment account.

### Prerequisites

- AWS CLI configured with State Account credentials
- AWS RAM (Resource Access Manager) enabled for your organization
- `ca-config.json` file with CA configuration (see example below)
- Appropriate IAM permissions for ACM-PCA, RAM, and ACM operations

### Step 0: Enable Resource Sharing

Enable resource sharing within your organization (run this in the management account):

```bash
aws ram enable-sharing-with-aws-organization --region us-east-1
```

### Step 1: Create a CA Configuration File

Create a `ca-config.json` file using the following command:

```bash
# Create ca-config.json
cat > ca-config.json << 'EOF'
{
    "KeyAlgorithm": "RSA_2048",
    "SigningAlgorithm": "SHA256WITHRSA",
    "Subject": {
        "Country": "US",
        "Organization": "YourOrganization",
        "OrganizationalUnit": "IT",
        "CommonName": "Your Organization Root CA"
    }
}
EOF
```

**Replace placeholders:**

- `YourOrganization`: Your organization name
- `IT`: Your organizational unit (e.g., "IT", "Security", "Infrastructure")
- `Your Organization Root CA`: Your CA common name
(e.g., "Your Organization Root CA")

### Step 2: Create the Root CA

Create the root Certificate Authority:

```bash
aws acm-pca create-certificate-authority \
    --certificate-authority-configuration file://ca-config.json \
    --certificate-authority-type "ROOT" \
    --region us-east-1 \
    --tags Key=Name,Value=RootCA Key=Purpose,Value=CentralCA
```

> [!NOTE]
>
> Save the CA ARN from the output - you'll need it for the next steps.

### Step 3: Get Certificate Signing Request (CSR)

Retrieve the CSR from the newly created CA:

```bash
# Set the CA ARN from the previous command output
CA_ARN="arn:aws:acm-pca:us-east-1:STATE_ACCOUNT_ID:certificate-authority/CA_ID"

# Get CSR
aws acm-pca get-certificate-authority-csr \
    --certificate-authority-arn $CA_ARN \
    --region us-east-1 \
    --output text > ca.csr
```

### Step 4: Issue the Root Certificate

Issue the root certificate using the CSR:

```bash
aws acm-pca issue-certificate \
    --certificate-authority-arn $CA_ARN \
    --csr fileb://ca.csr \
    --signing-algorithm "SHA256WITHRSA" \
    --template-arn "arn:aws:acm-pca:::template/RootCACertificate/V1" \
    --validity Value=10,Type="YEARS" \
    --region us-east-1
```

> [!NOTE]
>
> Save the certificate ARN from the output for the next step.

### Step 5: Import the Certificate

Import the certificate into the CA:

```bash
# Set the certificate ARN from the previous command output
CERTIFICATE_ARN="arn:aws:acm-pca:us-east-1:STATE_ACCOUNT_ID:certificate-authority/CA_ID/certificate/CERTIFICATE_ID"

# Get the certificate
aws acm-pca get-certificate \
    --certificate-authority-arn $CA_ARN \
    --certificate-arn $CERTIFICATE_ARN \
    --region us-east-1 \
    --output text > ca-cert.pem

# Import the certificate
aws acm-pca import-certificate-authority-certificate \
    --certificate-authority-arn $CA_ARN \
    --certificate fileb://ca-cert.pem \
    --region us-east-1
```

### Step 6: Share Private CA via RAM

Create a resource share to make the Private CA available to your organization:

```bash
aws ram create-resource-share \
    --name "Private-CA-Share" \
    --resource-arns $CA_ARN \
    --principals "arn:aws:organizations::STATE_ACCOUNT_ID:organization/ORGANIZATION_ID" \
    --region us-east-1 \
    --tags key=Purpose,value=CentralCA key=Organization,value=YourOrg
```

### Step 7: Verify Resource Share

Check the resource share details:

```bash
# Check the resource share details
aws ram get-resource-shares \
    --name "Private-CA-Share" \
    --resource-owner SELF \
    --region us-east-1

# Check RAM resource associations
aws ram get-resource-share-associations \
    --association-type RESOURCE \
    --region us-east-1

# Check for shared Private CAs
aws acm-pca list-certificate-authorities \
    --region us-east-1
```

### Step 8: Verify RAM Service Access

Verify that RAM service access is enabled for your organization:

```bash
# Run this in the state account
aws organizations list-aws-service-access-for-organization \
    --query 'EnabledServicePrincipals[?ServicePrincipal==`ram.amazonaws.com`]'

# Check resource share status
aws ram get-resource-shares \
    --name "Private-CA-Share" \
    --resource-owner SELF \
    --region us-east-1 \
    --query 'resourceShares[0].status'
```

### Step 9: Request Certificates in Deployment Accounts

Switch to each deployment account (development, production) and request certificates:

**For Production Account:**

```bash
# Switch to production account credentials first, then run:
aws --profile prod acm request-certificate \
    --domain-name "example.com" \
    --subject-alternative-names "*.example.com" \
    --certificate-authority-arn $CA_ARN \
    --region us-east-1 \
    --tags Key=Name,Value=PrivateCertProd Key=Env,Value=prod Key=Purpose,Value=ALB
```

**For Development Account:**

```bash
# Switch to development account credentials first, then run:
aws --profile dev acm request-certificate \
    --domain-name "example.com" \
    --subject-alternative-names "*.example.com" \
    --certificate-authority-arn $CA_ARN \
    --region us-east-1 \
    --tags Key=Name,Value=PrivateCertDev Key=Env,Value=dev Key=Purpose,Value=ALB
```

### Step 10: Verify Certificate Authority

Check the Private CA details:

```bash
aws acm-pca describe-certificate-authority \
    --certificate-authority-arn $CA_ARN \
    --region us-east-1
```

### Step 11: Verify ACM Service-Linked Role

Check if the ACM service-linked role exists (usually auto-created):

```bash
# Check for ACM service-linked role
aws --profile <sso-profile> iam get-role --role-name AWSServiceRoleForCertificateManager

# If it doesn't exist, create it (optional - usually auto-created)
aws --profile <sso-profile> iam create-service-linked-role --aws-service-name acm.amazonaws.com
```

### Important Notes

- **Replace Placeholders**: Replace all placeholders in the commands:
  - `STATE_ACCOUNT_ID`: Your State Account ID
  - `CA_ID`: The CA ID from the create command output
  - `CERTIFICATE_ID`: The certificate ID from the issue command output
  - `ORGANIZATION_ID`: Your AWS Organizations ID
  - `example.com`: Your actual domain name
  - `YourOrg`: Your organization name

- **Region Consistency**: Ensure all commands use the same region (e.g., `us-east-1`)

- **Certificate Validation**: After requesting certificates in deployment accounts,
they will be automatically validated if DNS validation records are created via Route53

- **Certificate Status**: Wait for certificates to reach `ISSUED` status before
using them with ALB

- **Resource Share**: The Private CA must be shared via RAM before deployment
accounts can request certificates from it

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

> [!IMPORTANT]
>
> **EKS Auto Mode ALB Controller Limitation**
>
> **EKS Auto Mode ALB controller CANNOT access cross-account ACM certificates.**
>
> The ACM certificate **MUST** be in the **Deployment Account** (same account where
> the ALB is created), not in the State Account.

**Certificate Architecture:**

- A **Private CA** is created in the **State Account**
- The Private CA issues separate ACM certificates for each deployment account
(development, production)
- Each deployment account has its own certificate issued from the Private CA
- Certificates are stored in their respective deployment accounts (not in the
State Account)
- This eliminates the need for cross-account certificate access

**Deployment Account Certificate Requirements:**

- ACM certificate is queried from Deployment Account using `data.aws_acm_certificate`
(default provider)
- Certificate ARN is passed to ALB and Ingress resources via IngressClassParams
- Certificate must be in the **same account** as the EKS cluster and ALB
- Certificate must be in the **same region** as the ALB/EKS cluster
- Certificate must be validated and in `ISSUED` status
- Certificate is issued from a **Private CA** in the State Account
- Certificate domain must match the domain used by your application

**Required Permissions (Deployment Account Role):**

The deployment account role (or default credentials) must have:

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

**How It Works:**

When an ALB is created in the Deployment Account:

1. Terraform queries ACM certificate from Deployment Account using
`data.aws_acm_certificate` (default provider)
2. Certificate ARN is passed to IngressClassParams (`certificateARNs` field)
3. EKS Auto Mode ALB controller validates that the certificate exists in the
same account
4. The ALB listener automatically uses the certificate for HTTPS/TLS termination

**Pre-Deployment Requirements:**

Since the certificate must be in the Deployment Account, ensure:

- ✅ Private CA exists in the **State Account**
- ✅ Certificate is issued from Private CA and exists in the **Deployment Account**
(not State Account)
- ✅ Certificate is in the **same region** as the ALB/EKS cluster
- ✅ Certificate is **validated** and in `ISSUED` status
- ✅ Certificate is issued from the **Private CA** in the State Account
- ✅ Certificate domain matches the domain used by your application
- ✅ Terraform can query the certificate using `data.aws_acm_certificate` with the
default provider (deployment account)
- ✅ No cross-account certificate access is needed (each account has its own certificate)

### 3. ALB Certificate Usage

**Deployment Account ALB → Deployment Account Certificate:**

- ALB is created in Deployment Account by EKS Auto Mode
- ALB uses ACM certificate ARN from Deployment Account via IngressClassParams
- Certificate ARN is passed to Kubernetes IngressClassParams resource
- EKS Auto Mode handles ALB creation and certificate attachment automatically

**Configuration Flow:**

1. Terraform queries ACM certificate from Deployment Account
(using default `aws` provider, not `aws.state_account`)
2. Certificate ARN is passed to ALB module
3. ALB module creates IngressClassParams with `certificateARNs` field
4. EKS Auto Mode creates ALB and attaches certificate from Deployment Account
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
- `data.aws_acm_certificate.this` - Queries ACM certificate from Deployment Account
(issued from Private CA in State Account)

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
- [x] ACM certificate data source uses default provider (deployment account)
- [x] All Route53 record resources use `aws.state_account` provider
- [x] State account role ARN is automatically injected by scripts
- [x] State account role has Route53 permissions
- [x] Private CA exists in State Account
- [x] Each deployment account has its own certificate issued from Private CA
- [x] ALB can use ACM certificate from Deployment Account (same account and region)
- [x] Route53 records point to ALB in Deployment Account
- [x] Certificate ARN is passed correctly to ALB module
- [x] Certificate ARN is passed correctly to OpenLDAP module
- [x] No cross-account certificate access needed (each account uses its own certificate)

## Troubleshooting

### Issue: "Empty result" when querying Route53 hosted zone

**Solution:** Ensure `state_account_role_arn` is set and the role has
`route53:GetHostedZone` permission.

### Issue: "Empty result" when querying ACM certificate

**Solution:**

- Ensure deployment account credentials/role have `acm:ListCertificates` and
`acm:DescribeCertificate` permissions
- Verify certificate exists in the deployment account (not state account)
- Certificate should be issued from Private CA in State Account but stored in
Deployment Account

### Issue: ALB cannot use certificate (CertificateNotFound)

**Root Cause:** EKS Auto Mode ALB controller cannot access cross-account certificates.
The certificate must be in the Deployment Account, not the State Account.

**Solution:**

1. **Verify certificate is in Deployment Account:**
   - Certificate MUST be in the same account as the EKS cluster and ALB
   - Check certificate account:
   `aws acm describe-certificate --certificate-arn <ARN> --region <region>`
   - Extract account ID from certificate ARN: `arn:aws:acm:region:ACCOUNT_ID:certificate/...`
   - Verify account ID matches Deployment Account ID (not State Account ID)

2. **Create certificate in Deployment Account if missing:**
   - If certificate doesn't exist in Deployment Account, issue it from the
   Private CA in State Account:

     ```bash
     aws acm request-certificate \
       --domain-name <your-domain> \
       --certificate-authority-arn <private-ca-arn> \
       --validation-method DNS \
       --region <region>
     ```

   - The Private CA ARN should be from the State Account
   - Validate the certificate using DNS validation records
   - Wait for certificate status to be `ISSUED`
   - Certificate will be stored in the Deployment Account
   (where the request is made)
   - **See the [Private CA Setup and Certificate Issuance](#private-ca-setup-and-certificate-issuance) section above for complete setup instructions**

3. **Update Terraform configuration:**
   - Ensure `data.aws_acm_certificate.this` uses default provider (deployment account),
   not `aws.state_account`
   - Certificate data source should NOT have `provider = aws.state_account`

4. **Verify certificate location:**
   - Certificate must be in the same region as ALB/EKS cluster
   - Check certificate region:
   `aws acm describe-certificate --certificate-arn <ARN> --region <region>`

5. **Verify certificate status:**
   - Certificate must be validated and in `ISSUED` status
   - Check status: `aws acm list-certificates --region <region>`

6. **Verify certificate type:**
   - Certificate is issued from Private CA in State Account
   - Certificate is stored in Deployment Account (no cross-account access needed)
   - Each deployment account has its own certificate issued from the Private CA

7. **Verify Terraform can access certificate:**
   - Ensure deployment account credentials/role have `acm:DescribeCertificate` permission
   - Verify data source works: Check Terraform plan output for `data.aws_acm_certificate.this.arn`

8. **Verify certificate ARN is passed correctly:**
   - Check that `data.aws_acm_certificate.this.arn` is not null
   - Verify certificate ARN is passed to ALB module: `acm_certificate_arn = data.aws_acm_certificate.this.arn`
   - Verify IngressClassParams has `certificateARNs` field populated

9. **Check ALB listener configuration:**
   - After ALB is created, verify listener has certificate attached
   - Check ALB in AWS Console or via:
   `aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN>`

**Common Errors:**

- **"CertificateNotFound: Certificate 'arn:aws:acm:...' not found"**: Certificate
is in wrong account (should be in Deployment Account, not State Account)
- **"Certificate not found"**: Certificate is in wrong region or Terraform can't
access it, or certificate hasn't been issued from Private CA yet
- **"Certificate not validated"**: Certificate is still pending validation
(DNS validation records may not be created yet)
- **"Invalid certificate ARN"**: Certificate ARN format is incorrect or certificate
doesn't exist
- **"CertificateAuthorityNotFound"**: Private CA ARN is incorrect or Private CA
doesn't exist in State Account

### Issue: Route53 records cannot be created

**Solution:** Ensure State Account role has `route53:ChangeResourceRecordSets`
permission on the hosted zone.
