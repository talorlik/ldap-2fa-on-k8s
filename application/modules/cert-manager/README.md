# cert-manager Module

This module installs cert-manager and creates a self-signed TLS certificate for OpenLDAP internal communication.

## Purpose

cert-manager automatically generates and manages TLS certificates for OpenLDAP to enable secure LDAP connections (StartTLS/LDAPS).

## What it Creates

1. **cert-manager** - Installed via kubectl apply
   - Deployed in `cert-manager` namespace
   - Manages certificate lifecycle automatically

2. **ClusterIssuer** (`selfsigned-issuer`) - Creates self-signed certificates
   - Cluster-wide resource
   - Uses self-signed certificate authority

3. **Certificate** (`openldap-tls`) - TLS certificate for OpenLDAP
   - Creates a Kubernetes secret named `openldap-tls` in the `ldap` namespace
   - Valid for 10 years
   - Auto-renews 30 days before expiration
   - Includes DNS names for all OpenLDAP service endpoints

## Certificate DNS Names

The certificate includes the following DNS names:
- `openldap-stack-ha`
- `openldap-stack-ha.ldap`
- `openldap-stack-ha.ldap.svc`
- `openldap-stack-ha.ldap.svc.cluster.local`
- `openldap-stack-ha-headless`
- `openldap-stack-ha-headless.ldap`
- `openldap-stack-ha-headless.ldap.svc`
- `openldap-stack-ha-headless.ldap.svc.cluster.local`
- `openldap-stack-ha-0.openldap-stack-ha-headless.ldap.svc.cluster.local`
- `openldap-stack-ha-1.openldap-stack-ha-headless.ldap.svc.cluster.local`
- `openldap-stack-ha-2.openldap-stack-ha-headless.ldap.svc.cluster.local`
- `*.talorlik.com`
- `talorlik.com`

## Usage

```hcl
module "cert_manager" {
  source = "./modules/cert-manager"

  cluster_name = "my-eks-cluster"
  namespace    = "ldap"
  domain_name  = "talorlik.com"

  depends_on = [data.aws_eks_cluster.cluster]
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| cluster_name | Name of the EKS cluster | string | yes |
| namespace | Kubernetes namespace where OpenLDAP is deployed | string | yes |
| domain_name | Domain name for certificate DNS names | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| certificate_secret_name | Name of the Kubernetes secret containing the TLS certificate (always `openldap-tls`) |

## How OpenLDAP Uses the Certificate

The OpenLDAP Helm chart is configured to use this certificate via:

```yaml
env:
  LDAP_TLS_ENFORCE: "true"
  LDAP_TLS_VERIFY_CLIENT: "never"

customTLS:
  enabled: true
  secret: openldap-tls
```

## Verifying Certificate Creation

```bash
# Check cert-manager is running
kubectl get pods -n cert-manager

# Check ClusterIssuer
kubectl get clusterissuer selfsigned-issuer

# Check Certificate status
kubectl get certificate -n ldap openldap-tls

# View certificate details
kubectl describe certificate -n ldap openldap-tls

# Check the secret was created
kubectl get secret -n ldap openldap-tls
```

## Notes

- Uses `null_resource` with `local-exec` provisioners because cert-manager CRDs are not natively supported by Terraform Kubernetes provider
- Requires `kubectl` to be configured with access to the EKS cluster
- cert-manager version: v1.13.2
