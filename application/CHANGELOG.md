# Changelog

All notable changes to the 2FA application components will be documented in this
file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
>
> This changelog contains application-related changes (PostgreSQL, Redis, SES, SNS,
> 2FA application backend/frontend, ArgoCD Applications). Infrastructure changes
> (OpenLDAP, ALB, Route53, ArgoCD Capability) are documented in
> [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).

## [2026-02-27] - Frontend Blank Page and Logout Display

### Fixed

- **2FA frontend blank page after login and menu pages**
  - Auth and app content are now separate views. `#auth-view` wraps login,
  signup, and reset-password; `#app-view` wraps profile, user management, and
  group management. When logged in, only `#app-view` is shown and
  `hideAllSections()` / `showSection()` only toggle sections inside it, so
  Profile and other menu pages display correctly.

- **2FA frontend logout: tabs visible but forms hidden until refresh**
  - On logout the UI switches back to `#auth-view` and the login tab is
  explicitly set active and visible. Tab handling is scoped to `#auth-view` so
  Login/Sign Up no longer affect app sections.

### Changed

- **2FA frontend view structure** (`index.html`, `main.js`)
  - Added `#auth-view` and `#app-view` wrappers. `showLoggedInState()` hides
  auth-view and shows app-view; `showLoggedOutState()` does the reverse.
  `setupTabs()` uses `#auth-view .tab-btn` and `#auth-view .tab-content` so
  tab clicks only change auth content.

## [2026-02-26] - Frontend Form Post, QR Code Library, and Redis Required

### Fixed

- **2FA frontend form submission**
  - Added null checks in `main.js` before attaching form and UI handlers
  (login, signup, enrollment, profile, forgot-password, top bar, admin users,
  admin groups) so submission works correctly when the current view does not
  yet have those DOM elements (e.g. during init or tab switch).
  - QRCode.js CDN version set to `1.4.4` (from `1.5.3`) for reliable form
  posting and QR display during TOTP enrollment.

### Changed

- **Login and Redis**
  - Login flow now stores all challenges in Redis only (no in-memory fallback).
  - `POST /api/auth/login/start` returns 503 "Storage unavailable" if Redis is
    down; TOTP setup, login verify, and SMS send/verify also require Redis and
    return 503 when Redis is unavailable.
  - Backend README, Redis client docstrings, and application docs updated to
    state Redis is required for SMS OTP and login challenge storage.

- **Admin-seed job: LDAP headless host**
  - Admin-seed job now receives `LDAP_HEADLESS_HOST` from application_infra
  outputs. `seed_admin.py` uses this to build OpenLDAP replica pod DNS names
  (e.g. `openldap-stack-ha-0.openldap-stack-ha-headless.ldap.svc.cluster.local`),
  fixing "invalid server address" when connecting to replicas. Previously the
  job used the ClusterIP service host, which does not resolve to individual pods.

## [2025-02-23] - Admin-Seed, Image Tags, and LDAP Fixes

### Added

- **LDAP and Admin-Seed-Job Troubleshooting Guide**
  - Created comprehensive troubleshooting document
  [LDAP and Admin-Seed Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED_TROUBLESHOOTING.md)
  documenting persistent LDAP issues, investigation timeline, root causes,
  ad-hoc manual corrections, and permanent code fixes
  - Includes verification commands and lessons learned

- **LDAPClient Group Membership Handling**
  - Added `_get_group_object_class()` method to detect group objectClass and
  use correct membership attribute (`uniqueMember` for `groupOfUniqueNames`,
  `member` for `groupOfNames`, `memberUid` for `posixGroup`)
  - Added `update_user()` method to update existing LDAP user attributes
  - Added `create_or_update_user()` method for idempotent user creation/update
  - Fixed `add_user_to_group()` and `remove_user_from_group()` to detect group
  objectClass before modifying membership

- **Idempotent Admin Seeding**
  - Updated `seed_admin.py` to use `create_or_update_user()` instead of
  `create_user()` so the seed job doesn't fail if the user already exists
  - Fixed AsyncSessionLocal import for proper database session handling

- **Image Tag Validation**
  - Added validation to `backend_image_tag` and `frontend_image_tag` variables
  to reject `"latest"` (which doesn't exist in ECR)
  - Added lifecycle precondition to admin-seed job requiring non-empty
  `backend_image_tag`
  - Updated `setup-application.sh` to fail early with error if image tag
  extraction fails or returns `"latest"`
  - Updated `04-application_provisioning.yaml` workflow with same fail-early behavior
  - Changed variable defaults from `"latest"` to `""` (empty) to force explicit
  setting from Helm values
  - ECR uses commit-based tags (e.g., `ldap-2fa-backend-<sha>-<run_id>`); the
  Backend Build workflow updates Helm values with correct tags

- **Destroy Script/Workflow Image Tag Handling**
  - Updated `destroy-application.sh` and `04-application_destroying.yaml` to use
  empty string as fallback when image tag extraction fails (instead of `"latest"`)
  - Empty string passes validation and is acceptable for destroy operations
  since Terraform doesn't need valid tags to destroy resources
  - Added check to reject `"latest"` even if extracted from Helm values

- **setup-application.sh: Image tags from Helm values and scripts/set-k8s-env.sh**
  - Backend and frontend image tags are read from
  `backend/helm/ldap-2fa-backend/values.yaml` and
  `frontend/helm/ldap-2fa-frontend/values.yaml` and exported as
  `TF_VAR_backend_image_tag` and `TF_VAR_frontend_image_tag` (replacing reliance
  on `:latest`). Defaults to `latest` if files are missing or tag cannot be parsed.
  - Script exports `TERRAFORM_WORKSPACE` before sourcing `scripts/set-k8s-env.sh`
  and restores the current directory after sourcing so Terraform runs in
  `application/`.
- **Application Terraform variable `frontend_image_tag`**
  - New variable (default `latest`) for the frontend Docker image tag used by the
  ArgoCD Application; application layer uses tags from Helm values updated by
  build workflows.
- **Application provisioning and destroying workflows**
  - Workflows export `TERRAFORM_WORKSPACE` and `BACKEND_PREFIX` for state path
  consistency. They extract backend and frontend image tags from Helm values and
  set `TF_VAR_backend_image_tag` and `TF_VAR_frontend_image_tag` so the correct
  image tags are deployed (no `:latest` dependency).

### Fixed

- **LDAP Admin Password Consistency: Cross-Namespace Secret Reading**
  - Fixed password mismatch issue that caused `admin-seed-job` to fail with
  `LDAPInvalidCredentialsResult - 49 - invalidCredentials`
  - `ldap-admin-secret` now reads password from OpenLDAP secret (`openldap-secret`)
  in `ldap` namespace instead of using a separate variable
  - Ensures backend application always uses the same password as OpenLDAP was
  initialized with
  - Added `openldap_secret_name` and `openldap_namespace` variables
  (defaults: `openldap-secret` and `ldap`) for configuration
  - Falls back to `TF_VAR_OPENLDAP_ADMIN_PASSWORD` variable if OpenLDAP secret
  doesn't exist (useful during initial deployment)
  - Prevents future password mismatches between `application_infra` and
  `application` deployments
  - Cross-namespace secret reading works via Kubernetes API (not affected by network
  policies which only control pod-to-pod traffic)
  - Fixed Terraform plan error: `Call to function "base64decode" failed: failed
  to decode base64 data (sensitive value)` by removing the unnecessary `base64decode()`
  call (the `kubernetes_secret` data source's `data` attribute already returns decoded
  plain text values) and using `nonsensitive()` to unwrap the sensitive value (safe
  because the password is only used internally in the `kubernetes_secret` resource
  and never exposed in outputs)

- **GitHub Actions Workflows: Backend Configuration File Creation**
  - Fixed `04-application_provisioning.yaml` to create `application_infra/backend.hcl`
  before checking ArgoCD capability status
  - Fixed `04-application_destroying.yaml` to create both `backend_infra/backend.hcl`
  and `application_infra/backend.hcl` before terraform init
  - Ensures backend configuration files exist before Terraform initialization,
  preventing initialization errors
  - Improved error handling in terraform init and workspace select commands to
  show actual errors instead of hiding them
  - Fixes issue where `application/providers.tf` requires `application_infra/backend.hcl`
  to read remote state configuration

- **destroy-application.sh: State Account assume-role context**
  - Corrected the assume-role context label from `destroy-application-infra` to
  `destroy-application` when assuming the State Account role for Terraform
  operations.

### Changed

- **Signup Process - MFA Method Selection Removed**
  - MFA method selection has been removed from the signup process
  - Users no longer choose TOTP or SMS during account registration
  - MFA method selection and enrollment now occurs exclusively during the login
  process after account activation
  - Signup form fields: first name, last name, username, email, phone
  (country code + number), password, confirm password
  - User model: `mfa_method` and `totp_secret` are set to `None` during signup
  and populated during MFA enrollment at login
  - Updated documentation: [PRD Signup Management](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/design/PRD_SIGNUP_MAN.md),
  [PRD Admin Functions](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/design/PRD_ADMIN_FUNCS.md)

## [2025-02-23] - Remember me and Forgot/Reset password

### Added

- **Remember me**
  Login step 1 accepts optional `remember_me`. When set, the JWT issued after
  MFA verification uses `JWT_REFRESH_EXPIRY_DAYS` (e.g. 7 days) instead of `JWT_EXPIRY_MINUTES`.
  Frontend login form includes a "Remember me" checkbox.

- **Forgot your password**
  - Backend: `POST /api/auth/forgot-password` (body: `email`) looks up user by email;
  for active users, creates a password-reset token, sends email with link to
  `APP_URL/#reset-password?token=...&username=...`, and returns a generic success
  message (no email enumeration).
  - Config: `PASSWORD_RESET_EXPIRY_HOURS` (default 1) for reset link expiry.
  - Email: `EmailClient.send_password_reset_email()`; reset links use the same
  SES sender as verification emails.
  - LDAP: `LDAPClient.change_password(username, new_password)` for updating password
  via admin connection.

- **Reset password**
  - Backend: `POST /api/auth/reset-password` (body: `token`, `username`, `new_password`,
  `confirm_password`) validates the token (stored as verification token type `password_reset`),
  updates LDAP password and DB `password_hash`, marks token used.
  - Frontend: "Forgot your password?" on the login tab opens a panel to request
  a reset link. When the app is opened with `#reset-password?token=...&username=...`,
  a set-new-password form is shown; after success, the user is redirected to the
  login page and can sign in with the new password.

### Changed

- Login challenge storage (in-memory) now stores `remember_me` and passes it to
the verify step for JWT expiry selection.
- Documentation: [application/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/README.md),
  [PRD 2FA App](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/design/PRD_2FA_APP.md),
  [application/backend/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/backend/README.md),
  [application/frontend/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/frontend/README.md)
updated with new endpoints, request/response schemas, config, and frontend API methods.

## [2026-02-15] - First Admin User Seed and LDAP Config from Application Infra

### Added

- **First admin user seed (optional)**
  When all admin seed variables are set (via `TF_VAR_admin_seed_*` or GitHub Secrets
  `ADMIN_SEED_*`), Terraform creates a Kubernetes secret and a one-time Job that
  seeds the first admin user so they can log into the 2FA application with the
  **same username and password** as the LDAP admin. The seed:
  - Creates the LDAP user (if missing) with the OpenLDAP admin password
  - Ensures the user is in the LDAP admins group
  - Inserts or updates the PostgreSQL user with email/phone pre-verified and status
  ACTIVE
  - Generates a TOTP secret (stored in the DB; operator can retrieve from PostgreSQL
  to add to an authenticator app)
  - Values are never hardcoded or logged; they are read from AWS Secrets Manager
  `tf-vars` or GitHub Secrets and passed via Kubernetes secrets to the Job.

- **Backend seed module**
  `app.seed_admin` runnable as `python -m app.seed_admin`; reads `ADMIN_SEED_*`
  and `LDAP_ADMIN_PASSWORD` from environment and performs the LDAP + DB seed idempotently.

- **Application destroy script and workflow**
  `destroy-application.sh` and the Application Destroying workflow now retrieve
  and export `TF_VAR_openldap_admin_password` and optional `TF_VAR_admin_seed_*`
  so Terraform can destroy the ldap-admin-secret and admin-seed secret/Job when
  present.

### Changed

- **LDAP configuration for admin-seed Job**
  LDAP host, base DN, admin DN, admin group DN, and search bases for the admin-seed
  Job are no longer hardcoded in `application/main.tf`. They are read from `application_infra`
  remote state (outputs from the OpenLDAP module).

- **Application infrastructure (application_infra)**
  OpenLDAP module and root outputs now expose: `ldap_host`, `ldap_base_dn`, `ldap_admin_dn`,
  `ldap_admin_group_dn`, `ldap_user_search_base`, `ldap_group_search_base` for
  use by the 2FA application and other consumers.

- **Documentation**
  [Secrets Requirements](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/reference/SECRETS_REQUIREMENTS.md),
  [application/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/README.md),
  root [README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/README.md),
  and [docs/index.html](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/index.html)
  updated to describe admin seed secrets, script/workflow behavior, and first
  admin login.

## [2026-02-15] - Shared ALB for 2FA Ingresses (Fix Conflicting Load Balancer Name)

### Fixed

- **2FA frontend/backend Ingress: "FailedBuildModel / conflicting load balancer
name"**
  - The EKS load balancer driver rejected 2FA Ingresses when they had an empty or
    different `alb.ingress.kubernetes.io/load-balancer-name` than OpenLDAP. All
    Ingresses in the same IngressGroup must use the same ALB name so they attach
    to the existing ALB and add new paths.
  - Application Terraform now reads `alb_load_balancer_name` and
    `alb_ingress_class_name` from `application_infra` remote state and passes
    them to the backend and frontend ArgoCD applications via `helm_config`
    parameters. The 2FA Ingresses therefore use the same ALB name and IngressClass
    as OpenLDAP.
  - Frontend and backend Helm charts: the Ingress template omits the
    `load-balancer-name` annotation when its value is empty, so an explicit
    empty string is never sent to the controller.

- **ArgoCD sync: "spec.rules[0].http.paths: Required value"**
  - Setting only `ingress.hosts[0].host` via Helm parameters can cause Helm to
    replace the first host entry and drop the `paths` array (known Helm `--set`
    merge behavior). Backend and frontend now receive explicit
    `ingress.hosts[0].paths[0].path` and `ingress.hosts[0].paths[0].pathType`
    parameters (backend: `/api`, frontend: `/`) so the rendered Ingress always
    has a non-empty paths array.

### Added

- **Outputs `alb_load_balancer_name` and `alb_ingress_class_name`** (from
  application_infra state) for use with manual Helm deployment or scripting;
  when using ArgoCD, these values are passed via Helm parameters automatically.

### Changed

- **ArgoCD Applications (backend and frontend)** now receive optional
  `helm_config` with parameters for `ingress.annotations` (load-balancer-name),
  `ingress.className`, and `ingress.hosts[0].host` when `application_infra`
  provides an ALB. This is set automatically; no variable changes required.

## [2026-02-15] - Backend Database URL from Secret, Log Redaction, IDE Config

### Added

- **Backend: Database URL from Kubernetes Secret (password-only)**
  - When the Helm chart uses `database.externalSecret` with only a password
  (no full URL), the app now builds the connection URL from `DATABASE_HOST`,
  `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`, and the password from the secret.
  Previously the chart incorrectly set `DATABASE_URL` to the raw password, causing
  startup failure (SQLAlchemy could not parse the URL).
  - Helm values: `database.host`, `database.port`, `database.user`, `database.name`
  for component-based config; optional `database.externalSecret.urlKey` for full
  URL in secret; optional `database.externalSecret.passwordFile` to mount the password
  as a file instead of env var.
  - App supports `DATABASE_PASSWORD_FILE`: when set, the password is read from
  the file (e.g. mounted Secret) so it is not in the process environment.

- **Backend: Log redaction for database connection strings**
  - Startup errors that may contain the connection URL or password are redacted
  before logging. New `app.utils.security.redact_connection_strings()` and its
  use in `main.py` ensure database credentials never appear in logs.

- **Backend: Pyright/Pylance config for `src` layout**
  - Added `application/backend/pyrightconfig.json` with `extraPaths: ["src"]` so
  IDE imports (`from app.xxx`) resolve correctly when the package lives under `src/app/`.

### Changed

- **Backend Helm chart**
  - Database block: when `database.externalSecret.enabled` is true and `urlKey`
  is set, `DATABASE_URL` is taken from that secret key; otherwise the chart injects
  `DATABASE_PASSWORD` (or `DATABASE_PASSWORD_FILE` when `passwordFile.enabled`
  is true) plus `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`
  from ConfigMap. ConfigMap now includes those keys when external secret is used
  without `urlKey`.
  - Default `database.externalSecret.passwordFile.enabled` is `false`
  (password from secret via env is sufficient for most deployments).

- **Backend README**
  - Documented database configuration: full URL vs component vars (`DATABASE_HOST`,
  `DATABASE_USER`, etc.) and `DATABASE_PASSWORD_FILE`. Documented Helm database
  external secret options (urlKey, passwordKey, passwordFile) and example install.
  Added IDE/Editor note for `pyrightconfig.json` and import resolution.
  Added `app/utils/security.py` to project structure. Security section updated to
  mention log redaction for DB credentials.

### Fixed

- **Backend Helm chart: Helm template parse error on deploy**
  - Replaced undefined `regexReplace` with Sprig’s `regexReplaceAll` in the backend
  deployment template for database password file `mountPath` and secret item `path`.
  Fixes `ComparisonError: function "regexReplace" not defined` when Argo CD / Helm
  renders the chart.

## [2026-02-11] - Backend Namespace Secrets and Application Documentation

### Added

- **Backend Namespace LDAP Secret**
  - Added `kubernetes_secret.ldap_admin` so the backend application namespace
  (2fa-app) has `ldap-admin-secret` for LDAP authentication
  - Secret is populated from `TF_VAR_OPENLDAP_ADMIN_PASSWORD` (GitHub) or
  OpenLDAP admin password from AWS Secrets Manager (local)
  - ArgoCD Application backend module depends on this secret so the backend can
  start with LDAP credentials

- **Application Documentation**
  - [PASSWORD_FLOW](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/PASSWORD_FLOW.md)
    – Password and MFA flow documentation
  - [REDIS_ENABLEMENT_SUMMARY](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/REDIS_ENABLEMENT_SUMMARY.md)
    – Redis enablement and SMS OTP summary
  - [SECRET_DEPENDENCIES](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/SECRET_DEPENDENCIES.md)
    – Secret dependencies for PostgreSQL, Redis, and LDAP admin across namespaces

### Changed

- **Backend Helm Values**
  - Backend Helm values updated to reference the LDAP admin secret in the
  backend namespace where applicable

## [2026-02-03] - Build Workflow Image Tags and Backend Dockerfile

### Changed

- **Build Workflow Image Tag Format**
  - Backend and frontend build workflows now generate unique image tags:
  `<image-name>-<commit-sha>-<run_id>` (e.g.,
  `ldap-2fa-backend-<sha>-<run_id>`)
  - Prevents ECR tag conflicts when re-running workflows (ECR tags are
  immutable)
  - Each workflow run produces a distinct tag; Helm values are updated and
  committed with the new tag

- **Backend Dockerfile and README**
  - Corrected Python LDAP dependencies in Dockerfile (libldap2-dev,
  libsasl2-dev for build stage; libldap-2.5-0, libsasl2-2 for runtime)
  - Updated backend README to reflect current Dockerfile and deployment
  steps

## [2026-01-26] - ArgoCD Capability Status Validation

### Added

- **ArgoCD Capability Status Validation**
  - Added ACTIVE status check in `setup-application.sh` to ensure ArgoCD capability
  is ACTIVE before deploying applications
  - Added ACTIVE status check in `.github/workflows/04-application_provisioning.yaml`
  to validate ArgoCD capability status
  - Both scripts and workflows now fail fast with clear error messages if
  ArgoCD capability is not ACTIVE
  - Prevents deployment of applications when ArgoCD capability is not ready
  - Validation retrieves ArgoCD capability status from `application_infra` remote
  state
  - Provides helpful error messages guiding users to ensure ArgoCD capability is
  deployed and active

### Changed

- **Application Deployment Script**
  - Enhanced `setup-application.sh` with ArgoCD capability status validation
  - Script now checks ArgoCD capability status before proceeding with Terraform
  operations
  - Improved error messages for better troubleshooting guidance

- **GitHub Actions Workflow**
  - Enhanced `04-application_provisioning.yaml` with ArgoCD capability status validation
  step
  - Workflow now validates ArgoCD capability status before proceeding with application
  deployment
  - Added clear error messages and status reporting in workflow output

## [2026-01-25] - Git Ignore Pattern Update and State Path Verification

### Changed

- **Git Ignore Pattern**
  - Updated `.gitignore` to use pattern `**/backend.hcl` instead of listing specific
  files
  - Simplifies maintenance by automatically ignoring all `backend.hcl` files in
  any directory
  - Ensures generated backend configuration files are not committed to the repository

### Fixed

- **State Path Verification**
  - Verified state file key uses correct path: `application_state/terraform.tfstate`
  - Confirmed all scripts and workflows use the `APPLICATION_PREFIX` repository
  variable correctly
  - Ensured state file isolation between `application_infra` and `application` directories

## [2026-01-21] - Backend State Configuration Standardization

### Changed

- **Backend State Template Configuration**
  - Updated `tfstate-backend-values-template.hcl` to use `APPLICATION_PREFIX` placeholder
  - State file key now uses repository variable `APPLICATION_PREFIX` (value: `application_state/terraform.tfstate`)
  - Simplified template to use direct prefix variable instead of constructing path
  - Ensures consistent state file naming across all deployment methods

- **Setup and Destroy Scripts**
  - Updated `setup-application.sh` to use `APPLICATION_PREFIX` directly from GitHub
  repository variables
  - Updated `destroy-application.sh` to use `APPLICATION_PREFIX` directly from GitHub
  repository variables
  - Removed logic that constructed state prefix path (now handled by repository
  variable value)
  - Scripts now replace `<APPLICATION_PREFIX>` placeholder with repository variable
  value

- **GitHub Workflows**
  - Updated `04-application_provisioning.yaml` to use `APPLICATION_PREFIX` repository
  variable
  - Updated `04-application_destroying.yaml` to use `APPLICATION_PREFIX` repository
  variable
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
  - Documentation updated in README.md and PRD_2FA_APP.md to reflect availability

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

- **Product Requirements Document (PRD_SIGNUP_MAN.md)**
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

- **Product Requirements Document (PRD_2FA_APP.md)**
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
  - References ArgoCD namespace and project name from `application_infra` remote
  state

- **Updated variables.tf and variables.tfvars**
  - Added ArgoCD Application configuration variables
  - Added repository URL and path configuration
  - Added sync policy configuration options

## Planned Changes

### [Future] - 2FA Application Enhancements

- [x] ~~Implement 2FA application with TOTP support~~ (Completed 2025-12-18)
- [x] ~~Add SMS-based verification via AWS SNS~~ (Completed 2025-12-18)
- [x] ~~Replace in-memory SMS OTP storage with Redis~~ (Completed 2025-12-18)
- [x] ~~Add self-service user signup with email/phone verification~~
(Completed 2025-12-18)
- [x] ~~Implement admin dashboard for user management~~ (Completed 2025-12-18)
- [x] ~~Add group management and user-group assignment~~ (Completed 2025-12-18)
- [x] ~~Add user profile management~~ (Completed 2025-12-18)
- [ ] Add email-based MFA verification option
- [ ] Implement backup codes for account recovery
- [ ] Add rate limiting for authentication attempts
- [ ] Add password reset functionality
