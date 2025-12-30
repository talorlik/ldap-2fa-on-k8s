# Backend Infrastructure

This Terraform configuration creates the core AWS infrastructure required for
deploying the LDAP 2FA application on Kubernetes.

## Overview

The backend infrastructure provisions:

- **VPC** with public and private subnets across two availability zones
- **EKS Cluster** (Auto Mode) for running Kubernetes workloads
- **IRSA** (IAM Roles for Service Accounts) for secure AWS API access from pods
- **VPC Endpoints** for secure access to AWS services (SSM, STS, SNS)
- **ECR Repository** for container image storage

> [!NOTE]
>
> The EBS module exists but is currently commented out in `main.tf`.
> Storage classes and PVCs are created by the application infrastructure instead.

## Architecture

```ascii
┌────────────────────────────────────────────────────────────────┐
│                              VPC                               │
│                                                                │
│  ┌──────────────────┐                    ┌──────────────────┐  │
│  │ Public Subnet 1  │                    │ Public Subnet 2  │  │
│  │                  │                    │                  │  │
│  └────────┬─────────┘                    └────────┬─────────┘  │
│           │                                       │            │
│           └──────────────── IGW ──────────────────┘            │
│                                                                │
│  ┌──────────────────┐                    ┌──────────────────┐  │
│  │ Private Subnet 1 │                    │ Private Subnet 2 │  │
│  │                  │                    │                  │  │
│  │  ┌────────────┐  │                    │  ┌────────────┐  │  │
│  │  │ EKS Nodes  │  │                    │  │ EKS Nodes  │  │  │
│  │  │            │  │                    │  │            │  │  │
│  │  │ ┌────────┐ │  │                    │  │            │  │  │
│  │  │ │ Pods   │ │  │                    │  │            │  │  │
│  │  │ │ (IRSA) │ │  │                    │  │            │  │  │
│  │  │ └────────┘ │  │                    │  │            │  │  │
│  │  └────────────┘  │                    │  └────────────┘  │  │
│  │                  │                    │                  │  │
│  │  ┌────────────┐  │                    │  ┌────────────┐  │  │
│  │  │ VPC        │  │                    │  │ VPC        │  │  │
│  │  │ Endpoints  │  │                    │  │ Endpoints  │  │  │
│  │  │ SSM/STS/   │  │                    │  │ SSM/STS/   │  │  │
│  │  │ SNS        │  │                    │  │ SNS        │  │  │
│  │  └────────────┘  │                    │  └────────────┘  │  │
│  └────────┬─────────┘                    └────────┬─────────┘  │
│           │                                       │            │
│           └───────────── NAT Gateway ─────────────┘            │
└────────────────────────────────────────────────────────────────┘
```

## Components

### 1. VPC Module

Creates a Virtual Private Cloud with:

- **Public Subnets**: For internet-facing resources (Load Balancers)
  - Tagged with `kubernetes.io/role/elb = 1` for ALB placement
- **Private Subnets**: For EKS nodes and application workloads
  - Tagged with `kubernetes.io/role/internal-elb = 1` for internal load
  balancers
- **NAT Gateway**: Single NAT gateway for cost optimization (private subnet
internet access)
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Properly configured for public and private subnets
- **DNS Support**: Enabled for service discovery (`enable_dns_hostnames = true`,
`enable_dns_support = true`)
- **DHCP Options**: Configured with domain name `ec2.internal`

**Key Configuration:**

- Uses `terraform-aws-modules/vpc/aws` module (version 6.5.1)
- Kubernetes-specific tags for EKS integration:
  - `kubernetes.io/cluster/${cluster_name} = "shared"` on all subnets
  - `kubernetes.io/role/elb = 1` on public subnets
  - `kubernetes.io/role/internal-elb = 1` on private subnets
- Two availability zones for high availability
- Subnets automatically named: `${vpc_name}-public-subnet-{1,2}` and
`${vpc_name}-private-subnet-{1,2}`

### 2. EKS Cluster

Deploys an Amazon EKS cluster in Auto Mode:

- **Auto Mode**: Simplified cluster management with automatic node provisioning
  - Enabled via `compute_config.enabled = true`
  - Uses "general-purpose" node pool
- **IRSA (IAM Roles for Service Accounts)**: Enabled via `enable_irsa = true`
  - Creates OIDC provider for the cluster
  - Allows pods to assume IAM roles for AWS service access
  - Required for secure SNS access for SMS 2FA
- **Elastic Load Balancing**: Automatically enabled by default with Auto Mode
  - No explicit configuration needed - `elastic_load_balancing` capability is
  enabled by default
  - Supports ALB provisioning via EKS Auto Mode Ingress
- **Public Endpoint**: API server accessible from internet
(`endpoint_public_access = true` for kubectl access)
- **Logging**: CloudWatch logging enabled for:
  - API server
  - Audit logs
  - Authenticator
  - Controller manager
  - Scheduler
- **Node IAM Policies**: Includes SSM access for Session Manager
(`AmazonSSMManagedInstanceCore`)

**Key Configuration:**

- Uses `terraform-aws-modules/eks/aws` module (version 21.9.0)
- Kubernetes version specified via `k8s_version` variable
- Compute config with "general-purpose" node pool
- Cluster creator has admin permissions
(`enable_cluster_creator_admin_permissions = true`)
- Nodes deployed in private subnets
- CloudWatch log group created automatically

### 3. VPC Endpoints Module

The VPC Endpoints module creates PrivateLink endpoints for secure access to
AWS services from EKS nodes without requiring internet gateway access.
It creates SSM endpoints (always enabled), STS endpoint (optional, default: enabled)
for IRSA, and SNS endpoint (optional, default: disabled) for SMS 2FA.

> [!NOTE]
>
> For detailed VPC endpoints configuration, security setup, IRSA integration,
> cost considerations, and usage examples, see the [VPC Endpoints Module Documentation](modules/endpoints/README.md).

### 4. ECR Module

The ECR module creates a private Docker registry for application images with
configurable lifecycle policies and image tag mutability settings.

> [!NOTE]
>
> For detailed ECR configuration, lifecycle policies, and usage examples,
> see the [ECR Module Documentation](modules/ecr/README.md).

## Module Structure

```bash
backend_infra/
├── main.tf                        # Main infrastructure configuration
├── variables.tf                   # Variable definitions
├── variables.tfvars               # Variable values (customize for your environment)
├── outputs.tf                     # Output values
├── providers.tf                   # Provider configuration (AWS, Kubernetes)
├── backend.hcl                    # Terraform backend configuration (generated)
├── tfstate-backend-values-template.hcl  # Backend config template
├── CHANGELOG.md                   # Change log for this module
├── setup-backend.sh               # Backend setup script (GitHub CLI)
└── modules/
    ├── ebs/                       # EBS storage resources (currently commented out in main.tf)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── ecr/                       # ECR repository
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    └── endpoints/                 # VPC endpoints (SSM, STS, SNS)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

## Destroying Infrastructure

> [!WARNING]
>
> Destroying infrastructure is a **destructive operation** that permanently
> deletes all resources. This action **cannot be undone**. Always ensure you have
> backups and understand the consequences before proceeding.

### Option 1: Using Destroy Script (Local)

```bash
cd backend_infra
./destroy-backend.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and ExternalId from AWS Secrets Manager
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, deployment account
  role ARN, and ExternalId
- Run Terraform destroy commands (init, workspace, validate, plan destroy, apply
  destroy) automatically
- **Requires confirmation**: Type 'yes' to confirm, then 'DESTROY' to proceed

### Option 2: Using GitHub Actions Workflow

1. Go to GitHub → Actions tab
2. Select "Backend Infrastructure Destroying" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

The workflow will:

- Use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
- Use environment-specific deployment account role ARN
- Use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
- Run Terraform destroy operations automatically

> [!IMPORTANT]
>
> **Destroy Order**: Backend infrastructure should be destroyed after application
> infrastructure. Ensure all application resources are destroyed first before
> destroying the backend infrastructure.

## Prerequisites

1. **Terraform Backend**: The Terraform state backend must be provisioned first
(see [tf_backend_state/README.md](../tf_backend_state/README.md))
2. **Multi-Account Setup**:
   - **Account A (State Account)**: Stores Terraform state in S3
     - GitHub Actions uses `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state
     operations
   - **Account B (Production/Development Accounts)**: Contains infrastructure
   resources (VPC, EKS, etc.)
     - Terraform provider assumes deployment account role via `assume_role`
     configuration
     - Role selection based on environment:
       - `prod` environment → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` (set in
       `deployment_account_role_arn` variable)
       - `dev` environment → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` (set in
       `deployment_account_role_arn` variable)
3. **AWS SSO/OIDC**: Configured GitHub OIDC provider and IAM roles (see main
[README.md](../README.md))
4. **Backend Configuration**: Generate `backend.hcl` using the setup scripts
(see main [README.md](../README.md))
5. **GitHub Secrets**: Ensure `AWS_STATE_ACCOUNT_ROLE_ARN`,
`AWS_PRODUCTION_ACCOUNT_ROLE_ARN`, `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`, and
`AWS_ASSUME_EXTERNAL_ID` are configured in repository secrets

## Key Variables

### Required Variables

| Variable | Description | Type |
| ---------- | ------------- | ------ |
| `env` | Deployment environment (prod, dev) | `string` |
| `region` | AWS region (us-east-1, us-east-2) | `string` |
| `prefix` | Prefix for all resource names | `string` |
| `vpc_cidr` | CIDR block for VPC | `string` |
| `k8s_version` | Kubernetes version for EKS cluster | `string` |

### Optional Variables

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `deployment_account_role_arn` | ARN of IAM role in Account B to assume for resource deployment | `null` |
| `deployment_account_external_id` | ExternalId for cross-account role assumption security (must match Trust Relationship) | `null` |
| `enable_sts_endpoint` | Whether to create STS VPC endpoint (required for IRSA) | `true` |
| `enable_sns_endpoint` | Whether to create SNS VPC endpoint (required for SMS 2FA) | `false` |

### Important Configuration

- **Naming Convention**: All resources follow the pattern
`${prefix}-${region}-${name}-${env}`
- **Workspace-based State**: Uses Terraform workspaces named `${region}-${env}`
- **Single NAT Gateway**: Configured for cost optimization (can be changed to
`false` for HA)
- **IRSA**: Enabled by default with STS endpoint for secure AWS API access from
pods

## Outputs

The infrastructure provides outputs for:

### AWS Account & Region

| Output | Description |
| -------- | ------------- |
| `aws_account` | AWS Account ID |
| `region` | AWS region |
| `env` | Deployment environment |
| `prefix` | Resource name prefix |

### VPC

| Output | Description |
| -------- | ------------- |
| `vpc_id` | VPC ID |
| `default_security_group_id` | Default VPC security group ID |
| `public_subnets` | List of public subnet IDs |
| `private_subnets` | List of private subnet IDs |
| `igw_id` | Internet Gateway ID |

### EKS Cluster

| Output | Description |
| -------- | ------------- |
| `cluster_name` | EKS cluster name (format: `${prefix}-${region}-${cluster_name}-${env}`) |
| `cluster_endpoint` | EKS Cluster API endpoint |
| `cluster_arn` | EKS Cluster ARN |
| `oidc_provider_arn` | OIDC provider ARN for creating IRSA IAM roles |
| `oidc_provider_url` | OIDC provider URL (without `https://`) |

### VPC Endpoints

| Output | Description |
| -------- | ------------- |
| `vpc_endpoint_sg_id` | Security group ID for VPC endpoints |
| `vpc_endpoint_ssm_id` | VPC endpoint ID for SSM |
| `vpc_endpoint_ssmmessages_id` | VPC endpoint ID for SSM Messages |
| `vpc_endpoint_ec2messages_id` | VPC endpoint ID for EC2 Messages |
| `vpc_endpoint_sts_id` | VPC endpoint ID for STS (null if disabled) |
| `vpc_endpoint_sns_id` | VPC endpoint ID for SNS (null if disabled) |
| `vpc_endpoint_ids` | List of all enabled VPC endpoint IDs |

### ECR

| Output | Description |
| -------- | ------------- |
| `ecr_name` | ECR repository name |
| `ecr_arn` | ECR repository ARN |
| `ecr_url` | ECR repository URL for Docker image push/pull operations |

> [!NOTE]
>
> EBS outputs are commented out since the EBS module is not currently active.

Use `terraform output` to view all available outputs.

## IRSA (IAM Roles for Service Accounts)

The backend infrastructure enables IRSA for secure AWS API access from
Kubernetes pods:

### How IRSA Works

1. EKS cluster has an OIDC provider (`enable_irsa = true`)
2. STS VPC endpoint allows pods to call `sts:AssumeRoleWithWebIdentity`
3. Pods use Kubernetes service accounts annotated with IAM role ARNs
4. AWS SDK automatically assumes the IAM role using the service account token

### Using IRSA in Application Infrastructure

To use IRSA in your application:

1. Reference the OIDC provider outputs from this module:

   ```hcl
   data "terraform_remote_state" "backend_infra" {
     backend = "s3"
     # ... configuration
   }

   # Create IAM role with OIDC trust policy
   resource "aws_iam_role" "app_role" {
     name = "app-role"
     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Effect = "Allow"
         Principal = {
           Federated = data.terraform_remote_state.backend_infra.outputs.oidc_provider_arn
         }
         Action = "sts:AssumeRoleWithWebIdentity"
         Condition = {
           StringEquals = {
             "${data.terraform_remote_state.backend_infra.outputs.oidc_provider_url}:sub" = "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT_NAME"
           }
         }
       }]
     })
   }
   ```

2. Create a Kubernetes service account with the IAM role annotation:

   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: my-app
     namespace: my-namespace
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-role
   ```

3. Use the service account in your pod/deployment

### SMS 2FA with SNS

To enable SMS 2FA functionality:

1. Set `enable_sns_endpoint = true` in your variables
2. Create an IAM role with SNS publish permissions using IRSA
3. Annotate your backend service account with the IAM role ARN
4. The backend can call `sns.publish()` to send SMS verification codes

## Security Considerations

1. **Private Subnets**: EKS nodes are deployed in private subnets (no public
IPs)
2. **VPC Endpoints**: Enable secure access to AWS services without internet
exposure
   - SSM endpoints for node access
   - STS endpoint for IRSA (IAM role assumption)
   - SNS endpoint for SMS 2FA (optional)
3. **IRSA**: Pods assume IAM roles via OIDC, not long-lived credentials
4. **Public API Endpoint**: EKS API server is publicly accessible (required for
kubectl access)
5. **IAM Permissions**:
   - Cluster creator has admin permissions
   - Nodes have SSM access via `AmazonSSMManagedInstanceCore` policy
   - Pods assume minimal IAM roles via IRSA
6. **Network Isolation**: Proper security group rules restrict access
   - VPC endpoints accept traffic only from node security group and VPC CIDR
7. **Kubernetes Tags**: Subnets are properly tagged for Kubernetes integration
8. **CloudWatch Logging**: Comprehensive logging enabled for audit and security
monitoring

## Cost Optimization

- **Single NAT Gateway**: Reduces NAT gateway costs (trade-off: single point of
failure)
- **EKS Auto Mode**: Simplified and cost-effective node management
- **Lifecycle Policies**: ECR lifecycle policies help manage storage costs
- **VPC Endpoints**: Consider which endpoints you need:
  - SSM endpoints: Required for node access without bastion hosts
  - STS endpoint: Required for IRSA (enabled by default)
  - SNS endpoint: Only enable if using SMS 2FA
  - Estimated cost per endpoint: ~$7-10/month per availability zone

## Troubleshooting

### Common Issues

1. **Cluster Not Accessible**: Ensure `backend.hcl` is configured correctly and
remote state is accessible
2. **SSM Access**: Ensure VPC endpoints are fully created and security groups
allow traffic
3. **Node Access**: Use `aws ssm start-session` instead of SSH for private nodes
(no public IPs)
4. **Kubectl Connection**: Ensure kubeconfig is updated: `aws eks
update-kubeconfig --name <cluster-name> --region <region>`
5. **IRSA Not Working**:
   - Verify STS endpoint is enabled (`enable_sts_endpoint = true`)
   - Check service account has correct annotation
   - Verify IAM role trust policy references correct OIDC provider
   - Check pod logs for AWS SDK errors
6. **SNS SMS Failing**:
   - Verify SNS endpoint is enabled (`enable_sns_endpoint = true`)
   - Check IAM role has SNS publish permissions
   - Verify service account annotation is correct

### Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name <cluster-name> --region <region>

# View cluster outputs
terraform output

# Update kubeconfig
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw region)

# Access node via SSM (get instance ID from EKS console or AWS CLI)
aws ssm start-session --target <instance-id>

# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/$(terraform output -raw cluster_name)

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Check OIDC provider details
aws eks describe-cluster --name $(terraform output -raw cluster_name) --query "cluster.identity.oidc.issuer"
```

## Related Documentation

- [Application Infrastructure](../application/README.md) - OpenLDAP, 2FA app,
PostgreSQL, Redis, SES, and ArgoCD deployment
- [Terraform Backend State](../tf_backend_state/README.md) - S3 state management
- [Main README](../README.md) - Project overview and quick start

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS SNS SMS](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [AWS SES](https://docs.aws.amazon.com/ses/latest/dg/Welcome.html)
