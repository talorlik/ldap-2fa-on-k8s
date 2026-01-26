# Application Deployment

This Terraform configuration deploys the 2FA application components, including
the backend and frontend applications, PostgreSQL database, Redis cache, AWS SES
for email verification, AWS SNS for SMS 2FA, and ArgoCD Applications for GitOps
deployments.

## Overview

The application deployment provisions:

- **PostgreSQL** (Bitnami Helm chart) for user registration and verification
token storage
- **Redis** for SMS OTP code storage with TTL-based expiration
- **AWS SES** for email verification and notifications (configured for backend
service account)
- **AWS SNS** for SMS-based 2FA verification (configured for backend service account)
- **ArgoCD Applications** for deploying backend and frontend via GitOps
- **Route53 Record** for the 2FA application (app.{domain_name})

> [!IMPORTANT]
>
> **Deployment Order**: The `application_infra/` directory must be deployed first
> before deploying the application. The application depends on infrastructure
> components including:
>
> - StorageClass (for PostgreSQL and Redis persistent storage)
> - ArgoCD Capability (for ArgoCD Applications) - **Must be ACTIVE before deploying
> applications**
> - ALB DNS name (for Route53 record)
>
> **ArgoCD Capability Status Validation**: The application deployment scripts and
> workflows automatically validate that the ArgoCD capability status is "ACTIVE"
> before proceeding. If the capability is not ACTIVE, deployment will fail with
> a clear error message. This ensures that ArgoCD Applications can be properly
> deployed and managed.

## Architecture

The application components integrate with infrastructure deployed by `application_infra/`:

```ascii
┌───────────────────────────────────────────────────────────────────┐
│                         EKS Cluster                               │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   2FA App Namespace                         │  │
│  │                                                             │  │
│  │  ┌──────────────────┐      ┌──────────────────┐             │  │
│  │  │ Backend          │      │ Frontend         │             │  │
│  │  │ (FastAPI)        │      │ (nginx)          │             │  │
│  │  │                  │      │                  │             │  │
│  │  │ Ingress /api/*   │      │ Ingress /*       │             │  │
│  │  └────────┬─────────┘      └──────────────────┘             │  │
│  │           │                                                 │  │
│  │           │ LDAP Auth / User Data                           │  │
│  │           ▼                                                 │  │
│  │  ┌──────────────────┐      ┌──────────────────┐             │  │
│  │  │ LDAP Service     │      │ PostgreSQL       │             │  │
│  │  │ (from infra)     │      │ (User Data)      │             │  │
│  │  └──────────────────┘      └──────────────────┘             │  │
│  │                                                             │  │
│  │  ┌──────────────────┐      ┌──────────────────┐             │  │
│  │  │ Redis            │      │ SNS/SES          │             │  │
│  │  │ (SMS OTP Cache)  │      │ (via IRSA)       │             │  │
│  │  └──────────────────┘      └──────────────────┘             │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   ArgoCD Applications                       │  │
│  │                   (GitOps Deployments)                      │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
         │
         │
    ┌────▼────────────────────────────┐
    │  Internet-Facing ALB            │
    │  (HTTPS)                        │
    │  - app.domain (2FA App)         │
    └─────────────────────────────────┘
```

## Components

### 1. PostgreSQL Module

The `modules/postgresql/` module deploys PostgreSQL for storing user registration
and verification data using the Bitnami Helm chart with persistent EBS-backed storage.

**Features:**

- Uses StorageClass from `application_infra` remote state
- ECR image support (images mirrored via infrastructure scripts)
- Persistent storage with configurable size
- Network policies for secure access

> [!NOTE]
>
> For detailed PostgreSQL configuration, connection strings, database schema,
> ECR image setup, and usage examples, see the [PostgreSQL Module Documentation](modules/postgresql/README.md).

### 2. Redis Module

The `modules/redis/` module deploys Redis for SMS OTP code storage using the
Bitnami Helm chart with TTL-based expiration, shared state across replicas, and
persistent storage.

**Features:**

- Uses StorageClass from `application_infra` remote state
- ECR image support (images mirrored via infrastructure scripts)
- Network policies restricting access to backend namespace
- TTL-based expiration for OTP codes

> [!NOTE]
>
> For detailed Redis architecture, key schema, debugging commands, ECR image setup,
> and configuration options, see the [Redis Module Documentation](modules/redis/README.md).

### 3. SES Module

The `modules/ses/` module configures AWS SES for sending verification emails,
including email identity verification, DKIM setup, IRSA configuration, and optional
Route53 integration.

**Features:**

- IRSA (IAM Roles for Service Accounts) for backend service account
- Email identity verification
- DKIM configuration
- Route53 integration for domain verification

> [!NOTE]
>
> For detailed SES configuration, email verification setup, IRSA configuration,
> and usage examples, see the [SES Module Documentation](modules/ses/README.md).

### 4. SNS Module

The `modules/sns/` module configures AWS SNS for SMS-based 2FA verification,
including topic creation, IRSA configuration, and SMS preferences.

**Features:**

- IRSA (IAM Roles for Service Accounts) for backend service account
- SNS topic creation
- SMS preferences configuration
- Configurable monthly spend limits

> [!NOTE]
>
> For detailed SNS configuration, SMS setup, IRSA configuration,
> and usage examples, see the [SNS Module Documentation](modules/sns/README.md).

### 5. ArgoCD Application Modules

The `modules/argocd_app/` module creates ArgoCD Application CRDs for deploying
backend and frontend via GitOps.

**Features:**

- Depends on ArgoCD Capability from `application_infra`
- Automated sync policies
- Self-healing capabilities
- Namespace creation

> [!NOTE]
>
> For detailed ArgoCD Application configuration, sync policies,
> and usage examples, see the [ArgoCD Application Module Documentation](modules/argocd_app/README.md).

### 6. Route53 Record

Creates a Route53 A (alias) record for the 2FA application pointing to the ALB
DNS name from `application_infra`.

### 7. 2FA Application (Backend + Frontend)

A full two-factor authentication application integrated with the LDAP
infrastructure, featuring self-service user registration and admin management.

#### Key Features

| Feature | Description |
| --------- | ------------- |
| **Self-Service Registration** | User signup with email/phone verification |
| **Email Verification** | UUID token-based verification via AWS SES |
| **Phone Verification** | 6-digit OTP codes via AWS SNS |
| **Profile Management** | User profile editing with verification restrictions |
| **Admin Dashboard** | User management, group CRUD, approval workflows |
| **MFA Methods** | TOTP (authenticator apps) and SMS verification |

#### Profile State Management

| State | Description |
| ------- | ------------- |
| **PENDING** | User registered, verification incomplete |
| **COMPLETE** | All verifications complete, awaiting admin approval |
| **ACTIVE** | Admin approved, user exists in LDAP |

#### MFA Methods Supported

| Method | Description | Infrastructure |
| -------- | ------------- | ---------------- |
| **TOTP** | Time-based One-Time Password using authenticator apps (Google Authenticator, Authy, etc.) | None (code generated locally) |
| **SMS** | Verification codes sent via AWS SNS to user's phone | AWS SNS, VPC endpoints, IRSA |

#### Backend (Python FastAPI)

- **Location**: `backend/src/app/`
- **Framework**: FastAPI with uvicorn
- **Port**: 8000
- **Features**:
  - LDAP authentication (bind operation)
  - TOTP secret generation and verification
  - SMS verification code generation and sending
  - QR code URI generation for authenticator apps
  - MFA method selection and storage
  - Self-service user registration
  - Email/phone verification
  - User profile management
  - Admin functions (user management, group CRUD)

**API Endpoints:**

| Method | Endpoint | Description |
| -------- | ---------- | ------------- |
| `GET` | `/api/healthz` | Liveness/readiness probe |
| `GET` | `/api/mfa/methods` | List available MFA methods |
| `GET` | `/api/mfa/status/{username}` | Get user's MFA enrollment status |
| `POST` | `/api/auth/enroll` | Enroll user for MFA (TOTP or SMS) |
| `POST` | `/api/auth/login` | Validate LDAP credentials + verification code |
| `POST` | `/api/auth/sms/send-code` | Send SMS verification code |
| `POST` | `/api/auth/signup` | Register new user |
| `POST` | `/api/auth/verify-email` | Verify email with token |
| `POST` | `/api/auth/verify-phone` | Verify phone with code |
| `POST` | `/api/auth/resend-verification` | Resend verification email/SMS |
| `GET` | `/api/profile/{username}` | Get user profile |
| `PUT` | `/api/profile/{username}` | Update user profile |
| `GET` | `/api/admin/users` | List all users (admin only) |
| `POST` | `/api/admin/users/{username}/approve` | Approve user (admin only) |
| `POST` | `/api/admin/users/{username}/revoke` | Revoke user (admin only) |
| `GET` | `/api/admin/groups` | List all groups (admin only) |
| `POST` | `/api/admin/groups` | Create group (admin only) |
| `PUT` | `/api/admin/groups/{group}` | Update group (admin only) |
| `DELETE` | `/api/admin/groups/{group}` | Delete group (admin only) |

**API Documentation:**

FastAPI automatically generates interactive API documentation that is always
available (not just in debug mode):

| Endpoint | Description |
| ---------- | ------------- |
| `GET` `/api/docs` | Swagger UI - Interactive API documentation and testing interface (always enabled) |
| `GET` `/api/redoc` | ReDoc UI - Alternative API documentation interface (always enabled) |
| `GET` `/api/openapi.json` | OpenAPI schema in JSON format |

Access the Swagger UI at `https://app.<domain>/api/docs` (e.g., `https://app.talorlik.com/api/docs`)
to explore all available endpoints, view request/response schemas, and test API
calls directly from the browser. The documentation automatically updates when
API endpoints change.

#### Frontend (Static HTML/JS/CSS)

- **Location**: `frontend/src/`
- **Server**: nginx
- **Container Port**: 8080 (runs as non-root user `appuser`, UID 1000 for security)
- **Service Port**: 80 (Kubernetes service abstraction - forwards to container
port 8080)
- **Security**: Non-root container execution reduces attack surface
- **Features**:
  - Modern, responsive UI
  - Self-service signup form with validation
  - Email/phone verification status panel
  - Enrollment flow with MFA method selection
  - QR code rendering for TOTP setup
  - Phone number input with E.164 validation
  - SMS send button with countdown timer
  - User profile page with edit functionality
  - Admin dashboard for user/group management
  - Top navigation bar with user menu
  - Error handling and user feedback

#### Routing Pattern (Single Domain)

| Setting | Value |
| --------- | ------- |
| Public hostname | `app.<domain>` (e.g., `app.talorlik.com`) |
| Frontend path | `/` |
| Backend API path | `/api/*` |
| DNS records needed | One A/ALIAS record |

## Module Structure

```bash
application/
├── main.tf                    # Main application configuration
├── variables.tf               # Variable definitions
├── variables.tfvars          # Variable values (customize for your environment)
├── outputs.tf                 # Output values
├── providers.tf               # Provider configuration (AWS, Kubernetes, Helm)
├── backend.hcl                # Terraform backend configuration (generated)
├── tfstate-backend-values-template.hcl  # Backend state configuration template
├── CHANGELOG.md              # Change log for application changes
├── setup-application.sh       # Application setup script
├── destroy-application.sh     # Application destroy script
├── helm/
│   ├── postgresql-values.tpl.yaml  # PostgreSQL Helm values template
│   └── redis-values.tpl.yaml       # Redis Helm values template
├── backend/                   # 2FA Backend application
│   ├── src/                   # Python FastAPI source code
│   ├── helm/                  # Backend Helm chart
│   └── Dockerfile
├── frontend/                  # 2FA Frontend application
│   ├── src/                   # HTML/JS/CSS source code
│   ├── helm/                  # Frontend Helm chart
│   └── Dockerfile
├── modules/
│   ├── argocd_app/            # ArgoCD Application module
│   ├── postgresql/            # PostgreSQL module
│   ├── redis/                 # Redis module
│   ├── ses/                   # SES module
│   └── sns/                   # SNS module
├── PRD-2FA-APP.md            # 2FA Application Product Requirements Document
├── PRD-ADMIN-FUNCS.md        # Admin Functions and Profile Management PRD
├── PRD-SIGNUP-MAN.md         # User Signup Management PRD
├── PRD-SMS-MAN.md            # SMS OTP Management with Redis PRD
├── DEPLOY-2FA-APPS.md        # Application deployment documentation
└── README.md                  # This file
```

## Prerequisites

1. **Backend Infrastructure**: The backend infrastructure must be deployed first
   (see [backend_infra/README.md](../backend_infra/README.md))
2. **Application Infrastructure**: The application infrastructure must be deployed
   first (see [application_infra/README.md](../application_infra/README.md))
   - This provides StorageClass, ArgoCD Capability, and ALB DNS name
3. **Multi-Account Setup**: Same as infrastructure (State Account and Deployment
   Account)
4. **Secrets Configuration**: All required secrets must be configured.
   See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for complete setup instructions.
5. **GitHub Repository Variables**: The following repository variables must be configured:
   - `BACKEND_BUCKET_NAME`: S3 bucket name for Terraform state storage
   - `APPLICATION_PREFIX`: State file key prefix (value: `application_state/terraform.tfstate`)

## Backend State Configuration

The application uses a separate Terraform state file stored in the same S3 bucket
as other infrastructure components, but with a unique key to prevent conflicts.

### State File Configuration

- **Template File**: `tfstate-backend-values-template.hcl`
- **Generated File**: `backend.hcl` (auto-generated by setup script, git-ignored)
- **Bucket**: Same as other infrastructure (`BACKEND_BUCKET_NAME` repository variable)
- **Key**: Uses `APPLICATION_PREFIX` repository variable (value: `application_state/terraform.tfstate`)
- **Region**: Same AWS region as the deployment

### Repository Variables Required

1. **`BACKEND_BUCKET_NAME`**: The S3 bucket name where Terraform state is stored
   - Must be the same bucket used by `backend_infra` and `application_infra`
   - Example: `talo-tf-395323424870-s3-tfstate`

2. **`APPLICATION_PREFIX`**: The state file key prefix for application state
   - Value: `application_state/terraform.tfstate`
   - This ensures the application state is stored separately from infrastructure
   state
   - The full S3 key will be: `application_state/terraform.tfstate`
   (or `env:/${workspace}/application_state/terraform.tfstate` for non-default workspaces)

### State File Generation

The `setup-application.sh` script automatically:

1. Retrieves `BACKEND_BUCKET_NAME` and `APPLICATION_PREFIX` from GitHub repository
variables
2. Creates `backend.hcl` from `tfstate-backend-values-template.hcl` template
3. Replaces placeholders:
   - `<BACKEND_BUCKET_NAME>` → actual bucket name
   - `<APPLICATION_PREFIX>` → `application_state/terraform.tfstate`
   - `<AWS_REGION>` → selected AWS region

The generated `backend.hcl` file is git-ignored and should not be committed to the
repository.

### State File Isolation

Each directory maintains its own state file in the same S3 bucket:

- **`application_infra/`**: Uses `APPLICATION_INFRA_PREFIX` → `application_infra_state/terraform.tfstate`
- **`application/`**: Uses `APPLICATION_PREFIX` → `application_state/terraform.tfstate`

This ensures complete isolation between infrastructure and application state, preventing
accidental state conflicts or overwrites.

## Configuration

### Required Variables

#### Core Variables

- `env`: Deployment environment (prod, dev)
- `region`: AWS region (must match backend and application infrastructure)
- `prefix`: Prefix for resource names (must match backend and application infrastructure)
- `cluster_name`: **Automatically retrieved** from backend_infra remote state
- `domain_name`: Root domain name (must match application infrastructure)

#### PostgreSQL Variables

- `enable_postgresql`: Enable PostgreSQL deployment (default: `true`)
- `postgresql_namespace`: Kubernetes namespace (default: `ldap-2fa`)
- `postgresql_database_name`: Database name (default: `ldap2fa`)
- `postgresql_database_username`: Database username (default: `ldap2fa`)
- `postgresql_database_password`: **MUST be set via environment variable**
- `postgresql_storage_size`: Storage size for PVC (default: `8Gi`)

#### Redis Variables

- `enable_redis`: Enable Redis deployment (default: `true`)
- `redis_namespace`: Kubernetes namespace (default: `redis`)
- `redis_password`: **MUST be set via environment variable**
- `redis_storage_size`: Storage size for PVC (default: `1Gi`)

#### SES Variables

- `enable_email_verification`: Enable SES email resources (default: `true`)
- `ses_sender_email`: Verified sender email address
- `ses_sender_domain`: Optional domain to verify (for DKIM)
- `ses_iam_role_name`: IAM role name for SES access

#### SNS Variables

- `enable_sms_2fa`: Enable SMS 2FA resources (default: `false`)
- `sns_topic_name`: SNS topic name component
- `sns_iam_role_name`: IAM role name for SNS access
- `sms_monthly_spend_limit`: Monthly SMS budget

#### ArgoCD Application Variables

- `enable_argocd_apps`: Enable ArgoCD Applications (default: `false`)
- `argocd_app_repo_url`: Git repository URL for application manifests
- `argocd_app_target_revision`: Git branch/tag for application manifests
- `argocd_app_backend_name`: Name of backend ArgoCD Application
- `argocd_app_backend_path`: Path to backend manifests in repository
- `argocd_app_backend_namespace`: Namespace for backend deployment
- `argocd_app_frontend_name`: Name of frontend ArgoCD Application
- `argocd_app_frontend_path`: Path to frontend manifests in repository
- `argocd_app_frontend_namespace`: Namespace for frontend deployment

> [!IMPORTANT]
>
> PostgreSQL and Redis passwords must be set via environment variables:
>
> - `TF_VAR_postgresql_database_password`
> - `TF_VAR_redis_password`
>
> See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for configuration details.

## Deployment

### Step 1: Deploy Infrastructure First

**Critical**: Application infrastructure must be deployed before the application:

```bash
cd application_infra
./setup-application-infra.sh
```

This deploys:

- StorageClass (used by PostgreSQL and Redis)
- ArgoCD Capability (required for ArgoCD Applications)
- ALB (provides DNS name for Route53 record)

### Step 2: Deploy Application

#### Option 1: Using Setup Script (Local)

```bash
cd application
./setup-application.sh
```

This script will:

- Prompt for AWS region and environment
- Retrieve secrets from AWS Secrets Manager
- Create `backend.hcl` from template
- Set up Kubernetes environment
- Run Terraform operations

#### Option 2: Using GitHub Actions Workflow

1. Go to GitHub → Actions tab
2. Select "Application Provisioning" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

### Step 3: Verify Deployment

Check that all components are running:

```bash
# Check PostgreSQL
kubectl get pods -n ldap-2fa -l app.kubernetes.io/name=postgresql

# Check Redis
kubectl get pods -n redis -l app.kubernetes.io/name=redis

# Check ArgoCD Applications (if enabled)
kubectl get applications -n argocd
```

## Dependencies

### Remote State Dependencies

The application reads from:

- **backend_infra** remote state:
  - `ecr_registry` (for PostgreSQL/Redis ECR images)
  - `ecr_repository` (for PostgreSQL/Redis ECR images)
  - `cluster_name` (for EKS cluster access, SES/SNS IRSA)

- **application_infra** remote state:
  - `storage_class_name` (for PostgreSQL/Redis modules)
  - `argocd_capability_status` (for ArgoCD Applications - **must be "ACTIVE"**)
  - `local_cluster_secret_name` (for argocd_app modules)
  - `argocd_namespace` (for argocd_app modules)
  - `argocd_project_name` (for argocd_app modules)
  - `alb_dns_name` (for Route53 record for twofa_app)

> [!IMPORTANT]
>
> **ArgoCD Capability Status Validation**: The `setup-application.sh` script and
> `application_provisioning.yaml` workflow automatically validate that
> `argocd_capability_status` is "ACTIVE" before proceeding with deployment. If the
> status is not ACTIVE, deployment will fail with a clear error message. This
> ensures that ArgoCD Applications can be properly deployed and managed. The
> validation prevents deployment failures due to incomplete ArgoCD capability setup.

### Deployment Order

1. **backend_infra/** - Deploy first (provides EKS cluster, ECR)
2. **application_infra/** - Deploy second (provides StorageClass, ArgoCD Capability,
ALB)
3. **application/** - Deploy last (depends on both infrastructure layers)

## Outputs

The application provides the following outputs:

- PostgreSQL: `postgresql_host`, `postgresql_connection_url`, `postgresql_database`
- Redis: `redis_host`, `redis_port`, `redis_namespace`, `redis_password_secret_name`
- SES: `ses_sender_email`, `ses_iam_role_arn`, `ses_verification_status`
- SNS: `sns_topic_arn`, `sns_topic_name`, `sns_iam_role_arn`
- ArgoCD Applications: `argocd_backend_app_name`, `argocd_frontend_app_name`
- 2FA URLs: `twofa_app_url`, `twofa_api_url`
- Route53: `twofa_app_route53_record_name`, `twofa_app_route53_record_fqdn`

## Destroying

### Using Destroy Script (Local)

```bash
cd application
./destroy-application.sh
```

### Using GitHub Actions Workflow

1. Go to GitHub → Actions tab
2. Select "Application Destroying" workflow
3. Click "Run workflow"
4. Select environment and region
5. Click "Run workflow"

> [!WARNING]
>
> Destroying the application will delete PostgreSQL and Redis data. Ensure you have
> backups before destroying.

## Accessing the Services

### 2FA Application

- **URL**: `https://app.${domain_name}` (e.g., `https://app.talorlik.com`)
- **Access**: Internet-facing (via internet-facing ALB)
- **Purpose**: Two-factor authentication, user registration, and management
- **Features**:
  - Self-service user registration
  - Email verification (click link in email)
  - Phone verification (enter 6-digit SMS code)
  - TOTP enrollment with QR code
  - SMS enrollment with phone number verification
  - Login with LDAP credentials + verification code
  - User profile management
  - Admin dashboard (visible to LDAP admin group members only):
    - User list with filtering and sorting
    - Approve/revoke users
    - Group CRUD operations
    - User-group assignment

## Troubleshooting

### Common Issues

1. **2FA Application Issues**
   - Check backend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-backend`
   - Check frontend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-frontend`
   - Verify LDAP connectivity from backend: test internal DNS resolution
   - Check IRSA role assumption: verify service account annotations

2. **SMS 2FA Not Working**
   - Verify SNS topic exists: `aws sns list-topics`
   - Check IAM role permissions: `aws iam get-role-policy`
   - Verify VPC endpoints for SNS and STS
   - Check backend logs for SNS errors
   - Verify phone number format (E.164)

3. **PostgreSQL Issues**
   - Check pods: `kubectl get pods -n ldap-2fa -l app.kubernetes.io/name=postgresql`
   - Check logs: `kubectl logs -n ldap-2fa -l app.kubernetes.io/name=postgresql`
   - Check PVC: `kubectl get pvc -n ldap-2fa`
   - Test connection: `kubectl exec -it -n ldap-2fa postgresql-0 -- \
     psql -U ldap2fa -d ldap2fa`

4. **Redis Issues**
   - Check pods: `kubectl get pods -n redis -l app.kubernetes.io/name=redis`
   - Check logs: `kubectl logs -n redis -l app.kubernetes.io/name=redis`
   - Check PVC: `kubectl get pvc -n redis`
   - Test connection: `kubectl exec -it -n redis redis-master-0 -- \
     redis-cli -a $REDIS_PASSWORD ping`

5. **SES Issues**
   - Check email identity: `aws ses get-identity-verification-attributes \
     --identities your@email.com`
   - Check send quota: `aws ses get-send-quota`
   - Verify IRSA: Check service account annotation for SES IAM role

6. **User Registration Issues**
   - Check backend logs for registration errors
   - Verify PostgreSQL connectivity
   - Check SES sending limits (sandbox mode restricts recipients)
   - Verify SNS SMS spending limit

### Useful Commands

```bash
# Check 2FA Backend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-backend

# Check 2FA Frontend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-frontend

# View Ingress details
kubectl describe ingress -n 2fa-app

# Test 2FA API endpoints
curl -X GET https://app.${domain_name}/api/healthz
curl -X GET https://app.${domain_name}/api/mfa/methods

# Check PostgreSQL
kubectl logs -n ldap-2fa -l app.kubernetes.io/name=postgresql
kubectl exec -it -n ldap-2fa postgresql-0 -- psql -U ldap2fa -d ldap2fa -c "\dt"

# Check Redis
kubectl logs -n redis -l app.kubernetes.io/name=redis
kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD KEYS "*"

# Check SES identity status
aws ses get-identity-verification-attributes --identities ${domain_name}

# Check SNS topic
aws sns list-topics
aws sns get-topic-attributes --topic-arn <topic-arn>

# Check ArgoCD applications
kubectl get application -n argocd
kubectl describe application -n argocd <app-name>
```

## Security Considerations

1. **IRSA for AWS Services**: SMS 2FA and email verification use IAM Roles for
Service Accounts (no hardcoded AWS credentials)
2. **VPC Endpoints**: SNS and STS access goes through VPC endpoints
(no public internet for SMS)
3. **Phone Number Validation**: E.164 format validation for SMS phone numbers
4. **SMS Code Expiration**: Verification codes expire after configurable timeout
5. **Non-Root Container Execution**: Frontend container runs as non-root user
(`appuser`, UID 1000) on port 8080, reducing attack surface and following security
best practices
6. **Password Security**: PostgreSQL and Redis passwords are marked as sensitive
in Terraform and must be set via environment variables, never in `variables.tfvars`.
See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for configuration details.
7. **Encrypted Storage**: EBS volumes are encrypted by default
(configurable via StorageClass from `application_infra`)
8. **Network Policies**: Network policies restrict pod-to-pod communication
(configured via modules)
9. **Rate Limiting**: Consider implementing rate limiting for authentication attempts
10. **HTTPS Only**: TLS termination at ALB with ACM certificate
(automatically validated via Route53)

## Architecture Notes

### 2FA Application Architecture

The 2FA application follows a single-domain pattern:

- **Single ALB Entry Point**: Both frontend and backend share the same ALB
- **Path-Based Routing**: `/api/*` routes to backend, `/` routes to frontend
- **No CORS Required**: Same-origin requests since both share `app.${domain}`
- **LDAP Integration**: Backend authenticates against internal LDAP service
- **PostgreSQL Integration**: Stores user registrations and verification tokens
- **Redis Integration**: Caches SMS OTP codes with TTL-based expiration
- **IRSA for AWS Services**: Backend uses IAM Roles for Service Accounts for
SNS and SES access
- **VPC Private Access**: SNS/STS calls go through VPC endpoints (no NAT
gateway)

### User Registration Flow

1. **Signup**: User submits registration form → stored in PostgreSQL (PENDING)
2. **Email Verification**: SES sends verification link → user clicks → email verified
3. **Phone Verification**: SNS sends OTP → user enters code → phone verified
4. **Profile Complete**: Both verified → status changes to COMPLETE
5. **Admin Approval**: Admin approves → user created in LDAP → status ACTIVE
6. **Welcome Email**: SES sends welcome email on activation

## Documentation

- [PostgreSQL Module](modules/postgresql/README.md)
- [Redis Module](modules/redis/README.md)
- [SES Module](modules/ses/README.md)
- [SNS Module](modules/sns/README.md)
- [ArgoCD Application Module](modules/argocd_app/README.md)
- [Backend Application](backend/README.md)
- [Frontend Application](frontend/README.md)
- [Deploy 2FA Apps](DEPLOY-2FA-APPS.md)
- [2FA Application PRD](PRD-2FA-APP.md) - Complete API and frontend requirements
- [User Signup Management PRD](PRD-SIGNUP-MAN.md) - Self-service signup system
- [Admin Functions PRD](PRD-ADMIN-FUNCS.md) - Admin dashboard and user management
- [SMS OTP Management PRD](PRD-SMS-MAN.md) - Redis-based SMS OTP storage

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [AWS SNS SMS Documentation](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [AWS SES Documentation](https://docs.aws.amazon.com/ses/)
- [IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Bitnami Redis Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## Related Documentation

- [Application Infrastructure](../application_infra/README.md)
- [Backend Infrastructure](../backend_infra/README.md)
- [Secrets Requirements](../SECRETS_REQUIREMENTS.md)
