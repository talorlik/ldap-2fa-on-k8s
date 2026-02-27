# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2026-02-26] - Frontend Form Fix, OpenLDAP LDIF Mount, and Redis Enforcement

### Changed

- **2FA frontend**: Form submission fix and QRCode.js version set to 1.4.4;
  null guards added for form/setup handlers so forms post correctly. See
  [application/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md).
- **Application infrastructure**: OpenLDAP chart custom LDIF bootstrap now uses
  a read-only mount and startup copy so osixia cleanup works correctly.
  OpenLDAP module and root now expose `ldap_headless_host` for admin-seed and
  other consumers. See [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).
- **2FA backend**: Login mechanism corrected; Redis is now required for all
  challenge storage (SMS OTP and login challenges). In-memory fallback removed;
  endpoints return 503 when Redis is unavailable. Documentation updated
  (REDIS_ENABLEMENT_SUMMARY, PRD_SMS_MAN, Redis module README, DEBUG_COMMANDS,
  docs/index.html, WARP.md).
- **Admin-seed job**: Uses LDAP headless host from application_infra outputs
  (`LDAP_HEADLESS_HOST`) so OpenLDAP replica connections use correct pod DNS.
  See [application/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md).

## [2026-02-25] - ArgoCD Single Wait and OpenLDAP Pre-deploy in Module

### Changed

- **Application infrastructure**: ArgoCD module now uses a single readiness wait
  (default 330s) instead of two sequential sleeps; OpenLDAP pre-deploy delay
  (3m) moved into the OpenLDAP module as its first resource. See
  [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).

## [2026-02-24] - ArgoCD IAM Revert and IngressClassParams Troubleshooting

### Changed

- **Application Infrastructure: ArgoCD IAM Reverted to Single Inline Policy**
  - Removed dependency on AWS managed policy
  `AmazonEKSCapabilityArgoCD` (policy does not exist or is not attachable in
  some regions/accounts). ArgoCD capability role now uses only one inline
  policy with EKS, Secrets Manager, KMS, CodeConnections (incl. UseConnection),
  and optional ECR/CodeCommit when enabled. Same permissions; no managed policy.
  - All ArgoCD IAM documentation updated (PRD, DEBUG_COMMANDS, module README,
  APPLICATION_INFRA_DEPLOYMENT). Removed ARGOCD_IAM_POLICY_COMPARISON.md;
  content moved to ArgoCD module README (IAM Policy section).

- **Application Infrastructure: IngressClassParams "Already Exists"**
  - When apply fails with "resource ... already exists" for
  `module.alb[0].kubernetes_manifest.ingressclassparams_alb`, import the
  existing resource into state so Terraform can manage/update it.
  - New troubleshooting section "ALB / IngressClassParams Failures" in
  [APPLICATION_INFRA_DEPLOYMENT](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  with `terraform import` command. ALB module comment added with import
  instructions.
  - See [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).

## [2025-02-23] - LDAP Admin-Seed Fixes and Image Tag Validation

### Added

- **Shared Scripts Directory (`scripts/`)**
  - Moved `assume-github-role.sh`, `mirror-images-to-ecr.sh`, and `set-k8s-env.sh`
    from `application_infra/` to `scripts/` for a single shared location. All
    workflows and setup/destroy scripts now reference `../scripts/...`.
  - **get-eks-token.sh**: New script used by Terraform Kubernetes and Helm
    providers (exec plugin) to generate a fresh EKS token on every API call,
    avoiding token timeout during long operations (e.g. 20-minute Helm timeouts).
    Supports optional cross-account role assumption via `ASSUME_ROLE_ARN` and
    `ASSUME_EXTERNAL_ID`. Located at `scripts/get-eks-token.sh`.
  - **Layer-specific monitoring scripts:** Replaced the single root
    `monitor-deployments.sh` with three scripts:
    - `backend_infra/monitor-deployments.sh` - backend infrastructure
    - `application_infra/monitor-deployments.sh` - application infrastructure
    - `application/monitor-deployments.sh` - application layer
    Each produces a report suitable for agent investigation or manual review.

- **LDAP and Admin-Seed-Job Troubleshooting Guide**
  - Created comprehensive troubleshooting document
  [LDAP and Admin-Seed Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED_TROUBLESHOOTING.md)
  documenting persistent OpenLDAP issues, investigation timeline, root causes,
  ad-hoc manual corrections, and permanent code fixes
  - Includes verification commands, lessons learned, and references

- **OpenLDAP Directory Structure Initialization**
  - Added `customLdifFiles` to OpenLDAP Helm values to automatically create
  `ou=users`, `ou=groups`, and `cn=admins` on all OpenLDAP pods at startup
  - Fixes issue where multi-master replication didn't sync initial directory
  structure (each pod initialized independently with empty directory)
  - See [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md)
  for details

- **LDAPClient Group Membership Handling**
  - Added methods to detect group objectClass and use correct membership attribute
  (`uniqueMember` for `groupOfUniqueNames`, `member` for `groupOfNames`)
  - Added `update_user()` and `create_or_update_user()` for idempotent operations
  - See [application/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md)
  for details

- **Image Tag Validation for Admin-Seed Job**
  - Added validation to reject `"latest"` tag (which doesn't exist in ECR)
  - Scripts and workflows fail early with helpful error if tag extraction fails
  - Destroy scripts use empty string as fallback (acceptable for destroy operations)
  - ECR uses commit-based tags; Backend Build workflow updates Helm values

### Changed

- **Application Infrastructure: ArgoCD Module Ordering and Dependencies**
  - ArgoCD module is now declared first in `application_infra/main.tf` so it is
  created before other modules that reference its outputs.
  - ArgoCD module internal dependency graph updated to avoid race conditions:
  IAM and namespace propagation wait extended to 2m; downstream resources
  (cluster registration secret, access policy association, manifests) depend
  on `time_sleep.wait_for_argocd` so the EKS capability's access entry exists
  before associating policies. See
  [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).

- **StorageClass Volume Binding Mode (EKS Auto Mode)**
  - StorageClass `volume_binding_mode` set to `WaitForFirstConsumer` (was
  `Immediate`). Required for EKS Auto Mode so that PVC provisioning occurs
  after pod scheduling, which triggers node creation. See
  [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md).

- **Application Infrastructure: OpenLDAP Module ACM and Chart**
  - OpenLDAP Terraform module no longer accepts `acm_cert_arn`; the ACM
  certificate is configured in IngressClassParams by the ALB module. The
  OpenLDAP module now receives `alb_ssl_policy` from the parent for ALB
  configuration.
  - OpenLDAP chart is vendored at `application_infra/charts/openldap-stack-ha`
  (version 5.0.0, osixia/openldap:1.5.0). See
  [application_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md)
  and [application_infra/OPENLDAP_CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/OPENLDAP_CHANGELOG.md).

- **Kubernetes Version Upgrade**
  - Upgraded Kubernetes version from 1.34 to 1.35
  - Updated `backend_infra/variables.tfvars` with new Kubernetes version
  - Updated documentation references in `WARP.md`
  - See [backend_infra/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/backend_infra/CHANGELOG.md)
  for details

- **Application: MFA Method Selection Removed from Signup**
  - MFA method selection (TOTP or SMS) has been removed from the user signup process
  - Users now enroll in their preferred MFA method during the login process after
  account activation
  - Signup flow simplified to collect only: name, username, email, phone, and password
  - Email and phone verification still occur during signup as before
  - Updated documentation: [PRD Signup Management](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/design/PRD_SIGNUP_MAN.md),
  [PRD Admin Functions](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/design/PRD_ADMIN_FUNCS.md)

### Fixed

- **Application Infrastructure: OpenLDAP Helm Pod Labels**
  - ltb-passwd and phpldapadmin `podLabels` in
  `application_infra/helm/openldap-values.tpl.yaml` now use
  `app.kubernetes.io/part-of` instead of `app` to avoid conflicting with
  reserved/standard Kubernetes labels.

- **Application Infrastructure: OpenLDAP Secret Key Name (osixia compatibility)**
  - Kubernetes secret created by Terraform uses key `LDAP_CONFIG_PASSWORD` (not
  `LDAP_CONFIG_ADMIN_PASSWORD`) to match the osixia/openldap image. The upstream
  jp-gouin/helm-openldap chart documents `LDAP_CONFIG_ADMIN_PASSWORD` for the
  Bitnami image; this project uses the osixia image. See
  [Osixia OpenLDAP Requirements](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application_infra/guides/OSIXIA_OPENLDAP_REQUIREMENTS.md).
  - The Terraform variable name (`TF_VAR_OPENLDAP_CONFIG_PASSWORD`) is unchanged.

## [2026-02-16] - GitHub Actions Support for ArgoCD Module and Workflow Improvements

### Added

- **GitHub Actions Support for ArgoCD Module External Data Source**
  - ArgoCD module's external data source now automatically detects GitHub Actions
  environment and uses `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID` environment variables
  directly instead of calling `assume-github-role.sh`
  - Eliminates dependency on AWS Secrets Manager for role ARNs in GitHub Actions
  - Falls back to `assume-github-role.sh` for local environments (maintains backward
  compatibility)
  - Uses `eval` to safely read environment variables and avoid Terraform
  interpolation issues

- **GitHub Actions Workflow Improvements**
  - Added `jq` installation step to all workflows that use ArgoCD module:
    - `02-application_infra_provisioning.yaml`
    - `02-application_infra_destroying.yaml`
    - `04-application_provisioning.yaml`
  - Added step to make `assume-github-role.sh` executable in workflows
  (for local fallback)
  - All workflows now export `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID` as environment
  variables for ArgoCD module external data source

### Fixed

- **GitHub Actions Workflows: Backend Configuration File Creation**
  - Fixed `04-application_provisioning.yaml` to create `application_infra/backend.hcl`
  before checking ArgoCD capability status
  - Fixed `04-application_destroying.yaml` to create both `backend_infra/backend.hcl`
  and `application_infra/backend.hcl` before terraform init
  - Ensures backend configuration files exist before Terraform initialization,
  preventing initialization errors
  - Improved error handling in terraform init and workspace select commands to
  show actual errors instead of hiding them

- **set-k8s-env.sh: Path Resolution When Sourced**
  - Fixed script directory detection when script is sourced (using `source ./set-k8s-env.sh`)
  - Changed from `$0` to `${BASH_SOURCE[0]}` for correct path resolution
  - Ensures script works correctly both locally and in GitHub Actions workflows
  - Fixes error: "backend.hcl not found" when running workflows

- **GitHub Actions: Automatic backend_infra/backend.hcl Creation**
  - Added automatic creation of `backend_infra/backend.hcl` in all relevant workflows:
    - `02-application_infra_provisioning.yaml`
    - `02-application_infra_destroying.yaml`
    - `04-application_provisioning.yaml`
    - `04-application_destroying.yaml`
  - Workflows now create `backend_infra/backend.hcl` from template before Terraform
  operations
  - Required because `application_infra/providers.tf` and `application/providers.tf`
  read this file to access backend_infra remote state
  - Works seamlessly both locally (skips if file exists) and in GitHub Actions
  (creates if needed)
  - Fixes error: "open ./../backend_infra/backend.hcl: no such file or directory"

- **ArgoCD Module External Data Source: GitHub Actions Compatibility**
  - Fixed external data source to work in GitHub Actions by detecting `GITHUB_ACTIONS`
  environment variable
  - Uses `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID` from environment instead of requiring
  AWS Secrets Manager access
  - Fixes error: "External Program Execution Failed" when running Terraform in GitHub
  Actions workflows

- **Path, context, and state consistency (scripts and workflows)**
  - **tf_backend_state**: `get-state.sh` and `set-state.sh` now change to the script
  directory before running so Terraform and variables are found whether invoked
  from repo root or `tf_backend_state/`. TF state workflows (`00-tfstate_infra_provisioning`,
  `00-tfstate_infra_destroying`) set default `AWS_REGION=us-east-1` when repository
  variable `vars.AWS_REGION` is not set.
  - **application_infra**: `set-k8s-env.sh` uses `BACKEND_PREFIX` (from repository
  variable or `backend_infra/backend.hcl`) and workspace from `TERRAFORM_WORKSPACE`
  or `AWS_REGION`+`ENVIRONMENT`, and restores the original working directory after
  sourcing so callers are not left in `application_infra/`. Setup and destroy scripts
  export `TERRAFORM_WORKSPACE` before sourcing `set-k8s-env.sh`.
  - **mirror-images-to-ecr.sh**: Backend_infra state key comes from `BACKEND_PREFIX`
  or `backend_infra/backend.hcl` (no hardcoded key). Workspace from `TERRAFORM_WORKSPACE`
  or `AWS_REGION`+`ENVIRONMENT`.
  - **monitor-deployments.sh**: Uses selected `REGION` for AWS Secrets Manager;
  reads `BACKEND_PREFIX` from GitHub variables (or environment); state path uses
  `env:/${REGION}-${ENVIRONMENT}/${BACKEND_PREFIX}`.
  - **Application workflows**: Export `TERRAFORM_WORKSPACE` and `BACKEND_PREFIX`;
  application provisioning and destroying workflows extract backend and frontend
  image tags from Helm values files and set `TF_VAR_backend_image_tag` and
  `TF_VAR_frontend_image_tag` (replacing reliance on `:latest`).
  - **Backend/Frontend build workflows**: No longer push a `:latest` tag; only the
  computed image tag is pushed. Application layer uses tags from Helm values (updated
  by build workflows).
  - **application/destroy-application.sh**: Assume-role context label corrected
  from `destroy-application-infra` to `destroy-application` for State Account role.
  - **application/setup-application.sh**: Exports `TERRAFORM_WORKSPACE`, sources
  `set-k8s-env.sh`, then restores current directory so Terraform runs in
  `application/`; extracts backend and frontend image tags from Helm values for
  `TF_VAR_backend_image_tag` and `TF_VAR_frontend_image_tag`.

## [2026-02-15] - Backend Database URL from Secret, Log Redaction, IDE Config

### Added

- **Backend: Database URL built from Kubernetes Secret (password-only)**
  - When the backend Helm chart uses an external secret that contains only the
  database password (not the full URL), the app now builds the PostgreSQL connection
  URL from `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`,
  and the password from the secret. This fixes startup failure when the chart had
  been setting `DATABASE_URL` to the raw password.
  - Optional: `database.externalSecret.urlKey` for full URL in secret;
  `database.externalSecret.passwordFile` to mount the password as a file so it is
  not in the process environment.
  - App supports `DATABASE_PASSWORD_FILE` to read the password from a mounted file.

- **Backend: Redaction of connection strings in logs**
  - Database startup errors are redacted so connection URLs and passwords never
  appear in log output (`app.utils.security.redact_connection_strings`).

- **Backend: Pyright config for import resolution**
  - `application/backend/pyrightconfig.json` with `extraPaths: ["src"]` so
  `from app.xxx` resolves correctly in the IDE when using the src layout.

### Changed

- **Backend Helm chart**
  - Database credentials: chart now injects either full `DATABASE_URL` from secret
  (when `urlKey` is set) or `DATABASE_PASSWORD` (or `DATABASE_PASSWORD_FILE` when
  password file is enabled) plus host/port/user/name from values/ConfigMap.
  ConfigMap supplies `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`
  when external secret is used without a full-URL key.
  - `database.externalSecret.passwordFile.enabled` defaults to `false`.

- **Backend README**
  - Documented database configuration (URL vs components, `DATABASE_PASSWORD_FILE`),
  Helm database external secret options, IDE/pyright note, and security note on
  log redaction.

### Fixed

- **Backend Helm chart: Helm template parse error on deploy**
  - Replaced undefined `regexReplace` with Sprig’s `regexReplaceAll` in `deployment.yaml`
  for database password file `mountPath` and secret item `path`.
  Fixes `ComparisonError: function "regexReplace" not defined` when Argo CD / Helm
  renders the backend chart.

## [2026-02-11] - Destroy Confirmation, Backend Namespace Secrets, and App Docs

### Added

- **Destroy Workflow Confirmation**
  - All destroy workflows (Application, Application Infrastructure, Backend
  Infrastructure, TF Backend State) now require an explicit confirmation input
  - When running a destroy workflow in GitHub Actions, you must type `yes` in the
  "Type 'yes' to confirm destruction" input; the workflow fails otherwise
  - Reduces risk of accidental destruction from mis-clicks or mistaken workflow
  runs

- **Backend Namespace Secrets**
  - Terraform now creates `ldap-admin-secret` in the backend application namespace
  (2fa-app) so the backend can authenticate to LDAP
  - Uses `TF_VAR_OPENLDAP_ADMIN_PASSWORD` (GitHub secret) or OpenLDAP admin
  password from AWS Secrets Manager for local runs
  - Application destroy workflow comment updated to list
  `TF_VAR_OPENLDAP_ADMIN_PASSWORD` as required for backend ldap-admin-secret

- **Application Documentation**
  - [PASSWORD_FLOW](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/PASSWORD_FLOW.md)
    – Password and MFA flow documentation
  - [REDIS_ENABLEMENT_SUMMARY](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/REDIS_ENABLEMENT_SUMMARY.md)
  Redis enablement and SMS OTP summary
  - [SECRET_DEPENDENCIES](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/SECRET_DEPENDENCIES.md)
  Which components require which secrets (PostgreSQL, Redis, LDAP admin)

### Changed

- **Documentation**
  - README and docs/index.html updated to describe destroy confirmation for
  GitHub Actions and correct destroy order (Application → Application
  Infrastructure → Backend Infrastructure → State)
  - docs/index.html streamlined: removed long duplicate manual deployment
  section in favor of link to DEPLOY_2FA_APPS.md; condensed Step 5 and build
  steps

## [2026-02-03] - Build Workflow Image Tags, ArgoCD Access Entry, and Backend Dockerfile

### Changed

- **Build Workflow Image Tag Creation**
  - Updated backend and frontend build workflows to generate unique image tags
  using both commit SHA and GitHub run ID: `<image-name>-<sha>-<run_id>`
  - Prevents tag conflicts when re-running the same workflow (ECR tags are
  immutable)
  - Ensures each workflow run produces a distinct tag that can be pushed to ECR
  - Updated commit message format for automated Helm values updates

- **ArgoCD Module: Access Entry and Cluster Role**
  - Corrected ArgoCD capability permissions by associating EKS Access Policy
  with the automatically-created EKS Access Entry
  - Added `aws_eks_access_policy_association.argocd_capability_cluster_admin`
  to grant the ArgoCD Capability IAM role full cluster admin via
  `AmazonEKSClusterAdminPolicy`
  - Access entry is created automatically by EKS when the capability is created;
  the module now only associates the access policy with the principal ARN
  - Retained ClusterRoleBinding for backward compatibility with IAM role-based
  RBAC
  - Ensures ArgoCD can sync applications and manage resources across all
  namespaces and cluster-scoped resources

- **Backend Dockerfile and Documentation**
  - Corrected Python LDAP library usage in backend Dockerfile (libldap2-dev,
  libsasl2-dev for build; libldap-2.5-0, libsasl2-2 for runtime)
  - Updated backend README to reflect current Dockerfile and deployment
  - Documentation updates across affected docs

## [2026-01-26] - ArgoCD Module Improvements and Application Deployment Validation

### Changed

- **ArgoCD Module External Data Resource**
  - Fixed external data resource in ArgoCD module to correctly fetch `server_url`
  and `status` from AWS EKS capability
  - Improved error handling with proper error reporting via `argocd_capability_error`
  output
  - Enhanced JSON parsing using `jq` for reliable data extraction
  - External data resource now uses `assume-github-role.sh` to assume the correct
  deployment account role based on environment
  - Added proper null/empty string handling with `trimspace()` and `try()` functions
  - Improved dependency management with `query` parameter for proper resource ordering

- **ArgoCD Module Outputs**
  - Corrected `argocd_server_url` output to use `trimspace()` and `try()` for better
  null handling
  - Corrected `argocd_capability_status` output to use `trimspace()` and `try()`
  for better null handling
  - Added new `argocd_capability_error` output for error reporting when capability
  queries fail
  - All outputs now properly handle empty strings and null values

- **Application Deployment Validation**
  - Added ACTIVE status check in `application/setup-application.sh` to ensure
  ArgoCD capability is ACTIVE before deploying applications
  - Added ACTIVE status check in `.github/workflows/04-application_provisioning.yaml`
  to validate ArgoCD capability status
  - Both scripts and workflows now fail fast with clear error messages if
  ArgoCD capability is not ACTIVE
  - Prevents deployment of applications when ArgoCD capability is not ready

### Added

- **Role Assumption Script**
  - Created `application_infra/assume-github-role.sh` script for convenient role
  switching in terminal
  - Supports assuming State Account, Development Account, or Production Account
  roles
  - Can be sourced or executed with eval for credential persistence
  - Automatically retrieves role ARNs from AWS Secrets Manager
  - Includes `clean` option to remove all AWS credentials from environment
  - Provides colored output and comprehensive error handling
  - Used by ArgoCD module external data resource for proper role assumption

## [2026-01-25] - Application Infrastructure Separation

### Changed

- **Project Structure Reorganization**
  - Separated application infrastructure provisioning from application code deployment
  - Renamed `application/` directory to `application_infra/` for infrastructure
  provisioning
  - Created new `application/` directory for 2FA application code and application-specific
  dependencies
  - Infrastructure components (ALB, OpenLDAP, ArgoCD Capability, Route53 records
  for phpldapadmin/ltb-passwd) moved to `application_infra/`
  - Application components (PostgreSQL, Redis, SES, SNS, ArgoCD Applications, Route53
  record for 2FA app) moved to `application/`
  - Updated all GitHub workflows to reference correct directories
  - Created new workflows: `04-application_provisioning.yaml` and `04-application_destroying.yaml`
  - Updated all documentation references to reflect new structure
  - Split CHANGELOG files between infrastructure and application changes

- **Directory Reorganization**: Separated application infrastructure from application
code
  - Renamed `application/` directory to `application_infra/` for infrastructure
  provisioning
  - Created new `application/` directory for application code and dependencies
  - Moved application-specific modules (PostgreSQL, Redis, SES, SNS, ArgoCD Applications)
  to `application/`
  - Moved application code (backend, frontend) to `application/`
  - Split outputs, variables, and CHANGELOG files between infrastructure and application
  - Updated GitHub workflows to reference correct directories
  - Updated all documentation references
  - See [Application Infrastructure CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/CHANGELOG.md)
  for infrastructure changes
  - See [Application CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md)
  for application changes

- **Project Structure Reorganization**:
  - Separated application infrastructure from application code
  - Renamed `application/` directory to `application_infra/` for infrastructure
  provisioning
  - Created new `application/` directory for 2FA application code and dependencies
  - Infrastructure components (OpenLDAP, ALB, ArgoCD Capability, StorageClass)
  now in `application_infra/`
  - Application components (backend, frontend, PostgreSQL, Redis, SES, SNS, ArgoCD
  Applications) now in `application/`
  - Updated all GitHub workflows, scripts, and documentation to reflect new structure
  - Application deployment now depends on infrastructure deployment via remote state
  - Enables independent deployment ordering and clearer separation of concerns

### Added

- **New Application Deployment Workflows**
  - `04-application_provisioning.yaml` - Deploys 2FA application and dependencies
  (PostgreSQL, Redis, SES, SNS)
  - `04-application_destroying.yaml` - Destroys application deployments
  - Application workflows depend on `application_infra` being deployed first

### Deployment Order

- **Critical**: `application_infra/` must be deployed before `application/`
  - Infrastructure provides: StorageClass, ArgoCD Capability, ALB DNS name
  - Application reads from `application_infra` remote state for dependencies
  - ArgoCD Applications require ArgoCD Capability CRD to exist before deployment

## [2026-01-20] - Project Reorganization: Separation of Infrastructure and Application

### Changed

- **Directory Structure Reorganization**
  - Separated application infrastructure from application code deployment
  - Renamed `application/` directory to `application_infra/` for infrastructure
  components
  - Created new `application/` directory for application code and dependencies
  - Enables independent deployment ordering and clearer separation of concerns

- **Infrastructure Components (`application_infra/`)**
  - Contains infrastructure Terraform modules: ALB, ArgoCD Capability,
    network-policies, OpenLDAP, Route53, Route53 Record (for phpldapadmin and ltb_passwd).
    cert-manager module exists but is not invoked in main.tf.
  - Contains infrastructure scripts: `setup-application-infra.sh`, `destroy-application-infra.sh`,
    `mirror-images-to-ecr.sh`, `set-k8s-env.sh`
  - Contains infrastructure documentation: ALB, ArgoCD Capability, Domain, OpenLDAP,
    Security, Cross-Account Access
  - Exports outputs for application use: `storage_class_name`, `local_cluster_secret_name`,
    `argocd_namespace`, `argocd_project_name`, `alb_dns_name`

- **Application Components (`application/`)**
  - Contains application code: `backend/` (Python FastAPI), `frontend/` (HTML/JS/CSS)
  - Contains application Terraform modules: argocd_app, postgresql, redis, ses,
  sns
  - Contains application scripts: `setup-application.sh`, `destroy-application.sh`
  - Contains application documentation: 2FA App, Admin Functions, Signup Management,
  SMS Management
  - References `application_infra` remote state for infrastructure dependencies

- **GitHub Workflows**
  - Updated `02-application_infra_provisioning.yaml` and `02-application_infra_destroying.yaml`:
    - Changed `working-directory` to `./application_infra`
    - Removed PostgreSQL and Redis password secrets (application components)
  - Created new workflows:
    - `04-application_provisioning.yaml` - For application deployment
    - `04-application_destroying.yaml` - For application destruction

- **Documentation Updates**
  - Updated `application_infra/README.md` to focus on infrastructure only
  - Created `application/README.md` focused on application deployment
  - Updated root `README.md` with new directory structure
  - Split CHANGELOG files:
    - `application_infra/CHANGELOG.md` - Infrastructure changes only
    - `application/CHANGELOG.md` - Application changes only

- **Deployment Order**
  - Infrastructure (`application_infra/`) must be deployed first
  - Application (`application/`) deploys after infrastructure is ready
  - Application reads from `application_infra` remote state for:
    - StorageClass name (for PostgreSQL/Redis)
    - ArgoCD Capability outputs (for ArgoCD Applications)
    - ALB DNS name (for Route53 record for twofa_app)

### Documentation

- **New README Files**
  - `application_infra/README.md` - Infrastructure deployment guide
  - `application/README.md` - Application deployment guide with infrastructure dependencies

- **Updated References**
  - All documentation updated to reflect new directory structure
  - Module documentation links updated to point to correct locations
  - Cross-references between infrastructure and application documentation added

## [2026-01-19] - ECR Repository Name Automation and Documentation Updates

### Added

- **Automatic ECR Repository Name Variable Management**
  - Backend infrastructure provisioning now automatically saves ECR repository name
  to GitHub repository variable `ECR_REPOSITORY_NAME`
  - `setup-backend.sh` script automatically retrieves ECR repository name from
  Terraform outputs and saves it to GitHub variables
  - `01-backend_infra_provisioning.yaml` workflow automatically sets `ECR_REPOSITORY_NAME`
  variable after provisioning
  - Eliminates need for manual GitHub variable configuration
  - Build workflows (`03-backend_build_push.yaml` and `03-frontend_build_push.yaml`)
  now require `ECR_REPOSITORY_NAME` variable
  - Removed redundant PREFIX fallback logic from build workflows for cleaner, more
  maintainable code

### Changed

- **Build Workflow Simplification**
  - Simplified ECR repository name resolution in build workflows
  - Removed manual PREFIX-based repository name construction
  - Build workflows now fail fast with clear error message if `ECR_REPOSITORY_NAME`
  is not set
  - Error messages guide users to run backend infrastructure provisioning first

- **Certificate Architecture Migration to Public ACM**

- **Certificate Architecture Migration to Public ACM**
  - Migrated from Private CA-based certificates to Public ACM certificates
    (Amazon-issued) for browser-trusted certificates
  - Public ACM certificates are requested in each deployment account and
    validated via DNS records in State Account's Route53 hosted zone
  - Certificates are automatically renewed by ACM (no manual intervention
    required)
  - Eliminates browser security warnings and simplifies certificate management
  - Updated all documentation to reflect Public ACM certificate architecture
  - Comprehensive Public ACM certificate setup documentation in
    `application/CROSS_ACCOUNT_ACCESS.md` with step-by-step AWS CLI commands
  - Private CA setup moved to "Legacy" section (deprecated for public-facing
    applications)

- **Image Tag Standardization Update**
  - Updated Redis and PostgreSQL image tags to use 'latest' tag instead of
    version-specific tags
  - Redis default image tag changed from `redis-8.4.0` to `redis-latest`
  - PostgreSQL default image tag changed from `postgresql-18.1.0` to
    `postgresql-latest`
  - OpenLDAP continues to use specific version tag: `openldap-1.5.0`
  - Updated ECR image mirroring script to use 'latest' tags
  - Updated all documentation to reflect new image tag naming convention

- **Comprehensive Documentation Updates**
  - Updated `docs/index.html` with latest features and information
  - Updated main `README.md` with Public ACM certificate prerequisites
  - Updated `application/README.md` with latest features and certificate
    architecture
  - Updated `backend_infra/README.md` with ExternalId and latest changes
  - Updated `tf_backend_state/README.md` with automatic ARN detection
  - All documentation now reflects Public ACM certificates as the recommended
    approach
  - Updated API documentation references to clarify always-enabled status
  - Added Helm release safety, ECR image support, and Kubeconfig auto-update
    documentation

### Fixed

- **Documentation Consistency**
  - Fixed inconsistent references to Private CA vs Public ACM certificates
  - Updated all prerequisites to reference Public ACM certificate setup
  - Corrected image tag references across all documentation files
  - Ensured all documentation reflects current implementation state

## [2026-01-15] - Helm Release Safety, ECR Image Support, and Infrastructure Improvements

### Added

- **Helm Release Attributes for Safer Deployments**
  - Added comprehensive Helm release attributes to all application modules
  (OpenLDAP, PostgreSQL, Redis) for safer and more reliable deployments. The
  cert-manager module code was also updated but the module is not invoked in main.tf.
  - Attributes include: atomic, force_update, replace, cleanup_on_fail,
  recreate_pods, wait, wait_for_jobs, upgrade_install
  - Prevents partial deployments, enables proper rollbacks, and ensures resource
  readiness
  - OpenLDAP module timeout set to 5 minutes, PostgreSQL and Redis modules set
  to 10 minutes

- **Standardized Helm Values Passing**
  - Standardized how Helm values are passed through to all modules using consistent
  `templatefile()` approach
  - All modules now support `values_template_path` variable for custom template
  paths
  - Created comprehensive Helm values templates for PostgreSQL and updated
  Redis/OpenLDAP templates
  - Improved maintainability and consistency across all Helm chart deployments

- **PostgreSQL Chart Repository Fix**
  - Fixed PostgreSQL Helm chart download issue by changing to OCI registry format
  - Changed repository from `https://charts.bitnami.com/bitnami` to `oci://registry-1.docker.io/bitnamicharts`
  - Resolves chart download failures during deployment

- **Image Tag Standardization**
  - Changed Redis and PostgreSQL image tags to use 'latest' tag instead of SHA digests
  - Redis default image tag: `redis-latest`
  - PostgreSQL default image tag: `postgresql-latest`
  - OpenLDAP continues to use specific version tag: `openldap-1.5.0`
  - Simplifies image management and updates while maintaining version control

- **Public ACM Certificate Architecture**
  - Migrated to Public ACM certificates (Amazon-issued) for browser-trusted
    certificates
  - Public ACM certificates requested in each deployment account (development,
    production)
  - DNS validation records created in Route53 hosted zone in State Account
  - Certificates stored in respective deployment accounts (not State Account)
  - Eliminates cross-account certificate access complexity
  - Compatible with EKS Auto Mode ALB controller requirements (certificate must
    be in same account as ALB)
  - Comprehensive Public ACM certificate setup documentation in
    `application/CROSS_ACCOUNT_ACCESS.md` with step-by-step AWS CLI commands
  - Certificate validation workflow documented for both production and development
    accounts
  - Certificates automatically renewed by ACM (no manual intervention required)
  - Browser-trusted certificates (no security warnings)

- **State Account Role ARN Support for Route53 Cross-Account Access**
  - Added support for querying Route53 hosted zones from State Account
  - New variable `state_account_role_arn` in `application/variables.tf` for
    assuming role in State Account
  - State account provider alias (`aws.state_account`) configured in
    `application/providers.tf`
  - All Route53 data sources and resources use state account provider when
    configured
  - Route53 records created in State Account while ALB deployed in Deployment
    Account
  - Route53 DNS validation records for Public ACM certificates created in State
    Account
  - ACM certificates are Public ACM certificates (Amazon-issued) requested in
    Deployment Account (not State Account)
  - Scripts automatically inject `state_account_role_arn`:
    - `application/setup-application.sh` exports `STATE_ACCOUNT_ROLE_ARN`
    - `application/set-k8s-env.sh` injects into `variables.tfvars`
  - GitHub Actions workflows export `STATE_ACCOUNT_ROLE_ARN` for automatic
    injection
  - No ExternalId required for state account role assumption (by design)
  - Comprehensive cross-account access documentation in
    `application/CROSS_ACCOUNT_ACCESS.md`
  - Updated ALB module to handle null certificate ARN and include in triggers

- **ExternalId Support for Cross-Account Role Assumption**
  - Added ExternalId requirement for enhanced security when assuming deployment
  account roles
  - ExternalId retrieved from AWS Secrets Manager (secret: `external-id`) for
  local deployment
  - ExternalId retrieved from GitHub repository secret (`AWS_ASSUME_EXTERNAL_ID`)
  for GitHub Actions
  - ExternalId passed to Terraform provider's `assume_role` block in both
  `application` and `backend_infra`
  - New variable `deployment_account_external_id` added to `application/variables.tf`
  and `backend_infra/variables.tf`
  - Setup scripts (`setup-application.sh` and `setup-backend.sh`) automatically
  retrieve ExternalId from AWS Secrets Manager
  - GitHub Actions workflows updated to use `AWS_ASSUME_EXTERNAL_ID` secret
  - Deployment account roles must have ExternalId condition in Trust Relationship
  - **Bidirectional Trust Relationships**: Both deployment account roles and state
    account role must trust each other in their respective Trust Relationships
  - State account role's Trust Relationship must include deployment account role
    ARNs to enable proper cross-account role assumption
  - Prevents confused deputy attacks in multi-account deployments
  - ExternalId generation: `openssl rand -hex 32`
  - Comprehensive documentation updates across all README files,
  SECURITY_IMPROVEMENTS.md, and docs/index.html

- **Destroy Scripts for Infrastructure Cleanup**
  - Created `application/destroy-application.sh` script for destroying application
  infrastructure
  - Created `backend_infra/destroy-backend.sh` script for destroying backend
  infrastructure
  - Both scripts support interactive region and environment selection
  - Automatic retrieval of role ARNs, ExternalId, and secrets from AWS Secrets
  Manager
  - Automatic backend configuration and variables.tfvars updates
  - Kubernetes environment setup for application destroy script
  - Safety confirmations required before destruction (type 'yes' then 'DESTROY')
  - Comprehensive error handling and user guidance
  - Updated GitHub Actions destroying workflows with ExternalId support
  - Documentation updates in README files and docs/index.html

- **Route53 Record Module Separation**
  - Separated Route53 record creation from OpenLDAP module into dedicated
    `route53_record` module
  - New module located at `application/modules/route53_record/` for per-record
    creation
  - Module uses state account provider for cross-account access (Route53 records
    created in State Account)
  - Three separate module calls: `route53_record_phpldapadmin`,
    `route53_record_ltb_passwd`, `route53_record_twofa_app`
  - Module outputs: `record_name`, `record_fqdn`, `record_id`
  - Precondition ensures ALB DNS name is available before record creation
  - Comprehensive ALB zone_id mapping by region (13 AWS regions supported)
  - Proper dependency chain: OpenLDAP module → ALB data source → Route53 records
  - All records use consistent ALB data source approach to avoid timing issues
  - Comprehensive module documentation in `application/modules/route53_record/README.md`

- **ECR Image Mirroring Script**
  - Created `application/mirror-images-to-ecr.sh` script to eliminate Docker Hub
    rate limiting and external dependencies
  - Automatically mirrors third-party container images from Docker Hub to ECR:
    - `bitnami/redis:8.4.0-debian-12-r6` → `redis-latest`
    - `bitnami/postgresql:18.1.0-debian-12-r4` → `postgresql-latest`
    - `osixia/openldap:1.5.0` → `openldap-1.5.0`
  - Checks if images exist in ECR before mirroring (skips if already present)
  - Uses State Account credentials to fetch ECR URL from backend_infra state
  - Assumes Deployment Account role for ECR operations (with ExternalId)
  - Authenticates Docker to ECR automatically
  - Cleans up local images after pushing to save space
  - Lists all images in ECR repository after completion
  - Integrated into `application/setup-application.sh` (runs before Terraform
    operations)
  - Integrated into GitHub Actions workflow (runs after Terraform validate, before
    set-k8s-env.sh)
  - Requires Docker to be installed and running
  - Requires `jq` for JSON parsing
  - Prevents Docker Hub rate limiting and external dependencies during deployments

- **ECR Image Support for Modules**
  - OpenLDAP, PostgreSQL, and Redis modules now use ECR images instead of
  Docker Hub
  - New variables in `application/variables.tf`:
    - `openldap_image_tag` (default: "openldap-1.5.0")
    - `postgresql_image_tag` (default: "postgresql-latest")
    - `redis_image_tag` (default: "redis-latest")
  - ECR registry and repository computed from backend_infra state (`ecr_url`)
  - All modules updated with ECR configuration variables:
    - `ecr_registry`: ECR registry URL
    - `ecr_repository`: ECR repository name
    - `image_tag` or module-specific tag variable
  - Helm values templates updated to use ECR images
  - Image tags correspond to tags created by `mirror-images-to-ecr.sh`

### Changed

- **Module Documentation Updates**
  - Updated all module READMEs with standardized Helm values passing documentation
  - Enhanced PostgreSQL, Redis, OpenLDAP, ALB, and ArgoCD module documentation
  - cert-manager module README was also updated (module exists but is not invoked)
  - Added comprehensive Route53 module README documentation
  - Improved consistency and clarity across all module documentation

- **Helm Values Template Organization**
  - Standardized Helm values template structure across all modules
  - Improved template variable naming and organization
  - Enhanced template documentation and comments

- **Kubeconfig Auto-Update to Prevent Stale Cluster Endpoints**
  - Fixed issue where kubeconfig could contain stale cluster endpoints after
    cluster recreation or endpoint changes
  - `set-k8s-env.sh` now automatically updates kubeconfig on every run using
    `aws eks update-kubeconfig`
  - Ensures kubeconfig always contains the latest cluster endpoint before any
    kubectl commands are executed
  - Prevents DNS lookup errors like: `dial tcp: lookup
    26A3426590C00FBB5A84A506D1F8B14A.gr7.us-east-1.eks.amazonaws.com: no such host`
  - Uses deployment account credentials (already assumed by the script) for
    kubeconfig update
  - Automatically creates kubeconfig directory if it doesn't exist
  - Script exits with error if kubeconfig update fails, preventing deployment
    with incorrect configuration
  - Fixes issues with Terraform provisioners (e.g., ALB IngressClassParams) that
    use kubectl commands

- **Documentation Improvements**
  - Removed duplication across README files by replacing detailed content with
  links to module documentation
  - Enhanced cross-references between main README, application README,
  and module READMEs
  - Updated architecture overview sections to be more concise with links to
  detailed documentation
  - Improved module documentation references in application and backend
  infrastructure READMEs
  - Added links to PRD documents for detailed feature specifications
  - Updated changelog references in main README

- **Setup Script Improvements**
  - Enhanced `backend_infra/setup-backend.sh` with improved error handling and
  ExternalId support
  - Enhanced `application/setup-application.sh` with improved error handling,
  ExternalId support, and Kubernetes environment setup
  - Both scripts now automatically retrieve ExternalId from AWS Secrets Manager
  - Improved role assumption logic with better error messages
  - Enhanced secret retrieval with validation and error handling
  - Better integration with GitHub repository variables and secrets
  - Improved user guidance and confirmation prompts
  - Improved credential handling to prevent conflicts between different AWS
    credentials
  - Better dependency chain organization to prevent failures
  - Enhanced script error handling in destroy scripts

- **GitHub Actions Workflow Updates**
  - Updated `02-application_infra_provisioning.yaml` with new environment variables
  for Redis, PostgreSQL, and SES
  - Added Docker Buildx setup step for image operations
  - Added "Mirror Docker images to ECR" step (runs after Terraform validate, before
    set-k8s-env.sh)
  - Workflow now handles image mirroring automatically
  - Improved credential handling to prevent conflicts between different AWS
    credentials
  - Updated `02-application_infra_destroying.yaml` with ExternalId support and
  improved error handling
  - Updated `01-backend_infra_provisioning.yaml` with ExternalId support
  - Updated `01-backend_infra_destroying.yaml` with ExternalId support and
  improved error handling
  - Workflows now pass Redis password via `TF_VAR_redis_password` environment
  variable (from GitHub Secret `TF_VAR_REDIS_PASSWORD`)
  - Workflows now pass PostgreSQL password via `TF_VAR_postgresql_database_password`
  environment variable (from GitHub Secret `TF_VAR_POSTGRES_PASSWORD`)
  - All workflows now use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state
  operations
  - All workflows now use `AWS_ASSUME_EXTERNAL_ID` for cross-account role
  assumption security
  - Maintains backward compatibility with existing OpenLDAP password secrets

- **Comprehensive Product Requirements Documents**
  - Added `PRD_SIGNUP_MAN.md` for user signup management system
  - Added `PRD_ADMIN_FUNCS.md` for admin functions and profile management
  - Added `PRD_SMS_MAN.md` for SMS OTP management with Redis

- **Documentation and linting improvements**
  - All documentation files updated for Markdown lint compliance
  - Added `.markdownlint.json` for consistent formatting across the project
  - Improved formatting consistency across CHANGELOG, README, and PRD files

- **Enhanced Network Policies**
  - Added cross-namespace communication rules for LDAP service access
  - Allows services in other namespaces to access LDAP on secure
  ports (443, 636, 8443)
  - Maintains security by only allowing encrypted ports

- **VPC Endpoints module enhancements**
  - Added `enable_sts_endpoint` and `enable_sns_endpoint` configuration options
  - Added `vpc_cidr` variable for security group rules
  - New outputs for STS and SNS endpoint IDs

- **Password management approach**
  - OpenLDAP passwords are now managed exclusively through GitHub repository
  secrets
  - Removed dependency on local password files or environment-specific
  configurations
  - Setup scripts automatically retrieve passwords from GitHub secrets
  - Updated documentation to reflect new password management workflow
  - Improved security by eliminating password storage in local files

- **Setup script consolidation**
  - Replaced `setup-backend.sh` and `setup-backend-api.sh` with unified
  `setup-application.sh`
  - New script provides complete end-to-end deployment automation
  - Improved error messages and user guidance
  - Better integration with GitHub repository secrets and variables

- **Documentation updates**
  - Updated `README.md` with comprehensive password management instructions and
  three-role architecture documentation
  - Updated `WARP.md` with latest setup procedures and password handling
  - Updated `application/README.md` to reflect new setup script workflow
  - Updated `backend_infra/README.md` to reflect environment-based role
  selection
  - Clarified local vs. GitHub Actions execution differences
  - Clarified the separation between backend state operations and deployment
  operations
  - Updated AWS IAM setup instructions to reflect the new role structure

- **Multi-account architecture clarification**
  - Separated backend state operations from deployment operations
  - Backend state operations now use `AWS_STATE_ACCOUNT_ROLE_ARN` (State
  Account)
  - Deployment operations use environment-specific role ARNs
  (`AWS_PRODUCTION_ACCOUNT_ROLE_ARN` or `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`)
  - Updated all workflows to use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend
  operations
  - Updated workflows to set `deployment_account_role_arn` variable based on
  selected environment

- **Workflow updates**
  - `01-backend_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role
  - `01-backend_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role
  - `02-application_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN`
  for backend, sets environment-based deployment role
  - `02-application_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role

## [2025-12-20] - User Signup, Admin Functions, and Infrastructure Modules

### Added

- **API Documentation (Swagger UI)**
  - FastAPI Swagger UI now always enabled at `/api/docs` (previously only available
  in debug mode)
  - ReDoc UI always available at `/api/redoc`
  - OpenAPI schema accessible at `/api/openapi.json`
  - Interactive API documentation automatically updates when endpoints change
  - Accessible at `https://app.<domain>/api/docs` for API exploration and testing

- **User Signup Management System**
  - Self-service user registration with profile fields (first name, last name,
  username, email, phone, password, MFA method)
  - Email verification via AWS SES with token-based verification links
  - Phone verification via AWS SNS with 6-digit OTP codes
  - Profile state management (PENDING → COMPLETE → ACTIVE)
  - PostgreSQL database for storing user data before LDAP activation
  - Administrator user management interface for approval workflow
  - Login restrictions based on verification status

- **Admin Functions and User Profile Management**
  - User profile page with viewable and editable fields
  - Edit restrictions for verified email/phone (read-only after verification)
  - Admin dashboard (only visible to LDAP admin group members)
  - Group CRUD operations (create, read, update, delete)
  - User-group assignment and management
  - Approve/Revoke workflow for user activation
  - List features with sorting, filtering, and searching
  - Admin email notifications on new user signup
  - Top navigation bar with user menu after login

- **PostgreSQL Module (`application/modules/postgresql/`)**
  - Bitnami PostgreSQL Helm chart deployment via Terraform
  - Database for storing user registrations and verification tokens
  - Password authentication via Kubernetes Secret (from GitHub Secrets)
  - PersistentVolume storage for data durability

- **SES Module (`application/modules/ses/`)**
  - AWS SES email identity verification
  - IAM Role configured for IRSA
  - Email sending capabilities for verification and notifications
  - Welcome email on user activation

- **Redis Module for SMS OTP Storage (`application/modules/redis/`)**
  - Bitnami Redis Helm chart deployment via Terraform
  - Replaces in-memory storage for SMS OTP codes
  - TTL-based automatic expiration for OTP codes
  - Network policy restricting Redis access to backend pods only
  - Password authentication via Kubernetes Secret

- **Two-Factor Authentication (2FA) Application**
  - Full-stack 2FA solution with Python FastAPI backend and static HTML/JS/CSS
  frontend
  - Dual MFA methods: TOTP (authenticator apps) and SMS (AWS SNS)
  - Single domain routing with path-based access (`/` for frontend, `/api/*` for
  backend)
  - Complete Helm charts, Dockerfiles, and Kubernetes resources for deployment
  - Comprehensive PRD documentation (`PRD_2FA_APP.md`)

- **ArgoCD GitOps Integration**
  - AWS EKS managed ArgoCD service deployment
  - ArgoCD Application module for GitOps-driven deployments
  - Support for Kubernetes manifests, Helm charts, and Kustomize
  - AWS Identity Center (IdC) authentication and RBAC mappings
  - ECR and CodeCommit access policy configuration

- **IRSA (IAM Roles for Service Accounts) Support**
  - Enabled OIDC provider on EKS cluster for secure pod-to-AWS-service
  authentication
  - New outputs: `oidc_provider_arn` and `oidc_provider_url`
  - Required for secure SNS access from application pods

- **VPC Endpoints for Private AWS Service Access**
  - STS VPC endpoint for IRSA/web identity role assumption
  - SNS VPC endpoint for SMS 2FA functionality
  - VPC CIDR security group rule for pod access to endpoints

- **SNS Module for SMS-based 2FA**
  - SNS Topic for centralized SMS notifications
  - IAM Role configured for IRSA
  - Direct SMS support with E.164 phone number format
  - Cost control via monthly spend limits

- **OpenLDAP password management via GitHub repository secrets**
  - `setup-application.sh` now automatically retrieves OpenLDAP passwords from
  GitHub repository secrets
  - New GitHub secrets: `TF_VAR_OPENLDAP_ADMIN_PASSWORD` and
  `TF_VAR_OPENLDAP_CONFIG_PASSWORD`
  - Script automatically exports passwords as environment variables for
  Terraform
  - Supports both GitHub Actions (automatic) and local execution (requires
  exported environment variables)
  - Eliminates need to manually manage password files or commit sensitive data

- **Consolidated application setup script**
  - New unified `setup-application.sh` script replaces `setup-backend.sh` and
  `setup-backend-api.sh`
  - Handles complete application deployment workflow: role assumption, backend
  configuration, Terraform operations, and Kubernetes environment setup
  - Automatically retrieves all required secrets and variables from GitHub
  - Includes comprehensive error handling and user-friendly output

- **Environment-based AWS role ARN selection**
  - Added support for separate role ARNs for production and development
  environments
  - New GitHub secrets: `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` and
  `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
  - Workflows and scripts automatically select the appropriate role ARN based on
  selected environment (`prod` or `dev`)
  - `setup-backend.sh` script now retrieves and uses environment-specific
  deployment account role ARNs

- **Automated Terraform execution in setup scripts**
  - `setup-backend.sh` now automatically runs Terraform commands (init,
  workspace, validate, plan, apply)
  - Eliminates the need for manual Terraform command execution after backend
  configuration
  - Script handles workspace creation/selection automatically

- **Automated backend.hcl creation**
  - `setup-backend.sh` now automatically creates `backend.hcl` from template if
  it doesn't exist
  - Skips creation if `backend.hcl` already exists (prevents overwriting
  existing configuration)

- **New GitHub Secrets for Infrastructure Components**
  - `TF_VAR_REDIS_PASSWORD`: Redis authentication password for SMS OTP storage
  (exported as `TF_VAR_redis_password`)
  - `TF_VAR_POSTGRES_PASSWORD`: PostgreSQL database password for user data
  (exported as `TF_VAR_postgresql_database_password`)
  - All secrets follow existing pattern (TF_VAR_ prefix for Terraform
  integration)
  - **Note:** Secret names in GitHub/AWS remain uppercase, but environment
  variables must be lowercase to match variable names in `variables.tf`

### Removed

- **Removed legacy setup scripts**
  - Removed `application/setup-backend.sh` (replaced by `setup-application.sh`)
  - Removed `application/setup-backend-api.sh` (replaced by
  `setup-application.sh`)
  - Consolidated functionality into single unified script for better
  maintainability

- **Removed `provider_profile` variable**
  - Removed `provider_profile` variable from `backend_infra/variables.tf` and
  `application/variables.tf`
  - Removed `provider_profile` from `backend_infra/variables.tfvars` and
  `application/variables.tfvars`
  - Removed `profile = var.provider_profile` from `backend_infra/providers.tf`
  and `application/providers.tf`
  - No longer needed since role assumption is handled via setup scripts and
  workflows

### Fixed

- **Corrected role ARN usage in workflows**
  - Fixed workflows to use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state
  operations
  - Fixed workflows to use environment-based role ARNs for deployment operations
  via `deployment_account_role_arn` variable

## [2025-12-19] - Terraform Backend State Infrastructure v1.0.0

### Changed

- **Terraform Backend State Infrastructure (v1.0.0)**
  - Migrated from DynamoDB-based state locking to S3 file-based locking
    (`use_lockfile = true`)
  - Updated AWS provider to version 6.21.0
  - Updated Terraform required version to 1.14.0
  - Improved automation scripts (`get-state.sh` and `set-state.sh`) to use
    AWS Secrets Manager instead of GitHub CLI for secret access
  - Enhanced documentation with detailed troubleshooting sections
  - Improved error handling and user feedback in automation scripts

### Removed

- **Terraform Backend State Infrastructure (v1.0.0)**
  - Removed DynamoDB table and all related resources (deprecated in favor
    of S3 file-based locking)
  - Removed all references to DynamoDB from code and documentation

## [2025-12-18] - 2FA Application and IRSA Infrastructure

### Added

- Full-stack 2FA application with TOTP and SMS verification methods
- IRSA (IAM Roles for Service Accounts) support on EKS cluster
- VPC endpoints for STS and SNS for private AWS service access
- SNS module for SMS-based 2FA verification

### Changed

- Enhanced network policies to support cross-namespace communication
- Updated VPC endpoints module with STS and SNS endpoint options
- Added new IRSA-related outputs to backend infrastructure

## [2025-12-16] - ArgoCD GitOps Integration

### Added

- ArgoCD capability module for EKS-managed ArgoCD service
- ArgoCD application module for GitOps-driven deployments
- Support for multiple deployment types (Kubernetes manifests, Helm, Kustomize)
- AWS Identity Center authentication and RBAC integration

## [2025-12-15] - Documentation and Linting Improvements

### Changed

- Comprehensive documentation updates for Markdown lint compliance
- Added `.markdownlint.json` configuration for consistent formatting
- Enhanced network policies module documentation

## [2025-12-14] - Deployment Versatility and Security Improvements

### Changed

- Made the deployment more versatile and secure
- Improved Terraform state deployment automation
- Updated documentation

## [2025-12-10] - Output and Ingress Configuration Updates

### Added

- Bubbled up outputs and added new ones
- Updated WARP.md documentation

### Fixed

- Corrected attributes across IngressClass, IngressClassParams, and the two
Ingresses
- Updated documentation to reflect changes

## [2025-12-08] - ALB, TLS, and Documentation Updates

### Added

- Consolidated annotations
- Added naming logic for better resource identification

### Changed

- Latest updates to resolve ALB and TLS issues (ALB issue still under
investigation)
- Updated documentation

### Removed

- Removed any mention of DynamoDB as that functionality is deprecated in
managing TF state

## [2025-12-03] - Backend Infrastructure Workflow Updates

### Changed

- Updated backend infrastructure workflows

## [2025-12-02] - Application Infrastructure and Storage

### Added

- Main application infrastructure related to the OpenLDAP Helm deployment

### Changed

- Commented out the use of the EBS module because OpenLDAP creates one per pod
already.

## [2025-12-01] - Circular Dependency Resolution and Documentation

### Fixed

- Resolved circular dependency issue with EKS module in the providers

### Changed

- Updated names in code and documentation
- Added WARP.md file which works with the Warp Terminal Agent

## [2025-11-27] - EBS Module Outputs

### Added

- Added outputs for the EBS module to get the name of the PVC for later use in
the application

## [2025-11-26] - VPC Endpoints, Storage, and ECR

### Added

- Added 3 VPC Endpoints
- Added EBS Storage Class and Claim
- Added ECR (Elastic Container Registry)
- Added CloudWatch logs
- Upgraded Kubernetes version to 1.34
- Updated documentation with all the latest changes

## [2025-11-25] - EKS Cluster and Backend Infrastructure

### Added

- Added EKS Auto cluster
- Initial backend infrastructure (VPC)
- Local setup with bash files
- Remote setup with GitHub workflows
- Interactive Region and Environment selection in both local and remote setups

### Changed

- Removed the use of profile in the provider

### Fixed

- Fixed bucket prefix issue: the prefix cannot start with '/' when defining the
'key' attribute for the backend state

## [2025-11-24] - Backend State Management Improvements

### Added

- Added backend state table name as an output
- Altered workflows to save and retrieve backend state table name
- Updated documentation

### Fixed

- Updated provisioning workflow to pre-check for an already existing state to
prevent errors

## [2025-11-23] - Backend State Infrastructure

### Added

- Upgraded versions of AWS provider and Terraform
- Added files to begin with main infrastructure
- Added a README to the backend state that explains everything
- Added a link to backend state README in the main README
- Added missing GitHub Token
- Added a way to manage the backend state's state without having to commit it to
the repository
- Added a way to transfer the backend bucket name after its creation
- Added account number to bucket name to make it unique

## [2025-11-22] - Initial Project Setup

### Added

- Initial commit
- Added Terraform backend state and GitHub Actions to deploy and destroy it

## Architecture Overview

This project uses a multi-account architecture:

- **State Account (Account A)**: Stores Terraform state files in S3
- **Production Account (Account B)**: Contains production infrastructure
resources
- **Development Account (Account B)**: Contains development infrastructure
resources

### Key Components

- Terraform backend state infrastructure (`tf_backend_state/`)
- Backend infrastructure (VPC, EKS cluster, VPC endpoints, IRSA) (`backend_infra/`)
- Application infrastructure (OpenLDAP, 2FA app, ALB, Route53, ArgoCD)
(`application/`)
- 2FA Backend and Frontend applications (`application/backend/`,
`application/frontend/`)
- GitHub Actions workflows for CI/CD (`.github/workflows/`)

### Supporting Infrastructure

- **PostgreSQL** (`application/modules/postgresql/`): User registration and
verification token storage
- **Redis** (`application/modules/redis/`): SMS OTP code storage with TTL
- **SES** (`application/modules/ses/`): Email verification and notifications
- **SNS** (`application/modules/sns/`): SMS-based 2FA verification

### Required GitHub Secrets

| Secret | Purpose |
| -------- | --------- |
| `AWS_STATE_ACCOUNT_ROLE_ARN` | Role for Terraform state operations |
| `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` | Role for production deployments |
| `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` | Role for development deployments |
| `TF_VAR_OPENLDAP_ADMIN_PASSWORD` | OpenLDAP admin password (exported as `TF_VAR_openldap_admin_password`) |
| `TF_VAR_OPENLDAP_CONFIG_PASSWORD` | OpenLDAP config password (exported as `TF_VAR_openldap_config_password`) |
| `TF_VAR_REDIS_PASSWORD` | Redis authentication password (exported as `TF_VAR_redis_password`) |
| `TF_VAR_POSTGRES_PASSWORD` | PostgreSQL database password (exported as `TF_VAR_postgresql_database_password`) |

## Notes

### Role ARN Selection Logic

The system automatically selects the appropriate role ARN based on the
environment:

- **Backend State Operations**: Always uses `AWS_STATE_ACCOUNT_ROLE_ARN`
- **Deployment Operations**:
  - `prod` environment → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` environment → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`

### Setup Script Behavior

The `setup-backend.sh` script:

1. Assumes `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
2. Retrieves the appropriate deployment account role ARN based on selected
environment
3. Creates `backend.hcl` if it doesn't exist
4. Updates `variables.tfvars` with region, environment, and deployment account
role ARN
5. Runs Terraform commands automatically (init, workspace, validate, plan,
apply)

### Terraform State Management

- **S3 File-Based Locking**: The Terraform backend state infrastructure
  (v1.0.0) uses S3 file-based locking (`use_lockfile = true`) instead of
  DynamoDB
- **State Storage**: All Terraform state files are stored in S3 with
  versioning enabled and server-side encryption (AES256)
- **Access Control**: IAM-based access control with principal ARN support
  and OIDC-based authentication (no access keys required)
- **Automation**: Local automation scripts (`get-state.sh` and
  `set-state.sh`) use AWS Secrets Manager for role ARN retrieval
- **Security**: Private bucket ACL configuration, comprehensive public
  access blocking, and encryption at rest for all state files
- **Provider Versions**: AWS provider 6.21.0, Terraform 1.14.0
- All references to DynamoDB have been removed from code and
  documentation

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
