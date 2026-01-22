# Changelog

All notable changes to the 2FA application components will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
>
> This changelog contains application-related changes (PostgreSQL, Redis, SES, SNS,
> 2FA application backend/frontend, ArgoCD Applications). Infrastructure changes
> (OpenLDAP, ALB, Route53, ArgoCD Capability) are documented in
> [application_infra/CHANGELOG.md](../application_infra/CHANGELOG.md).

## [2026-01-21] - Backend State Configuration Standardization

### Changed

- **Backend State Template Configuration**
  - Updated `tfstate-backend-values-template.hcl` to use `APPLICATION_PREFIX` placeholder
  - State file key now uses repository variable `APPLICATION_PREFIX` (value: `application_state/terraform.tfstate`)
  - Simplified template to use direct prefix variable instead of constructing path
  - Ensures consistent state file naming across all deployment methods

- **Setup and Destroy Scripts**
  - Updated `setup-application.sh` to use `APPLICATION_PREFIX` directly from GitHub repository variables
  - Updated `destroy-application.sh` to use `APPLICATION_PREFIX` directly from GitHub repository variables
  - Removed logic that constructed state prefix path (now handled by repository variable value)
  - Scripts now replace `<APPLICATION_PREFIX>` placeholder with repository variable value

- **GitHub Workflows**
  - Updated `application_provisioning.yaml` to use `APPLICATION_PREFIX` repository variable
  - Updated `application_destroying.yaml` to use `APPLICATION_PREFIX` repository variable
  - Removed hardcoded path construction (now uses variable value directly)

### Added

- **Backend State Configuration Documentation**
  - Added comprehensive "Backend State Configuration" section to `README.md`
  - Documented state file configuration, template usage, and generation process
  - Documented required repository variables (`BACKEND_BUCKET_NAME`, `APPLICATION_PREFIX`)
  - Documented state file isolation between `application_infra` and `application`
  - Clarified that both directories use same bucket but different keys

### Fixed

- **State File Key Consistency**
  - Fixed state file key to use consistent naming: `application_state/terraform.tfstate`
  - Ensured all scripts and workflows use the same prefix variable
  - Eliminated discrepancies between bash scripts and GitHub workflows

## [2026-01-20] - Comprehensive Documentation Updates for Backend and Frontend

### Added

- **Backend API Documentation (`backend/README.md`)**
  - Comprehensive backend API documentation covering all features and endpoints
  - Complete architecture overview with component diagrams
  - Detailed installation and configuration instructions
  - Docker setup guide with multi-stage build process documentation
  - API endpoint reference with request/response schemas
  - Development guidelines and best practices
  - Security considerations and deployment instructions
  - Health check and scaling documentation

- **Frontend Application Documentation (`frontend/README.md`)**
  - Complete frontend application documentation
  - Architecture diagrams showing deployment flow and routing patterns
  - Detailed feature documentation (authentication, registration, MFA enrollment,
  profile management, admin dashboard)
  - nginx configuration documentation
  - Helm chart configuration reference
  - Container image deployment guide with security features
  - Local development setup instructions
  - Code structure and organization documentation
  - Security features and browser support information
  - API integration documentation
  - Troubleshooting guide and testing checklist

### Changed

- **Application Deployment Documentation (`README.md`)**
  - Enhanced frontend port configuration documentation with security details
  - Added explicit mention of non-root user (`appuser`, UID 1000) for frontend container
  - Clarified service port (80) vs container port (8080) relationship
  - Added security consideration about non-root container execution
  - Updated frontend section with security enhancement details

- **Documentation Consistency**
  - Ensured all documentation reflects latest backend and frontend changes
  - Updated port configurations across all relevant documentation files
  - Verified consistency between README files and actual implementation
  - Aligned security documentation with current container security practices

### Documentation

- **Comprehensive Component Documentation**
  - Backend README provides complete reference for API development and deployment
  - Frontend README serves as full guide for frontend development and deployment
  - Both READMEs include troubleshooting sections and best practices
  - Documentation covers all aspects from local development to production deployment

## [2026-01-20] - Frontend Security Enhancement: Non-Root Container Port Configuration

### Changed

- **Frontend Container Port Configuration**
  - Changed frontend container port from 80 to 8080 to support running as
  non-root user
  - Frontend container now runs as non-root user (`appuser`, UID 1000) for
  improved security
  - Kubernetes service port remains 80 (external interface unchanged)
  - Container port 8080 is internal only; service port 80 forwards to container
  port 8080
  - Updated nginx configuration to listen on port 8080
  - Updated Dockerfile health check to use port 8080
  - Updated Helm values to include separate `containerPort` (8080) and `service.port`
  (80) configuration
  - No impact on external access or frontend-backend communication
  (routing handled by ALB)

### Security

- **Non-Root Container Execution**
  - Frontend container no longer requires root privileges to bind to port 80
  - Reduced attack surface by running container as unprivileged user
  - Follows security best practices for containerized applications

## [2025-12-20] - Swagger UI for API Documentation

- **API Documentation (Swagger UI)**
  - FastAPI Swagger UI now always enabled at `/api/docs` (previously only available
  in debug mode)
  - ReDoc UI always available at `/api/redoc`
  - OpenAPI schema accessible at `/api/openapi.json`
  - Interactive API documentation automatically updates when endpoints change
  - Documentation updated in README.md and PRD-2FA-APP.md to reflect availability

## [2025-12-18] - Admin Functions and User Profile Management

### Added

- **Admin Dashboard and User Management**
  - Admin tab visible only to LDAP admin group members
  - User management section with comprehensive user details view
  - Filter users by status (pending, complete, active, revoked)
  - View user details: name, email, phone, verification status, MFA method,
  group memberships
  - Activation and revocation workflow with audit logging

- **User Profile Management**
  - Profile page with viewable and editable fields
  - Edit restrictions: email/phone read-only after verification
  - Profile fields: username, first/last name, email, phone, MFA method, status

- **Group Management (Full CRUD)**
  - Create, read, update, delete groups via admin interface
  - Group-user assignment management
  - Sync with LDAP groups on create/update/delete
  - View group members and member counts

- **Approve/Revoke Workflow**
  - Approval requires group assignment (at least one group)
  - Creates user in LDAP with all attributes on approval
  - Adds user to selected LDAP groups
  - Sends welcome email on activation
  - Revocation removes user from LDAP and all groups

- **List Features**
  - Sortable columns with visual indicators
  - Filtering by status and group membership
  - Real-time search for users and groups

- **Admin Notifications**
  - Email notification to all admins on new user signup
  - Uses existing AWS SES infrastructure
  - Async notification (non-blocking)

- **Top Navigation Bar**
  - Persistent navigation after login
  - User menu with profile and logout options
  - Admin-specific menu items for admin users

- **Email Client Module (`app/email/`)**
  - AWS SES integration for sending emails
  - Email templates for verification and welcome emails
  - IRSA-based authentication for SES access

- **Database Models**
  - Extended user model with profile fields
  - Group model for LDAP group management
  - UserGroup model for user-group relationships

### Changed

- **Updated `routes.py`**
  - Added profile management endpoints (`/api/profile/{username}`)
  - Added admin endpoints for user and group management
  - Added admin authentication and authorization checks

- **Updated Frontend**
  - Added admin dashboard UI components
  - Added profile page with edit functionality
  - Added top navigation bar component
  - Enhanced CSS with admin-specific styles

## [2025-12-18] - User Signup Management System

### Added

- **Self-Service User Registration**
  - Signup form with fields: first name, last name, username, email, phone,
  password, MFA method
  - Username validation (3-64 chars, alphanumeric + underscore/hyphen)
  - Email and phone uniqueness validation
  - Password hashing with bcrypt

- **Email Verification via AWS SES**
  - UUID token-based verification links
  - 24-hour token expiry (configurable)
  - Resend verification with 60-second cooldown
  - Email delivery via AWS SES with IRSA

- **Phone Verification via AWS SNS**
  - 6-digit OTP code via SMS
  - 1-hour code expiry
  - Resend code with 60-second cooldown
  - SMS delivery via AWS SNS with IRSA

- **Profile State Management**
  - PENDING: User registered, verification incomplete
  - COMPLETE: All verifications complete, awaiting admin
  - ACTIVE: Admin activated, exists in LDAP

- **Login Restrictions**
  - PENDING users cannot login (shows missing verifications)
  - COMPLETE users see "awaiting admin approval" message
  - Only ACTIVE users can complete login flow

- **PostgreSQL Module (`modules/postgresql/`)**
  - Bitnami PostgreSQL Helm chart deployment
  - Database for user registrations and verification tokens
  - Password authentication from GitHub Secrets
  - PersistentVolume storage with RDB
  - Uses StorageClass from `application_infra` remote state

- **SES Module (`modules/ses/`)**
  - AWS SES email identity verification
  - IAM Role with IRSA for secure pod access
  - Email sending for verification and notifications
  - Sender email configuration

- **Database Connection Module (`app/database/`)**
  - PostgreSQL connection management
  - SQLAlchemy models for users and verification tokens
  - Async database operations

- **New API Endpoints**
  - `POST /api/auth/signup` - Register new user
  - `POST /api/auth/verify-email` - Verify email with token
  - `POST /api/auth/verify-phone` - Verify phone with code
  - `POST /api/auth/resend-verification` - Resend verification
  - `GET /api/profile/status/{username}` - Get profile status

- **Product Requirements Document (PRD-SIGNUP-MAN.md)**
  - Comprehensive documentation of signup system
  - User stories and acceptance criteria
  - Data models and API specifications
  - UI mockups and deployment checklist

### Changed

- **Updated `main.tf`**
  - Added PostgreSQL module invocation
  - Added SES module invocation
  - Added related variables and outputs
  - References StorageClass from `application_infra` remote state

- **Updated `variables.tf`**
  - Added PostgreSQL configuration variables
  - Added SES configuration variables
  - Added database URL and email settings

- **Updated Backend Helm Chart**
  - Added PostgreSQL environment variables
  - Added SES environment variables
  - Added database connection configuration

- **Updated Frontend**
  - Added signup form with validation
  - Added verification status panel
  - Added resend verification functionality
  - Enhanced error messages for login restrictions

## [2025-12-18] - Redis SMS OTP Storage

### Added

- **Redis Module (`modules/redis/`) for SMS OTP Code Storage**
  - Bitnami Redis Helm chart deployment via Terraform
  - Standalone architecture (sufficient for OTP cache use case)
  - Password authentication via Kubernetes Secret (from GitHub Secrets)
  - PersistentVolume storage with RDB snapshots for data recovery
  - Non-root security context (UID 1001)
  - Network policy restricting Redis access to backend pods only
  - TTL-based automatic expiration for OTP codes
  - Uses StorageClass from `application_infra` remote state

- **Redis Client Module (`app/redis/`)**
  - `RedisOTPClient` class with TTL-aware storage operations
  - Automatic fallback to in-memory storage when Redis is disabled
  - Methods: `store_code()`, `get_code()`, `delete_code()`, `code_exists()`
  - Connection health checking and error handling
  - Lazy initialization with connection pooling

- **Configuration Updates**
  - Redis configuration settings in `config.py`
  - Helm chart values for Redis connection parameters
  - ConfigMap entries for Redis environment variables
  - Secret reference for Redis password in deployment

- **GitHub Actions Updates**
  - Added `TF_VAR_redis_password` environment variable for Redis password
  - Password sourced from `TF_VAR_REDIS_PASSWORD` GitHub Secret (secret name remains
  uppercase, but exported as lowercase to match `variables.tf`)

### Changed

- **Updated `routes.py` for Redis Integration**
  - `send_sms_code` endpoint now stores OTP codes in Redis with automatic TTL
  - `login` endpoint now retrieves and verifies OTP codes from Redis
  - Graceful fallback to in-memory storage when Redis is disabled
  - Returns 503 Service Unavailable if Redis fails during code storage

- **Updated Backend Helm Chart**
  - Added Redis configuration section in `values.yaml`
  - Added Redis environment variables in `configmap.yaml`
  - Added Redis password secret reference in `deployment.yaml`

### Documentation

- Added `modules/redis/README.md` with:
  - Architecture diagram showing backend-Redis communication
  - Redis key schema documentation
  - Debugging commands for Redis CLI
  - Usage examples and configuration options

## [2025-12-18] - 2FA Application and SMS Integration

### Added

- **Full 2FA Application (Backend + Frontend)**
  - Python FastAPI backend with LDAP authentication integration
  - Support for **two MFA methods**:
    - **TOTP (Time-based One-Time Password)** - Using authenticator apps (Google
    Authenticator, Authy, etc.)
    - **SMS** - Verification codes sent via AWS SNS
  - Static HTML/JS/CSS frontend with modern, responsive UI
  - Single domain routing pattern (`app.<domain>`) with path-based routing:
    - `/` → Frontend
    - `/api/*` → Backend API
  - Complete Helm charts for both backend and frontend deployments
  - Docker files for containerized deployment
  - Kubernetes resources: Deployment, Service, Ingress, ConfigMap, Secret,
  ServiceAccount, HPA

- **SNS Module for SMS-based 2FA Verification**
  - SNS Topic for centralized SMS notifications
  - IAM Role configured for IRSA (IAM Roles for Service Accounts)
  - Direct SMS support for sending verification codes to phone numbers
  - E.164 phone number format support
  - Transactional SMS type for higher delivery priority
  - Cost control via monthly spend limits

- **Product Requirements Document (PRD-2FA-APP.md)**
  - Comprehensive documentation of 2FA application architecture
  - API endpoint specifications for all authentication flows
  - Frontend component and state machine documentation
  - Security considerations and error handling patterns

### Changed

- **Updated variables.tf and variables.tfvars**
  - Added 2FA application configuration variables
  - Added SNS topic configuration
  - Added backend/frontend deployment settings

## [2025-12-16] - ArgoCD GitOps Integration

### Added

- **ArgoCD Application Module (`modules/argocd_app/`)**
  - Creates ArgoCD Application CRD for GitOps deployments
  - Configures source (Git repository, path, revision) and destination
  (cluster, namespace)
  - Supports multiple deployment types:
    - Plain Kubernetes manifests
    - Helm charts with value files and parameters
    - Kustomize with image overrides and common labels
  - Sync policy configuration (automated/manual)
  - Retry policies with backoff configuration
  - Ignore differences for externally managed fields
  - Multi-application pattern support
  - Depends on ArgoCD Capability from `application_infra` remote state

### Changed

- **Updated main.tf**
  - Added ArgoCD application module calls for backend and frontend
  - Configured cluster registration using ArgoCD Capability outputs from infrastructure
  - References ArgoCD namespace and project name from `application_infra` remote state

- **Updated variables.tf and variables.tfvars**
  - Added ArgoCD Application configuration variables
  - Added repository URL and path configuration
  - Added sync policy configuration options

## Planned Changes

### [Future] - 2FA Application Enhancements

- [x] ~~Implement 2FA application with TOTP support~~ (Completed 2025-12-18)
- [x] ~~Add SMS-based verification via AWS SNS~~ (Completed 2025-12-18)
- [x] ~~Replace in-memory SMS OTP storage with Redis~~ (Completed 2025-12-18)
- [x] ~~Add self-service user signup with email/phone verification~~ (Completed 2025-12-18)
- [x] ~~Implement admin dashboard for user management~~ (Completed 2025-12-18)
- [x] ~~Add group management and user-group assignment~~ (Completed 2025-12-18)
- [x] ~~Add user profile management~~ (Completed 2025-12-18)
- [ ] Add email-based MFA verification option
- [ ] Implement backup codes for account recovery
- [ ] Add rate limiting for authentication attempts
- [ ] Add password reset functionality
