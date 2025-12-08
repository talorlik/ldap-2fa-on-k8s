# Backend Infrastructure

This Terraform configuration creates the core AWS infrastructure required for deploying the LDAP 2FA application on Kubernetes.

## Overview

The backend infrastructure provisions:

- **VPC** with public and private subnets across two availability zones
- **EKS Cluster** (Auto Mode) for running Kubernetes workloads
- **VPC Endpoints** for secure SSM access to nodes
- **ECR Repository** for container image storage

> **Note**: The EBS module exists but is currently commented out in `main.tf`. Storage classes and PVCs are created by the application infrastructure instead.

## Architecture

```ascii
┌─────────────────────────────────────────────────────────┐
│                      VPC                                 │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ Public       │         │ Public       │             │
│  │ Subnet 1     │         │ Subnet 2    │             │
│  └──────────────┘         └──────────────┘             │
│         │                        │                      │
│         └──────── IGW ──────────┘                      │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ Private      │         │ Private      │             │
│  │ Subnet 1     │         │ Subnet 2    │             │
│  │              │         │              │             │
│  │  ┌────────┐  │         │  ┌────────┐ │             │
│  │  │ EKS    │  │         │  │ VPC    │ │             │
│  │  │ Nodes  │  │         │  │ Endpts │ │             │
│  │  └────────┘  │         │  └────────┘ │             │
│  └──────┬───────┘         └──────┬──────┘             │
│         │                        │                      │
│         └────── NAT Gateway ─────┘                      │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. VPC Module

Creates a Virtual Private Cloud with:

- **Public Subnets**: For internet-facing resources (Load Balancers)
  - Tagged with `kubernetes.io/role/elb = 1` for ALB placement
- **Private Subnets**: For EKS nodes and application workloads
  - Tagged with `kubernetes.io/role/internal-elb = 1` for internal load balancers
- **NAT Gateway**: Single NAT gateway for cost optimization (private subnet internet access)
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Properly configured for public and private subnets
- **DNS Support**: Enabled for service discovery (`enable_dns_hostnames = true`, `enable_dns_support = true`)
- **DHCP Options**: Configured with domain name `ec2.internal`

**Key Configuration:**

- Uses `terraform-aws-modules/vpc/aws` module (version 6.5.1)
- Kubernetes-specific tags for EKS integration:
  - `kubernetes.io/cluster/${cluster_name} = "shared"` on all subnets
  - `kubernetes.io/role/elb = 1` on public subnets
  - `kubernetes.io/role/internal-elb = 1` on private subnets
- Two availability zones for high availability
- Subnets automatically named: `${vpc_name}-public-subnet-{1,2}` and `${vpc_name}-private-subnet-{1,2}`

### 2. EKS Cluster

Deploys an Amazon EKS cluster in Auto Mode:

- **Auto Mode**: Simplified cluster management with automatic node provisioning
  - Enabled via `compute_config.enabled = true`
  - Uses "general-purpose" node pool
- **Elastic Load Balancing**: Automatically enabled by default with Auto Mode
  - No explicit configuration needed - `elastic_load_balancing` capability is enabled by default
  - Supports ALB provisioning via EKS Auto Mode Ingress
- **Public Endpoint**: API server accessible from internet (`endpoint_public_access = true` for kubectl access)
- **Logging**: CloudWatch logging enabled for:
  - API server
  - Audit logs
  - Authenticator
  - Controller manager
  - Scheduler
- **Node IAM Policies**: Includes SSM access for Session Manager (`AmazonSSMManagedInstanceCore`)

**Key Configuration:**

- Uses `terraform-aws-modules/eks/aws` module (version 21.9.0)
- Kubernetes version specified via `k8s_version` variable
- Compute config with "general-purpose" node pool
- Cluster creator has admin permissions (`enable_cluster_creator_admin_permissions = true`)
- Nodes deployed in private subnets
- CloudWatch log group created automatically

### 3. VPC Endpoints Module

See [modules/endpoints/README.md](./modules/endpoints/README.md) for details.

Creates PrivateLink endpoints for:

- SSM Session Manager access
- Secure node access without public IPs
- No internet gateway dependency for SSM

### 4. ECR Module

See [modules/ecr/README.md](./modules/ecr/README.md) for details.

Creates container registry:

- Private Docker registry for application images
- Configurable lifecycle policies
- Image tag mutability settings

## Module Structure

```bash
backend_infra/
├── main.tf             # Main infrastructure configuration
├── variables.tf        # Variable definitions
├── variables.tfvars    # Variable values (customize for your environment)
├── outputs.tf          # Output values
├── providers.tf        # Provider configuration (AWS, Kubernetes)
├── backend.hcl         # Terraform backend configuration (generated)
├── setup-backend.sh    # Backend setup script (GitHub CLI)
├── setup-backend-api.sh # Backend setup script (GitHub API)
├── tfstate-backend-values-template.hcl # Backend config template
└── modules/
    ├── ebs/            # EBS storage resources (currently commented out in main.tf)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── ecr/            # ECR repository
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    └── endpoints/      # VPC endpoints
        ├── main.tf
        ├── variables.tf
        └── README.md
```

## Prerequisites

1. **Terraform Backend**: The Terraform state backend must be provisioned first (see [tf_backend_state/README.md](../tf_backend_state/README.md))
2. **AWS Credentials**: Configured AWS credentials with appropriate permissions
3. **Backend Configuration**: Generate `backend.hcl` using the setup scripts (see main [README.md](../README.md))

## Key Variables

### Required Variables

- `env`: Deployment environment (prod, dev)
- `region`: AWS region (us-east-1, us-east-2)
- `prefix`: Prefix for all resource names
- `vpc_cidr`: CIDR block for VPC
- `k8s_version`: Kubernetes version for EKS cluster

### Important Configuration

- **Naming Convention**: All resources follow the pattern `${prefix}-${region}-${name}-${env}`
- **Workspace-based State**: Uses Terraform workspaces named `${region}-${env}`
- **Single NAT Gateway**: Configured for cost optimization (can be changed to `false` for HA)

## Outputs

The infrastructure provides outputs for:

**AWS Account & Region:**

- `aws_account`: AWS Account ID
- `region`: AWS region
- `env`: Deployment environment
- `prefix`: Resource name prefix

**VPC:**

- `vpc_id`: VPC ID
- `default_security_group_id`: Default VPC security group ID
- `public_subnets`: List of public subnet IDs
- `private_subnets`: List of private subnet IDs
- `igw_id`: Internet Gateway ID

**EKS Cluster:**

- `cluster_name`: EKS cluster name (format: `${prefix}-${region}-${cluster_name}-${env}`)
- `cluster_endpoint`: EKS Cluster API endpoint
- `cluster_arn`: EKS Cluster ARN

> **Note**: EBS outputs are commented out since the EBS module is not currently active.

Use `terraform output` to view all available outputs.

## Security Considerations

1. **Private Subnets**: EKS nodes are deployed in private subnets (no public IPs)
2. **VPC Endpoints**: Enable secure SSM access without internet exposure
3. **Public API Endpoint**: EKS API server is publicly accessible (required for kubectl access)
4. **IAM Permissions**:
   - Cluster creator has admin permissions
   - Nodes have SSM access via `AmazonSSMManagedInstanceCore` policy
5. **Network Isolation**: Proper security group rules restrict access
6. **Kubernetes Tags**: Subnets are properly tagged for Kubernetes integration
7. **CloudWatch Logging**: Comprehensive logging enabled for audit and security monitoring

## Cost Optimization

- **Single NAT Gateway**: Reduces NAT gateway costs (trade-off: single point of failure)
- **EKS Auto Mode**: Simplified and cost-effective node management
- **Lifecycle Policies**: ECR lifecycle policies help manage storage costs

## Troubleshooting

### Common Issues

1. **Cluster Not Accessible**: Ensure `backend.hcl` is configured correctly and remote state is accessible
2. **SSM Access**: Ensure VPC endpoints are fully created and security groups allow traffic
3. **Node Access**: Use `aws ssm start-session` instead of SSH for private nodes (no public IPs)
4. **Kubectl Connection**: Ensure kubeconfig is updated: `aws eks update-kubeconfig --name <cluster-name> --region <region>`

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
```

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
