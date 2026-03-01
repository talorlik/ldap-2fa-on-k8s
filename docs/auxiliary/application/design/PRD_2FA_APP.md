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

### 2FA Flow

- **First login**: User chooses TOTP or SMS. TOTP (not enrolled): QR code and secret
  for authenticator app. SMS: code sent to verified phone (enrollment completes
  on verify). No MFA method is pre-entered by the seed; admin chooses at first login.
- **Profile**: User can enroll additional methods (TOTP or SMS) after logging in.
- **Consecutive logins**: User chooses which enrolled method to use (TOTP or SMS).
- **SMS prerequisite**: Phone must be verified; SMS available when phone is verified
  (no prior SMS enrollment required for first-time use).

## Functional Requirements

### REQ-1: Application Architecture

| ID | Requirement |
| ---- | ------------- |
| REQ-1.1 | Application must use single domain pattern (frontend and backend on same domain) |
| REQ-1.2 | Frontend must be accessible at root path (`/`) |
| REQ-1.3 | Backend API must be accessible at `/api/*` path |
| REQ-1.4 | Application must not require CORS configuration (same origin) |
| REQ-1.5 | Application must use shared ALB via IngressGroup |

## Backend Requirements

### Functional Requirements

| ID | Requirement |
| ---- | ------------- |
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
| ---- | ------------- |
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
| -------- | ---------- | ------------- |
| `GET` | `/api/healthz` | Liveness/readiness probe (includes SMS status) |
| `GET` | `/api/app-config` | Application-level state only: `{ isActive, mode }`. `isActive` is true when APP_ACTIVE and DB, Redis, LDAP are reachable. Frontend uses on load to enable/disable login form. User active/disabled is separate (profile status). |
| `GET` | `/api/mfa/methods` | List available MFA methods (TOTP, SMS if enabled) |
| `GET` | `/api/mfa/status/{username}` | Get user's MFA enrollment status |
| `POST` | `/api/auth/login/start` | Step 1: Validate username/password; optional `remember_me`; returns challenge_token, totp_enrolled, sms_available, sms_enrolled |
| `POST` | `/api/auth/login/totp-setup` | Generate TOTP secret for first-time Authenticator setup (body: challenge_token) |
| `POST` | `/api/auth/login/verify` | Step 2: Verify MFA code (TOTP or SMS) and return JWT (expiry extended if remember_me was set) |
| `POST` | `/api/auth/sms/send-code` | Send SMS code (challenge_token or username+password); requires verified phone (enroll or use) |
| `POST` | `/api/auth/forgot-password` | Request password reset link by email (body: email); generic response for security |
| `POST` | `/api/auth/reset-password` | Set new password with token from email link (body: token, username, new_password, confirm_password) |
| `POST` | `/api/auth/enroll` | Re-enroll or change MFA method (active users only) |
| `POST` | `/api/auth/login` | Legacy one-step login (username + password + verification_code) |

#### API Documentation Endpoints

FastAPI automatically generates interactive API documentation that is always available:

| Method | Endpoint | Description |
| -------- | ---------- | ------------- |
| `GET` | `/api/docs` | Swagger UI - Interactive API documentation and testing interface |
| `GET` | `/api/redoc` | ReDoc UI - Alternative API documentation interface |
| `GET` | `/api/openapi.json` | OpenAPI schema in JSON format |

The Swagger UI provides an interactive interface to explore all available endpoints,
view request/response schemas, and test API calls directly from the browser.
The documentation automatically updates when API endpoints change.

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

#### Login Start Request (Step 1)

```json
{
  "username": "string",
  "password": "string",
  "remember_me": false
}
```

When `remember_me` is true, the JWT returned after login/verify uses a longer expiry
(e.g. 7 days) instead of the default session expiry.

#### Login Start Response

```json
{
  "challenge_token": "string",
  "totp_enrolled": true,
  "sms_available": true,
  "sms_enrolled": true
}
```

- `totp_enrolled`: Whether user has Authenticator app set up
- `sms_available`: Whether SMS option is available (verified phone; can enroll
  or use)
- `sms_enrolled`: Whether user has SMS as an enrolled method

#### Login Verify Request (Step 2)

```json
{
  "challenge_token": "string",
  "mfa_method": "totp | sms",
  "verification_code": "123456"
}
```

#### Send SMS Code Request (with challenge token from login/start)

```json
{
  "challenge_token": "string"
}
```

#### Forgot Password Request

```json
{
  "email": "user@example.com"
}
```

Response is always a generic success message (no email enumeration).

#### Reset Password Request

```json
{
  "token": "uuid-from-email-link",
  "username": "string",
  "new_password": "string",
  "confirm_password": "string"
}
```

#### Legacy Login Request (one-step)

```json
{
  "username": "string",
  "password": "string",
  "verification_code": "123456"
}
```

### Configuration Requirements

| Config Item | Source | Description |
| ------------- | -------- | ------------- |
| LDAP service DNS | Environment/ConfigMap | Internal Kubernetes service DNS name |
| LDAP base DN | Environment/ConfigMap | Base distinguished name for LDAP operations |
| LDAP admin credentials | Secret | Bind DN and password for LDAP queries |
| MFA settings | Environment/ConfigMap | TOTP issuer name, algorithm settings |

#### SMS Configuration Requirements

| Config Item | Source | Description |
| ------------- | -------- | ------------- |
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
| ---- | ------------- |
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
| ---- | ------------- |
| FE-01 | Display two-step login: (1) username/password; (2) MFA screen with Authenticator app or SMS choice and verification code; TOTP setup (QR) when not enrolled; SMS enrollment when phone verified; user may choose any enrolled method on consecutive logins |
| FE-02 | Display login flow: step 1 username/password → step 2 MFA method + verification code → success/failure |
| FE-03 | Render QR code from backend-provided `otpauth://` URI (TOTP) |
| FE-04 | Handle and display error messages from backend |
| FE-05 | Allow user to select MFA method (TOTP or SMS) during first-time enrollment; support multiple methods; user chooses which to use at each login |
| FE-06 | Show/hide SMS option based on backend configuration |

### SMS-Specific Frontend Requirements

| ID | Requirement |
| ---- | ------------- |
| FE-SMS-01 | Display phone number input field for SMS enrollment |
| FE-SMS-02 | Validate phone number format (E.164) on client side |
| FE-SMS-03 | Show "Send SMS Code" button on MFA step when user selects SMS |
| FE-SMS-04 | Display countdown timer after sending SMS code |
| FE-SMS-05 | Auto-detect user's MFA method and show appropriate UI |
| FE-SMS-06 | Display masked phone number for SMS-enrolled users |

### Technical Requirements

| ID | Requirement |
| ---- | ------------- |
| FE-T01 | Static HTML/CSS/JavaScript (no server-side rendering) |
| FE-T02 | Call backend using relative URLs (`fetch("/api/...")`) |
| FE-T03 | Served via nginx in container |
| FE-T04 | Expose container port 8080 (runs as non-root user, cannot bind to port 80) |

## Infrastructure Requirements

### REQ-2: GitOps Deployment

| ID | Requirement |
| ---- | ------------- |
| REQ-2.1 | Backend and frontend must be deployable via ArgoCD Applications |
| REQ-2.2 | ArgoCD Applications must support automated sync |
| REQ-2.3 | ArgoCD Applications must support self-healing |
| REQ-2.4 | ArgoCD Applications must support resource pruning |

### REQ-3: CI/CD Pipeline

| ID | Requirement |
| ---- | ------------- |
| REQ-3.1 | Backend code changes must trigger automated build and deployment |
| REQ-3.2 | Frontend code changes must trigger automated build and deployment |
| REQ-3.3 | Docker images must be built and pushed to ECR |
| REQ-3.4 | Image tags must use commit SHA for versioning |
| REQ-3.5 | Helm chart values must be automatically updated with new image tags |

### DNS (Route53)

| Requirement |
| ------------- |
| Create one A/ALIAS record: `app.<domain>` → existing ALB |
| Use existing hosted zone |
| No separate `api.<domain>` record needed |

### Ingress Configuration

Both Ingresses share the existing ALB by using the same `IngressClass`, which
references `IngressClassParams` containing the shared `group.name`.

#### Backend Ingress

| Setting | Value |
| --------- | ------- |
| IngressClassName | `${ingressclass_alb_name}` (existing) |
| Host | `app.<domain>` |
| Path | `/api` |
| Path Type | `Prefix` |
| Target Service | Backend ClusterIP service |

#### Frontend Ingress

| Setting | Value |
| --------- | ------- |
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
| --------- | ------------- |
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
| ------------ | ---------- | ------------- |
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
| ------------- |
| Create SNS topic for SMS notifications |
| Configure topic policy to allow IAM role to publish |
| Set display name for SMS sender identification |

#### IAM Role for IRSA (IAM Roles for Service Accounts)

| Requirement |
| ------------- |
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
| ---------- | --------- | --------- |
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
| ---------- | ------------- |
| `aws_sns_topic` | SNS topic for SMS |
| `aws_sns_topic_policy` | Topic policy for IAM role access |
| `aws_iam_role` | IAM role for IRSA |
| `aws_iam_role_policy` | SNS publish/subscribe permissions |
| `aws_sns_sms_preferences` | Account-level SMS settings (optional) |

#### Module Inputs

| Variable | Description | Default |
| ---------- | ------------- | --------- |
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
| -------- | ------------- |
| `sns_topic_arn` | SNS topic ARN |
| `iam_role_arn` | IAM role ARN for IRSA |
| `service_account_annotation` | Annotation for K8s service account |

## Security Requirements

| ID | Requirement |
| ---- | ------------- |
| SEC-01 | LDAP server must remain internal-only (ClusterIP, no public Ingress) |
| SEC-02 | Backend communicates with LDAP via internal Kubernetes DNS only |
| SEC-03 | TLS termination at ALB for all public traffic |
| SEC-04 | LDAP credentials stored in Kubernetes Secrets |
| SEC-05 | TOTP secrets must be securely generated and transmitted |

### SMS Security Requirements

| ID | Requirement |
| ---- | ------------- |
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
| ---- | ----------- |
| AC-01 | `https://app.<domain>` loads the frontend UI |
| AC-02 | Enrollment flow displays a TOTP QR code scannable by Google Authenticator |
| AC-03 | Login succeeds only with correct LDAP password AND correct TOTP code |
| AC-04 | `curl -X POST https://app.<domain>/api/auth/login ...` works from outside the cluster |
| AC-05 | LDAP server is not accessible from outside the cluster |
| AC-06 | ArgoCD shows two healthy Applications |
| AC-07 | Code changes trigger automatic deployment via ArgoCD sync |

### SMS Acceptance Criteria

| ID | Criterion |
| ---- | ----------- |
| AC-SMS-01 | `/api/mfa/methods` returns `["totp", "sms"]` when SMS is enabled |
| AC-SMS-02 | User can enroll with SMS by providing phone number |
| AC-SMS-03 | SMS verification code is received on enrolled phone |
| AC-SMS-04 | Login succeeds with correct LDAP password AND correct SMS code |
| AC-SMS-05 | Expired SMS codes are rejected |
| AC-SMS-06 | Invalid phone numbers are rejected during enrollment |
| AC-SMS-07 | SMS send button shows countdown timer |
| AC-SMS-08 | Backend uses VPC endpoint for SNS (no NAT gateway traffic) |

## Dependencies

### REQ-4: Infrastructure Prerequisites

| ID | Requirement |
| ---- | ------------- |
| REQ-4.1 | EKS cluster with Auto Mode must be deployed |
| REQ-4.2 | EKS cluster must have OIDC provider enabled for IRSA |
| REQ-4.3 | ALB must be configured via IngressClass/IngressClassParams |
| REQ-4.4 | OpenLDAP stack must be deployed |
| REQ-4.5 | Route53 hosted zone must be configured |
| REQ-4.6 | ACM certificate must be provisioned and validated |
| REQ-4.7 | ArgoCD EKS Capability must be deployed |
| REQ-4.8 | ECR repository must exist for container images |

### REQ-5: SMS-Specific Prerequisites

| ID | Requirement |
| ---- | ------------- |
| REQ-5.1 | VPC endpoint for STS must be enabled |
| REQ-5.2 | VPC endpoint for SNS must be enabled |
| REQ-5.3 | SNS Terraform module must be deployed |
| REQ-5.4 | IAM role ARN must be configured for backend service account |

### REQ-6: GitHub Repository Variables Prerequisites

| ID | Requirement |
| ---- | ------------- |
| REQ-6.1 | `BACKEND_BUCKET_NAME` repository variable must be configured (S3 bucket name for Terraform state storage) |
| REQ-6.2 | `APPLICATION_PREFIX` repository variable must be configured (value: `application_state/terraform.tfstate`) |
| REQ-6.3 | Repository variables must be accessible to GitHub Actions workflows and local deployment scripts |
| REQ-6.4 | State file key must use `APPLICATION_PREFIX` to ensure isolation from infrastructure state |
