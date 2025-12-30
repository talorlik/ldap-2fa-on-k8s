# Changelog

All notable changes to the backend infrastructure will be documented in this
file.

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
  - Setup script (`setup-backend.sh`) automatically retrieves ExternalId from
  AWS Secrets Manager
  - GitHub Actions workflow (`backend_infra_provisioning.yaml`) updated to use
  `AWS_ASSUME_EXTERNAL_ID` secret
  - Deployment account roles must have ExternalId condition in Trust Relationship
  - **Bidirectional Trust Relationships**: Both deployment account roles and state
    account role must trust each other in their respective Trust Relationships
  - State account role's Trust Relationship must include deployment account role
    ARNs to enable proper cross-account role assumption
  - Prevents confused deputy attacks in multi-account deployments
  - ExternalId generation: `openssl rand -hex 32`

- **Destroy Script for Backend Infrastructure**
  - Created `destroy-backend.sh` script for destroying backend infrastructure
  - Interactive region and environment selection
  - Automatic retrieval of role ARNs and ExternalId from AWS Secrets Manager
  - Automatic backend configuration and variables.tfvars updates
  - Safety confirmations required before destruction (type 'yes' then 'DESTROY')
  - Comprehensive error handling and user guidance
  - Updated GitHub Actions destroying workflow with ExternalId support

### Changed

- **Setup Script Improvements**
  - Enhanced `setup-backend.sh` with improved error handling and ExternalId
  support
  - Automatic ExternalId retrieval from AWS Secrets Manager
  - Improved role assumption logic with better error messages
  - Enhanced secret retrieval with validation and error handling
  - Better integration with GitHub repository variables and secrets
  - Improved user guidance and confirmation prompts

- **GitHub Actions Workflow Updates**
  - Updated `backend_infra_provisioning.yaml` with ExternalId support and
  improved error handling
  - Updated `backend_infra_destroying.yaml` with ExternalId support and
  improved error handling
  - Workflows now use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
  - Workflows now use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
  security
  - Improved environment variable handling

- **Documentation Improvements**
  - Removed duplication by replacing detailed module descriptions with links
  to module READMEs
  - Enhanced cross-references to VPC Endpoints and ECR module documentation
  - Updated component descriptions to be more concise with links to detailed documentation

## [2025-12-18] - VPC Endpoints for IRSA and SMS 2FA Support

### Added

- **STS VPC Endpoint for IRSA (IAM Roles for Service Accounts)**
  - Added optional STS VPC endpoint (`com.amazonaws.${region}.sts`)
  - Required for pods to assume IAM roles via web identity (IRSA)
  - Controlled by `enable_sts_endpoint` variable (default: `true`)
  - Enables secure internal communication for IAM role assumption

- **SNS VPC Endpoint for SMS 2FA functionality**
  - Added optional SNS VPC endpoint (`com.amazonaws.${region}.sns`)
  - Required for pods to send SMS verification codes via SNS
  - Controlled by `enable_sns_endpoint` variable (default: `false`)
  - Enables secure internal communication for SMS 2FA

- **IRSA (IAM Roles for Service Accounts) support**
  - Enabled OIDC provider on EKS cluster with `enable_irsa = true`
  - Allows pods to assume IAM roles for AWS service access
  - Required for secure SNS access from application pods

- **New outputs for IRSA and VPC endpoints**
  - Added `oidc_provider_arn`: OIDC provider ARN for creating IAM roles
  - Added `oidc_provider_url`: OIDC provider URL (without `https://`)
  - Added `vpc_endpoint_sts_id`: VPC endpoint ID for STS
  - Added `vpc_endpoint_sns_id`: VPC endpoint ID for SNS

- **VPC CIDR security group rule**
  - Added ingress rule allowing VPC CIDR to access VPC endpoints
  - Supports pods that may not use node security group
  - Ensures all pods can reach VPC endpoints regardless of network policy

### Changed

- **VPC Endpoints module configuration**
  - Added `vpc_cidr` variable for security group rules
  - Added `enable_sts_endpoint` variable (default: `true`)
  - Added `enable_sns_endpoint` variable (default: `false`)
  - Updated `vpc_endpoint_ids` output to include optional STS and SNS endpoints
  - Added description and Name tag to endpoint security group

- **Root module variables**
  - Added `enable_sts_endpoint` variable to control STS endpoint creation
  - Added `enable_sns_endpoint` variable to control SNS endpoint creation
  - Variables passed through to endpoints module

## [2025-12-15] - Provider Profile Cleanup

### Changed

- **Removed provider_profile variable dependency**
  - Removed `provider_profile` variable from `variables.tf` and
  `variables.tfvars`
  - Removed `profile = var.provider_profile` from `providers.tf`
  - Provider now uses role assumption via `deployment_account_role_arn` variable
  instead of AWS profiles
  - Aligns with multi-account architecture and environment-based role selection

- **Updated setup script for multi-account architecture**
  - `setup-backend.sh` now retrieves deployment account role ARN from GitHub
  repository secrets
  - Script automatically selects appropriate role ARN based on environment
  (`prod` or `dev`)
  - Removed dependency on AWS profiles for role assumption
  - Improved error handling and user guidance

### Removed

- **Removed `setup-backend-api.sh` script**
  - Consolidated functionality into `setup-backend.sh`
  - Eliminated duplicate script maintenance
  - Improved script organization and maintainability

## [2025-12-14] - Deployment Versatility and Security Improvements

### Added

- **Multi-account role assumption support**
  - Added `deployment_account_role_arn` variable to support role assumption in
  deployment accounts
  - Variable automatically injected by GitHub Actions workflows based on
  environment
  - Supports separate production and development account deployments
  - Provider configuration updated to use `assume_role` when
  `deployment_account_role_arn` is provided

- **Enhanced setup script automation**
  - `setup-backend.sh` now automatically retrieves deployment account role ARN
  from GitHub secrets
  - Script handles environment-based role selection
  (`AWS_PRODUCTION_ACCOUNT_ROLE_ARN` or `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`)
  - Improved error messages and validation
  - Better integration with GitHub repository secrets and variables

### Changed

- **Provider configuration for multi-account support**
  - Updated `providers.tf` to conditionally use `assume_role` when
  `deployment_account_role_arn` is provided
  - Maintains backward compatibility for single-account deployments
  - Supports both local execution and GitHub Actions workflows

- **Setup script consolidation**
  - Enhanced `setup-backend.sh` with comprehensive role assumption logic
  - Removed `setup-backend-api.sh` (functionality merged into
  `setup-backend.sh`)
  - Improved script structure and error handling
  - Better user feedback and guidance

- **Documentation updates**
  - Updated `README.md` to reflect multi-account architecture
  - Clarified role assumption workflow
  - Updated prerequisites and setup instructions

### Removed

- **Removed `setup-backend-api.sh` script**
  - Functionality consolidated into unified `setup-backend.sh`
  - Reduces script maintenance overhead
  - Simplifies deployment workflow

## [2025-12-14] - Terraform State Deployment Automation

### Added

- **Automated Terraform state management**
  - Setup script now automatically handles Terraform workspace
  creation/selection
  - Automatic Terraform initialization with backend configuration
  - Automated validation, planning, and application of infrastructure changes
  - Eliminates need for manual Terraform command execution

- **Backend configuration automation**
  - `setup-backend.sh` automatically creates `backend.hcl` from template if it
  doesn't exist
  - Script retrieves backend state information from GitHub repository variables
  - Prevents overwriting existing backend configuration

- **Environment-based workspace management**
  - Workspaces automatically created/selected based on `${region}-${env}`
  pattern
  - Ensures proper state isolation between environments and regions

### Changed

- **Provider configuration enhancements**
  - Added conditional backend configuration support
  - Improved error handling for missing backend state information
  - Better integration with GitHub repository variables

- **Variable management**
  - Added variables for backend state configuration
  - Improved variable descriptions and documentation
  - Better default value handling

## [2025-12-10] - Output Enhancements

### Added

- **Comprehensive VPC Endpoints outputs**
  - Added `vpc_endpoint_sg_id`: Security group ID for VPC endpoints
  - Added `vpc_endpoint_ssm_id`: VPC endpoint ID for SSM
  - Added `vpc_endpoint_ssmmessages_id`: VPC endpoint ID for SSM Messages
  - Added `vpc_endpoint_ec2messages_id`: VPC endpoint ID for EC2 Messages
  - Added `vpc_endpoint_ids`: List of all VPC endpoint IDs
  - All outputs properly documented with descriptions

- **ECR repository outputs**
  - Added `ecr_name`: ECR repository name
  - Added `ecr_arn`: ECR repository ARN
  - Added `ecr_url`: ECR repository URL for Docker image push/pull operations

- **Enhanced module outputs**
  - VPC endpoints module now exports all endpoint IDs and security group
  information
  - Improved output organization and documentation

### Changed

- **Output structure improvements**
  - Reorganized outputs by component (VPC, EKS, Endpoints, ECR, EBS)
  - Added consistent descriptions to all outputs
  - Improved output naming conventions

## [2025-12-08] - Documentation Updates

### Changed

- **Comprehensive README updates**
  - Expanded architecture documentation with ASCII diagrams
  - Added detailed component descriptions (VPC, EKS, VPC Endpoints, ECR)
  - Enhanced security considerations section
  - Added cost optimization notes
  - Improved troubleshooting guide with useful commands
  - Added module structure documentation
  - Clarified prerequisites and setup requirements

## [2025-12-02] - EBS Module Deprecation

### Changed

- **EBS module commented out in main.tf**
  - EBS module usage commented out as OpenLDAP creates storage per pod
  - Module definition remains for future use if needed
  - EBS outputs commented out to match module status
  - Updated documentation to reflect current state

### Added

- **EBS module outputs (commented)**
  - Added `ebs_pvc_name` output (commented)
  - Added `ebs_storage_class_name` output (commented)
  - Preserved for potential future reactivation

## [2025-12-01] - Circular Dependency Resolution

### Fixed

- **Resolved circular dependency in EKS module providers**
  - Fixed provider configuration to prevent circular dependencies
  - Updated provider initialization order
  - Improved module dependency management

### Changed

- **Provider configuration updates**
  - Refactored provider setup to eliminate circular references
  - Improved provider initialization sequence
  - Updated setup scripts to reflect provider changes

## [2025-11-27] - EBS Module Outputs

### Added

- **EBS module outputs**
  - Added `ebs_pvc_name` output to get the name of the PVC for later use in the
  application
  - Added `ebs_storage_class_name` output
  - Enables application infrastructure to reference EBS resources

## [2025-11-26] - VPC Endpoints, Storage, and ECR

### Added

- **VPC Endpoints module**
  - Created new `modules/endpoints/` module for VPC endpoint management
  - Implements PrivateLink endpoints for SSM Session Manager access
  - Enables secure node access without public IPs
  - Creates endpoints for:
    - SSM (Systems Manager)
    - SSM Messages
    - EC2 Messages
  - Comprehensive README documentation

- **EBS Storage module**
  - Created new `modules/ebs/` module for EBS storage management
  - Implements Kubernetes StorageClass and PersistentVolumeClaim
  - Configurable storage class with gp3 volume type
  - Supports ReadWriteOnce access mode
  - Comprehensive README documentation

- **ECR Repository module**
  - Created new `modules/ecr/` module for container registry
  - Implements private Docker registry for application images
  - Configurable lifecycle policies for cost management
  - Image tag mutability settings
  - Comprehensive README documentation

- **Module integration**
  - All three modules integrated into `main.tf`
  - Proper dependency management between modules
  - Consistent naming conventions across modules

### Changed

- **Provider updates**
  - Updated Terraform provider versions
  - Added Kubernetes provider for EBS module
  - Improved provider configuration

- **Documentation**
  - Added comprehensive README for each new module
  - Updated main README with module information
  - Added architecture diagrams and usage examples

## [2025-11-26] - CloudWatch Logging and Kubernetes Upgrade

### Added

- **CloudWatch logging for EKS cluster**
  - Enabled comprehensive logging for:
    - API server logs
    - Audit logs
    - Authenticator logs
    - Controller manager logs
    - Scheduler logs
  - Automatic CloudWatch log group creation
  - Improved observability and troubleshooting capabilities

### Changed

- **Kubernetes version upgrade**
  - Upgraded Kubernetes version to 1.34
  - Updated EKS module configuration
  - Improved cluster stability and features

- **Provider version updates**
  - Updated Terraform AWS provider versions
  - Updated EKS module version
  - Improved compatibility and feature support

## [2025-11-25] - EKS Auto Mode Cluster

### Added

- **EKS Auto Mode cluster deployment**
  - Deployed Amazon EKS cluster using Auto Mode
  - Automatic node provisioning with "general-purpose" node pool
  - Elastic Load Balancing automatically enabled
  - Public API endpoint for kubectl access
  - Cluster creator admin permissions enabled
  - Nodes deployed in private subnets

- **EKS module integration**
  - Integrated `terraform-aws-modules/eks/aws` module (version 21.9.0)
  - Proper VPC and subnet integration
  - Kubernetes-specific subnet tagging
  - Security group configuration

- **Node IAM policies**
  - Added `AmazonSSMManagedInstanceCore` policy for SSM access
  - Enables Session Manager access to nodes without public IPs

## [2025-11-25] - Provider Profile Removal

### Removed

- **Removed AWS profile dependency**
  - Removed `provider_profile` variable from `variables.tf`
  - Removed `profile = var.provider_profile` from `providers.tf`
  - Removed profile configuration from `variables.tfvars`
  - Transitioned to role assumption for authentication

### Changed

- **Provider authentication method**
  - Moved from AWS profile-based authentication to role assumption
  - Improved security and multi-account support
  - Better alignment with CI/CD workflows

## [2025-11-25] - Initial Backend Infrastructure

### Added

- **VPC infrastructure**
  - Created VPC with public and private subnets across two availability zones
  - Internet Gateway for public subnet internet access
  - NAT Gateway for private subnet internet access (single NAT for cost
  optimization)
  - Proper route table configuration
  - DNS support and DHCP options configured
  - Kubernetes-specific subnet tagging for EKS integration

- **Terraform configuration**
  - Main Terraform configuration files (`main.tf`, `variables.tf`, `outputs.tf`,
  `providers.tf`)
  - Variable definitions and default values
  - Comprehensive output definitions
  - Provider configuration for AWS

- **Setup scripts**
  - `setup-backend.sh`: Local setup script with interactive region and
  environment selection
  - `setup-backend-api.sh`: API-based setup script (later removed)
  - Both scripts support interactive region and environment selection
  - Backend configuration template (`tfstate-backend-values-template.hcl`)

- **GitHub Actions workflows**
  - Remote setup with GitHub workflows
  - Interactive region and environment selection in workflows
  - Automated infrastructure provisioning

- **Documentation**
  - Initial README with setup instructions
  - Backend configuration documentation

### Configuration Details

- **VPC Module**: Uses `terraform-aws-modules/vpc/aws` module (version 6.5.1)
- **Naming Convention**: Resources follow `${prefix}-${region}-${name}-${env}`
pattern
- **Workspace Management**: Uses Terraform workspaces named `${region}-${env}`
- **Subnet Configuration**:
  - Public subnets tagged with `kubernetes.io/role/elb = 1`
  - Private subnets tagged with `kubernetes.io/role/internal-elb = 1`
  - All subnets tagged with `kubernetes.io/cluster/${cluster_name} = "shared"`

## Architecture Overview

The backend infrastructure provides the foundational AWS resources for deploying
containerized applications on Kubernetes:

- **VPC**: Network isolation and segmentation
- **EKS Cluster**: Kubernetes orchestration platform
- **VPC Endpoints**: Secure access to AWS services without internet exposure
- **ECR Repository**: Container image storage and management
- **EBS Module**: Storage provisioning (currently commented out)

### Key Components

1. **VPC Module** (`terraform-aws-modules/vpc/aws`)
   - Public and private subnets
   - Internet Gateway and NAT Gateway
   - Route tables and DNS configuration

2. **EKS Module** (`terraform-aws-modules/eks/aws`)
   - EKS Auto Mode cluster
   - Automatic node provisioning
   - CloudWatch logging

3. **VPC Endpoints Module** (`modules/endpoints/`)
   - SSM, SSM Messages, EC2 Messages endpoints
   - Security group configuration

4. **ECR Module** (`modules/ecr/`)
   - Private container registry
   - Lifecycle policies
   - Image tag mutability

5. **EBS Module** (`modules/ebs/`) - Currently commented out
   - StorageClass and PersistentVolumeClaim
   - gp3 storage configuration

## Notes

### Multi-Account Architecture

The backend infrastructure supports multi-account deployments:

- **State Account (Account A)**: Stores Terraform state in S3
- **Deployment Accounts (Account B)**: Contains infrastructure resources (VPC,
EKS, etc.)
  - Production environment: Uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - Development environment: Uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`

### Role Assumption

The provider uses role assumption when `deployment_account_role_arn` is
provided:

- Automatically injected by GitHub Actions workflows
- Can be set manually for local execution
- Supports environment-based role selection

### Setup Script Behavior

The `setup-backend.sh` script:

1. Retrieves backend state information from GitHub repository variables
2. Retrieves deployment account role ARN from GitHub secrets based on
environment
3. Creates `backend.hcl` if it doesn't exist
4. Updates `variables.tfvars` with region, environment, and deployment account
role ARN
5. Runs Terraform commands automatically (init, workspace, validate, plan,
apply)

### EBS Module Status

The EBS module is currently commented out in `main.tf` because:

- OpenLDAP creates EBS volumes per pod automatically
- Storage classes and PVCs are managed by the application infrastructure
- Module definition remains for potential future use

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
