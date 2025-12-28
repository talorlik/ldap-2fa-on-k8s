# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

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

- **GitHub Actions Workflow Updates**
  - Updated `application_infra_provisioning.yaml` with new environment variables
  for Redis, PostgreSQL, and SES
  - Workflows now pass Redis password via `TF_VAR_redis_password` environment
  variable (from GitHub Secret `TF_VAR_REDIS_PASSWORD`)
  - Workflows now pass PostgreSQL password via `TF_VAR_postgresql_database_password`
  environment variable (from GitHub Secret `TF_VAR_POSTGRES_PASSWORD`)
  - Maintains backward compatibility with existing OpenLDAP password secrets

- **Comprehensive Product Requirements Documents**
  - Added `PRD-SIGNUP-MAN.md` for user signup management system
  - Added `PRD-ADMIN-FUNCS.md` for admin functions and profile management
  - Added `PRD-SMS-MAN.md` for SMS OTP management with Redis

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
  - `backend_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role
  - `backend_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role
  - `application_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role
  - `application_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for
  backend, sets environment-based deployment role

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
  - Comprehensive PRD documentation (`PRD-2FA-APP.md`)

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
