# Changelog

All notable changes to the OpenLDAP application infrastructure will be
documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **ExternalId Support for Cross-Account Role Assumption**
  - Added ExternalId requirement for enhanced security when assuming deployment
  account roles
  - ExternalId retrieved from AWS Secrets Manager (secret: `external-id`) for
  local deployment
  - ExternalId retrieved from GitHub repository secret (`AWS_ASSUME_EXTERNAL_ID`)
  for GitHub Actions
  - ExternalId passed to Terraform provider's `assume_role` block
  - New variable `deployment_account_external_id` added to `variables.tf`
  - Setup script (`setup-application.sh`) automatically retrieves ExternalId from
  AWS Secrets Manager
  - GitHub Actions workflow (`application_infra_provisioning.yaml`) updated to use
  `AWS_ASSUME_EXTERNAL_ID` secret
  - Deployment account roles must have ExternalId condition in Trust Relationship
  - **Bidirectional Trust Relationships**: Both deployment account roles and state
    account role must trust each other in their respective Trust Relationships
  - State account role's Trust Relationship must include deployment account role
    ARNs to enable proper cross-account role assumption
  - Prevents confused deputy attacks in multi-account deployments
  - ExternalId generation: `openssl rand -hex 32`

- **Destroy Script for Application Infrastructure**
  - Created `destroy-application.sh` script for destroying application
  infrastructure
  - Interactive region and environment selection
  - Automatic retrieval of role ARNs, ExternalId, and password secrets from AWS
  Secrets Manager
  - Automatic backend configuration and variables.tfvars updates
  - Kubernetes environment setup using `set-k8s-env.sh`
  - Safety confirmations required before destruction (type 'yes' then 'DESTROY')
  - Comprehensive error handling and user guidance
  - Updated GitHub Actions destroying workflow with ExternalId support

### Changed

- **Setup Script Improvements**
  - Enhanced `setup-application.sh` with improved error handling and ExternalId
  support
  - Automatic ExternalId retrieval from AWS Secrets Manager
  - Improved role assumption logic with better error messages
  - Enhanced secret retrieval with validation and error handling
  - Better integration with GitHub repository variables and secrets
  - Improved Kubernetes environment setup using `set-k8s-env.sh`
  - Enhanced user guidance and confirmation prompts

- **GitHub Actions Workflow Updates**
  - Updated `application_infra_provisioning.yaml` with ExternalId support and
  improved error handling
  - Updated `application_infra_destroying.yaml` with ExternalId support and
  improved error handling
  - Workflows now use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
  - Workflows now use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
  security
  - Improved environment variable handling for password secrets

- **Documentation Improvements**
  - Removed duplication by replacing detailed module descriptions with links to
  module READMEs
  - Enhanced cross-references to module documentation (ALB, ArgoCD, cert-manager,
  Network Policies, PostgreSQL, Redis, SES, SNS)
  - Updated component descriptions to be more concise with links to detailed documentation
  - Improved consistency across documentation files

- **Backend API Configuration**
  - Removed debug mode condition for API documentation endpoints
  - Swagger UI, ReDoc UI, and OpenAPI schema are now always accessible in production

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

- **ArgoCD Capability Module (`modules/argocd/`)**
  - Deploys AWS EKS managed ArgoCD service (runs in EKS control plane)
  - Creates IAM role and policies for ArgoCD capability
  - Configures AWS Identity Center (IdC) authentication
  - Registers local EKS cluster with ArgoCD
  - Sets up RBAC mappings for Identity Center groups/users
  - Optional VPC endpoint configuration for private access
  - Support for ECR and CodeCommit access policies
  - Comprehensive documentation with usage examples

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

### Changed

- **Updated main.tf**
  - Added ArgoCD capability module integration
  - Added ArgoCD application module calls
  - Configured cluster registration for GitOps

- **Updated variables.tf and variables.tfvars**
  - Added ArgoCD configuration variables
  - Added Identity Center configuration (instance ARN, region)
  - Added RBAC role mapping configuration
  - Added VPC endpoint configuration options

## [2025-12-15] - Documentation and Linting Improvements

### Changed

- **Updated documentation across all files for Markdown lint compliance**
  - Corrected row length issues to comply with markdownlint rules
  - Improved formatting consistency across all documentation files
  - Updated CHANGELOG.md, OPENLDAP-README.md, OSIXIA-OPENLDAP-REQUIREMENTS.md
  - Updated PRD-ALB.md, PRD-DOMAIN.md, PRD.md, README.md
  - Updated SECURITY-IMPROVEMENTS.md and module README files

- **Added Markdown lint configuration**
  - Added `.markdownlint.json` for consistent documentation formatting

- **Enhanced Network Policies module**
  - Added additional network policy rules in `modules/network-policies/main.tf`
  - Updated documentation in `modules/network-policies/README.md`

## [2025-12-14] - Deployment Versatility and Security Improvements

### Changed

- **Network Policies: Enabled cross-namespace communication for LDAP service
access**
  - Updated network policies to allow services in other namespaces to access the
  LDAP service on secure ports (443, 636, 8443)
  - Added ingress rules using `namespace_selector {}` to enable cross-namespace
  communication
  - Maintains security by only allowing encrypted ports (HTTPS, LDAPS)
  - Updated documentation across all relevant files to reflect cross-namespace
  communication capability
  - Enables microservices in different namespaces to securely access the
  centralized LDAP service

- **Password management workflow**
  - OpenLDAP passwords are now exclusively managed through GitHub repository
  secrets
  - Removed dependency on local password files or manual environment variable
  setup
  - Setup script automatically handles password retrieval and export
  - Updated documentation to reflect new password management approach

- **Updated AWS provider configuration for multi-account architecture**
  - Removed `provider_profile` variable from `variables.tf` and
  `variables.tfvars`
  - Removed `profile = var.provider_profile` from `providers.tf`
  - Provider now uses role assumption via `deployment_account_role_arn` variable
  instead of AWS profiles
  - Aligns with environment-based role selection (production/development
  accounts)
  - Backend state operations use `AWS_STATE_ACCOUNT_ROLE_ARN` (configured in
  workflows/setup scripts)
  - Deployment operations use environment-specific role ARNs via `assume_role`
  configuration

- **Updated GitHub Actions workflows for application infrastructure**
  - `application_infra_provisioning.yaml`: Now uses `AWS_STATE_ACCOUNT_ROLE_ARN`
  for backend operations
  - `application_infra_destroying.yaml`: Now uses `AWS_STATE_ACCOUNT_ROLE_ARN`
  for backend operations
  - Both workflows automatically set `deployment_account_role_arn` variable
  based on selected environment:
    - `prod` environment → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
    - `dev` environment → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
  - Ensures proper separation between state account (S3) and deployment accounts
  (resource creation)

### Added

- **Automated OpenLDAP password retrieval from GitHub secrets**
  - `setup-application.sh` now automatically retrieves OpenLDAP passwords from
  GitHub repository secrets
  - Script checks for `TF_VAR_OPENLDAP_ADMIN_PASSWORD` and
  `TF_VAR_OPENLDAP_CONFIG_PASSWORD`, `TF_VAR_POSTGRESQL_PASSWORD`,
  and `TF_VAR_REDIS_PASSWORD` secrets (exported as lowercase `TF_VAR_openldap_admin_password`,
  `TF_VAR_openldap_config_password`, `TF_VAR_postgresql_database_password`,
  and `TF_VAR_redis_password` to match `variables.tf`)
  - Automatically exports passwords as environment variables for Terraform
  - Supports both GitHub Actions (secrets automatically available) and local
  execution (requires exported environment variables)
  - Eliminates need for manual password file management

- **Unified application setup script**
  - New `setup-application.sh` script consolidates all application deployment
  steps
  - Handles role assumption, backend configuration, Terraform operations, and
  Kubernetes environment setup
  - Automatically retrieves all required secrets and variables from GitHub
  - Replaces previous `setup-backend.sh` and `setup-backend-api.sh` scripts
  - Includes comprehensive error handling and user guidance

### Removed

- **Legacy setup scripts**
  - Removed `setup-backend.sh` (replaced by unified `setup-application.sh`)
  - Removed `setup-backend-api.sh` (replaced by unified `setup-application.sh`)
  - Consolidated functionality improves maintainability and reduces complexity

### Fixed

- Corrected documentation to reflect new password management via GitHub
repository secrets
  - Updated README.md with accurate password setup instructions
  - Clarified local vs. GitHub Actions execution differences

## [2025-12-10] - Ingress Configuration Updates

### Changed

- **Moved certificate ARN and group name to IngressClassParams (cluster-wide
configuration)**
  - Certificate ARN (`certificateARNs`) is now configured in IngressClassParams
  instead of Ingress annotations
  - ALB group name (`group.name`) is now configured in IngressClassParams
  instead of Ingress annotations
  - This centralizes TLS and group configuration at the cluster level, reducing
  annotation duplication
  - Updated `modules/alb/main.tf` to include `certificateARNs` and `group.name`
  in IngressClassParams
  - Updated Helm values template to remove `group.name` and `certificate-arn`
  from Ingress annotations
  - All Ingresses now use the same annotations (no leader/secondary distinction
  needed for group/certificate config)
  - Updated documentation in `PRD-ALB.md` and `README.md` to reflect new
  annotation strategy

### Verified

- Multi-ingress single ALB configuration is correctly implemented with EKS Auto
Mode
  - Both Ingresses share the same ALB via `group.name` configured in
  IngressClassParams
  - Certificate ARN configured once in IngressClassParams (cluster-wide)
  - `load-balancer-name` annotation on both Ingresses (per-Ingress setting)
  - Per-Ingress settings (target-type, listen-ports, ssl-redirect) configured in
  Ingress annotations
  - Cluster-wide defaults (`scheme`, `ipAddressType`, `group.name`,
  `certificateARNs`) inherited from IngressClassParams

## [2025-12-08] - ALB and TLS Configuration Updates

### Changed

- **Migrated from AWS Load Balancer Controller to EKS Auto Mode**
  - Updated ALB controller from `alb.ingress.kubernetes.io` to
  `eks.amazonaws.com/alb`
  - Changed IngressClassParams API group from `elbv2.k8s.aws` to
  `eks.amazonaws.com`
  - EKS Auto Mode provides built-in load balancer driver (no separate controller
  installation needed)
  - IAM permissions are automatically handled by EKS Auto Mode (no manual policy
  attachment required)
  - Updated `modules/alb/main.tf` to use EKS Auto Mode controller and API group

- **Improved ALB naming with separate group name and load balancer name**
  - Added distinction between `alb_group_name` (Kubernetes identifier, max 63
  chars) and `alb_load_balancer_name` (AWS resource name, max 32 chars)
  - Added automatic truncation logic to ensure names don't exceed Kubernetes (63
  chars) and AWS (32 chars) limits
  - Updated `main.tf` to handle name concatenation with prefix, region, and env,
  with proper truncation
  - Added `alb_load_balancer_name` variable to `variables.tf` with proper
  description
  - Updated Helm values template to use `alb_load_balancer_name` for AWS ALB
  name annotation

- **Optimized Ingress annotations to minimize duplication** (superseded by
cluster-wide IngressClassParams configuration)
  - Certificate ARN and group name moved to IngressClassParams (see latest
  changes above)
  - Ingress annotations now only contain per-Ingress settings
  (load-balancer-name, target-type, listen-ports, ssl-redirect)

- Updated TLS environment variables in `helm/openldap-values.tpl.yaml` to match
osixia/openldap image requirements
  - Changed `LDAP_TLS_CERT_FILE` → `LDAP_TLS_CRT_FILENAME` (filename only, not
  full path)
  - Changed `LDAP_TLS_KEY_FILE` → `LDAP_TLS_KEY_FILENAME` (filename only, not
  full path)
  - Changed `LDAP_TLS_CA_FILE` → `LDAP_TLS_CA_CRT_FILENAME` (filename only, not
  full path)
  - Added explicit `LDAP_TLS: "true"` to enable TLS
  - Updated comments to clarify osixia/openldap-specific behavior

### Added

- **New variable `alb_load_balancer_name`** for custom AWS ALB naming
  - Allows separate control over Kubernetes group identifier vs AWS resource
  name
  - Supports AWS naming constraints (max 32 characters)
  - Defaults to `alb_group_name` (truncated to 32 chars if needed)

- **Comprehensive documentation updates in `PRD-ALB.md`**
  - Added detailed explanation of EKS Auto Mode vs AWS Load Balancer Controller
  differences
  - Added comparison table highlighting key differences between the two
  approaches
  - Documented IngressClassParams limitations (only `scheme` and `ipAddressType`
  supported in EKS Auto Mode)
  - Clarified annotation strategy and inheritance patterns
  - Added implementation details section explaining Terraform and Helm chart
  responsibilities

### Fixed

- Fixed TLS configuration compatibility issue between Helm chart (designed for
Bitnami) and osixia/openldap image
  - osixia/openldap uses different environment variable names than Bitnami
  OpenLDAP
  - Certificates are now referenced by filename only (not full paths)
  - osixia/openldap will auto-generate self-signed certificates if they don't
  exist

## [2025-12-02] - Initial Configuration

### Added

- Initial OpenLDAP deployment using osixia/openldap:1.5.0 image
- Helm chart from jp-gouin/helm-openldap (version 4.0.1)
- Multi-master replication configuration (3 replicas)
- Persistent storage with EBS volumes (8Gi, ReadWriteOnce)
- ALB configuration with IngressGroup for multiple Ingresses
- TLS termination at ALB using ACM certificates
- Two Ingress resources:
  - phpldapadmin.talorlik.com → phpLDAPadmin service
  - passwd.talorlik.com → ltb-passwd service
- Route53 DNS records for both hostnames pointing to ALB

### Configuration Details

- **Image**: osixia/openldap:1.5.0 (overriding chart's default Bitnami image)
- **Replication**: Multi-master replication enabled
- **Storage**: Persistent volumes with gp3 storage class
- **ALB**: Internet-facing, IP target type, TLS 1.2/1.3 only
- **TLS**: Auto-generated certificates for internal communication, ACM
certificates for ALB

## Planned Changes

### [Future] - Custom Certificate Support

- [ ] Add support for mounting custom TLS certificates from Kubernetes Secrets
- [ ] Implement cert-manager integration for automatic certificate management
- [ ] Add documentation for using ACM certificates with OpenLDAP

### [Future] - Security Enhancements

- [ ] Enforce TLS for all LDAP connections (`LDAP_TLS_ENFORCE: "true"`)
- [ ] Implement client certificate verification for enhanced security
- [x] ~~Add network policies for stricter pod-to-pod communication~~ (Completed
2025-12-14)

### [Future] - Monitoring and Observability

- [ ] Add Prometheus metrics export for OpenLDAP
- [ ] Implement logging aggregation for LDAP operations
- [ ] Add health check endpoints for better monitoring

### [Future] - High Availability Improvements

- [ ] Evaluate read-only replica configuration
- [ ] Implement backup automation for LDAP data
- [ ] Add disaster recovery procedures

### [Future] - GitOps Enhancements

- [x] ~~Implement ArgoCD for GitOps deployments~~ (Completed 2025-12-16)
- [ ] Add ApplicationSet for multi-cluster deployments
- [ ] Implement progressive delivery with Argo Rollouts

### [Future] - 2FA Application Enhancements

- [x] ~~Implement 2FA application with TOTP support~~ (Completed 2025-12-18)
- [x] ~~Add SMS-based verification via AWS SNS~~ (Completed 2025-12-18)
- [x] ~~Replace in-memory SMS OTP storage with Redis~~ (Completed 2025-12-18)
- [x] ~~Add self-service user signup with email/phone verification~~ (Completed
2025-12-18)
- [x] ~~Implement admin dashboard for user management~~ (Completed 2025-12-18)
- [x] ~~Add group management and user-group assignment~~ (Completed 2025-12-18)
- [x] ~~Add user profile management~~ (Completed 2025-12-18)
- [ ] Add email-based MFA verification option
- [ ] Implement backup codes for account recovery
- [ ] Add rate limiting for authentication attempts
- [ ] Add password reset functionality

## Verification Steps

After applying changes, verify the configuration:

### TLS Configuration Verification

```bash
kubectl get configmap -n ldap openldap-stack-ha-openldap-env -o yaml | grep LDAP_TLS
```

Expected output:

- `LDAP_TLS: "true"`
- `LDAP_TLS_CRT_FILENAME: "ldap.crt"`
- `LDAP_TLS_KEY_FILENAME: "ldap.key"`
- `LDAP_TLS_CA_CRT_FILENAME: "ca.crt"`

### ALB Configuration Verification

```bash
kubectl get ingress -n ldap
kubectl describe ingress -n ldap openldap-stack-ha-ltb-passwd
kubectl describe ingress -n ldap openldap-stack-ha-phpldapadmin
```

Both Ingresses should:

- Use the same IngressClass (which references IngressClassParams with
`group.name` and `certificateARNs`)
- Point to the same ALB DNS name
- Have the same `alb.ingress.kubernetes.io/load-balancer-name` annotation

### TLS Connection Testing

```bash
# Test LDAPS connection (port 636)
ldapsearch -x -H ldaps://openldap-stack-ha-openldap-0.openldap-stack-ha-openldap-headless.ldap.svc.cluster.local:636 -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w <password>

# Test LDAP connection (port 389)
ldapsearch -x -H ldap://openldap-stack-ha-openldap-0.openldap-stack-ha-openldap-headless.ldap.svc.cluster.local:389 -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w <password>
```

### ALB TLS Verification

```bash
# Check ALB listeners
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>
```

Expected:

- HTTP listener on port 80 (redirecting to HTTPS)
- HTTPS listener on port 443 with ACM certificate

## Notes

### Certificate Auto-Generation

osixia/openldap will automatically generate self-signed certificates on first
startup if they don't exist. These certificates:

- ✅ Work for internal cluster communication
- ✅ Enable LDAPS (port 636)
- ⚠️ Won't be trusted by external clients (self-signed)
- ⚠️ Will be regenerated if the container is recreated without persistent
storage

### Using Custom Certificates

To use custom certificates (e.g., from cert-manager or ACM):

1. Create a Kubernetes Secret:

    ```bash
    kubectl create secret generic openldap-tls-certs \
      --from-file=ldap.crt=/path/to/cert.pem \
      --from-file=ldap.key=/path/to/key.pem \
      --from-file=ca.crt=/path/to/ca.pem \
      -n ldap
    ```

2. Add volume mounts to Helm values:

    ```yaml
    extraVolumes:
      - name: tls-certs
        secret:
          secretName: openldap-tls-certs

    extraVolumeMounts:
      - name: tls-certs
        mountPath: /container/service/slapd/assets/certs
        readOnly: true
    ```

### Multi-Ingress Single ALB

The configuration implements a single ALB with multiple Ingresses:

- ✅ Both Ingresses share the same `group.name` (configured in
IngressClassParams)
- ✅ Certificate ARN configured once in IngressClassParams (cluster-wide)
- ✅ `load-balancer-name` annotation on both Ingresses (per-Ingress setting)
- ✅ Per-Ingress settings (target-type, listen-ports, ssl-redirect) in Ingress
annotations
- ✅ Host-based routing (different hosts for each service)

The ALB routes traffic based on the `Host` header:

- `phpldapadmin.talorlik.com` → phpLDAPadmin service
- `passwd.talorlik.com` → ltb-passwd service

## References

- [osixia/openldap GitHub](https://github.com/osixia/docker-openldap)
- [osixia/openldap TLS Documentation](https://github.com/osixia/docker-openldap#tls)
- [AWS Load Balancer Controller IngressGroups](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#ingressgroup)
- [jp-gouin/helm-openldap GitHub](https://github.com/jp-gouin/helm-openldap)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
