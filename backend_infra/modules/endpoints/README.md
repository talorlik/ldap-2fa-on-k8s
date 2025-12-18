# VPC Endpoints Module

This module creates VPC endpoints (PrivateLink) to enable secure access to AWS
services from EKS nodes without requiring internet gateway access.

## Purpose

The endpoints module enables secure, private communication between EKS nodes and
AWS services, allowing:

- **SSM Session Manager** access to nodes without public IPs
- **IRSA (IAM Roles for Service Accounts)** for pods to assume IAM roles
- **SMS 2FA** via SNS for sending verification codes
- **No internet gateway dependency** for AWS service communication

## Key Features

### VPC Endpoints Created

The module creates the following VPC endpoints:

#### SSM Endpoints (Always Enabled)

1. **SSM Endpoint** (`com.amazonaws.<region>.ssm`)
   - Core Systems Manager service endpoint

2. **SSM Messages Endpoint** (`com.amazonaws.<region>.ssmmessages`)
   - Enables Session Manager message passing

3. **EC2 Messages Endpoint** (`com.amazonaws.<region>.ec2messages`)
   - Enables EC2 instance messaging for SSM agent communication

#### STS Endpoint (Optional, Default: Enabled)

4. **STS Endpoint** (`com.amazonaws.<region>.sts`)
   - **Required for IRSA** (IAM Roles for Service Accounts)
   - Allows pods to call `sts:AssumeRoleWithWebIdentity`
   - Enable with `enable_sts_endpoint = true`

#### SNS Endpoint (Optional, Default: Disabled)

5. **SNS Endpoint** (`com.amazonaws.<region>.sns`)
   - **Required for SMS 2FA** functionality
   - Allows pods to send SMS via SNS
   - Enable with `enable_sns_endpoint = true`

### Security Configuration

- **Security Group**: Dedicated security group for VPC endpoints
- **Ingress Rules**:
  - Allows HTTPS (port 443) from EKS node security group
  - Allows HTTPS (port 443) from VPC CIDR (for pods)
- **Egress Rules**: Allows all outbound traffic
- **Private DNS**: Enabled for seamless service discovery

### Network Configuration

- **Endpoint Type**: Interface endpoints (PrivateLink)
- **Subnet Placement**: Deployed in private subnets
- **High Availability**: Endpoints are created across multiple availability zones

## Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `env` | Deployment environment (e.g., prod, dev) | Yes | - |
| `region` | AWS region | Yes | - |
| `prefix` | Prefix added to all resource names | Yes | - |
| `vpc_id` | ID of the VPC where endpoints will be created | Yes | - |
| `vpc_cidr` | CIDR block of the VPC (for security group rules) | Yes | - |
| `private_subnets` | List of private subnet IDs for endpoint placement | Yes | - |
| `endpoint_sg_name` | Name for the VPC endpoint security group | Yes | - |
| `node_security_group_id` | Security group ID of EKS nodes | Yes | - |
| `enable_sts_endpoint` | Whether to create STS endpoint (for IRSA) | No | `true` |
| `enable_sns_endpoint` | Whether to create SNS endpoint (for SMS 2FA) | No | `false` |
| `tags` | Map of tags to apply to resources | Yes | - |

## Usage Example

```hcl
module "endpoints" {
  source                 = "./modules/endpoints"
  env                    = var.env
  region                 = var.region
  prefix                 = var.prefix
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  private_subnets        = module.vpc.private_subnets
  endpoint_sg_name       = var.endpoint_sg_name
  node_security_group_id = module.eks.node_security_group_id
  enable_sts_endpoint    = true   # Required for IRSA
  enable_sns_endpoint    = true   # Required for SMS 2FA
  tags                   = local.tags
}
```

## IRSA (IAM Roles for Service Accounts)

When `enable_sts_endpoint = true`, pods can assume IAM roles using service accounts:

1. The EKS cluster must have OIDC provider enabled (`enable_irsa = true` in EKS module)
2. Create an IAM role with a trust policy for the service account
3. Annotate the Kubernetes service account with the IAM role ARN
4. Pods using that service account can call AWS APIs

Example service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-role
```

## SNS for SMS 2FA

When `enable_sns_endpoint = true`, pods can send SMS via SNS:

1. Enable the SNS VPC endpoint
2. Create IAM role with SNS publish permissions
3. Configure IRSA for the backend service account
4. Backend can call `sns.publish()` to send SMS

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_endpoint_sg_id` | Security group ID for VPC endpoints |
| `vpc_endpoint_ssm_id` | VPC endpoint ID for SSM |
| `vpc_endpoint_ssmmessages_id` | VPC endpoint ID for SSM Messages |
| `vpc_endpoint_ec2messages_id` | VPC endpoint ID for EC2 Messages |
| `vpc_endpoint_sts_id` | VPC endpoint ID for STS (null if disabled) |
| `vpc_endpoint_sns_id` | VPC endpoint ID for SNS (null if disabled) |
| `vpc_endpoint_ids` | List of all enabled VPC endpoint IDs |

## Cost Considerations

- Interface endpoints incur hourly charges per endpoint per availability zone
- Data transfer charges apply for data processed through endpoints
- Estimated monthly cost per endpoint: ~$7-10/AZ
- Consider whether you need SNS endpoint (can use NAT gateway instead)

## Accessing Nodes via SSM

After deployment, you can access EKS nodes using AWS Systems Manager Session
Manager:

```bash
aws ssm start-session --target <instance-id>
```

No SSH keys or bastion hosts required!

## References

- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [AWS SNS SMS](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [VPC Endpoint Pricing](https://aws.amazon.com/privatelink/pricing/)
