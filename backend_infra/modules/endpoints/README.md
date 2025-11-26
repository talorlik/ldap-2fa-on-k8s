# VPC Endpoints Module

This module creates VPC endpoints (PrivateLink) to enable secure access to AWS Systems Manager (SSM) services from EKS nodes without requiring internet gateway access.

## Purpose

The endpoints module enables secure, private communication between EKS nodes and AWS SSM services, allowing:

- **SSM Session Manager** access to nodes without public IPs
- **Secure shell access** to private nodes via SSM
- **No internet gateway dependency** for SSM communication

## Key Features

### VPC Endpoints Created

The module creates three VPC endpoints for complete SSM functionality:

1. **SSM Endpoint** (`com.amazonaws.<region>.ssm`)
   - Core Systems Manager service endpoint

2. **SSM Messages Endpoint** (`com.amazonaws.<region>.ssmmessages`)
   - Enables Session Manager message passing

3. **EC2 Messages Endpoint** (`com.amazonaws.<region>.ec2messages`)
   - Enables EC2 instance messaging for SSM agent communication

### Security Configuration

- **Security Group**: Dedicated security group for VPC endpoints
- **Ingress Rules**: Allows HTTPS (port 443) traffic from EKS node security group
- **Egress Rules**: Allows all outbound traffic
- **Private DNS**: Enabled for seamless service discovery

### Network Configuration

- **Endpoint Type**: Interface endpoints (PrivateLink)
- **Subnet Placement**: Deployed in private subnets
- **High Availability**: Endpoints are created across multiple availability zones

## Important Notes

### Security Group Rules

The security group allows inbound HTTPS traffic (port 443) from the EKS node security group. This ensures:

- Only EKS nodes can access the VPC endpoints
- Traffic is encrypted via HTTPS
- No public internet access is required

### Private DNS

Private DNS is enabled, which means:

- Services can be accessed using their standard AWS service names
- No DNS configuration changes are required in your applications
- Seamless integration with existing AWS SDKs and tools

### Cost Considerations

- Interface endpoints incur hourly charges per endpoint per availability zone
- Data transfer charges apply for data processed through endpoints
- Consider using a single NAT gateway if cost is a concern (though this reduces security)

## Variables

- `env`: Deployment environment (e.g., prod, dev)
- `region`: AWS region
- `prefix`: Prefix added to all resource names
- `vpc_id`: ID of the VPC where endpoints will be created
- `private_subnets`: List of private subnet IDs for endpoint placement
- `endpoint_sg_name`: Name for the VPC endpoint security group
- `node_security_group_id`: Security group ID of EKS nodes
- `tags`: Map of tags to apply to resources

## Usage Example

```hcl
module "endpoints" {
  source                 = "./modules/endpoints"
  env                    = var.env
  region                 = var.region
  prefix                 = var.prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnets        = module.vpc.private_subnets
  endpoint_sg_name       = var.endpoint_sg_name
  node_security_group_id = module.eks.node_security_group_id
  tags                   = local.tags
}
```

## Accessing Nodes via SSM

After deployment, you can access EKS nodes using AWS Systems Manager Session Manager:

```bash
aws ssm start-session --target <instance-id>
```

No SSH keys or bastion hosts required!

## References

- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VPC Endpoint Pricing](https://aws.amazon.com/privatelink/pricing/)
