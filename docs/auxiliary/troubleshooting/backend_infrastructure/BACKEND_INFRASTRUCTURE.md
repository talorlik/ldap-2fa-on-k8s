# Backend Infrastructure Troubleshooting

This document covers common issues when deploying or operating the EKS
backend infrastructure (VPC, EKS cluster, IRSA, VPC endpoints, SNS/SES).

## Common Issues

1. **Cluster Not Accessible**
   - Ensure `backend.hcl` is configured correctly and remote state is
     accessible.
   - Verify you are in the correct Terraform workspace (e.g. `us-east-1-prod`).

2. **SSM Access**
   - Ensure VPC endpoints are fully created and security groups allow traffic.
   - Use `aws ssm start-session` instead of SSH for private nodes (no public
     IPs).

3. **Node Access**
   - Use `aws ssm start-session` instead of SSH for private nodes (no public
     IPs). Get instance ID from EKS console or AWS CLI.

4. **Kubectl Connection**
   - Ensure kubeconfig is updated:
     `aws eks update-kubeconfig --name <cluster-name> --region <region>`.

5. **IRSA Not Working**
   - Verify STS endpoint is enabled (`enable_sts_endpoint = true`).
   - Check service account has correct annotation.
   - Verify IAM role trust policy references correct OIDC provider.
   - Check pod logs for AWS SDK errors.

6. **SNS SMS Failing**
   - Verify SNS endpoint is enabled (`enable_sns_endpoint = true`).
   - Check IAM role has SNS publish permissions.
   - Verify service account annotation is correct.

## Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name <cluster-name> --region <region>

# View cluster outputs
terraform output

# Update kubeconfig
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) \
  --region $(terraform output -raw region)

# Access node via SSM (get instance ID from EKS console or AWS CLI)
aws ssm start-session --target <instance-id>

# Check VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# View CloudWatch logs
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/$(terraform output -raw cluster_name)

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Check OIDC provider details
aws eks describe-cluster --name $(terraform output -raw cluster_name) \
  --region <region> --query "cluster.identity.oidc.issuer"
```

## Related Documentation

- [Troubleshooting Index](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/INDEX.md)
- [Application Infrastructure Deployment](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
- [Debug Commands](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/reference/DEBUG_COMMANDS.md)
