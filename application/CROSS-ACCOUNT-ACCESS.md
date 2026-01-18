# Cross-Account Access Configuration

This document describes the cross-account access requirements between the
**State Account** (where Route53 hosted zone resides) and the
**Deployment Account** (where EKS cluster, ALB, ACM certificates, and application
resources are deployed).

## Overview

The application infrastructure requires access to Route53 hosted zones from the
State Account, while deploying resources in the Deployment Account
(development or production).

### Certificate Architecture

The certificate architecture uses **Public ACM certificates** with DNS validation:

1. **Public ACM Certificates**: Public ACM certificates are requested in each
deployment account (development, production)
2. **DNS Validation**: DNS validation records are created in Route53 hosted zone
in the State Account
3. **Certificate Storage**: Each certificate is stored in its respective deployment
account (not in the State Account)
4. **No Cross-Account Access**: Since each deployment account has its own certificate,
there's no need for cross-account certificate access
5. **EKS Auto Mode Compatibility**: This architecture satisfies EKS Auto Mode ALB
controller requirements (certificate must be in the same account as the ALB)
6. **Browser Trust**: Public ACM certificates are trusted by browsers without warnings

**Benefits:**

- ✅ Eliminates cross-account certificate access complexity
- ✅ Each account manages its own certificate lifecycle
- ✅ Browser-trusted certificates (no security warnings)
- ✅ Automatic renewal via ACM
- ✅ Free certificates (no cost)
- ✅ No additional provider configuration or credentials needed for certificates
- ✅ Compatible with EKS Auto Mode ALB controller limitations

## Public ACM Certificate Setup and DNS Validation

This section provides step-by-step AWS CLI commands to request public ACM certificates
in each deployment account and validate them using DNS records in the State Account's Route53 hosted zone.

### Prerequisites

- AWS CLI configured with SSO profiles for State Account and Deployment Accounts
- Access to State Account (Route53 hosted zone)
- Access to Deployment Accounts (production, development)
- `jq` installed for JSON parsing (optional, for advanced parsing)

**AWS SSO Profiles:**
- `default` - State Account
- `dev` - Development Deployment Account
- `prod` - Production Deployment Account

### Step 1: Request Public ACM Certificate (Production)

Request a public ACM certificate in the production deployment account:

```bash
# Request public certificate with DNS validation
PROD_CERT_ARN=$(aws --profile prod acm request-certificate \
  --domain-name "talorlik.com" \
  --subject-alternative-names "*.talorlik.com" \
  --validation-method DNS \
  --region us-east-1 \
  --tags Key=Name,Value=PublicCertProd Key=Env,Value=prod Key=Purpose,Value=ALB Key=Type,Value=Public \
  --query 'CertificateArn' \
  --output text)

echo "Production Certificate ARN: $PROD_CERT_ARN"
```

**Save this ARN** - you'll need it for subsequent steps.

### Step 2: Get DNS Validation Records (Production)

Wait a few seconds for AWS to generate validation records, then retrieve them:

```bash
# Wait for AWS to generate validation records
sleep 5

# Get validation records
aws --profile prod acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.Name,ResourceRecord.Type,ResourceRecord.Value]' \
  --output table
```

**Expected Output:**
```
----------------------------------------------------------------------------------
||                          DescribeCertificate                                   |
+------------------+--------------------------------------------+-------+----------+
||  talorlik.com    |  _xxx.talorlik.com.                       | CNAME |  _yyy... |
||  *.talorlik.com  |  _xxx.talorlik.com.                       | CNAME |  _yyy... |
+------------------+--------------------------------------------+-------+----------+
```

**Note:** Both domains will use the same CNAME record.

### Step 3: Extract Validation Record Details

Extract the validation record name and value:

```bash
# Extract validation record details
VALIDATION_NAME=$(aws --profile prod acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
  --output text)

VALIDATION_VALUE=$(aws --profile prod acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' \
  --output text)

echo "Validation Name: $VALIDATION_NAME"
echo "Validation Value: $VALIDATION_VALUE"
```

### Step 4: Get Route53 Hosted Zone ID (State Account)

Get the hosted zone ID for your domain in the State Account:

```bash
# Get hosted zone ID for talorlik.com
ZONE_ID=$(aws --profile default route53 list-hosted-zones-by-name \
  --dns-name talorlik.com \
  --query 'HostedZones[0].Id' \
  --output text | cut -d'/' -f3)

echo "Hosted Zone ID: $ZONE_ID"
```

### Step 5: Create DNS Validation Record in Route53 (State Account)

Create the DNS validation record in the State Account's Route53 hosted zone:

```bash
# Create change batch JSON
cat > /tmp/prod-validation-record.json << EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$VALIDATION_NAME",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$VALIDATION_VALUE"
          }
        ]
      }
    }
  ]
}
EOF

# Create the record in Route53 (State Account)
aws --profile default route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file:///tmp/prod-validation-record.json

echo "DNS validation record created in Route53"
```

### Step 6: Wait for Certificate Validation (Production)

Wait for the certificate to be validated:

```bash
# Check certificate status (should change from PENDING_VALIDATION to ISSUED)
echo "Waiting for certificate validation..."
aws --profile prod acm wait certificate-validated \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1

echo "Certificate validated successfully!"

# Verify status
aws --profile prod acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.[Status,Type,Issuer]' \
  --output table
```

**Expected Output:**
```
------------------------------------------
||       DescribeCertificate             |
+----------+--------+--------------------+
||  ISSUED  | AMAZON | Amazon RSA 2048... |
+----------+--------+--------------------+
```

### Step 7: Request Public Certificate (Development) - Optional

If you want to set up the development environment as well:

```bash
# Request public certificate for dev
DEV_CERT_ARN=$(aws --profile dev acm request-certificate \
  --domain-name "talorlik.com" \
  --subject-alternative-names "*.talorlik.com" \
  --validation-method DNS \
  --region us-east-1 \
  --tags Key=Name,Value=PublicCertDev Key=Env,Value=dev Key=Purpose,Value=ALB Key=Type,Value=Public \
  --query 'CertificateArn' \
  --output text)

echo "Development Certificate ARN: $DEV_CERT_ARN"

# Wait for validation records
sleep 5

# Get validation records
aws --profile dev acm describe-certificate \
  --certificate-arn $DEV_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.Name,ResourceRecord.Type,ResourceRecord.Value]' \
  --output table

# Note: If validation record already exists from production setup, dev certificate will validate automatically
# Otherwise, repeat Steps 3-6 for development certificate
```

### Step 8: Verify Certificates

Verify that certificates are issued and ready:

```bash
# List production certificates
aws --profile prod acm list-certificates --region us-east-1 \
  --query 'CertificateSummaryList[?Type==`AMAZON_ISSUED`]' --output table

# List development certificates (if applicable)
aws --profile dev acm list-certificates --region us-east-1 \
  --query 'CertificateSummaryList[?Type==`AMAZON_ISSUED`]' --output table
```

### Important Notes

- **Replace Placeholders**: Replace all placeholders in the commands:
  - `talorlik.com`: Your actual domain name
  - Profile names (`prod`, `dev`, `default`) should match your SSO profile names

- **Region Consistency**: Ensure all commands use the same region (e.g., `us-east-1`)

- **Certificate Validation**: Certificates will be automatically validated once DNS validation records are created in Route53

- **Certificate Status**: Wait for certificates to reach `ISSUED` status before using them with ALB

- **DNS Propagation**: DNS validation may take a few minutes to propagate

- **Reuse Validation Records**: If multiple certificates use the same domain, they may share the same validation record

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

- **Public ACM certificates** are requested in each deployment account (development, production)
- DNS validation records are created in Route53 hosted zone in the State Account
- Each deployment account has its own public ACM certificate
- Certificates are stored in their respective deployment accounts (not in the
State Account)
- This eliminates the need for cross-account certificate access
- Certificates are automatically renewed by ACM

**Deployment Account Certificate Requirements:**

- ACM certificate is queried from Deployment Account using `data.aws_acm_certificate`
(default provider)
- Certificate ARN is passed to ALB and Ingress resources via IngressClassParams
- Certificate must be in the **same account** as the EKS cluster and ALB
- Certificate must be in the **same region** as the ALB/EKS cluster
- Certificate must be validated and in `ISSUED` status
- Certificate is a **public ACM certificate** (Amazon-issued)
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

- ✅ Public ACM certificate is requested in the **Deployment Account**
- ✅ DNS validation records are created in Route53 hosted zone in the **State Account**
- ✅ Certificate exists in the **Deployment Account** (not State Account)
- ✅ Certificate is in the **same region** as the ALB/EKS cluster
- ✅ Certificate is **validated** and in `ISSUED` status
- ✅ Certificate is a **public ACM certificate** (Amazon-issued)
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
- `data.aws_acm_certificate.this` - Queries public ACM certificate from Deployment Account

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

### Configuration Checklist

- [x] Route53 hosted zone data source uses `aws.state_account` provider
- [x] ACM certificate data source uses default provider (deployment account)
- [x] All Route53 record resources use `aws.state_account` provider
- [x] State account role ARN is automatically injected by scripts
- [x] State account role has Route53 permissions
- [x] Public ACM certificates are requested in each deployment account
- [x] DNS validation records are created in Route53 hosted zone in State Account
- [x] Each deployment account has its own public ACM certificate
- [x] ALB can use ACM certificate from Deployment Account (same account and region)
- [x] Route53 records point to ALB in Deployment Account
- [x] Certificate ARN is passed correctly to ALB module
- [x] Certificate ARN is passed correctly to OpenLDAP module
- [x] No cross-account certificate access needed (each account uses its own certificate)

### Post-Setup Verification Checklist

After setting up certificates, verify:

- [ ] **Production certificate validated and ISSUED**
  ```bash
  aws --profile prod acm list-certificates --region us-east-1 \
    --query 'CertificateSummaryList[?Type==`AMAZON_ISSUED`]' --output table
  ```

- [ ] **Development certificate validated and ISSUED** (if applicable)
  ```bash
  aws --profile dev acm list-certificates --region us-east-1 \
    --query 'CertificateSummaryList[?Type==`AMAZON_ISSUED`]' --output table
  ```

- [ ] **DNS validation records exist in Route53**
  ```bash
  aws --profile default route53 list-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --query "ResourceRecordSets[?Type=='CNAME' && contains(Name, '_')]" --output table
  ```

- [ ] **ALB using new public certificate**
  ```bash
  # Get ALB ARN
  ALB_ARN=$(aws --profile prod elbv2 describe-load-balancers \
    --names talo-tf-us-east-1-alb-prod \
    --region us-east-1 \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

  # Check HTTPS listener certificate
  aws --profile prod elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --region us-east-1 \
    --query 'Listeners[?Protocol==`HTTPS`].[Certificates[0].CertificateArn,SslPolicy]' \
    --output table

  # Check via curl
  curl -vI https://phpldapadmin.talorlik.com 2>&1 | grep -E "issuer:|subject:"
  # Should show: issuer: Amazon
  ```

- [ ] **Browser shows secure connection** (manual check)
  - Visit: https://phpldapadmin.talorlik.com
  - Check: Lock icon shows "Secure"
  - Verify: Certificate details show Amazon as issuer
  - Verify: No security warnings

## Troubleshooting

### Issue: "Empty result" when querying Route53 hosted zone

**Solution:** Ensure `state_account_role_arn` is set and the role has
`route53:GetHostedZone` permission.

### Issue: "Empty result" when querying ACM certificate

**Solution:**

- Ensure deployment account credentials/role have `acm:ListCertificates` and
`acm:DescribeCertificate` permissions
- Verify certificate exists in the deployment account (not state account)
- Certificate should be a public ACM certificate requested in the Deployment Account
- Verify certificate is validated and in `ISSUED` status

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
   - If certificate doesn't exist in Deployment Account, request a public ACM certificate:

     ```bash
     # Request public certificate
     CERT_ARN=$(aws --profile <deployment-profile> acm request-certificate \
       --domain-name <your-domain> \
       --subject-alternative-names "*.<your-domain>" \
       --validation-method DNS \
       --region <region> \
       --query 'CertificateArn' \
       --output text)

     # Get validation records
     aws --profile <deployment-profile> acm describe-certificate \
       --certificate-arn $CERT_ARN \
       --region <region> \
       --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
       --output json
     ```

   - Create DNS validation record in Route53 hosted zone in State Account
   - Wait for certificate status to be `ISSUED`
   - Certificate will be stored in the Deployment Account (where the request is made)
   - **See the [Public ACM Certificate Setup and DNS Validation](#public-acm-certificate-setup-and-dns-validation) section above for complete setup instructions**

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
   - Certificate is a public ACM certificate (Amazon-issued)
   - Certificate is stored in Deployment Account (no cross-account access needed)
   - Each deployment account has its own public ACM certificate

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
- **"Certificate not found"**: Certificate doesn't exist or hasn't been requested yet

### Issue: Route53 records cannot be created

**Solution:** Ensure State Account role has `route53:ChangeResourceRecordSets`
permission on the hosted zone.

### Issue: Certificate Not Validating

**Check DNS record exists:**
```bash
aws --profile default route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Type=='CNAME' && contains(Name, '_')]" \
  --output json
```

**Check DNS propagation:**
```bash
# Get validation record name
VALIDATION_NAME=$(aws --profile prod acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
  --output text)

# Query DNS
dig $VALIDATION_NAME CNAME +short
```

**Solution:** Ensure DNS validation record exists in Route53 and has propagated (may take a few minutes).

### Issue: ALB Not Using New Certificate

**Check current ALB certificate:**
```bash
# Get ALB ARN
ALB_ARN=$(aws --profile prod elbv2 describe-load-balancers \
  --names talo-tf-us-east-1-alb-prod \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Check HTTPS listener certificate
aws --profile prod elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[?Protocol==`HTTPS`].[Certificates[0].CertificateArn,SslPolicy]' \
  --output table
```

**Solution:** Delete and recreate IngressClassParams:
```bash
kubectl delete ingressclassparams talo-tf-us-east-1-icp-alb-ldap-prod

# Re-run Terraform
./setup-application.sh
```

### Issue: Certificate in Wrong Account

**Verify certificate account from ARN:**
```bash
# Certificate ARN format: arn:aws:acm:region:ACCOUNT_ID:certificate/...
echo $PROD_CERT_ARN
# Account ID should match your deployment account ID
```

**Solution:** Ensure certificate is requested in the deployment account, not the state account.

### Issue: Cannot Delete Certificate (In Use)

**Check what's using the certificate:**
```bash
aws --profile prod acm describe-certificate \
  --certificate-arn <certificate-arn> \
  --region us-east-1 \
  --query 'Certificate.InUseBy' \
  --output table
```

**Solution:** Update ALB to use new certificate first, then delete old certificate.

## Quick Reference: Environment Variables

For scripting convenience, set these environment variables:

```bash
# Set profile aliases
export STATE_PROFILE="default"
export PROD_PROFILE="prod"
export DEV_PROFILE="dev"

# Set region
export AWS_REGION="us-east-1"

# Certificate ARNs (after creation)
export PROD_CERT_ARN="<production-certificate-arn>"
export DEV_CERT_ARN="<development-certificate-arn>"

# Route53 Zone ID
export ZONE_ID="<hosted-zone-id>"
```

Then use in commands:
```bash
aws --profile $PROD_PROFILE acm describe-certificate \
  --certificate-arn $PROD_CERT_ARN \
  --region $AWS_REGION
```

## Legacy: Private CA Setup (Deprecated)

> [!WARNING]
>
> **This section is deprecated.** The recommended approach is to use public ACM certificates
> with DNS validation as described in the [Public ACM Certificate Setup](#public-acm-certificate-setup-and-dns-validation)
> section above.

If you need to set up Private CA certificates (not recommended for public-facing applications),
follow these steps:

### Prerequisites

- AWS CLI configured with State Account credentials
- AWS RAM (Resource Access Manager) enabled for your organization
- `ca-config.json` file with CA configuration (see example below)
- Appropriate IAM permissions for ACM-PCA, RAM, and ACM operations

### Step 1: Enable Resource Sharing

Enable resource sharing within your organization (run this in the management account):

```bash
aws ram enable-sharing-with-aws-organization --region us-east-1
```

### Step 2: Create a CA Configuration File

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

### Step 3: Create the Root CA

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

### Step 4: Get Certificate Signing Request (CSR)

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

### Step 5: Issue the Root Certificate

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

### Step 6: Import the Certificate

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

### Step 7: Share Private CA via RAM

Create a resource share to make the Private CA available to your organization:

```bash
aws ram create-resource-share \
    --name "Private-CA-Share" \
    --resource-arns $CA_ARN \
    --principals "arn:aws:organizations::STATE_ACCOUNT_ID:organization/ORGANIZATION_ID" \
    --region us-east-1 \
    --tags key=Purpose,value=CentralCA key=Organization,value=YourOrg
```

### Step 8: Verify Resource Share

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

### Step 9: Verify RAM Service Access

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

### Step 10: Request Certificates in Deployment Accounts

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

### Step 11: Verify Certificate Authority

Check the Private CA details:

```bash
aws acm-pca describe-certificate-authority \
    --certificate-authority-arn $CA_ARN \
    --region us-east-1
```

### Step 12: Verify ACM Service-Linked Role

Check if the ACM service-linked role exists (usually auto-created):

```bash
# Check for ACM service-linked role
aws --profile <sso-profile> iam get-role --role-name AWSServiceRoleForCertificateManager

# If it doesn't exist, create it (optional - usually auto-created)
aws --profile <sso-profile> iam create-service-linked-role --aws-service-name acm.amazonaws.com
```

### Important Notes for Private CA

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

- **Browser Warnings**: Private CA certificates will show "Not secure" warnings in browsers
