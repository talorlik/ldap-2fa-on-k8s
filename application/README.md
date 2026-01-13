# Application Infrastructure

This Terraform configuration deploys the OpenLDAP stack with PhpLdapAdmin and
LTB-passwd UIs, plus a **full 2FA application** (backend + frontend) with LDAP
authentication integration on the EKS cluster created by the backend
infrastructure.

## Overview

The application infrastructure provisions:

- **Route53 Hosted Zone** for domain management (can be in State Account)
- **ACM Certificate** with DNS validation for HTTPS (issued from Private CA in
  State Account, stored in Deployment Account)
- **Helm Release** for OpenLDAP Stack HA (High Availability)
- **Application Load Balancer (ALB)** via EKS Auto Mode Ingress
- **Persistent Storage** using EBS-backed PVCs
- **Internet-Facing ALB** for UI access from the internet
- **2FA Application** with Python FastAPI backend and static HTML/JS/CSS
frontend
  - Self-service user registration with email/phone verification
  - Admin dashboard for user management and approval workflows
  - User profile management with edit restrictions
- **ArgoCD Capability** for GitOps deployments (AWS EKS managed service)
- **cert-manager** module available (future improvement for automatic TLS
certificate management)
- **Network Policies** for securing pod-to-pod communication
- **PostgreSQL** for user registration and verification token storage
- **Redis** for SMS OTP code storage with TTL-based expiration
- **SES Integration** for email verification and notifications
- **SNS Integration** for SMS-based 2FA verification (optional)

## Architecture

```ascii
┌───────────────────────────────────────────────────────────────────┐
│                         EKS Cluster                               │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                    LDAP Namespace                           │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐   │  │
│  │  │ OpenLDAP     │  │ PhpLdapAdmin     │  │ LTB-passwd   │   │  │
│  │  │ StatefulSet  │  │ Deployment       │  │ Deployment   │   │  │
│  │  │              │  │                  │  │              │   │  │
│  │  │ ClusterIP    │  │ Ingress (ALB)    │  │ Ingress (ALB)│   │  │
│  │  │ (Internal)   │  │ (Internet)       │  │ (Internet)   │   │  │
│  │  └──────────────┘  └──────────────────┘  └──────────────┘   │  │
│  │                                                             │  │
│  │  ┌──────────────┐                                           │  │
│  │  │ EBS PVC      │                                           │  │
│  │  │ (8Gi)        │                                           │  │
│  │  └──────────────┘                                           │  │
│  └─────────────────────────────────────────────────────────────┘  │
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
│  │  │ (ClusterIP)      │      │ (User Data)      │             │  │
│  │  └──────────────────┘      └──────────────────┘             │  │
│  │                                                             │  │
│  │  ┌──────────────────┐      ┌──────────────────┐             │  │
│  │  │ Redis            │      │ SNS/SES          │             │  │
│  │  │ (SMS OTP Cache)  │      │ (via IRSA)       │             │  │
│  │  └──────────────────┘      └──────────────────┘             │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   ArgoCD (EKS Managed)                      │  │
│  │                   GitOps Deployments                        │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
         │
         │
    ┌────▼────────────────────────────┐
    │  Internet-Facing ALB            │
    │  (HTTPS)                        │
    │  - phpldapadmin.domain          │
    │  - passwd.domain                │
    │  - app.domain (2FA App)         │
    └─────────────────────────────────┘
         │
         │
    ┌────▼────────┐
    │  Internet   │
    │  Access     │
    └─────────────┘
```

## Components

### 1. Route53 Hosted Zone and ACM Certificate

> [!NOTE]
>
> The Route53 module (`modules/route53/`) exists but is currently
> **commented out** in `main.tf`. The code uses **data sources** to reference
> existing Route53 hosted zone and ACM certificate resources that must already
> exist.
>
> **Cross-Account Access**: Route53 hosted zone and ACM certificate can be in
> the State Account (different from deployment account). When
> `state_account_role_arn` is configured, Terraform automatically queries these
> resources from the State Account. See [Cross-Account Access
> Documentation](./CROSS-ACCOUNT-ACCESS.md) for details.

**Current Implementation (Data Sources):**

The code references existing resources using data sources:

- **Route53 Hosted Zone**: Must already exist (referenced via
`data.aws_route53_zone`)
- **ACM Certificate**: Must already exist and be validated (referenced via
`data.aws_acm_certificate`)
  - Certificate must be issued from a Private CA in the State Account
  - Certificate must exist in the Deployment Account (not State Account)
  - See [Private CA Setup and Certificate Issuance](./CROSS-ACCOUNT-ACCESS.md#private-ca-setup-and-certificate-issuance)
    for setup instructions
- The certificate must be in the same region as the EKS cluster

**Prerequisites:**

- Route53 hosted zone must be created beforehand (manually or via another
Terraform configuration)
- **Private CA Setup**: A central Private CA must be created in the State Account
  and shared via RAM. See [Private CA Setup and Certificate Issuance](./CROSS-ACCOUNT-ACCESS.md#private-ca-setup-and-certificate-issuance)
  for detailed instructions.
- ACM certificate must be requested from the Private CA in each deployment
  account and validated beforehand
- Certificate must be in `ISSUED` status
- Certificate must be in the same region as the EKS cluster

**Outputs:**

Outputs come from data sources (not module outputs):

- `route53_acm_cert_arn`: ACM certificate ARN from data source (used by ALB)
- `route53_domain_name`: Root domain name from variable
- `route53_zone_id`: Route53 hosted zone ID from data source
- `route53_name_servers`: Route53 name servers from data source (for registrar
configuration)

**Alternative Approach:**

If you want to create Route53 zone and ACM certificate via Terraform, uncomment
the Route53 module in `main.tf` (lines 43-53) and update the code to use module
outputs instead of data sources.

### 1a. Route53 Record Module

The `modules/route53_record/` module creates Route53 A (alias) records pointing
to the ALB. This module is called separately for each subdomain (phpldapadmin,
ltb_passwd, twofa_app) to create individual DNS records.

> [!NOTE]
>
> For detailed Route53 record module documentation, including cross-account
> access, ALB zone_id mapping, dependencies, and usage examples, see the
> [Route53 Record Module Documentation](modules/route53_record/README.md).

**Key Features:**

- **Cross-Account Support**: Uses state account provider to create records in
  State Account while ALB is in Deployment Account
- **ALB Alias Records**: Creates A (alias) records for optimal performance
- **Health Check Integration**: Supports target health evaluation
- **Precondition Validation**: Ensures ALB DNS name is available before record
  creation
- **Safe Updates**: Uses `create_before_destroy` lifecycle to prevent DNS
  downtime

**Module Calls in main.tf:**

- `module.route53_record_phpldapadmin` - Creates A record for phpLDAPadmin
- `module.route53_record_ltb_passwd` - Creates A record for ltb-passwd
- `module.route53_record_twofa_app` - Creates A record for 2FA application

**Dependencies:**

- OpenLDAP module (ensures Ingress is created, which triggers ALB creation)
- ALB data source (ensures ALB exists before creating record)

### 2. OpenLDAP Stack HA Helm Release

Deploys the complete OpenLDAP stack using the
[helm-openldap](https://github.com/jp-gouin/helm-openldap) Helm chart:

- **OpenLDAP StatefulSet**: Core LDAP server with EBS-backed persistent storage
- **PhpLdapAdmin**: Web-based LDAP administration interface
- **LTB-passwd**: Self-service password management UI
- **Internal LDAP Service**: ClusterIP service (not exposed externally)

**Key Configuration:**

- Chart: `openldap-stack-ha` version `4.0.1`
- Repository: `https://jp-gouin.github.io/helm-openldap`
- Namespace: `ldap` (created automatically)
- Storage: Creates a new PVC using a StorageClass created by this Terraform
configuration (see Storage Configuration section below)
- LDAP Ports: Standard ports (389 for LDAP, 636 for LDAPS)
- **ECR Images**: Uses ECR images instead of Docker Hub (images mirrored via
  `mirror-images-to-ecr.sh`)
- **Route53 Records**: Route53 record creation has been moved to the dedicated
  `route53_record` module (see Route53 Record Module section above)

### 3. 2FA Application (Backend + Frontend)

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

FastAPI automatically generates interactive API documentation that is always available:

| Endpoint | Description |
| ---------- | ------------- |
| `GET` `/api/docs` | Swagger UI - Interactive API documentation and testing interface |
| `GET` `/api/redoc` | ReDoc UI - Alternative API documentation interface |
| `GET` `/api/openapi.json` | OpenAPI schema in JSON format |

Access the Swagger UI at `https://app.<domain>/api/docs` (e.g., `https://app.talorlik.com/api/docs`)
to explore all available endpoints, view request/response schemas, and test API
calls directly from the browser. The documentation automatically updates when
API endpoints change.

#### Frontend (Static HTML/JS/CSS)

- **Location**: `frontend/src/`
- **Server**: nginx
- **Port**: 80
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

### 4. Application Load Balancer (ALB)

The ALB is automatically provisioned by EKS Auto Mode when Ingress resources are
created with the appropriate annotations. The ALB provides:

- **Internet-Facing Access**: Accessible from the internet (`scheme: internet-facing`)
- **HTTPS Only**: TLS termination at ALB using ACM certificate
- **Target Type**: IP mode (direct pod targeting)
- **Multiple Hostnames**: Single ALB handles all services via host-based routing

The ALB is created via Kubernetes Ingress resources using EKS Auto Mode
(not AWS Load Balancer Controller). The `elastic_load_balancing` capability is
**enabled by default** when EKS Auto Mode is enabled (configured in backend_infra
via `compute_config.enabled = true`).

> [!NOTE]
>
> For detailed ALB configuration, annotation strategy, EKS Auto Mode vs
> AWS Load Balancer Controller differences, and implementation details,
> see the [ALB Module Documentation](modules/alb/README.md).

### 5. Storage Configuration

Creates a StorageClass and the Helm chart creates a new PVC using that
StorageClass:

- **StorageClass**: Created by this Terraform configuration
(`kubernetes_storage_class_v1` resource)
  - Name: `${prefix}-${region}-${storage_class_name}-${env}`
  - Provisioner: `ebs.csi.eks.amazonaws.com`
  - Volume binding mode: `WaitForFirstConsumer`
  - Encryption: Configurable via `storage_class_encrypted` variable
  - Volume type: Configurable via `storage_class_type` variable (gp2, gp3, io1,
  io2, etc.)
  - Can be set as default StorageClass via `storage_class_is_default` variable
- **PVC**: Created by the Helm chart using the StorageClass
  - **Storage Size**: 8Gi (configurable in Helm values)
  - **Access Mode**: ReadWriteOnce
  - The Helm chart creates a new PVC, it does not reuse an existing PVC from
  backend infrastructure

### 6. Network Policies

The `modules/network-policies/` module creates Kubernetes Network Policies to secure
internal cluster communication, enforcing secure ports only (443, 636, 8443) and
enabling cross-namespace communication for LDAP service access.

> [!NOTE]
>
> For detailed network policy rules, security configuration, and cross-namespace
> communication setup, see the [Network Policies Module Documentation](modules/network-policies/README.md).

### 7. ArgoCD Capability (GitOps)

The `modules/argocd/` module deploys the AWS EKS managed ArgoCD service for GitOps
deployments, including IAM integration, Identity Center authentication, and
cluster registration.

The `modules/argocd_app/` module creates ArgoCD Application CRDs for GitOps-driven
deployments.

> [!NOTE]
>
> For detailed ArgoCD configuration, Identity Center setup, Application CRD creation,
> and deployment examples, see:
>
> - [ArgoCD Module Documentation](modules/argocd/README.md)
> - [ArgoCD Application Module Documentation](modules/argocd_app/README.md)

### 8. cert-manager Module

> [!NOTE]
>
> **Current Status**: The cert-manager module exists in the codebase but is
> **not currently used** by the OpenLDAP module. OpenLDAP currently uses auto-generated
> self-signed certificates from the osixia/openldap image. Integrating cert-manager
> for automatic TLS certificate management is a **future improvement** that
> would provide:
>
> - Automatic certificate generation and renewal
> - Better certificate lifecycle management
> - Integration with Let's Encrypt or other certificate authorities
> - Consistent certificate management across services
>
> For detailed cert-manager configuration, certificate management, and usage examples,
> see the [cert-manager Module Documentation](modules/cert-manager/README.md).

### 9. SNS Module (SMS 2FA)

The `modules/sns/` module creates AWS SNS resources for SMS-based 2FA verification,
including SNS Topic, IAM Role (IRSA), direct SMS support, and cost control via
monthly spend limits.

> [!NOTE]
>
> For detailed SNS configuration, IRSA setup, SMS sending methods, phone number
> format requirements, and cost considerations, see the [SNS Module Documentation](modules/sns/README.md).

### 10. PostgreSQL Module (User Data Storage)

The `modules/postgresql/` module deploys PostgreSQL for storing user registration
and verification data using the Bitnami Helm chart with persistent EBS-backed storage.

**ECR Image Support:**

- Uses ECR images instead of Docker Hub (images mirrored via
  `mirror-images-to-ecr.sh`)
- Image tag: `postgresql-18.1.0` (default, corresponds to
  `bitnami/postgresql:18.1.0-debian-12-r4`)
- ECR registry and repository computed from backend_infra state

> [!NOTE]
>
> For detailed PostgreSQL configuration, connection strings, database schema,
> ECR image setup, and usage examples, see the [PostgreSQL Module Documentation](modules/postgresql/README.md).

### 11. SES Module (Email Verification)

The `modules/ses/` module configures AWS SES for sending verification emails,
including email identity verification, DKIM setup, IRSA configuration, and optional
Route53 integration.

> [!NOTE]
>
> For detailed SES configuration, email verification setup, IRSA configuration,
> and usage examples, see the [SES Module Documentation](modules/ses/README.md).

### 12. Redis Module (SMS OTP Storage)

The `modules/redis/` module deploys Redis for SMS OTP code storage using the
Bitnami Helm chart with TTL-based expiration, shared state across replicas, and
persistent storage.

**ECR Image Support:**

- Uses ECR images instead of Docker Hub (images mirrored via
  `mirror-images-to-ecr.sh`)
- Image tag: `redis-8.4.0` (default, corresponds to
  `bitnami/redis:8.4.0-debian-12-r6`)
- ECR registry and repository computed from backend_infra state

> [!NOTE]
>
> For detailed Redis architecture, key schema, debugging commands, ECR image setup,
> and configuration options, see the [Redis Module Documentation](modules/redis/README.md).

## Module Structure

```bash
application/
├── main.tf                    # Main application configuration
├── variables.tf               # Variable definitions
├── variables.tfvars          # Variable values (customize for your environment)
├── outputs.tf                 # Output values
├── providers.tf               # Provider configuration (AWS, Kubernetes, Helm)
├── backend.hcl                # Terraform backend configuration template
├── tfstate-backend-values-template.hcl  # Backend state configuration template
├── CHANGELOG.md              # Change log for this module
├── setup-application.sh       # Application setup script
├── set-k8s-env.sh            # Kubernetes environment setup script
├── helm/
│   ├── openldap-values.tpl.yaml  # OpenLDAP Helm values template
│   └── redis-values.tpl.yaml   # Redis Helm values template
├── backend/
│   ├── src/
│   │   └── app/
│   │       ├── main.py           # FastAPI application entry point
│   │       ├── config.py         # Configuration management
│   │       ├── api/
│   │       │   ├── __init__.py
│   │       │   └── routes.py    # API route definitions
│   │       ├── database/
│   │       │   ├── __init__.py
│   │       │   ├── connection.py # Database connection management
│   │       │   └── models.py    # Database models
│   │       ├── email/
│   │       │   ├── __init__.py
│   │       │   └── client.py     # Email client for SES integration
│   │       ├── ldap/
│   │       │   ├── __init__.py
│   │       │   └── client.py     # LDAP client for authentication
│   │       ├── mfa/
│   │       │   ├── __init__.py
│   │       │   └── totp.py      # TOTP secret generation/verification
│   │       ├── redis/
│   │       │   ├── __init__.py
│   │       │   └── client.py     # Redis client for OTP storage
│   │       └── sms/
│   │           ├── __init__.py
│   │           └── client.py     # SMS client for SNS integration
│   ├── src/
│   │   └── requirements.txt     # Python dependencies
│   ├── helm/
│   │   └── ldap-2fa-backend/    # Backend Helm chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── configmap.yaml
│   │           ├── deployment.yaml
│   │           ├── hpa.yaml
│   │           ├── ingress.yaml
│   │           ├── NOTES.txt
│   │           ├── secret.yaml
│   │           ├── service.yaml
│   │           ├── serviceaccount.yaml
│   │           └── tests/
│   │               └── test-connection.yaml
│   └── Dockerfile               # Backend container image
├── frontend/
│   ├── src/
│   │   ├── index.html          # Main HTML page
│   │   ├── css/
│   │   │   └── styles.css      # Styling
│   │   └── js/
│   │       ├── api.js          # API client
│   │       └── main.js         # Main application logic
│   ├── helm/
│   │   └── ldap-2fa-frontend/  # Frontend Helm chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── deployment.yaml
│   │           ├── hpa.yaml
│   │           ├── ingress.yaml
│   │           ├── NOTES.txt
│   │           ├── service.yaml
│   │           ├── serviceaccount.yaml
│   │           └── tests/
│   │               └── test-connection.yaml
│   ├── nginx.conf              # nginx configuration
│   └── Dockerfile              # Frontend container image
├── modules/
│   ├── alb/                    # ALB module - creates IngressClass and IngressClassParams for EKS Auto Mode
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── argocd/                 # ArgoCD Capability module - deploys managed ArgoCD
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── argocd_app/             # ArgoCD Application module - creates Application CRDs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── cert-manager/           # cert-manager module - TLS certificate management
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── network-policies/       # Network Policies module - secures pod-to-pod communication
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── openldap/               # OpenLDAP module - LDAP directory service deployment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── postgresql/             # PostgreSQL module - User data storage
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── redis/                  # Redis module - SMS OTP storage
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── route53/                # Route53 module - hosted zone and DNS management
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── route53_record/         # Route53 Record module - A (alias) records for ALB
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── README.md
│   ├── ses/                    # SES module - Email verification
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── sns/                    # SNS module - SMS 2FA verification
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── PRD-2FA-APP.md              # 2FA Application Product Requirements Document
├── PRD-ADMIN-FUNCS.md          # Admin Functions and Profile Management PRD
├── PRD-ALB.md                  # ALB configuration PRD
├── PRD-ArgoCD.md               # ArgoCD configuration PRD
├── PRD-DOMAIN.md               # Domain configuration PRD
├── PRD-SIGNUP-MAN.md           # User Signup Management PRD
├── PRD-SMS-MAN.md              # SMS OTP Management with Redis PRD
├── PRD.md                      # Main PRD
├── OPENLDAP-README.md          # OpenLDAP deployment documentation
├── OSIXIA-OPENLDAP-REQUIREMENTS.md  # OpenLDAP requirements documentation
├── SECURITY-IMPROVEMENTS.md   # Security improvements documentation
├── CROSS-ACCOUNT-ACCESS.md    # Cross-account Route53/ACM access documentation
└── README.md                   # This file
```

## Prerequisites

1. **Backend Infrastructure**: The backend infrastructure must be deployed first
(see [backend_infra/README.md](../backend_infra/README.md))
2. **Multi-Account Setup**:
   - **Account A (State Account)**: Stores Terraform state in S3, Route53
     hosted zones, and ACM certificates
   - **Account B (Deployment Account)**: Contains application resources (EKS,
     ALB, etc.)
   - Route53 hosted zone and ACM certificate can be in State Account
     (accessed via `state_account_role_arn`)
   - Route53 records are created in State Account while ALB is deployed in
     Deployment Account
   - ALB in Deployment Account can use ACM certificate from State Account
     (same region required)
   - GitHub Actions uses Account A role for backend access and Route53/ACM
     access
   - Terraform provider assumes Account B role for resource deployment
   - See [Cross-Account Access Documentation](./CROSS-ACCOUNT-ACCESS.md) for
     details
3. **AWS SSO/OIDC**: Configured GitHub OIDC provider and IAM roles (see main
[README.md](../README.md))
4. **EKS Cluster**: The EKS cluster must be running with Auto Mode enabled
5. **Route53 Hosted Zone**: Must already exist (the Route53 module is commented
out, code uses data sources)
6. **Private CA Setup**: A central Private Certificate Authority (PCA) must be
   created in the State Account, and ACM certificates must be issued for each
   deployment account
   - See [Private CA Setup and Certificate Issuance](./CROSS-ACCOUNT-ACCESS.md#private-ca-setup-and-certificate-issuance)
     for detailed setup instructions with step-by-step AWS CLI commands
   - Includes Resource Access Manager (RAM) sharing configuration
   - Certificate issuance workflow for both production and development accounts
7. **ACM Certificate**: Must already exist and be validated in the same region
   as the EKS cluster
   - Certificate must be issued from the Private CA in the State Account
   - Certificate must exist in the Deployment Account (not State Account)
   - Each deployment account has its own certificate issued from the Private CA
   - See [Cross-Account Access Documentation](./CROSS-ACCOUNT-ACCESS.md) for
     details
7. **Domain Registration**: The domain name must be registered (can be with any
registrar)
8. **DNS Configuration**: After deployment, point your domain registrar's NS
records to the Route53 name servers (output from data source)
9. **Environment Variables**: OpenLDAP passwords must be set via environment
variables (see Configuration section)
10. **AWS Identity Center**: Required for ArgoCD RBAC configuration
11. **VPC Endpoints (for SMS 2FA)**: STS and SNS endpoints must be enabled in
backend_infra
12. **Secrets Configuration**: All required secrets must be configured.
See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for complete setup instructions.
13. **Docker (for Local Deployment)**: Docker must be installed and running for
ECR image mirroring. The `mirror-images-to-ecr.sh` script requires Docker to
pull images from Docker Hub and push them to ECR.
14. **jq (for Local Deployment)**: The `jq` command-line tool is required for
JSON parsing in the image mirroring script (with fallback to sed for
compatibility).

## Configuration

### Required Variables

#### Core Variables

- `env`: Deployment environment (prod, dev)
- `region`: AWS region (must match backend infrastructure)
- `prefix`: Prefix for resource names (must match backend infrastructure)
- `cluster_name`: **Automatically retrieved** from backend_infra remote state
(see Cluster Name section below)
- `deployment_account_role_arn`: (Optional, for GitHub Actions) ARN of IAM role
in Account B to assume for resource deployment
  - Automatically injected by GitHub workflows
  - Required when using multi-account setup
  - Format: `arn:aws:iam::ACCOUNT_B_ID:role/github-actions-deployment-role`
- `deployment_account_external_id`: (Optional, for security) ExternalId for
cross-account role assumption
  - Automatically retrieved from AWS Secrets Manager (secret: `external-id`) for
  local deployment
  - Automatically retrieved from GitHub secret (`AWS_ASSUME_EXTERNAL_ID`) for
  GitHub Actions
  - Required when deployment account roles have ExternalId condition in Trust Relationship
  - Must match the ExternalId configured in the deployment account role's
  Trust Relationship
  - Generated using: `openssl rand -hex 32`
- `state_account_role_arn`: (Optional) ARN of IAM role in State Account for
  Route53/ACM access
  - Automatically injected by `setup-application.sh` and `set-k8s-env.sh`
    scripts
  - Automatically injected by GitHub workflows
  - Required when Route53 hosted zone and ACM certificate are in a different account
  - Format: `arn:aws:iam::STATE_ACCOUNT_ID:role/terraform-state-role`
  - See [Cross-Account Access Documentation](./CROSS-ACCOUNT-ACCESS.md) for details

#### Cluster Name Injection

The cluster name is automatically retrieved using a fallback chain:

1. **First**: Attempts to retrieve from `backend_infra` Terraform remote state
(if `backend.hcl` exists)
2. **Second**: Uses `cluster_name` variable if provided in `variables.tfvars`
3. **Third**: Calculates cluster name using pattern:
`${prefix}-${region}-${cluster_name_component}-${env}`

The backend configuration (bucket, key, region) is read from `backend.hcl`
(created by `setup-application.sh`).

If `backend.hcl` doesn't exist or remote state is not available, you can provide
the cluster name directly in `variables.tfvars`:

```hcl
cluster_name = "talo-tf-us-east-1-kc-prod"
```

#### Kubernetes Kubeconfig Auto-Update

The `set-k8s-env.sh` script automatically updates the kubeconfig file on every
run to ensure it always contains the latest cluster endpoint. This prevents issues
with stale kubeconfig entries that can occur when:

- The EKS cluster is recreated (new cluster endpoint)
- The cluster endpoint changes due to AWS infrastructure updates
- Kubeconfig becomes stale between deployment runs

**Behavior**:

- **Automatic Update**: The script runs `aws eks update-kubeconfig` on every execution
- **Uses Deployment Account Credentials**: The update uses the deployment account
role credentials (already assumed by the script)
- **Creates Directory if Needed**: Automatically creates the kubeconfig directory
if it doesn't exist
- **Error Handling**: Script exits with error if kubeconfig update fails

**Kubeconfig Path**:

- Default: `~/.kube/config`
- Can be overridden via `KUBE_CONFIG_PATH` environment variable
- Path is exported as `KUBE_CONFIG_PATH` for use by Terraform and kubectl commands

This ensures that all `kubectl` commands (including those executed by Terraform
provisioners) use the current cluster endpoint, preventing DNS lookup errors.

#### OpenLDAP Passwords (Environment Variables)

> [!IMPORTANT]
>
> Passwords must be set via environment variables, NOT in `variables.tfvars`.

The `setup-application.sh` script automatically retrieves these passwords from
AWS Secrets Manager (for local use) or GitHub repository secrets (for GitHub Actions)
and exports them as environment variables for Terraform.

> [!NOTE]
>
> For complete secrets configuration details, including AWS Secrets Manager setup,
> GitHub repository secrets, and troubleshooting, see [Secrets Requirements](../SECRETS_REQUIREMENTS.md).

#### Route53 and Domain Variables

- `domain_name`: Root domain name for Route53 hosted zone and ACM certificate
(e.g., `talorlik.com`)
  - The Route53 hosted zone and ACM certificate must already exist (code uses
  data sources)
  - The ACM certificate should cover the domain and any subdomains you plan to
  use

> [!NOTE]
>
> Hostnames for all services can be configured via variables or are
> automatically derived:
>
> - PhpLdapAdmin: `phpldapadmin.${domain_name}` (or set `phpldapadmin_host` variable)
> - LTB-passwd: `passwd.${domain_name}` (or set `ltb_passwd_host` variable)
> - 2FA App: `app.${domain_name}` (or set `app_host` variable)

#### Other OpenLDAP Variables

- `openldap_ldap_domain`: LDAP domain (e.g., `ldap.talorlik.internal`)

#### ALB Variables

- `use_alb`: Whether to create ALB resources (default: `true`)
- `ingressclass_alb_name`: Name component for ingress class (required if
`use_alb` is true)
- `ingressclassparams_alb_name`: Name component for ingress class params
(required if `use_alb` is true)
- `alb_group_name`: ALB group name for grouping multiple Ingresses (optional,
defaults to `app_name`)
  - Kubernetes identifier (max 63 characters)
  - Used to group multiple Ingresses to share a single ALB
  - Configured in IngressClassParams (cluster-wide)
- `alb_load_balancer_name`: Custom AWS ALB name (optional, defaults to
`alb_group_name` truncated to 32 chars)
  - AWS resource name (max 32 characters per AWS constraints)
  - Appears in AWS console
  - Configured in Ingress annotations (per-Ingress)
- `alb_scheme`: ALB scheme - `internet-facing` or `internal` (default:
`internet-facing`)
- `alb_ip_address_type`: ALB IP address type - `ipv4` or `dualstack` (default:
`ipv4`)
- `alb_target_type`: ALB target type - `ip` or `instance` (default: `ip`)
- `alb_ssl_policy`: ALB SSL policy for HTTPS listeners (default:
`ELBSecurityPolicy-TLS13-1-2-2021-06`)
- `phpldapadmin_host`: Hostname for PhpLdapAdmin ingress (optional, defaults to
`phpldapadmin.${domain_name}`)
- `ltb_passwd_host`: Hostname for LTB-passwd ingress (optional, defaults to
`passwd.${domain_name}`)

#### Storage Variables

- `storage_class_name`: Name component for the StorageClass (e.g., `gp3-ldap`)
- `storage_class_type`: EBS volume type (gp2, gp3, io1, io2, etc.)
- `storage_class_encrypted`: Whether to encrypt EBS volumes (default: `true`)
- `storage_class_is_default`: Whether to mark StorageClass as default (default:
`false`)

#### ArgoCD Variables

- `enable_argocd`: Whether to enable ArgoCD capability (default: `false`)
- `idc_instance_arn`: ARN of the AWS Identity Center instance
- `idc_region`: Region of the Identity Center instance
- `rbac_role_mappings`: List of RBAC role mappings for Identity Center
- `argocd_vpce_ids`: List of VPC endpoint IDs for private access (optional)
- `enable_ecr_access`: Whether to enable ECR access in ArgoCD IAM policy

#### SNS (SMS 2FA) Variables

- `enable_sms_2fa`: Enable SMS 2FA resources (default: `false`)
- `sns_topic_name`: SNS topic name component (default: `2fa-sms`)
- `sns_display_name`: SMS sender display name (default: `2FA Verification`)
- `sms_sender_id`: SMS sender ID (max 11 chars, default: `2FA`)
- `sms_type`: SMS type - `Transactional` or `Promotional` (default:
`Transactional`)
- `sms_monthly_spend_limit`: Monthly SMS budget (default: `10`)

#### PostgreSQL Variables

- `enable_postgresql`: Enable PostgreSQL deployment (default: `true`)
- `postgresql_namespace`: Kubernetes namespace (default: `ldap-2fa`)
- `postgresql_database_name`: Database name (default: `ldap2fa`)
- `postgresql_database_username`: Database username (default: `ldap2fa`)
- `postgresql_storage_size`: Storage size for PVC (default: `8Gi`)

> [!IMPORTANT]
>
> PostgreSQL password must be set via environment variable `TF_VAR_postgresql_database_password`.
> See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for configuration details.

#### SES Variables

- `enable_ses`: Enable SES email resources (default: `true`)
- `ses_sender_email`: Verified sender email address
(set in `variables.tfvars`, default: `"noreply@example.com"`)
- `ses_sender_domain`: Optional domain to verify (for DKIM)
- `ses_route53_zone_id`: Optional Route53 zone ID for automatic DNS records

#### Redis Variables

- `enable_redis`: Enable Redis deployment (default: `true`)
- `redis_namespace`: Kubernetes namespace (default: `redis`)
- `redis_storage_size`: Storage size for PVC (default: `1Gi`)
- `redis_persistence_enabled`: Enable data persistence (default: `true`)

> [!IMPORTANT]
>
> Redis password must be set via environment variable `TF_VAR_redis_password`
> (minimum 8 characters). See [Secrets Requirements](../SECRETS_REQUIREMENTS.md)
> for configuration details.

#### ECR Image Tag Variables

These variables specify the image tags for container images stored in ECR. The
images are automatically mirrored from Docker Hub to ECR by the
`mirror-images-to-ecr.sh` script before Terraform operations.

- `openldap_image_tag`: OpenLDAP image tag in ECR (default: `"openldap-1.5.0"`)
  - Corresponds to `osixia/openldap:1.5.0` from Docker Hub
  - Tag created by `mirror-images-to-ecr.sh`
- `postgresql_image_tag`: PostgreSQL image tag in ECR (default: `"postgresql-18.1.0"`)
  - Corresponds to `bitnami/postgresql:18.1.0-debian-12-r4` from Docker Hub
  - Tag created by `mirror-images-to-ecr.sh`
- `redis_image_tag`: Redis image tag in ECR (default: `"redis-8.4.0"`)
  - Corresponds to `bitnami/redis:8.4.0-debian-12-r6` from Docker Hub
  - Tag created by `mirror-images-to-ecr.sh`

> [!NOTE]
>
> The ECR registry and repository are automatically computed from the
> `backend_infra` Terraform state (`ecr_url`). You don't need to configure these
> manually.

### Example Configuration

**variables.tfvars:**

```hcl
env                         = "prod"
region                      = "us-east-1"
prefix                      = "talo-tf"

# Cluster name from remote state
backend_bucket = "talo-tf-395323424870-s3-tfstate"
backend_key    = "backend_state/terraform.tfstate"

# OpenLDAP Configuration
# Passwords set via environment variables (see above)
openldap_ldap_domain        = "ldap.talorlik.internal"

# Route53 and Domain Configuration
domain_name                 = "talorlik.com"
# Note: Route53 zone and ACM certificate must already exist
# The ACM certificate should cover the domain and wildcard subdomains (*.talorlik.com)

# ArgoCD Configuration (optional)
enable_argocd               = true
idc_instance_arn            = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
idc_region                  = "us-east-1"

# SMS 2FA Configuration (optional)
enable_sms_2fa              = true
sms_monthly_spend_limit     = 50

# PostgreSQL Configuration
enable_postgresql           = true
postgresql_storage_size     = "10Gi"

# Redis Configuration
enable_redis                = true
redis_storage_size          = "1Gi"

# SES Configuration
enable_ses                  = true
```

> [!NOTE]
>
> For secrets configuration (passwords), see [Secrets Requirements](../SECRETS_REQUIREMENTS.md).
> The `setup-application.sh` script automatically retrieves passwords from
> AWS Secrets Manager.

## Deployment

### Destroying Infrastructure

> [!WARNING]
>
> Destroying infrastructure is a **destructive operation** that permanently
> deletes all resources. This action **cannot be undone**. Always ensure you have
> backups and understand the consequences before proceeding.

#### Option 1: Using Destroy Script (Local)

```bash
cd application
./destroy-application.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and ExternalId from AWS Secrets Manager
- Retrieve password secrets from AWS Secrets Manager
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, deployment account
  role ARN, and ExternalId
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform destroy commands (init, workspace, validate, plan destroy, apply
  destroy) automatically
- **Requires confirmation**: Type 'yes' to confirm, then 'DESTROY' to proceed

#### Option 2: Using GitHub Actions Workflow

1. Go to GitHub → Actions tab
2. Select "Application Infrastructure Destroying" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

The workflow will:

- Use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations and
  Route53/ACM access
- Use environment-specific deployment account role ARN
- Use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
- Export `STATE_ACCOUNT_ROLE_ARN` for automatic injection into `variables.tfvars`
- Retrieve password secrets from GitHub repository secrets
- Run Terraform destroy operations automatically

> [!IMPORTANT]
>
> **Destroy Order**: Application infrastructure should be destroyed before backend
> infrastructure. See [Backend Infrastructure README](../backend_infra/README.md)
> for backend destroy instructions.

### Step 1: Configure Variables

1. Update `variables.tfvars` with your values:
   - Configure LDAP domain
   - Set domain name (must match existing Route53 hosted zone)
   - Ensure ACM certificate exists and covers your domain/subdomains
   - Configure ArgoCD settings if using GitOps
   - Configure SMS 2FA settings if using SMS verification

### Step 2: Configure Secrets

> [!NOTE]
>
> The `setup-application.sh` script automatically retrieves passwords from
> AWS Secrets Manager (for local use) or GitHub repository secrets (for GitHub Actions).

**Setup Instructions:**

See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for complete configuration
instructions, including:

- AWS Secrets Manager setup (for local scripts)
- GitHub Repository Secrets setup (for GitHub Actions)
- Secret names and descriptions
- Troubleshooting guide

### Step 3: ECR Image Mirroring (Automatic)

> [!NOTE]
>
> The `setup-application.sh` script automatically runs `mirror-images-to-ecr.sh`
> before Terraform operations. This step is documented here for reference.

**Purpose:**

The `mirror-images-to-ecr.sh` script eliminates Docker Hub rate limiting and
external dependencies by mirroring third-party container images to a private
ECR repository. This ensures reliable deployments without depending on Docker
Hub availability or rate limits.

**Images Mirrored:**

- `bitnami/redis:8.4.0-debian-12-r6` → `redis-8.4.0`
- `bitnami/postgresql:18.1.0-debian-12-r4` → `postgresql-18.1.0`
- `osixia/openldap:1.5.0` → `openldap-1.5.0`

**How It Works:**

1. **ECR Discovery**: Uses State Account credentials to fetch ECR URL from
   `backend_infra` Terraform state
2. **Image Check**: Checks if images already exist in ECR (skips mirroring if
   present)
3. **Docker Authentication**: Assumes Deployment Account role (with ExternalId)
   and authenticates Docker to ECR
4. **Image Pull**: Pulls images from Docker Hub
5. **Image Push**: Tags and pushes images to ECR with standardized tags
6. **Cleanup**: Removes local images after pushing to save disk space
7. **Verification**: Lists all images in ECR repository after completion

**Requirements:**

- Docker must be installed and running
- `jq` command-line tool (with fallback to sed for compatibility)
- AWS credentials configured (State Account for S3, Deployment Account for ECR)
- ECR repository must exist (created by `backend_infra`)

**Manual Execution (if needed):**

```bash
cd application
chmod +x ./mirror-images-to-ecr.sh
./mirror-images-to-ecr.sh
```

**Integration:**

- **Local Deployment**: Automatically executed by `setup-application.sh` before
  Terraform operations
- **GitHub Actions**: Automatically executed in workflow after Terraform
  validate, before `set-k8s-env.sh`

### Step 4: Deploy Application Infrastructure

#### Option 1: Using GitHub CLI (Recommended)

```bash
cd application
./setup-application.sh
```

This script will:

- Prompt you to select an AWS region (us-east-1 or us-east-2)
- Prompt you to select an environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` and assume it for backend state and
  Route53/ACM access
operations
- Retrieve the appropriate deployment account role ARN from AWS Secrets Manager
based on the selected environment:
  - `prod` → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
- Retrieve ExternalId from AWS Secrets Manager (secret: `external-id`) for
cross-account role assumption security
- **Mirror Docker images to ECR** (runs `mirror-images-to-ecr.sh` before
  Terraform operations):
  - Checks if images exist in ECR before mirroring (skips if already present)
  - Pulls images from Docker Hub: `bitnami/redis:8.4.0-debian-12-r6`,
    `bitnami/postgresql:18.1.0-debian-12-r4`, `osixia/openldap:1.5.0`
  - Pushes images to ECR with tags: `redis-8.4.0`, `postgresql-18.1.0`,
    `openldap-1.5.0`
  - Uses State Account credentials to fetch ECR URL from backend_infra state
  - Assumes Deployment Account role for ECR operations (with ExternalId)
  - Authenticates Docker to ECR automatically
  - Cleans up local images after pushing to save disk space
  - Requires Docker to be installed and running
  - Requires `jq` for JSON parsing (with fallback to sed for compatibility)
- Retrieve password secrets from AWS Secrets Manager and export them as
environment variables
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the
actual values (if it doesn't exist)
- Update `variables.tfvars` with the selected region, environment,
deployment account role ARN, and ExternalId
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!NOTE]
>
> The generated `backend.hcl` file is automatically ignored by git (see
> `.gitignore`). Only the placeholder template
> (`tfstate-backend-values-template.hcl`) is committed to the repository.

### Step 4: Configure Domain Registrar

After deployment, configure your domain registrar to use the Route53 name
servers:

```bash
# Get Route53 name servers
terraform output -json | jq -r '.route53_name_servers.value'

# Or view in AWS Console: Route53 > Hosted zones > Your domain > NS record
```

Update your domain registrar's NS records to point to these Route53 name
servers.

### Step 5: Verify Deployment

```bash
# Check Helm release status
helm list -n ldap
helm list -n redis
helm list -n ldap-2fa

# Check OpenLDAP pods
kubectl get pods -n ldap

# Check 2FA application pods
kubectl get pods -n 2fa-app

# Check PostgreSQL pods
kubectl get pods -n ldap-2fa

# Check Redis pods
kubectl get pods -n redis

# Check Ingress resources
kubectl get ingress -n ldap
kubectl get ingress -n 2fa-app

# Check ALB status (via AWS CLI)
aws elbv2 describe-load-balancers --region us-east-1

# Check Route53 hosted zone
aws route53 list-hosted-zones --query "HostedZones[?Name=='talorlik.com.']"

# Check ACM certificate status
aws acm list-certificates --region us-east-1

# Check ArgoCD capability (if enabled)
aws eks describe-capability \
  --cluster-name <cluster-name> \
  --capability-name <argocd-capability-name> \
  --capability-type ARGOCD

# Check ArgoCD applications
kubectl get application -n argocd
```

## Accessing the Services

### PhpLdapAdmin

- **URL**: `https://phpldapadmin.${domain_name}` (e.g.,
`https://phpldapadmin.talorlik.com`)
- **Access**: Internet-facing (via internet-facing ALB)
- **Login**: Use OpenLDAP admin credentials
- **Note**: Ensure DNS is properly configured at your registrar

### LTB-passwd

- **URL**: `https://passwd.${domain_name}` (e.g., `https://passwd.talorlik.com`)
- **Access**: Internet-facing (via internet-facing ALB)
- **Purpose**: Self-service password management for LDAP users
- **Note**: Ensure DNS is properly configured at your registrar

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

### LDAP Service

- **Access**: Cluster-internal only (ClusterIP service)
- **Port**: 389 (LDAP), 636 (LDAPS)
- **Not Exposed**: LDAP ports are not accessible outside the cluster

### ArgoCD (if enabled)

- **URL**: Retrieved from Terraform output `argocd_server_url`
- **Access**: Depends on configuration (private via VPC endpoints or
internet-facing)
- **Authentication**: AWS Identity Center (SSO)

## Security Considerations

1. **Internet-Facing ALB**: All UIs are accessible from the internet via a
single ALB with host-based routing (ensure proper security measures are in
place)
2. **HTTPS Only**: TLS termination at ALB with ACM certificate (automatically
validated via Route53)
3. **LDAP Internal**: LDAP service is ClusterIP only, not exposed externally
4. **Sensitive Variables**: Passwords are marked as sensitive in Terraform and
must be set via environment variables, never in `variables.tfvars`.
See [Secrets Requirements](../SECRETS_REQUIREMENTS.md) for configuration details.
5. **Encrypted Storage**: EBS volumes are encrypted by default (configurable via
`storage_class_encrypted`)
6. **Network Isolation**: Services run in private subnets
7. **Network Policies**: Kubernetes Network Policies restrict pod-to-pod
communication to secure ports only (443, 636, 8443), with cross-namespace access
enabled for LDAP service access
8. **Password Injection**: Passwords are injected at runtime via environment
variables from AWS Secrets Manager (local scripts) or GitHub Secrets (GitHub Actions),
ensuring they never appear in version control. See [Secrets Requirements](../SECRETS_REQUIREMENTS.md)
for details.
9. **DNS Validation**: ACM certificate uses DNS validation via Route53, ensuring
secure certificate provisioning
10. **EKS Auto Mode Security**: IAM permissions are automatically handled by EKS
Auto Mode (no manual policy attachment required)
11. **IRSA for SNS**: SMS 2FA uses IAM Roles for Service Accounts (no hardcoded
AWS credentials)
12. **VPC Endpoints**: SNS and STS access goes through VPC endpoints (no public
internet for SMS)
13. **Phone Number Validation**: E.164 format validation for SMS phone numbers
14. **SMS Code Expiration**: Verification codes expire after configurable
timeout
15. **Rate Limiting**: Consider implementing rate limiting for authentication
attempts

## Customization

### Modifying Helm Values

Edit `helm/openldap-values.tpl.yaml` to customize:

- LDAP ports
- Storage size
- Image tags
- Environment variables
- Ingress annotations

After modifying the template, run `terraform plan` and `terraform apply`.

### Using Secrets Instead of Plain Text

To use Kubernetes secrets instead of plain text passwords:

1. Create a Kubernetes secret with keys `LDAP_ADMIN_PASSWORD` and
`LDAP_CONFIG_ADMIN_PASSWORD`
2. Update the Helm values template to use `global.existingSecret`
3. Remove `adminPassword` and `configPassword` from the template

Example:

```yaml
global:
  existingSecret: "openldap-secrets"
  # Remove adminPassword and configPassword
```

## Troubleshooting

### Common Issues

1. **Helm Release Fails**
   - Verify EKS cluster is accessible: `kubectl get nodes`
   - Check Helm repository is accessible: `helm repo list`
   - Verify PVC exists: `kubectl get pvc -n ldap`

2. **ALB Not Created**
   - Ensure EKS Auto Mode has `elastic_load_balancing.enabled = true`
   - Check Ingress annotations are correct
   - Verify ACM certificate validation completed (check Route53 validation
   records)
   - Ensure certificate is in the same region as the EKS cluster

3. **PVC Not Found**
   - Verify PVC name matches exactly (case-sensitive)
   - Check PVC exists: `kubectl get pvc -A`
   - Ensure PVC is in the same namespace or update namespace in Helm values

4. **Cannot Access UIs**
   - Verify ALB is created: `aws elbv2 describe-load-balancers`
   - Check DNS resolution: `dig phpldapadmin.${domain_name}` or `nslookup
   phpldapadmin.${domain_name}`
   - Verify domain registrar NS records point to Route53 name servers
   - Verify security groups allow HTTPS traffic
   - Check Ingress status: `kubectl describe ingress -n ldap`
   - Verify ACM certificate is validated: `aws acm describe-certificate
   --certificate-arn <arn>`

5. **2FA Application Issues**
   - Check backend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-backend`
   - Check frontend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-frontend`
   - Verify LDAP connectivity from backend: test internal DNS resolution
   - Check IRSA role assumption: verify service account annotations

6. **SMS 2FA Not Working**
   - Verify SNS topic exists: `aws sns list-topics`
   - Check IAM role permissions: `aws iam get-role-policy`
   - Verify VPC endpoints for SNS and STS
   - Check backend logs for SNS errors
   - Verify phone number format (E.164)

7. **ArgoCD Issues**
   - Check capability status: `aws eks describe-capability`
   - Verify cluster registration secret: `kubectl get secret -n argocd`
   - Check Application sync status: `kubectl describe application -n argocd`

8. **PostgreSQL Issues**
   - Check pods: `kubectl get pods -n ldap-2fa -l app.kubernetes.io/name=postgresql`
   - Check logs: `kubectl logs -n ldap-2fa -l app.kubernetes.io/name=postgresql`
   - Check PVC: `kubectl get pvc -n ldap-2fa`
   - Test connection: `kubectl exec -it -n ldap-2fa postgresql-0 -- \
     psql -U ldap2fa -d ldap2fa`

9. **Redis Issues**
   - Check pods: `kubectl get pods -n redis -l app.kubernetes.io/name=redis`
   - Check logs: `kubectl logs -n redis -l app.kubernetes.io/name=redis`
   - Check PVC: `kubectl get pvc -n redis`
   - Test connection: `kubectl exec -it -n redis redis-master-0 -- \
     redis-cli -a $REDIS_PASSWORD ping`

10. **SES Issues**
    - Check email identity: `aws ses get-identity-verification-attributes \
      --identities your@email.com`
    - Check send quota: `aws ses get-send-quota`
    - Verify IRSA: Check service account annotation for SES IAM role

11. **User Registration Issues**
    - Check backend logs for registration errors
    - Verify PostgreSQL connectivity
    - Check SES sending limits (sandbox mode restricts recipients)
    - Verify SNS SMS spending limit

### Useful Commands

```bash
# View Helm release values
helm get values openldap-stack-ha -n ldap

# Check OpenLDAP logs
kubectl logs -n ldap -l app=openldap

# Check PhpLdapAdmin logs
kubectl logs -n ldap -l app=phpldapadmin

# Check LTB-passwd logs
kubectl logs -n ldap -l app=ltb-passwd

# Check 2FA Backend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-backend

# Check 2FA Frontend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-frontend

# View Ingress details
kubectl describe ingress -n ldap
kubectl describe ingress -n 2fa-app

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Test LDAP connectivity (from within cluster)
kubectl run -it --rm ldap-test --image=osixia/openldap --restart=Never -- bash
ldapsearch -x -H ldap://openldap-stack-ha:389 -b "dc=corp,dc=internal"

# Check ArgoCD applications
kubectl get application -n argocd
kubectl describe application -n argocd <app-name>

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
```

## Outputs

The application provides outputs for:

- `alb_dns_name`: DNS name of the ALB (extracted from Ingress resources created
by Helm chart)
  - Empty string if ALB is still provisioning or not created
  - Retrieved from either phpldapadmin or ltb-passwd Ingress status
- `route53_acm_cert_arn`: ACM certificate ARN (from data source, not module)
- `route53_domain_name`: Root domain name (from variable)
- `route53_zone_id`: Route53 hosted zone ID (from data source)
- `route53_name_servers`: Route53 name servers (from data source, for registrar
configuration)
- `argocd_server_url`: ArgoCD UI/API endpoint URL (if ArgoCD is enabled)
- `sns_topic_arn`: SNS topic ARN for SMS 2FA (if SMS 2FA is enabled)
- `sns_iam_role_arn`: IAM role ARN for IRSA (if SMS 2FA is enabled)
- `postgresql_host`: PostgreSQL service hostname (if PostgreSQL is enabled)
- `postgresql_port`: PostgreSQL service port (if PostgreSQL is enabled)
- `postgresql_database`: PostgreSQL database name (if PostgreSQL is enabled)
- `redis_host`: Redis service hostname (if Redis is enabled)
- `redis_port`: Redis service port (if Redis is enabled)
- `ses_sender_email`: Verified SES sender email (if SES is enabled)
- `ses_iam_role_arn`: IAM role ARN for SES IRSA (if SES is enabled)

View all outputs:

```bash
terraform output
```

> [!IMPORTANT]
>
> After deployment, update your domain registrar's NS records to
> point to the Route53 name servers shown in the `route53_name_servers` output.

## References

- [Helm OpenLDAP Chart](https://github.com/jp-gouin/helm-openldap)
- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode.html)
- [EKS Auto Mode IngressClassParams](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode-ingress.html)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [OpenLDAP Documentation](https://www.openldap.org/doc/)
- [PhpLdapAdmin Documentation](https://www.phpldapadmin.org/)
- [LTB-passwd Documentation](https://ltb-project.org/documentation/self-service-password)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [AWS SNS SMS Documentation](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [AWS SES Documentation](https://docs.aws.amazon.com/ses/)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Bitnami Redis Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)

## Architecture Notes

### Route53 A Records

The Terraform configuration automatically creates Route53 A (alias) records for
the subdomains:

- `phpldapadmin.${domain_name}` → ALB DNS name
- `passwd.${domain_name}` → ALB DNS name
- `app.${domain_name}` → ALB DNS name (2FA application)

These records are created after the Helm release and Ingress resources are
provisioned, ensuring the ALB DNS name is available.

### Internet-Facing ALB Configuration

The ALB is configured as `internet-facing` to enable:

- Access to UIs from anywhere on the internet
- Public accessibility for user convenience
- HTTPS-only access for secure communication
- Proper DNS configuration required for public access

### Why ClusterIP for LDAP?

The LDAP service uses ClusterIP (not LoadBalancer or NodePort) to:

- Keep LDAP ports strictly internal to the cluster
- Prevent external access to LDAP
- Only allow access from pods within the cluster
- Follow security best practices for sensitive services

### EKS Auto Mode Benefits

Using EKS Auto Mode provides:

- Automatic ALB provisioning via Ingress annotations
- No need to manually install or configure AWS Load Balancer Controller
- Simplified IAM permissions (handled automatically by EKS)
- Built-in EBS CSI driver (no manual installation needed)
- IngressClassParams support for cluster-wide ALB defaults (scheme,
ipAddressType)
- Direct integration with EKS cluster (no separate controller pods)

### Network Policies

The Network Policies module enforces security at the pod level:

- **Secure Ports Only**: Pods can only communicate on encrypted ports (443,
636, 8443)
- **Namespace Isolation**: Policies apply to all pods in the `ldap` namespace
- **Cross-Namespace Access**: Services in other namespaces can access the LDAP
service on secure ports (443, 636, 8443)
- **DNS Required**: DNS resolution is allowed for service discovery
- **External Access**: HTTPS/HTTP egress is allowed for external API calls
- **Default Deny**: All other ports are implicitly denied

This provides defense-in-depth security, ensuring that even if a pod is
compromised, it can only communicate on secure, encrypted ports. Cross-namespace
communication enables microservices in different namespaces to securely access
the centralized LDAP service.

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

### GitOps with ArgoCD

ArgoCD provides continuous delivery:

- **Managed Service**: Runs in EKS control plane (no worker node resources)
- **Git as Source of Truth**: All application state defined in Git
- **Automatic Sync**: Changes in Git trigger automatic deployments
- **Self-Healing**: Automatically corrects drift from desired state
- **Identity Center Auth**: SSO authentication via AWS Identity Center
