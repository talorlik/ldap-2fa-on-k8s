# Changelog

All notable changes to the application infrastructure will be documented in this
file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
>
> This changelog contains infrastructure-related changes (OpenLDAP, ALB, Route53,
> ArgoCD Capability, StorageClass, Network Policies). Application changes
> (PostgreSQL, Redis, SES, SNS, 2FA application backend/frontend, ArgoCD Applications)
> are documented in [application/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md).

## [2026-02-26] - OpenLDAP Custom LDIF Mount Fix and Headless Host Output

### Added

- **OpenLDAP headless host output**
  - OpenLDAP module and root now expose `ldap_headless_host` (e.g.
  `openldap-stack-ha-headless.ldap.svc.cluster.local`) for StatefulSet pod DNS
  addressing. The 2FA application admin-seed job uses this so `seed_admin.py`
  can connect to OpenLDAP replicas by pod hostname, fixing "invalid server
  address" when using the ClusterIP service host for replica connections.

### Changed

- **OpenLDAP chart (osixia): Custom LDIF bootstrap mount**
  - Resolved mount directory issue so osixia cleanup of configuration files
  works correctly during startup. Custom LDIF volume is now mounted read-only
  at `/tmp/custom-ldif-files`; the container entrypoint copies files from there
  into `/container/service/slapd/assets/config/bootstrap/ldif/custom/` before
  running `/container/tool/run`. The bootstrap custom directory is no longer
  a direct volume mount, avoiding conflicts with osixia's startup cleanup.
  - See [OPENLDAP_CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/OPENLDAP_CHANGELOG.md)
  [5.0.2].

## [2026-02-26] - Log Capture, Busybox ECR, Network Policy LDAP Port

### Added

- **Capturing logs before rollback**: New guide
  [CAPTURING_LOGS_BEFORE_ROLLBACK](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_infra/CAPTURING_LOGS_BEFORE_ROLLBACK.md)
  and script `scripts/capture-openldap-logs.sh`. When OpenLDAP deploy fails with
  atomic rollback, logs are lost. The guide explains setting `openldap_helm_atomic
  = false` for debugging so failed releases stay in place; the script dumps pod
  logs and describe output to a timestamped directory.
- **Busybox from ECR**: OpenLDAP chart init container (copy-custom-ldif) now
  supports `customLdifInitImage` so busybox can be mirrored to ECR and used
  instead of Docker Hub (`busybox:1.36`), avoiding rate limits. Mirror script
  `scripts/mirror-images-to-ecr.sh` adds `busybox:1.36` as tag `busybox-1.36`.
  New variable `openldap_busybox_image_tag` (default `busybox-1.36`).
- **Network policy port 389**: LDAP plain port 389 added to
  `namespace-secure-communication` policy (ingress/egress) so internal LDAP
  traffic is allowed once policies are created.

### Changed

- **OpenLDAP chart**: Version 5.0.1; new optional value `customLdifInitImage`.
  See [OPENLDAP_CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/OPENLDAP_CHANGELOG.md).
- **variables.tfvars**: Commented example for `openldap_helm_atomic = false`
  for debugging.

## [2026-02-25] - ArgoCD Single Sleep and OpenLDAP Pre-deploy in Module

### Changed

- **OpenLDAP Module: Pre-deploy Delay Moved into Module (3m)**
  - Moved `time_sleep.openldap_pre_deploy` from root into the OpenLDAP module
  as `time_sleep.pre_deploy`, the first resource in the module (3m fixed).
  - Root `module.openldap` now depends on StorageClass, ALB, and ArgoCD
  directly; the module applies the delay internally before creating namespace
  and Helm release.
  - Removed root variable `openldap_pre_deploy_delay_seconds`.

- **ArgoCD Module: Single Sleep for Capability Readiness**
  - Removed redundant `time_sleep.wait_after_argocd_propagation`; it ran
  immediately after `time_sleep.wait_for_argocd` with no other work in between.
  - All dependent resources now depend only on `time_sleep.wait_for_argocd`.
  - `wait_capability_ready_duration` default set to `330s` (was 5m + 30s
  separate sleeps). Removed variable `wait_after_capability_propagation_duration`.

## [2026-02-24] - ArgoCD IAM Revert and IngressClassParams Import Guidance

### Changed

- **ArgoCD Module: IAM Permissions Reverted to Single Inline Policy**
  - Removed dependency on AWS managed policy
  `AmazonEKSCapabilityArgoCD` (policy does not exist or is not attachable in
  some regions/accounts). The capability role now uses only one inline policy
  (`aws_iam_role_policy.argocd_capability`) with EKS, Secrets Manager, KMS,
  CodeConnections (incl. UseConnection), and optional ECR/CodeCommit when
  enabled. Same permissions as before; no managed policy attachment.
  - `time_sleep.wait_for_iam_and_ns_propagation` now depends on
  `aws_iam_role_policy.argocd_capability` only.

- **ALB Module: IngressClassParams "Already Exists"**
  - Added comment and troubleshooting steps when apply fails with "resource
  ... already exists" for `kubernetes_manifest.ingressclassparams_alb`. Import
  the existing resource into state so Terraform can manage/update it; see
  [APPLICATION_INFRA_DEPLOYMENT](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  (section "ALB / IngressClassParams Failures").

### Documentation

- **ArgoCD IAM**
  - ArgoCD module README, PRD_ArgoCD, DEBUG_COMMANDS, and
  APPLICATION_INFRA_DEPLOYMENT updated to match. Permissions-by-service
  table, recommendations, and AWS doc links live in the module README.
- **IngressClassParams**
  - New troubleshooting section "ALB / IngressClassParams Failures" with
  `terraform import` command for existing IngressClassParams.

## [2025-02-23] - OpenLDAP, ArgoCD, PhpLdapAdmin/LTB-passwd, and Destroy Cleanup

### Changed

- **ArgoCD Module Ordering and Dependency Graph**
  - ArgoCD module is declared at the top of `main.tf` so it is created first;
  other modules can depend on its outputs.
  - Within the ArgoCD module: IAM and namespace propagation
  `time_sleep.wait_for_iam_and_ns_propagation` extended to 2m and includes
  namespace in `depends_on`; downstream resources (cluster registration secret,
  `aws_eks_access_policy_association`, Kubernetes manifests) depend on
  `time_sleep.wait_for_argocd` so the EKS capability's access entry is created
  before associating policies, avoiding AccessDenied race; EKS cluster data
  source moved to end of module.

- **StorageClass Volume Binding Mode**
  - `volume_binding_mode` set to `WaitForFirstConsumer` (reverted from
  `Immediate`). Required for EKS Auto Mode: the PVC is provisioned after a pod
  is scheduled, which triggers node creation; with `Immediate`, binding could
  occur before nodes exist.

- **OpenLDAP Module: ACM Certificate and Chart Configuration**
  - Removed `acm_cert_arn` variable from the OpenLDAP Terraform module. The ACM
  certificate is now configured only in IngressClassParams by the ALB module;
  the OpenLDAP module no longer receives or passes the certificate ARN.
  - OpenLDAP module now receives `alb_ssl_policy` from the parent module for
  ALB HTTPS listener configuration (passed through to Ingress annotations where
  applicable).
  - Chart is vendored locally at `application_infra/charts/openldap-stack-ha`
  (version 5.0.0, osixia/openldap:1.5.0). READMEs and module documentation
  reference [OPENLDAP_CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/OPENLDAP_CHANGELOG.md)
  for chart change details.

### Added

- **OpenLDAP Directory Structure Initialization via customLdifFiles**
  - Added `customLdifFiles` section to `helm/openldap-values.tpl.yaml` to
  automatically create the LDAP directory structure on all OpenLDAP pods
  - Creates `ou=users` and `ou=groups` organizational units on pod startup
  - Creates `cn=admins` group (objectClass `groupOfUniqueNames`) with placeholder
  member for 2FA application admin authorization
  - Fixes issue where multi-master replication didn't sync initial directory
  structure across pods (each pod initialized independently with empty directory)
  - Added `openldap_base_dn` variable and computed local in OpenLDAP module for
  LDIF template interpolation
  - See [LDAP and Admin-Seed Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED_TROUBLESHOOTING.md)
  for detailed investigation and root cause analysis

- **PhpLdapAdmin and LTB-passwd image mirroring and Helm timeout**
  - Mirroring of PhpLdapAdmin and LTB-passwd images to ECR added to
  `mirror-images-to-ecr.sh` (now in `scripts/`). Image names are injected into
  OpenLDAP Helm values via Terraform variables.
  - Helm apply timeout for OpenLDAP release increased to 20 minutes to accommodate
  longer apply times.

- **Destroy script and workflow cleanup step**
  - `destroy-application-infra.sh` and the application_infra destroying workflow
  now include a cleanup step so destroy runs leave the workspace in a consistent
  state.

### Fixed

- **OpenLDAP Helm Pod Labels**
  - In `helm/openldap-values.tpl.yaml`, ltb-passwd and phpldapadmin
  `podLabels` now use `app.kubernetes.io/part-of` instead of `app` to avoid
  conflicting with reserved/standard Kubernetes labels.

- **OpenLDAP Secret Key Name (osixia compatibility)**
  - Kubernetes secret uses key `LDAP_CONFIG_PASSWORD` (not
  `LDAP_CONFIG_ADMIN_PASSWORD`) to match the osixia/openldap image. The upstream
  jp-gouin/helm-openldap chart documents `LDAP_CONFIG_ADMIN_PASSWORD` for the
  Bitnami image; this project uses the osixia image. Terraform
  (`modules/openldap/main.tf`) and the vendored chart
  (`charts/openldap-stack-ha`) are aligned on `LDAP_CONFIG_PASSWORD`.
  - The Terraform variable name (`TF_VAR_OPENLDAP_CONFIG_PASSWORD`) is unchanged.
  - See [Osixia OpenLDAP Requirements](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application_infra/guides/OSIXIA_OPENLDAP_REQUIREMENTS.md).

- **OpenLDAP secret and chart: environment variable names for passwords**
  - Corrected secret key names in the vendored chart and Terraform to use
  `LDAP_ADMIN_PASSWORD` and `LDAP_CONFIG_PASSWORD` (osixia/openldap image
  convention). Chart templates and `values.yaml` updated so the created secret
  and container env vars match what the image expects.

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
    - `application_infra_provisioning.yaml`
    - `application_infra_destroying.yaml`
    - `application_provisioning.yaml`
  - Added step to make `assume-github-role.sh` executable in workflows
  (for local fallback)
  - All workflows now export `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID` as environment
  variables for ArgoCD module external data source

- **set-k8s-env.sh: BACKEND_PREFIX, workspace, and directory behavior**
  - Backend_infra state key is no longer hardcoded: uses `BACKEND_PREFIX`
  (e.g. from repository variables in CI) or parses `backend_infra/backend.hcl`
  when available.
  - Workspace for S3 state path is resolved from `TERRAFORM_WORKSPACE`, or
  `AWS_REGION`+`ENVIRONMENT`, or `terraform workspace show` (when run from
  application_infra after workspace select). Callers (setup/destroy scripts
  and CI) should export `TERRAFORM_WORKSPACE` or both `AWS_REGION` and
  `ENVIRONMENT` before sourcing the script.
  - Script restores the original working directory after running so that callers
  (e.g. application/setup-application.sh) are not left in `application_infra/`.
- **setup-application-infra.sh and destroy-application-infra.sh**
  - Both export `TERRAFORM_WORKSPACE="$WORKSPACE_NAME"` before sourcing
  `set-k8s-env.sh` so the correct backend_infra state is read in all contexts.
- **mirror-images-to-ecr.sh**
  - Backend_infra state key from `BACKEND_PREFIX` or `backend_infra/backend.hcl`;
  workspace from `TERRAFORM_WORKSPACE` or `AWS_REGION`+`ENVIRONMENT` for correct
  state path when mirroring images.

### Fixed

- **set-k8s-env.sh: Path Resolution When Sourced**
  - Fixed script directory detection when script is sourced (using `source ./set-k8s-env.sh`)
  - Changed from `$0` to `${BASH_SOURCE[0]}` for correct path resolution
  - Ensures script works correctly both locally and in GitHub Actions workflows
  - Fixes error: "backend.hcl not found" when running workflows

- **GitHub Actions: Automatic backend_infra/backend.hcl Creation**
  - Added automatic creation of `backend_infra/backend.hcl` in all relevant workflows:
    - `application_infra_provisioning.yaml`
    - `application_infra_destroying.yaml`
    - `application_provisioning.yaml`
    - `application_destroying.yaml`
  - Workflows now create `backend_infra/backend.hcl` from template before Terraform
  operations
  - Required because `application_infra/providers.tf` reads this file to access
  backend_infra remote state
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

## [2026-02-15] - LDAP Connection Outputs for 2FA Application

### Added

- **OpenLDAP module outputs** for use by the 2FA application (and other consumers)
so LDAP settings are not hardcoded:
  - `ldap_host` – OpenLDAP service DNS (e.g. `openldap-stack-ha.ldap.svc.cluster.local`)
  - `ldap_base_dn` – Base DN derived from `openldap_ldap_domain`
  - `ldap_admin_dn` – Admin bind DN
  - `ldap_admin_group_dn` – Admin group DN for 2FA app admin role
  - `ldap_user_search_base` – User search base (e.g. `ou=users`)
  - `ldap_group_search_base` – Group search base (e.g. `ou=groups`)
- **Root outputs** in `application_infra/outputs.tf` re-export the above from the
OpenLDAP module. The application layer reads these from remote state for the
admin-seed Job and can use them for manual Helm or other automation.

## [2026-02-15] - ALB Load Balancer Name Output for 2FA Application

### Added

- **Output `alb_load_balancer_name`**
  - Exposes the AWS ALB name used by OpenLDAP Ingresses (e.g.
    `talo-tf-us-east-1-alb-prod`). The 2FA application (backend and frontend)
    must use this same name on their Ingress annotations so they attach to the
    existing ALB. The application layer reads this output from remote state and
    passes it to ArgoCD Helm parameters to avoid "FailedBuildModel / conflicting
    load balancer name" errors.

## [2026-02-03] - ArgoCD Access Entry Association and Cluster Admin Policy

### Changed

- **ArgoCD Capability Permissions**
  - Corrected ArgoCD cluster access by associating EKS Access Policy with the
  automatically-created EKS Access Entry
  - Added `aws_eks_access_policy_association.argocd_capability_cluster_admin`
  resource to grant the ArgoCD Capability IAM role
  `AmazonEKSClusterAdminPolicy` (cluster scope)
  - EKS automatically creates an access entry for the ArgoCD Capability IAM role
  when the capability is created; the module now associates the access policy
  with that principal ARN
  - Retained existing ClusterRoleBinding for backward compatibility with IAM
  role-based RBAC
  - Ensures ArgoCD can sync applications and manage cluster-scoped resources
  (e.g., runtimeclasses.node.k8s.io) across all namespaces

## [2026-01-26] - ArgoCD Module External Data Resource Fix and Role Assumption Script

### Changed

- **ArgoCD Module External Data Resource**
  - Fixed external data resource to correctly fetch `server_url` and `status` from
  AWS EKS capability
  - Improved error handling with proper error reporting via `argocd_capability_error`
  output
  - Enhanced JSON parsing using `jq` for reliable data extraction
  - External data resource now uses `assume-github-role.sh` to assume the correct
  deployment account role based on environment
  - Added proper null/empty string handling with `trimspace()` and `try()` functions
  in outputs
  - Improved dependency management with `query` parameter for proper resource ordering
  - External data resource now properly handles role assumption failures and
  AWS CLI errors

- **ArgoCD Module Outputs**
  - Corrected `argocd_server_url` output to use `trimspace()` and `try()` for better
  null handling
  - Corrected `argocd_capability_status` output to use `trimspace()` and `try()`
  for better null handling
  - Added new `argocd_capability_error` output for error reporting when capability
  queries fail
  - All outputs now properly handle empty strings and null values

### Added

- **Role Assumption Script**
  - Created `assume-github-role.sh` script for convenient role switching in terminal
  - Supports assuming State Account, Development Account, or Production Account
  roles
  - Can be sourced (`source ./assume-github-role.sh [option]`) or executed with
  eval (`eval $(./assume-github-role.sh [option])`) for credential persistence
  - Automatically retrieves role ARNs from AWS Secrets Manager (secret: `github-role`)
  - Includes `clean` option to remove all AWS credentials from environment
  - Provides colored output and comprehensive error handling
  - Used by ArgoCD module external data resource for proper role assumption
  - Supports interactive account selection if no argument is provided

## [2026-01-25] - ArgoCD Module Improvements and Dependency Simplification

### Changed

- **ArgoCD Module Resource Containment**
  - Moved `time_sleep.wait_for_argocd` resource from root module into ArgoCD module
    itself for better containment and module self-sufficiency
  - Module now manages its own deployment wait logic internally
  - Improved module encapsulation and reduces coupling with root module

- **AWS CLI Command Optimization**
  - Removed dependency on `jq` for JSON parsing in ArgoCD capability data source
  - AWS CLI command now uses `--query` parameter directly to output JSON format
  - Simplified external data source script by leveraging AWS CLI's built-in JSON
    output capabilities
  - Eliminates external tool dependency for ArgoCD capability status queries

- **IAM Propagation Wait Time**
  - Increased IAM role propagation wait time from 30 seconds to 60 seconds
  - Provides more reliable IAM propagation before creating EKS capability
  - Reduces potential race conditions during ArgoCD capability deployment

- **ArgoCD Namespace Resource**
  - Added `kubernetes_namespace_v1.argocd` resource inside the ArgoCD module
  - Namespace creation is now managed within the module for better resource
    organization
  - Ensures namespace exists before capability deployment and cluster registration

### Fixed

- **Resource Dependencies**
  - Updated ArgoCD capability dependencies to include namespace resource
  - Updated cluster registration secret dependencies to include namespace resource
  - Ensures proper resource creation order within the module

## [2026-01-25] - Git Ignore Pattern Update and State Path Correction

### Changed

- **Git Ignore Pattern**
  - Updated `.gitignore` to use pattern `**/backend.hcl` instead of listing specific
  files
  - Simplifies maintenance by automatically ignoring all `backend.hcl` files in
  any directory
  - Ensures generated backend configuration files are not committed to the repository

### Fixed

- **State Path Correction**
  - Corrected state file key to use correct path: `application_infra_state/terraform.tfstate`
  - Removed generated `backend.hcl` file from repository (now properly git-ignored)
  - Verified all scripts and workflows use the `APPLICATION_INFRA_PREFIX` repository
  variable correctly
  - Ensured state file isolation between `application_infra` and `application` directories

## [2026-01-21] - Backend State Configuration Standardization

### Changed

- **Backend State Template Configuration**
  - Updated `tfstate-backend-values-template.hcl` to use `APPLICATION_INFRA_PREFIX`
  placeholder
  - State file key now uses repository variable `APPLICATION_INFRA_PREFIX`
  (value: `application_infra_state/terraform.tfstate`)
  - Changed from generic `APPLICATION_PREFIX` to specific `APPLICATION_INFRA_PREFIX`
  for clarity
  - Ensures unique state file naming separate from application state

- **Setup and Destroy Scripts**
  - Updated `setup-application-infra.sh` to use `APPLICATION_INFRA_PREFIX` from
  GitHub repository variables
  - Updated `destroy-application-infra.sh` to use `APPLICATION_INFRA_PREFIX` from
  GitHub repository variables
  - Changed from `APPLICATION_PREFIX` to `APPLICATION_INFRA_PREFIX` for
  infrastructure-specific naming
  - Scripts now replace `<APPLICATION_INFRA_PREFIX>` placeholder with repository
  variable value

- **GitHub Workflows**
  - Updated `application_infra_provisioning.yaml` to use `APPLICATION_INFRA_PREFIX`
  repository variable
  - Updated `application_infra_destroying.yaml` to use `APPLICATION_INFRA_PREFIX`
  repository variable
  - Changed from `APPLICATION_PREFIX` to `APPLICATION_INFRA_PREFIX` for consistency

### Added

- **Backend State Configuration Documentation**
  - Added comprehensive "Backend State Configuration" section to `README.md`
  - Documented state file configuration, template usage, and generation process
  - Documented required repository variables (`BACKEND_BUCKET_NAME`, `APPLICATION_INFRA_PREFIX`)
  - Documented state file isolation between `application_infra` and `application`
  - Clarified that both directories use same bucket but different keys

### Fixed

- **State File Key Consistency**
  - Fixed state file key to use consistent naming: `application_infra_state/terraform.tfstate`
  - Ensured all scripts and workflows use the correct prefix variable
  - Eliminated discrepancies between bash scripts and GitHub workflows
  - Separated infrastructure state from application state using distinct prefix
  variables

## [2026-01-19] - Build Workflow Simplification and ECR Variable Requirements

### Changed

- **Build Workflow ECR Repository Name Resolution**
  - Simplified ECR repository name resolution in `backend_build_push.yaml` and
  `frontend_build_push.yaml` workflows
  - Removed redundant PREFIX fallback logic for constructing ECR repository names
  - Build workflows now require `ECR_REPOSITORY_NAME` GitHub repository variable
  to be set
  - Variable is automatically set by backend infrastructure provisioning workflow
  or `setup-backend.sh` script
  - Workflows fail fast with clear error message if variable is not set
  - Error messages guide users to run backend infrastructure provisioning first

### Removed

- **PREFIX-based ECR Repository Name Construction**
  - Removed manual PREFIX variable fallback logic from build workflows
  - Removed nested conditional checks for PREFIX variable
  - Simplified workflow logic for better maintainability

## [2026-01-18] - Documentation Updates and Certificate Architecture Migration

### Changed

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
    `CROSS_ACCOUNT_ACCESS.md` with step-by-step AWS CLI commands
  - Private CA setup moved to "Legacy" section (deprecated for public-facing
    applications)

- **Image Tag Standardization Update**
  - Updated Redis and PostgreSQL image tags to use 'latest' tag instead of
    version-specific tags
  - Redis default image tag changed from `redis-8.4.0` to `redis-latest`
  - PostgreSQL default image tag changed from `postgresql-18.1.0` to
    `postgresql-latest`
  - Updated ECR image mirroring script to use 'latest' tags
  - Updated all documentation to reflect new image tag naming convention

- **Comprehensive Documentation Updates**
  - Updated `application/README.md` with latest features and certificate
    architecture
  - Updated all prerequisites to reference Public ACM certificate setup
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
  - Added comprehensive Helm release attributes to modules (OpenLDAP, PostgreSQL,
  Redis) for safer and more reliable deployments. cert-manager module code was
  also updated but the module is not invoked in main.tf:
    - `atomic: true` - Prevents partial deployments by rolling back on failure
    - `force_update: true` - Enables forced updates when needed
    - `replace: true` - Prevents resource name conflicts and allows reuse of names
    - `cleanup_on_fail: true` - Automatically cleans up resources on failed deployments
    - `recreate_pods: true` - Forces pod restart on upgrade and rollbacks
    - `wait: true` - Waits for all resources to be ready before marking as successful
    - `wait_for_jobs: true` - Waits for any jobs to be completed for success state
    - `upgrade_install: true` - Prevents failures if there are pre-existing resources
  - OpenLDAP module timeout set to 5 minutes (300 seconds)
  - PostgreSQL and Redis module timeouts set to 10 minutes (600 seconds)
  - Improves deployment reliability and prevents stuck deployments

- **Standardized Helm Values Passing**
  - Standardized how Helm values are passed through to all modules
  (OpenLDAP, PostgreSQL, Redis)
  - All modules now use consistent `templatefile()` approach with `values_template_path`
  variable
  - Modules can use default template path or custom path via variable
  - Improved maintainability and consistency across all Helm chart deployments
  - Created comprehensive Helm values templates:
    - `helm/postgresql-values.tpl.yaml` - PostgreSQL Helm chart values template
    - `helm/redis-values.tpl.yaml` - Updated Redis Helm chart values template
    - `helm/openldap-values.tpl.yaml` - Updated OpenLDAP Helm chart values template

- **PostgreSQL Chart Repository Fix**
  - Fixed PostgreSQL Helm chart download issue by changing repository from
  `https://charts.bitnami.com/bitnami` to `oci://registry-1.docker.io/bitnamicharts`
  - Uses OCI registry format for better compatibility and reliability
  - Resolves chart download failures during deployment

- **Image Tag Standardization**
  - Changed Redis and PostgreSQL image tags to use 'latest' tag instead of SHA digests
  - Redis default image tag: `redis-latest`
  - PostgreSQL default image tag: `postgresql-latest`
  - OpenLDAP continues to use specific version tag: `openldap-1.5.0`
  - Image tags correspond to tags created by `mirror-images-to-ecr.sh` script
  - Simplifies image management and updates

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
    `CROSS_ACCOUNT_ACCESS.md` with step-by-step AWS CLI commands
  - Certificate validation workflow documented for both production and development
    accounts
  - Certificates automatically renewed by ACM (no manual intervention required)
  - Browser-trusted certificates (no security warnings)

- **State Account Role ARN Support for Route53 Cross-Account Access**
  - Added support for querying Route53 hosted zones from State Account
  - New variable `state_account_role_arn` for assuming role in State Account
    (where Route53 hosted zone resides)
  - State account provider alias (`aws.state_account`) configured in
    `providers.tf`
  - All Route53 data sources and resources now use state account provider when
    configured
  - Route53 records (phpldapadmin, ltb_passwd, twofa_app, SES
    verification/DKIM) created in State Account
  - Route53 DNS validation records for Public ACM certificates created in State
    Account
  - ACM certificates are Public ACM certificates (Amazon-issued) requested in
    Deployment Account (not State Account)
  - Scripts automatically inject `state_account_role_arn` into
    `variables.tfvars`:
    - `setup-application.sh` exports `STATE_ACCOUNT_ROLE_ARN` environment
      variable
    - `set-k8s-env.sh` injects `state_account_role_arn` into
      `variables.tfvars`
  - GitHub Actions workflows export `STATE_ACCOUNT_ROLE_ARN` for automatic
    injection
  - No ExternalId required for state account role assumption (by design)
  - Comprehensive cross-account access documentation in
    `CROSS_ACCOUNT_ACCESS.md`
  - Updated ALB module to handle null certificate ARN gracefully
  - Added certificate ARN to ALB module triggers for proper
    IngressClassParams updates

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

- **Route53 Record Module Separation**
  - Separated Route53 record creation from OpenLDAP module into dedicated
    `route53_record` module
  - New module located at `application/modules/route53_record/` for per-record
    creation
  - Module uses state account provider (`aws.state_account`) for cross-account
    access
  - Route53 records created in State Account while ALB deployed in Deployment
    Account
  - Three separate module calls in `main.tf`:
    - `module.route53_record_phpldapadmin` - Creates A record for phpLDAPadmin
    - `module.route53_record_ltb_passwd` - Creates A record for ltb-passwd
    - `module.route53_record_twofa_app` - Creates A record for 2FA application
  - Module outputs: `record_name`, `record_fqdn`, `record_id`
  - Precondition ensures ALB DNS name is available before record creation
  - Comprehensive ALB zone_id mapping by region (13 AWS regions supported:
    us-east-1, us-east-2, us-west-1, us-west-2, eu-west-1, eu-west-2, eu-west-3,
    eu-central-1, ap-southeast-1, ap-southeast-2, ap-northeast-1,
    ap-northeast-2, sa-east-1)
  - Proper dependency chain: OpenLDAP module → ALB data source → Route53 records
  - All records use consistent ALB data source approach to avoid timing issues
  - Lifecycle block with `create_before_destroy` for safe updates
  - Comprehensive module documentation in
    `application/modules/route53_record/README.md`

- **ECR Image Mirroring Script**
  - Created `application/mirror-images-to-ecr.sh` script (290 lines) to eliminate
    Docker Hub rate limiting and external dependencies
  - Automatically mirrors third-party container images from Docker Hub to ECR:
    - `bitnami/redis:8.4.0-debian-12-r6` → `redis-latest`
    - `bitnami/postgresql:18.1.0-debian-12-r4` → `postgresql-latest`
    - `osixia/openldap:1.5.0` → `openldap-1.5.0`
  - Checks if images exist in ECR before mirroring (skips if already present)
  - Uses State Account credentials to fetch ECR URL from backend_infra state
  - Assumes Deployment Account role for ECR operations (with ExternalId)
  - Authenticates Docker to ECR automatically using `aws ecr get-login-password`
  - Cleans up local images after pushing to save disk space
  - Lists all images in ECR repository after completion
  - Integrated into `application/setup-application.sh` (runs before Terraform
    operations)
  - Integrated into GitHub Actions workflow (runs after Terraform validate, before
    set-k8s-env.sh)
  - Requires Docker to be installed and running
  - Requires `jq` for JSON parsing (with fallback to sed for compatibility)
  - Prevents Docker Hub rate limiting and external dependencies during
    deployments
  - Comprehensive error handling and user feedback

- **ECR Image Support for OpenLDAP, PostgreSQL, and Redis Modules**
  - All three modules now use ECR images instead of Docker Hub
  - New variables in `application/variables.tf`:
    - `openldap_image_tag` (default: "openldap-1.5.0")
    - `postgresql_image_tag` (default: "postgresql-latest")
    - `redis_image_tag` (default: "redis-latest")
  - ECR registry and repository computed from backend_infra state (`ecr_url`)
  - All modules updated with ECR configuration variables:
    - `ecr_registry`: ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)
    - `ecr_repository`: ECR repository name
    - `image_tag` or module-specific tag variable
  - Helm values templates updated to use ECR images
  - Image tags correspond to tags created by `mirror-images-to-ecr.sh`
  - **OpenLDAP module**: Updated `helm/openldap-values.tpl.yaml` to use ECR
    registry/repository/tag
  - **PostgreSQL module**: Updated Helm values to use ECR image configuration
  - **Redis module**: Updated Helm values to use ECR image configuration

### Changed

- **Module Documentation Updates**
  - Updated module READMEs with standardized Helm values passing documentation
  - Enhanced PostgreSQL module README with chart repository information
  - Updated Redis module README with latest configuration details
  - Improved ALB module README with latest annotation strategy
  - Enhanced ArgoCD module documentation. cert-manager module README was also
  updated (module exists but is not invoked).
  - Added comprehensive Route53 module README documentation

- **Helm Values Template Organization**
  - Standardized Helm values template structure across all modules
  - Improved template variable naming and organization
  - Enhanced template documentation and comments
  - Better separation of concerns between module logic and Helm values

- **Setup Script Improvements**
  - Enhanced `setup-application.sh` with improved error handling and ExternalId
  support
  - Automatic ExternalId retrieval from AWS Secrets Manager
  - Improved role assumption logic with better error messages
  - Enhanced secret retrieval with validation and error handling
  - Better integration with GitHub repository variables and secrets
  - Improved Kubernetes environment setup using `set-k8s-env.sh`
  - Enhanced user guidance and confirmation prompts
  - Automatic injection of `state_account_role_arn` for Route53 access
  - Integrated ECR image mirroring script execution (runs before Terraform
    operations)
  - Improved credential handling to prevent conflicts between different AWS
    credentials
  - Better dependency chain organization to prevent failures
  - Enhanced script error handling in destroy scripts

- **GitHub Actions Workflow Updates**
  - Updated `application_infra_provisioning.yaml` with ExternalId support and
  improved error handling
  - Updated `application_infra_destroying.yaml` with ExternalId support and
  improved error handling
  - Workflows now use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state
    operations
  - Workflows now export `STATE_ACCOUNT_ROLE_ARN` for Route53
    cross-account access
  - Workflows now use `AWS_ASSUME_EXTERNAL_ID` for cross-account role
    assumption
  security
  - Improved environment variable handling for password secrets
  - Added Docker Buildx setup step for image operations
  - Added "Mirror Docker images to ECR" step (runs after Terraform validate,
    before set-k8s-env.sh)
  - Workflow now handles image mirroring automatically
  - Improved credential handling to prevent conflicts between different AWS
    credentials

- **Documentation Improvements**
  - Removed duplication by replacing detailed module descriptions with links to
  module READMEs
  - Enhanced cross-references to module documentation (ALB, ArgoCD, Network
  Policies, PostgreSQL, Redis, SES, SNS, Route53 Record). cert-manager module
  is documented but not invoked.
  - Updated component descriptions to be more concise with links to detailed documentation
  - Improved consistency across documentation files
  - Added comprehensive documentation for Route53 record module
  - Added documentation for ECR image mirroring script
  - Updated module documentation to reflect ECR image usage

- **Backend API Configuration**
  - Removed debug mode condition for API documentation endpoints
  - Swagger UI, ReDoc UI, and OpenAPI schema are now always accessible in production
  - API documentation always enabled (not just in debug mode)

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

## [2025-12-16] - ArgoCD Capability Integration

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

> [!NOTE]
>
> ArgoCD Application CRDs are created by the `application/` Terraform configuration.
> See [application/CHANGELOG](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/CHANGELOG.md)
> for ArgoCD Application changes.

### Changed

- **Updated main.tf**
  - Added ArgoCD capability module integration
  - Configured cluster registration for GitOps

- **Updated variables.tf and variables.tfvars**
  - Added ArgoCD Capability configuration variables
  - Added Identity Center configuration (instance ARN, region)
  - Added RBAC role mapping configuration
  - Added VPC endpoint configuration options

## [2025-12-15] - Documentation and Linting Improvements

### Changed

- **Updated documentation across all files for Markdown lint compliance**
  - Corrected row length issues to comply with markdownlint rules
  - Improved formatting consistency across all documentation files
  - Updated CHANGELOG.md, OPENLDAP_README.md, OSIXIA_OPENLDAP_REQUIREMENTS.md
  - Updated PRD_ALB.md, PRD_DOMAIN.md, PRD.md, README.md
  - Updated SECURITY_IMPROVEMENTS.md and module README files

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
  - Updated documentation in `PRD_ALB.md` and `README.md` to reflect new
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

- **Comprehensive documentation updates in `PRD_ALB.md`**
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
