# 2FA Application - Product Requirements Document

## Overview

This document defines the requirements for a two-factor authentication (2FA) GUI
application consisting of a Python backend API and a static HTML/JS/CSS frontend,
integrated with the existing LDAP infrastructure.

The application supports **two MFA methods**:

1. **TOTP (Time-based One-Time Password)** - Using authenticator apps like Google
   Authenticator, Authy, etc.
2. **SMS** - Verification codes sent via AWS SNS to the user's phone number

**Repository**: [https://github.com/talorlik/ldap-2fa-on-k8s](https://github.com/talorlik/ldap-2fa-on-k8s)

## Architecture Decisions

### Routing Pattern (Pattern B - Single Domain)

| Decision | Value |
|----------|-------|
| Public hostname | `app.<domain>` (e.g., `app.talo-ldap.com`) |
| Frontend path | `/` |
| Backend API path | `/api/*` |
| DNS records needed | One A/ALIAS record |
| Ingress resources | Two (one per application) |
| CORS handling | Not required (same origin) |

### MFA Method Selection

| Method | Use Case | Infrastructure |
|--------|----------|----------------|
| TOTP | Primary method, no network dependency | None (code generated locally) |
| SMS | Alternative method, requires phone | AWS SNS, VPC endpoints |

### Traffic Flow

```text
Internet (Browser / CLI)
       │
       │  https://app.<domain>/
       │  https://app.<domain>/api/...
       ▼
 Existing ALB (shared via group.name)
       │
       ├── Path: /api/*  → Backend Ingress  → Backend Service  → Backend Pods
       │                                                              │
       │                                            ┌─────────────────┼─────────────────┐
       │                                            │                 │                 │
       │                                            ▼                 ▼                 ▼
       │                                      LDAP (ClusterIP)   SNS (VPC Endpoint)  STS (IRSA)
       │
       └── Path: /*      → Frontend Ingress → Frontend Service → Frontend Pods
```

## Directory Structure

```text
ldap-2fa-on-k8s/
└── application/
    ├── modules/
    │   └── sns/                         # Terraform module for SNS
    │       ├── main.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       └── README.md
    ├── backend/
    │   ├── src/
    │   │   ├── app/
    │   │   │   ├── main.py
    │   │   │   ├── api/
    │   │   │   │   ├── __init__.py
    │   │   │   │   └── routes.py
    │   │   │   ├── ldap/
    │   │   │   │   ├── __init__.py
    │   │   │   │   └── client.py
    │   │   │   ├── mfa/
    │   │   │   │   ├── __init__.py
    │   │   │   │   └── totp.py
    │   │   │   ├── sms/                 # SMS module for SNS
    │   │   │   │   ├── __init__.py
    │   │   │   │   └── client.py
    │   │   │   └── config.py
    │   │   └── requirements.txt
    │   ├── helm/
    │   │   └── ldap-2fa-backend/
    │   │       ├── Chart.yaml
    │   │       ├── values.yaml
    │   │       └── templates/
    │   │           ├── deployment.yaml
    │   │           ├── service.yaml
    │   │           ├── ingress.yaml
    │   │           ├── configmap.yaml
    │   │           ├── secret.yaml
    │   │           └── serviceaccount.yaml  # For IRSA
    │   └── Dockerfile
    │
    └── frontend/
        ├── src/
        │   ├── index.html
        │   ├── css/
        │   │   └── styles.css
        │   └── js/
        │       ├── api.js
        │       └── main.js
        ├── helm/
        │   └── ldap-2fa-frontend/
        │       ├── Chart.yaml
        │       ├── values.yaml
        │       └── templates/
        │           ├── deployment.yaml
        │           ├── service.yaml
        │           └── ingress.yaml
        └── Dockerfile
```

## Backend Requirements

### Functional Requirements

| ID | Requirement |
|----|-------------|
| BE-01 | Authenticate users against LDAP (bind operation) |
| BE-02 | Generate TOTP secrets for MFA enrollment |
| BE-03 | Return `otpauth://` URI for QR code generation |
| BE-04 | Verify TOTP codes during login |
| BE-05 | Provide clear success/failure responses for UI and CLI |
| BE-06 | Support multiple MFA methods (TOTP and SMS) |
| BE-07 | Allow user to select MFA method during enrollment |
| BE-08 | Store user's MFA method preference |

### SMS-Specific Functional Requirements

| ID | Requirement |
|----|-------------|
| SMS-01 | Validate phone numbers in E.164 format (e.g., `+14155552671`) |
| SMS-02 | Generate random 6-digit verification codes |
| SMS-03 | Send verification codes via AWS SNS |
| SMS-04 | Implement code expiration (default: 5 minutes) |
| SMS-05 | Support phone number subscription to SNS topic (optional) |
| SMS-06 | Handle SMS delivery failures gracefully |
| SMS-07 | Check and handle phone number opt-out status |

### API Endpoints

All endpoints must be served under the `/api` prefix (no path rewriting).

#### Core Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/healthz` | Liveness/readiness probe (includes SMS status) |
| `GET` | `/api/mfa/methods` | List available MFA methods (TOTP, SMS if enabled) |
| `GET` | `/api/mfa/status/{username}` | Get user's MFA enrollment status |
| `POST` | `/api/auth/enroll` | Enroll user for MFA (TOTP or SMS) |
| `POST` | `/api/auth/login` | Validate LDAP credentials + verification code |

#### SMS-Specific Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/sms/send-code` | Send SMS verification code to enrolled user |

#### API Documentation Endpoints

FastAPI automatically generates interactive API documentation that is always available:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/docs` | Swagger UI - Interactive API documentation and testing interface |
| `GET` | `/api/redoc` | ReDoc UI - Alternative API documentation interface |
| `GET` | `/api/openapi.json` | OpenAPI schema in JSON format |

The Swagger UI provides an interactive interface to explore all available endpoints, view request/response schemas, and test API calls directly from the browser. The documentation automatically updates when API endpoints change.

### API Request/Response Schemas

#### Enroll Request

```json
{
  "username": "string",
  "password": "string",
  "mfa_method": "totp | sms",
  "phone_number": "+14155552671"  // Required if mfa_method is "sms"
}
```

#### Enroll Response (TOTP)

```json
{
  "success": true,
  "message": "MFA enrollment successful",
  "mfa_method": "totp",
  "otpauth_uri": "otpauth://totp/...",
  "secret": "BASE32SECRET"
}
```

#### Enroll Response (SMS)

```json
{
  "success": true,
  "message": "MFA enrollment successful",
  "mfa_method": "sms",
  "phone_number": "****2671"  // Masked
}
```

#### Login Request

```json
{
  "username": "string",
  "password": "string",
  "verification_code": "123456"
}
```

#### Send SMS Code Request

```json
{
  "username": "string",
  "password": "string"
}
```

### Configuration Requirements

| Config Item | Source | Description |
|-------------|--------|-------------|
| LDAP service DNS | Environment/ConfigMap | Internal Kubernetes service DNS name |
| LDAP base DN | Environment/ConfigMap | Base distinguished name for LDAP operations |
| LDAP admin credentials | Secret | Bind DN and password for LDAP queries |
| MFA settings | Environment/ConfigMap | TOTP issuer name, algorithm settings |

#### SMS Configuration Requirements

| Config Item | Source | Description |
|-------------|--------|-------------|
| `ENABLE_SMS_2FA` | Environment/ConfigMap | Enable/disable SMS MFA method |
| `AWS_REGION` | Environment/ConfigMap | AWS region for SNS |
| `SNS_TOPIC_ARN` | Environment/ConfigMap | SNS topic ARN (optional, for subscriptions) |
| `SMS_SENDER_ID` | Environment/ConfigMap | SMS sender ID (max 11 chars) |
| `SMS_TYPE` | Environment/ConfigMap | `Transactional` or `Promotional` |
| `SMS_CODE_LENGTH` | Environment/ConfigMap | Verification code length (default: 6) |
| `SMS_CODE_EXPIRY_SECONDS` | Environment/ConfigMap | Code expiration time (default: 300) |
| `SMS_MESSAGE_TEMPLATE` | Environment/ConfigMap | Message template with `{code}` placeholder |

### Technical Requirements

| ID | Requirement |
|----|-------------|
| BE-T01 | Built with Python (FastAPI recommended) |
| BE-T02 | Run with production server (uvicorn/gunicorn) |
| BE-T03 | Expose container port 8000 |
| BE-T04 | Communicate with LDAP via ClusterIP service (internal only) |
| BE-T05 | Use boto3 for AWS SNS integration |
| BE-T06 | Use IRSA (IAM Roles for Service Accounts) for SNS access |
| BE-T07 | Communicate with SNS via VPC endpoint (private connectivity) |

## Frontend Requirements

### Functional Requirements

| ID | Requirement |
|----|-------------|
| FE-01 | Display enrollment flow: username/password → MFA method selection → setup |
| FE-02 | Display login flow: username/password + verification code → success/failure |
| FE-03 | Render QR code from backend-provided `otpauth://` URI (TOTP) |
| FE-04 | Handle and display error messages from backend |
| FE-05 | Allow user to select MFA method (TOTP or SMS) during enrollment |
| FE-06 | Show/hide SMS option based on backend configuration |

### SMS-Specific Frontend Requirements

| ID | Requirement |
|----|-------------|
| FE-SMS-01 | Display phone number input field for SMS enrollment |
| FE-SMS-02 | Validate phone number format (E.164) on client side |
| FE-SMS-03 | Show "Send SMS Code" button on login for SMS-enrolled users |
| FE-SMS-04 | Display countdown timer after sending SMS code |
| FE-SMS-05 | Auto-detect user's MFA method and show appropriate UI |
| FE-SMS-06 | Display masked phone number for SMS-enrolled users |

### Technical Requirements

| ID | Requirement |
|----|-------------|
| FE-T01 | Static HTML/CSS/JavaScript (no server-side rendering) |
| FE-T02 | Call backend using relative URLs (`fetch("/api/...")`) |
| FE-T03 | Served via nginx in container |
| FE-T04 | Expose container port 80 |

## Infrastructure Requirements

### DNS (Route53)

| Requirement |
|-------------|
| Create one A/ALIAS record: `app.<domain>` → existing ALB |
| Use existing hosted zone |
| No separate `api.<domain>` record needed |

### Ingress Configuration

Both Ingresses share the existing ALB by using the same `IngressClass`, which
references `IngressClassParams` containing the shared `group.name`.

#### Backend Ingress

| Setting | Value |
|---------|-------|
| IngressClassName | `${ingressclass_alb_name}` (existing) |
| Host | `app.<domain>` |
| Path | `/api` |
| Path Type | `Prefix` |
| Target Service | Backend ClusterIP service |

#### Frontend Ingress

| Setting | Value |
|---------|-------|
| IngressClassName | `${ingressclass_alb_name}` (existing) |
| Host | `app.<domain>` |
| Path | `/` |
| Path Type | `Prefix` |
| Target Service | Frontend ClusterIP service |

### ALB Configuration

#### Cluster-Wide Settings (IngressClassParams)

These settings are configured once at the cluster level via the existing
`IngressClassParams` resource and inherited by all Ingresses:

| Setting | Description |
|---------|-------------|
| `scheme` | `internet-facing` |
| `ipAddressType` | `ipv4` |
| `group.name` | ALB group name (groups multiple Ingresses to single ALB) |
| `certificateARNs` | ACM certificate ARN for TLS termination |

#### Per-Ingress Annotations

Each Ingress specifies only per-Ingress settings via annotations:

```yaml
alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
alb.ingress.kubernetes.io/target-type: "${app_alb_target_type}"
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
alb.ingress.kubernetes.io/ssl-redirect: "${app_alb_ssl_redirect}"
```

| Annotation | Variable | Description |
|------------|----------|-------------|
| `load-balancer-name` | `${alb_load_balancer_name}` | Shared ALB name (same as OpenLDAP) |
| `target-type` | `${app_alb_target_type}` | Target type (default: `ip`) |
| `listen-ports` | — | HTTPS 443 only |
| `ssl-redirect` | `${app_alb_ssl_redirect}` | Redirect port (default: `443`) |

> [!NOTE]
>
> `group.name`, `scheme`, and `certificate-arn` are NOT specified in
> Ingress annotations—they are inherited from `IngressClassParams`.

### SMS Infrastructure Requirements (AWS SNS)

#### SNS Topic

| Requirement |
|-------------|
| Create SNS topic for SMS notifications |
| Configure topic policy to allow IAM role to publish |
| Set display name for SMS sender identification |

#### IAM Role for IRSA (IAM Roles for Service Accounts)

| Requirement |
|-------------|
| Create IAM role with trust policy for EKS OIDC provider |
| Scope trust to specific service account and namespace |
| Attach policy with SNS publish permissions |

#### IAM Policy Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["sns:Publish"],
      "Resource": "<SNS_TOPIC_ARN>"
    },
    {
      "Effect": "Allow",
      "Action": ["sns:Publish"],
      "Resource": "*",
      "Condition": {
        "StringEquals": { "sns:Protocol": "sms" }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic"
      ],
      "Resource": "<SNS_TOPIC_ARN>"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:CheckIfPhoneNumberIsOptedOut",
        "sns:OptInPhoneNumber"
      ],
      "Resource": "*"
    }
  ]
}
```

#### VPC Endpoints (Required for Private Connectivity)

| Endpoint | Service | Purpose |
|----------|---------|---------|
| STS | `com.amazonaws.<region>.sts` | IRSA - pods assume IAM roles |
| SNS | `com.amazonaws.<region>.sns` | Send SMS without NAT gateway |

#### Service Account Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ldap-2fa-backend
  namespace: 2fa-app
  annotations:
    eks.amazonaws.com/role-arn: <IAM_ROLE_ARN>
```

### Terraform Module: SNS

The SNS Terraform module (`application/modules/sns/`) creates:

| Resource | Description |
|----------|-------------|
| `aws_sns_topic` | SNS topic for SMS |
| `aws_sns_topic_policy` | Topic policy for IAM role access |
| `aws_iam_role` | IAM role for IRSA |
| `aws_iam_role_policy` | SNS publish/subscribe permissions |
| `aws_sns_sms_preferences` | Account-level SMS settings (optional) |

#### Module Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_sms_2fa` | Enable SMS 2FA resources | `false` |
| `sns_topic_name` | SNS topic name component | `2fa-sms` |
| `sns_display_name` | SMS sender display name | `2FA Verification` |
| `service_account_namespace` | K8s namespace | `2fa-app` |
| `service_account_name` | K8s service account | `ldap-2fa-backend` |
| `sms_sender_id` | SMS sender ID | `2FA` |
| `sms_type` | SMS type | `Transactional` |
| `sms_monthly_spend_limit` | Monthly SMS budget | `10` |

#### Module Outputs

| Output | Description |
|--------|-------------|
| `sns_topic_arn` | SNS topic ARN |
| `iam_role_arn` | IAM role ARN for IRSA |
| `service_account_annotation` | Annotation for K8s service account |

## GitOps Requirements (ArgoCD)

### ArgoCD Applications

| Application | Helm Chart Path | Namespace |
|-------------|-----------------|-----------|
| `ldap-2fa-backend` | `application/backend/helm/ldap-2fa-backend` | `2fa-app` |
| `ldap-2fa-frontend` | `application/frontend/helm/ldap-2fa-frontend` | `2fa-app` |

### Sync Configuration

| Setting | Value |
|---------|-------|
| Automated sync | Enabled |
| Self-heal | Enabled |
| Prune | Enabled |

### Helm Values for SMS

The backend Helm chart must support these SMS-related values:

```yaml
sms:
  enabled: true
  awsRegion: "us-east-1"
  snsTopicArn: ""
  senderId: "2FA"
  smsType: "Transactional"
  codeLength: 6
  codeExpirySeconds: 300
  messageTemplate: "Your verification code is: {code}. It expires in 5 minutes."

serviceAccountIAM:
  roleArn: ""  # From Terraform output
```

## CI/CD Requirements (GitHub Actions)

### Backend Workflow

| Trigger | `application/backend/**` changes |
|---------|----------------------------------|
| Steps | 1. Build Docker image |
|       | 2. Tag with commit SHA |
|       | 3. Push to ECR |
|       | 4. Update `values.yaml` with new image tag |
|       | 5. Commit and push changes |

### Frontend Workflow

| Trigger | `application/frontend/**` changes |
|---------|-----------------------------------|
| Steps | Same pattern as backend |

## Security Requirements

| ID | Requirement |
|----|-------------|
| SEC-01 | LDAP server must remain internal-only (ClusterIP, no public Ingress) |
| SEC-02 | Backend communicates with LDAP via internal Kubernetes DNS only |
| SEC-03 | TLS termination at ALB for all public traffic |
| SEC-04 | LDAP credentials stored in Kubernetes Secrets |
| SEC-05 | TOTP secrets must be securely generated and transmitted |

### SMS Security Requirements

| ID | Requirement |
|----|-------------|
| SEC-SMS-01 | Phone numbers must be validated (E.164 format) |
| SEC-SMS-02 | SMS codes must expire after configurable timeout |
| SEC-SMS-03 | Use constant-time comparison for code verification |
| SEC-SMS-04 | Implement rate limiting for SMS send requests |
| SEC-SMS-05 | Backend must use IRSA (no hardcoded AWS credentials) |
| SEC-SMS-06 | SNS access must go through VPC endpoint (no public internet) |
| SEC-SMS-07 | IAM role must be scoped to specific service account |
| SEC-SMS-08 | Mask phone numbers in API responses and logs |

## Acceptance Criteria

### Core Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-01 | `https://app.<domain>` loads the frontend UI |
| AC-02 | Enrollment flow displays a TOTP QR code scannable by Google Authenticator |
| AC-03 | Login succeeds only with correct LDAP password AND correct TOTP code |
| AC-04 | `curl -X POST https://app.<domain>/api/auth/login ...` works from outside the cluster |
| AC-05 | LDAP server is not accessible from outside the cluster |
| AC-06 | ArgoCD shows two healthy Applications |
| AC-07 | Code changes trigger automatic deployment via ArgoCD sync |

### SMS Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-SMS-01 | `/api/mfa/methods` returns `["totp", "sms"]` when SMS is enabled |
| AC-SMS-02 | User can enroll with SMS by providing phone number |
| AC-SMS-03 | SMS verification code is received on enrolled phone |
| AC-SMS-04 | Login succeeds with correct LDAP password AND correct SMS code |
| AC-SMS-05 | Expired SMS codes are rejected |
| AC-SMS-06 | Invalid phone numbers are rejected during enrollment |
| AC-SMS-07 | SMS send button shows countdown timer |
| AC-SMS-08 | Backend uses VPC endpoint for SNS (no NAT gateway traffic) |

## Dependencies

### Existing Infrastructure (Prerequisites)

- EKS cluster with Auto Mode enabled
- EKS cluster with OIDC provider enabled (`enable_irsa = true`)
- ALB via IngressClass/IngressClassParams
- OpenLDAP stack-ha deployed
- Route53 hosted zone configured
- ACM certificate provisioned and validated
- ArgoCD EKS Capability module deployed
- ArgoCD Application module configured
- ECR repository (created in `backend_infra`) for all images, distinguished by tags

### SMS-Specific Prerequisites

- VPC endpoint for STS (`enable_sts_endpoint = true` in `backend_infra`)
- VPC endpoint for SNS (`enable_sns_endpoint = true` in `backend_infra`)
- SNS Terraform module deployed (`enable_sms_2fa = true` in `application`)
- IAM role ARN configured in Helm values (`serviceAccountIAM.roleArn`)

## Implementation Checklist

### Core Implementation

- [ ] Create backend directory structure
- [ ] Implement backend Python API with `/api/*` endpoints
- [ ] Create backend Dockerfile
- [ ] Create backend Helm chart with Ingress (`/api`, order 10)
- [ ] Create frontend directory structure
- [ ] Implement frontend HTML/JS/CSS
- [ ] Create frontend Dockerfile
- [ ] Create frontend Helm chart with Ingress (`/`, order 20)
- [ ] Create Route53 A/ALIAS record for `app.<domain>`
- [ ] Configure ArgoCD Application for backend
- [ ] Configure ArgoCD Application for frontend
- [ ] Create GitHub Actions workflow for backend CI/CD
- [ ] Create GitHub Actions workflow for frontend CI/CD
- [ ] Verify end-to-end enrollment flow (TOTP)
- [ ] Verify end-to-end login flow (TOTP)
- [ ] Verify CLI access via API endpoint

### SMS Implementation

- [ ] Create SNS Terraform module (`application/modules/sns/`)
- [ ] Add SMS variables to `application/variables.tf`
- [ ] Add SNS module invocation to `application/main.tf`
- [ ] Enable STS VPC endpoint in `backend_infra`
- [ ] Enable SNS VPC endpoint in `backend_infra`
- [ ] Enable IRSA on EKS cluster (`enable_irsa = true`)
- [ ] Create backend SMS client (`app/sms/client.py`)
- [ ] Add SMS configuration to backend `config.py`
- [ ] Update backend API routes for SMS support
- [ ] Add boto3 to backend `requirements.txt`
- [ ] Update backend Helm chart with SMS configuration
- [ ] Add IRSA annotation to service account template
- [ ] Update frontend with MFA method selection UI
- [ ] Update frontend with SMS phone input
- [ ] Update frontend with "Send SMS Code" button
- [ ] Create Kubernetes secret for LDAP password
- [ ] Configure Helm values with IAM role ARN
- [ ] Verify end-to-end SMS enrollment flow
- [ ] Verify end-to-end SMS login flow
- [ ] Verify SMS code expiration
- [ ] Verify VPC endpoint usage (no NAT traffic)
