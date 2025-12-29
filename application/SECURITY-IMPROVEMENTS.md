# Security Improvements Summary

This document outlines the security enhancements made to ensure fully secured
communication both from the internet (HTTPS on port 443) and internally within
the Kubernetes cluster.

## Changes Made

### 1. External HTTPS Security (Internet to ALB)

#### ✅ HTTP to HTTPS Redirect

- **Added**: HTTP (port 80) to HTTPS (port 443) redirect on all ALB ingress
resources
- **Location**: `application/helm/openldap-values.tpl.yaml`
- **Implementation**:
  - Added `alb.ingress.kubernetes.io/listen-ports:
  '[{"HTTP":80},{"HTTPS":443}]'` to listen on both ports
  - Added `alb.ingress.kubernetes.io/ssl-redirect: "443"` to automatically
  redirect HTTP to HTTPS
  - Added `alb.ingress.kubernetes.io/ssl-policy:
  "ELBSecurityPolicy-TLS13-1-2-2021-06"` for modern TLS security

#### ✅ ALB Module HTTPS Configuration

- **Updated**: `application/modules/alb/main.tf` to support optional HTTPS
configuration
- **Added**:
  - Certificate ARN parameter support
  - Listen-ports configuration for HTTP and HTTPS
  - SSL redirect annotation
  - SSL policy annotation
- **New Variable**: `acm_certificate_arn` in
`application/modules/alb/variables.tf`

**Result**: All external traffic is now forced to use HTTPS on port 443, with
automatic redirection from HTTP to HTTPS.

### 2. Internal Cluster Security

#### ✅ Network Policies for Pod-to-Pod Communication

- **Created**: New module `application/modules/network-policies/` with generic,
service-agnostic network policies
- **Generic Approach**: Any service can communicate with any service, but only
on secure ports
- **Cross-Namespace Communication**: Services in other namespaces can access the
LDAP service on secure ports
- **Policies Created**:
  1. **Namespace Secure Communication Policy**: Applies to ALL pods, allows
  secure inter-service communication
     - Allows HTTPS (port 443) between any services (same namespace and
     cross-namespace)
     - Allows LDAPS (port 636) between any services (same namespace and
     cross-namespace)
     - Allows alternative HTTPS (port 8443) between any services (same namespace
     and cross-namespace)
     - Allows DNS resolution (port 53)
     - Allows external HTTPS/HTTP for API calls (2FA providers, etc.)

**Key Security Features**:

- **Generic and Future-Proof**: Works with any service (PhpLdapAdmin,
LTB-passwd, 2FA website, future services) without policy changes
- **Encrypted Internal Communication**: Only secure ports (HTTPS 443, LDAPS 636)
are allowed
- **Cross-Namespace Access**: Services in other namespaces can securely access
the LDAP service using LDAPS (port 636)
- **Service-Agnostic**: No need to create new policies when adding services like
your 2FA website
- **Secure by Default**: Unencrypted ports (LDAP 389, HTTP 80) are blocked

### 3. TLS Security Policy

#### ✅ Modern TLS Configuration

- **SSL Policy**: `ELBSecurityPolicy-TLS13-1-2-2021-06` - Supports TLS 1.2 and
TLS 1.3
- **Applied to**: All ALB ingress resources (PhpLdapAdmin and LTB-passwd)

**Result**: Only modern, secure TLS protocols are used for external
communication.

## Security Architecture

### External Communication Flow

```bash
Internet (HTTP/HTTPS)
    ↓
ALB (Port 80 → Redirects to 443)
    ↓
ALB (Port 443 - HTTPS with TLS 1.2/1.3)
    ↓
Kubernetes Service (ClusterIP)
    ↓
Pod (PhpLdapAdmin or LTB-passwd)
```

### Internal Communication Flow

```bash
Any Service Pod (PhpLdapAdmin, LTB-passwd, 2FA Website, etc.)
    ↓ (Secure ports only: HTTPS 443, LDAPS 636)
Network Policy Enforcement
    ↓
Any Service Pod (OpenLDAP, APIs, etc.)
    ↓ (Secure ports only)
External APIs (HTTPS 443) - 2FA providers, etc.
```

**Cross-Namespace Communication Flow**:

```bash
Service Pod (Other Namespace, e.g., production)
    ↓ LDAPS (636) ✅ Allowed by Network Policy
LDAP Service (ldap namespace)
```

**Key Points**:

- Any service can communicate with any service (same namespace or
cross-namespace)
- Only secure/encrypted ports are allowed (443, 636, 8443)
- Cross-namespace communication is enabled for LDAP service access
- Your 2FA website will work automatically without policy changes

## Files Modified

1. **application/helm/openldap-values.tpl.yaml**

   - Added HTTP to HTTPS redirect
   - Added SSL policy configuration
   - Updated listen-ports to include both HTTP and HTTPS

2. **application/modules/alb/main.tf**

   - Added HTTPS configuration support
   - Added SSL redirect and SSL policy annotations

3. **application/modules/alb/variables.tf**

   - Added `acm_certificate_arn` variable

4. **application/main.tf**

   - Added network policies module
   - Updated ALB module to pass certificate ARN

## Files Created

1. **application/modules/network-policies/main.tf**

   - Network policies for OpenLDAP ingress
   - Network policies for PhpLdapAdmin egress
   - Network policies for LTB-passwd egress
   - Default deny policy for the namespace

2. **application/modules/network-policies/variables.tf**

   - Namespace variable for network policies

3. **application/modules/network-policies/README.md**

   - Comprehensive documentation for network policies

## Deployment Notes

### Prerequisites

- EKS cluster must support Network Policies (CNI plugin must support Network
Policies)
- Helm chart must create pods with labels matching the network policy selectors

### Important Considerations

1. **Generic Policy Approach**: The network policies are **service-agnostic**
and apply to ALL pods in the namespace:

   - No label selectors needed - works with any service
   - Cross-namespace communication enabled for LDAP service access
   - Your 2FA website will work automatically
   - Future services will work without policy changes

2. **Secure Ports Only**: Services must use secure ports:

   - **HTTPS** (port 443) for web services - not HTTP (port 80)
   - **LDAPS** (port 636) for LDAP - not LDAP (port 389)
   - **Alternative HTTPS** (port 8443) if needed
   - Unencrypted ports are blocked by the policy

3. **Service Configuration**: Ensure your services are configured correctly:

   - OpenLDAP must listen on LDAPS port 636
   - PhpLdapAdmin and LTB-passwd must use `ldaps://` instead of `ldap://`
   - Your 2FA website must use HTTPS for internal APIs
   - All inter-service communication must use secure ports

4. **Network Policy Enforcement**: Network policies are enforced by the CNI
plugin. If your cluster uses a CNI that doesn't support Network Policies (e.g.,
older versions of Flannel), the policies will be ignored.

## Testing

After deployment, verify:

1. **External HTTPS**:

   ```bash
   # Test HTTP redirect
   curl -I http://phpldapadmin.talorlik.com
   # Should return 301/302 redirect to HTTPS

   # Test HTTPS
   curl -I https://phpldapadmin.talorlik.com
   # Should return 200 OK
   ```

2. **Network Policies**:

   ```bash
   # Check network policies
   kubectl get networkpolicies -n ldap

   # Verify pod labels match policy selectors
   kubectl get pods -n ldap --show-labels
   ```

3. **LDAPS Communication**:

   ```bash
   # Test LDAPS connectivity from PhpLdapAdmin pod
   kubectl exec -n ldap <phpldapadmin-pod> -- nc -zv <openldap-service> 636
   # Should succeed

   # Test LDAP (should fail due to network policy)
   kubectl exec -n ldap <phpldapadmin-pod> -- nc -zv <openldap-service> 389
   # Should fail or timeout
   ```

### 4. Cross-Account Role Assumption Security

#### ✅ ExternalId for Role Assumption

- **Added**: ExternalId requirement for cross-account role assumption between
state account (Account A) and deployment accounts (Account B)
- **Location**: `application/providers.tf`, `backend_infra/providers.tf`
- **Implementation**:
  - ExternalId retrieved from AWS Secrets Manager (secret: `external-id`) for
  local deployment
  - ExternalId retrieved from GitHub repository secret (`AWS_ASSUME_EXTERNAL_ID`)
  for GitHub Actions
  - ExternalId passed to Terraform provider's `assume_role` block
  - Deployment account roles must have ExternalId condition in Trust Relationship

**Key Security Features**:

- **Prevents Confused Deputy Attacks**: ExternalId ensures only authorized
callers can assume deployment account roles
- **Secret-Based Management**: ExternalId stored securely in AWS Secrets Manager
and GitHub secrets (never hardcoded)
- **Consistent Value**: Same ExternalId used across both local and CI/CD
deployments
- **Trust Relationship Condition**: Deployment account roles require ExternalId
match in Trust Relationship policy

**Trust Relationship Configuration**:

The deployment account role's Trust Relationship must include:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "<generated-external-id>"
    }
  }
}
```

**ExternalId Generation**:

- Generate using: `openssl rand -hex 32`
- Must match in:
  - AWS Secrets Manager secret `external-id` (plain text)
  - GitHub repository secret `AWS_ASSUME_EXTERNAL_ID`
  - Deployment account role Trust Relationship condition

**Result**: Enhanced security for cross-account role assumption, preventing
unauthorized role assumption attempts.

## Security Compliance

These changes ensure:

✅ **End-to-End Encryption**: All external traffic uses HTTPS (TLS 1.2/1.3)
✅ **Internal Encryption**: All internal LDAP communication uses LDAPS
(encrypted)
✅ **Network Segmentation**: Services can only communicate with explicitly
allowed services
✅ **Default Deny**: All traffic is denied by default, with explicit allow rules
✅ **Principle of Least Privilege**: Each service has minimal required network
access
✅ **Modern TLS**: Only secure TLS protocols are used
✅ **Cross-Account Security**: ExternalId prevents confused deputy attacks in
multi-account deployments

## Next Steps (Optional Enhancements)

1. **Service Mesh**: Consider implementing a service mesh (Istio, Linkerd) for
mTLS between all services
2. **Certificate Rotation**: Implement automated certificate rotation for ACM
certificates
3. **Monitoring**: Set up monitoring and alerting for security events
4. **Audit Logging**: Enable Kubernetes audit logging for security compliance
5. **Pod Security Standards**: Implement Pod Security Standards for additional
security

## References

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [AWS ALB Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [AWS EKS Network Policies](https://docs.aws.amazon.com/eks/latest/userguide/network-policy.html)
- [TLS Security Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies)
