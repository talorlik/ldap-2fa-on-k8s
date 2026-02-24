# Cross-Account Access and DNS Troubleshooting

This document covers issues related to cross-account Terraform (State vs
Deployment account), Route53 hosted zones, ACM certificates, and ALB/DNS.

## Route53 Issues

### "Empty result" when querying Route53 hosted zone

**Solution:** Ensure `state_account_role_arn` is set and the role has
`route53:GetHostedZone` permission.

### Route53 records cannot be created

**Solution:** Ensure State Account role has
`route53:ChangeResourceRecordSets` permission on the hosted zone.

### Record creation fails with "ALB DNS name must be available"

**Cause:** The ALB has not been provisioned yet, or the ALB data source
cannot find the ALB.

**Solution:**

1. Ensure the OpenLDAP module has been deployed (creates Ingress resources).
2. Verify the ALB exists:
   `aws elbv2 describe-load-balancers --region <region>`.
3. Check the ALB data source in `main.tf` is correctly configured.
4. Verify the ALB name matches `local.alb_load_balancer_name`.

### Record points to wrong ALB

**Cause:** The `alb_dns_name` variable is incorrect or points to a different
ALB.

**Solution:**

1. Verify the ALB data source is querying the correct ALB.
2. Check the ALB name in `main.tf` matches the actual ALB name.
3. Ensure the ALB zone_id matches the region where the ALB is deployed.

### Cross-account access issues (Route53 module)

**Cause:** The state account provider is not configured correctly, or the
role cannot be assumed.

**Solution:**

1. Verify `state_account_role_arn` is set in `variables.tfvars`.
2. Check the state account role trust relationship allows the current
   identity.
3. Ensure the state account provider is correctly configured in
   `providers.tf`.
4. Verify the provider is passed to the module in `main.tf`.

## ACM Certificate Issues

### "Empty result" when querying ACM certificate

**Solution:**

- Ensure deployment account credentials/role have `acm:ListCertificates` and
  `acm:DescribeCertificate` permissions.
- Verify certificate exists in the deployment account (not state account).
- Certificate should be a public ACM certificate requested in the
  Deployment Account.
- Verify certificate is validated and in `ISSUED` status.

### ALB cannot use certificate (CertificateNotFound)

**Root Cause:** EKS Auto Mode ALB controller cannot access cross-account
certificates. The certificate must be in the Deployment Account, not the
State Account.

**Solution:**

1. **Verify certificate is in Deployment Account:**
   - Certificate MUST be in the same account as the EKS cluster and ALB.
   - Check certificate account:
     `aws acm describe-certificate --certificate-arn <ARN> --region <region>`.
   - Extract account ID from certificate ARN. Verify it matches Deployment
     Account ID (not State Account ID).

2. **Create certificate in Deployment Account if missing:**
   - Request a public ACM certificate in the deployment account with DNS
     validation.
   - Create DNS validation record in Route53 hosted zone (State Account).
   - Wait for certificate status to be `ISSUED`.
   - See the main [CROSS_ACCOUNT_ACCESS.md](../../../application_infra/CROSS_ACCOUNT_ACCESS.md)
     document for full setup instructions.

3. **Update Terraform configuration:**
   - Ensure `data.aws_acm_certificate.this` uses default provider
     (deployment account), not `aws.state_account`.
   - Certificate data source should NOT have `provider = aws.state_account`.

4. **Verify certificate location and status:**
   - Certificate must be in the same region as ALB/EKS cluster.
   - Certificate must be validated and in `ISSUED` status.
   - Check: `aws acm list-certificates --region <region>`.

### Certificate not validating

**Check DNS record exists:**

```bash
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Type=='CNAME' && contains(Name, '_')]" \
  --output json
```

Ensure the CNAME validation record from ACM is present in the hosted zone.

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Application Infrastructure Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md)
- [Application Infrastructure CROSS_ACCOUNT_ACCESS](../../../application_infra/CROSS_ACCOUNT_ACCESS.md)
Full cross-account setup guide
- [Route53 Record Module README](../../../application_infra/modules/route53_record/README.md)
