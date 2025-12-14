# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Environment-based AWS role ARN selection**
  - Added support for separate role ARNs for production and development environments
  - New GitHub secrets: `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` and `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
  - Workflows and scripts automatically select the appropriate role ARN based on selected environment (`prod` or `dev`)
  - `setup-backend.sh` script now retrieves and uses environment-specific deployment account role ARNs

- **Automated Terraform execution in setup scripts**
  - `setup-backend.sh` now automatically runs Terraform commands (init, workspace, validate, plan, apply)
  - Eliminates the need for manual Terraform command execution after backend configuration
  - Script handles workspace creation/selection automatically

- **Automated backend.hcl creation**
  - `setup-backend.sh` now automatically creates `backend.hcl` from template if it doesn't exist
  - Skips creation if `backend.hcl` already exists (prevents overwriting existing configuration)

### Changed

- **Multi-account architecture clarification**
  - Separated backend state operations from deployment operations
  - Backend state operations now use `AWS_STATE_ACCOUNT_ROLE_ARN` (State Account)
  - Deployment operations use environment-specific role ARNs (`AWS_PRODUCTION_ACCOUNT_ROLE_ARN` or `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`)
  - Updated all workflows to use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend operations
  - Updated workflows to set `deployment_account_role_arn` variable based on selected environment

- **Workflow updates**
  - `backend_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for backend, sets environment-based deployment role
  - `backend_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for backend, sets environment-based deployment role
  - `application_infra_provisioning.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for backend, sets environment-based deployment role
  - `application_infra_destroying.yaml`: Uses `AWS_STATE_ACCOUNT_ROLE_ARN` for backend, sets environment-based deployment role

- **Documentation updates**
  - Updated `README.md` to document the three-role architecture (State, Production, Development)
  - Updated `backend_infra/README.md` to reflect environment-based role selection
  - Clarified the separation between backend state operations and deployment operations
  - Updated AWS IAM setup instructions to reflect the new role structure

### Removed

- **Removed `provider_profile` variable**
  - Removed `provider_profile` variable from `backend_infra/variables.tf` and `application/variables.tf`
  - Removed `provider_profile` from `backend_infra/variables.tfvars` and `application/variables.tfvars`
  - Removed `profile = var.provider_profile` from `backend_infra/providers.tf` and `application/providers.tf`
  - No longer needed since role assumption is handled via setup scripts and workflows

### Fixed

- **Corrected role ARN usage in workflows**
  - Fixed workflows to use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
  - Fixed workflows to use environment-based role ARNs for deployment operations via `deployment_account_role_arn` variable

---

## [2025-12-14] - Deployment Versatility and Security Improvements

### Changed

- Made the deployment more versatile and secure
- Improved Terraform state deployment automation
- Updated documentation

---

## [2025-12-10] - Output and Ingress Configuration Updates

### Added

- Bubbled up outputs and added new ones
- Updated WARP.md documentation

### Fixed

- Corrected attributes across IngressClass, IngressClassParams, and the two Ingresses
- Updated documentation to reflect changes

---

## [2025-12-08] - ALB, TLS, and Documentation Updates

### Added

- Consolidated annotations
- Added naming logic for better resource identification

### Changed

- Latest updates to resolve ALB and TLS issues (ALB issue still under investigation)
- Updated documentation

### Removed

- Removed any mention of DynamoDB as that functionality is deprecated in managing TF state

---

## [2025-12-03] - Backend Infrastructure Workflow Updates

### Changed

- Updated backend infrastructure workflows

---

## [2025-12-02] - Application Infrastructure and Storage

### Added

- Main application infrastructure related to the OpenLDAP Helm deployment

### Changed

- Commented out the use of the EBS module because OpenLDAP creates one per pod already

---

## [2025-12-01] - Circular Dependency Resolution and Documentation

### Fixed

- Resolved circular dependency issue with EKS module in the providers

### Changed

- Updated names in code and documentation
- Added WARP.md file which works with the Warp Terminal Agent

---

## [2025-11-27] - EBS Module Outputs

### Added

- Added outputs for the EBS module to get the name of the PVC for later use in the application

---

## [2025-11-26] - VPC Endpoints, Storage, and ECR

### Added

- Added 3 VPC Endpoints
- Added EBS Storage Class and Claim
- Added ECR (Elastic Container Registry)
- Added CloudWatch logs
- Upgraded Kubernetes version to 1.34
- Updated documentation with all the latest changes

---

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

- Fixed bucket prefix issue: the prefix cannot start with '/' when defining the 'key' attribute for the backend state

---

## [2025-11-24] - Backend State Management Improvements

### Added

- Added backend state table name as an output
- Altered workflows to save and retrieve backend state table name
- Updated documentation

### Fixed

- Updated provisioning workflow to pre-check for an already existing state to prevent errors

---

## [2025-11-23] - Backend State Infrastructure

### Added

- Upgraded versions of AWS provider and Terraform
- Added files to begin with main infrastructure
- Added a README to the backend state that explains everything
- Added a link to backend state README in the main README
- Added missing GitHub Token
- Added a way to manage the backend state's state without having to commit it to the repository
- Added a way to transfer the backend bucket name after its creation
- Added account number to bucket name to make it unique

---

## [2025-11-22] - Initial Project Setup

### Added

- Initial commit
- Added Terraform backend state and GitHub Actions to deploy and destroy it

---

## Architecture Overview

This project uses a multi-account architecture:

- **State Account (Account A)**: Stores Terraform state files in S3
- **Production Account (Account B)**: Contains production infrastructure resources
- **Development Account (Account B)**: Contains development infrastructure resources

### Key Components

- Terraform backend state infrastructure (`tf_backend_state/`)
- Backend infrastructure (VPC, EKS cluster) (`backend_infra/`)
- Application infrastructure (OpenLDAP, ALB, Route53) (`application/`)
- GitHub Actions workflows for CI/CD (`.github/workflows/`)

---

## Notes

### Role ARN Selection Logic

The system automatically selects the appropriate role ARN based on the environment:

- **Backend State Operations**: Always uses `AWS_STATE_ACCOUNT_ROLE_ARN`
- **Deployment Operations**:
  - `prod` environment → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` environment → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`

### Setup Script Behavior

The `setup-backend.sh` script:

1. Assumes `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
2. Retrieves the appropriate deployment account role ARN based on selected environment
3. Creates `backend.hcl` if it doesn't exist
4. Updates `variables.tfvars` with region, environment, and deployment account role ARN
5. Runs Terraform commands automatically (init, workspace, validate, plan, apply)

### Terraform State Management

- The use of DynamoDB for Terraform state locking has been deprecated
- Native S3 handling is now in use for state locking
- All references to DynamoDB have been removed from code and documentation

---

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
