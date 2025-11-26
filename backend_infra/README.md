# Backend Infrastructure

This Terraform configuration creates the core AWS infrastructure required for deploying the LDAP 2FA application on Kubernetes.

## Overview

The backend infrastructure provisions:

- **VPC** with public and private subnets
- **EKS Cluster** (Auto Mode) for running Kubernetes workloads
- **VPC Endpoints** for secure SSM access to nodes
- **EBS Storage** resources for persistent volumes
- **ECR Repository** for container image storage

## Architecture

```
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
- **Private Subnets**: For EKS nodes and application workloads
- **NAT Gateway**: Single NAT gateway for cost optimization (private subnet internet access)
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Properly configured for public and private subnets
- **DNS Support**: Enabled for service discovery

**Key Configuration:**

- Uses `terraform-aws-modules/vpc/aws` module (version 6.5.1)
- Kubernetes-specific tags for EKS integration
- Two availability zones for high availability

### 2. EKS Cluster

Deploys an Amazon EKS cluster in Auto Mode:

- **Auto Mode**: Simplified cluster management with automatic node provisioning
- **Public Endpoint**: API server accessible from internet (for kubectl access)
- **Logging**: CloudWatch logging enabled for API, audit, authenticator, controller manager, and scheduler
- **Node IAM Policies**: Includes SSM access for Session Manager

**Key Configuration:**

- Uses `terraform-aws-modules/eks/aws` module (version 21.9.0)
- Compute config with "general-purpose" node pool
- Cluster creator has admin permissions
- Nodes deployed in private subnets

### 3. VPC Endpoints Module

See [modules/endpoints/README.md](./modules/endpoints/README.md) for details.

Creates PrivateLink endpoints for:

- SSM Session Manager access
- Secure node access without public IPs
- No internet gateway dependency for SSM

### 4. EBS Module

See [modules/ebs/README.md](./modules/ebs/README.md) for details.

Creates Kubernetes storage resources:

- Default StorageClass for EBS volumes
- PersistentVolumeClaim for application storage
- Uses EKS Auto Mode's built-in EBS CSI driver

### 5. ECR Module

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
├── providers.tf        # Provider configuration
├── backend.hcl         # Terraform backend configuration (generated)
└── modules/
    ├── ebs/            # EBS storage resources
    │   └── README.md
    ├── ecr/            # ECR repository
    │   └── README.md
    └── endpoints/      # VPC endpoints
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

- VPC information (ID, subnets, security groups)
- EKS cluster details (name, endpoint, ARN)
- AWS account and region information

Use `terraform output` to view all available outputs.

## Security Considerations

1. **Private Subnets**: EKS nodes are deployed in private subnets
2. **VPC Endpoints**: Enable secure access without internet exposure
3. **Encrypted Storage**: EBS volumes are encrypted by default
4. **IAM Permissions**: Follow least privilege principles
5. **Network Isolation**: Proper security group rules restrict access

## Cost Optimization

- **Single NAT Gateway**: Reduces NAT gateway costs (trade-off: single point of failure)
- **EKS Auto Mode**: Simplified and cost-effective node management
- **Lifecycle Policies**: ECR lifecycle policies help manage storage costs

## Troubleshooting

### Common Issues

1. **PVC Not Binding**: The PVC will remain pending until a pod uses it (by design)
2. **SSM Access**: Ensure VPC endpoints are fully created and security groups allow traffic
3. **Node Access**: Use `aws ssm start-session` instead of SSH for private nodes

### Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name <cluster-name>

# View node security group
terraform output node_security_group_id

# Access node via SSM
aws ssm start-session --target <instance-id>
```

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
