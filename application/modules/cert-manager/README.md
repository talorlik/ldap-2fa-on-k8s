# cert-manager Module

This module installs cert-manager and creates a self-signed TLS certificate for
OpenLDAP internal communication.

## Purpose

cert-manager automatically generates and manages TLS certificates for OpenLDAP
to enable secure LDAP connections (StartTLS/LDAPS).

## What it Creates

1. **cert-manager** - Installed via Helm chart
   - Deployed in `cert-manager` namespace
   - Automatically installs CRDs
   - Manages certificate lifecycle automatically

2. **ClusterIssuer** (`selfsigned-issuer`) - Creates self-signed certificate authority
   - Cluster-wide resource
   - Uses self-signed certificate authority
   - Managed via `kubernetes_manifest` resource

3. **CA Certificate** (`openldap-ca`) - Certificate Authority certificate
   - Creates a Kubernetes secret named `openldap-ca-secret` in the specified namespace
   - Valid for 10 years
   - Used as the root CA for signing OpenLDAP certificates
   - Managed via `kubernetes_manifest` resource

4. **Issuer** (`openldap-ca-issuer`) - Issuer based on the CA certificate
   - Namespace-scoped resource
   - References the CA certificate secret
   - Used to sign the OpenLDAP TLS certificate
   - Managed via `kubernetes_manifest` resource

5. **Certificate** (`openldap-tls`) - TLS certificate for OpenLDAP
   - Creates a Kubernetes secret named `openldap-tls` in the specified namespace
   - Signed by the CA issuer
   - Valid for 10 years
   - Auto-renews 30 days before expiration
   - Includes DNS names for all OpenLDAP service endpoints
   - Managed via `kubernetes_manifest` resource

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
| ------ | ------------- | ------ | ---------- |
| cluster_name | Name of the EKS cluster | string | yes |
| namespace | Kubernetes namespace where OpenLDAP is deployed | string | yes |
| domain_name | Domain name for certificate DNS names | string | yes |

## Outputs

| Name | Description |
| ------ | ------------- |
| certificate_secret_name | Kubernetes secret name for TLS cert (always `openldap-tls`) |

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

# Check CA Certificate
kubectl get certificate -n ldap openldap-ca

# Check Issuer
kubectl get issuer -n ldap openldap-ca-issuer

# Check Certificate status
kubectl get certificate -n ldap openldap-tls

# View certificate details
kubectl describe certificate -n ldap openldap-tls

# Check the secret was created
kubectl get secret -n ldap openldap-tls
```

## Notes

- Uses Helm provider to install cert-manager (no kubectl required)
- Uses `kubernetes_manifest` resources for cert-manager CRDs
(ClusterIssuer, Issuer, Certificate)
- All resources are managed natively by Terraform with proper state tracking
- cert-manager version: v1.13.2
- Requires Helm provider to be configured with access to the EKS cluster
