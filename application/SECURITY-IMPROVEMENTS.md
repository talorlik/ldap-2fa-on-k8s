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
  "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"` for modern TLS security with post-quantum
  cryptography support

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

- **SSL Policy**: `ELBSecurityPolicy-TLS13-1-0-PQ-2025-09` - Supports TLS 1.3 with
post-quantum cryptography
- **Applied to**: All ALB ingress resources (PhpLdapAdmin, LTB-passwd, and 2FA application)

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

**State Account Role Trust Relationship (Reverse Direction)**:

In addition to deployment account roles trusting the state account role, the
state account role's Trust Relationship must also be updated to allow the
deployment account roles. This bidirectional trust is required for proper
cross-account role assumption.

> [!IMPORTANT]
>
> **ExternalId Still Required**: The ExternalId security mechanism is still
> required when the state account role assumes deployment account roles. The
> ExternalId condition must be present in the deployment account roles' Trust
> Relationships (as shown above), and the state account role must provide the
> ExternalId when assuming those roles. The ExternalId is retrieved from
> `AWS_ASSUME_EXTERNAL_ID` secret (for GitHub Actions) or AWS Secrets Manager
> (for local deployment).

Update the state account role's Trust Relationship to include the deployment
account role ARNs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::STATE_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::PRODUCTION_ACCOUNT_ID:role/github-role",
          "arn:aws:iam::DEVELOPMENT_ACCOUNT_ID:role/github-role",
          "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Replace `PRODUCTION_ACCOUNT_ID` and `DEVELOPMENT_ACCOUNT_ID` with your actual
account IDs, and `github-role` with your actual deployment role names.

> [!IMPORTANT]
>
> **Self-Assumption Statement**: The last statement allows the role to assume itself.
> This is required when:
>
> - The State Account role is used for both backend state operations and
> Route53/ACM access (when `state_account_role_arn` points to the same role)
> - Terraform providers need to assume the same role that was already assumed by
> the initial authentication
> - You encounter errors like "User: arn:aws:sts::ACCOUNT_ID:assumed-role/github-role/SESSION
> is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::ACCOUNT_ID:role/github-role"
>
> Without this statement, if a session is already running under `github-role` and
> Terraform tries to assume the same role again (via `assume_role` in `providers.tf`),
> the operation will fail with an `AccessDenied` error.

**ExternalId Generation**:

- Generate using: `openssl rand -hex 32`
- Must match in:
  - AWS Secrets Manager secret `external-id` (plain text)
  - GitHub repository secret `AWS_ASSUME_EXTERNAL_ID`
  - Deployment account role Trust Relationship condition

**Result**: Enhanced security for cross-account role assumption, preventing
unauthorized role assumption attempts. Both the deployment account roles and the
state account role must trust each other in their respective Trust
Relationships for proper bidirectional cross-account access.

#### ✅ Route53 Cross-Account Access

- **Added**: Support for accessing Route53 hosted zones from State Account
- **Location**: `application/providers.tf`, `application/main.tf`, `application/modules/route53_record/`,
`application/modules/ses/`
- **Implementation**:
  - State account provider alias (`aws.state_account`) configured in `providers.tf`
  - Route53 hosted zone data source queries from State Account when `state_account_role_arn`
  is provided
  - All Route53 record resources use state account provider for creating records
  in State Account
  - Scripts automatically inject `state_account_role_arn` into `variables.tfvars`
  - No ExternalId required for state account role assumption (by design)

#### ✅ ACM Certificate Architecture (EKS Auto Mode)

- **Important**: EKS Auto Mode ALB controller **CANNOT** access cross-account
ACM certificates
- **Requirement**: ACM certificate **MUST** be in the Deployment Account
(same account as EKS cluster)
- **Architecture**: Public ACM certificates with DNS validation via Route53
- **Location**: `application/main.tf`
- **Implementation**:
  - Public ACM certificates are requested in each deployment account
  (development, production)
  - DNS validation records are created in Route53 hosted zone in State Account
  - Each deployment account has its own public ACM certificate
  - ACM certificate data source uses default provider (deployment account),
  NOT `aws.state_account`
  - Certificate must exist in Deployment Account before ALB creation
  - Certificate must be validated and in `ISSUED` status
  - Certificate must be in the same region as the EKS cluster
  - No cross-account certificate access needed (each account uses its own certificate)
  - Certificates are automatically renewed by ACM

**Key Security Features**:

- **Public ACM Certificate Architecture**: Public ACM certificates requested in
each deployment account
- **Browser-Trusted Certificates**: Public ACM certificates are trusted by browsers
without warnings
- **No Cross-Account Certificate Access**: Each deployment account has its own
certificate, eliminating cross-account certificate access needs
- **Cross-Account Resource Access**: Route53 hosted zones reside in State Account
while ALB is deployed in Deployment Account
- **Automatic Provider Selection**: Terraform automatically uses state account
provider when `state_account_role_arn` is configured
- **No ExternalId Required**: State account role assumption does not require
ExternalId (by design, different security model)
- **Automatic Renewal**: ACM automatically renews certificates before expiration
- **Comprehensive Documentation**: See `CROSS-ACCOUNT-ACCESS.md` for complete
configuration details, including step-by-step AWS CLI commands for public ACM
certificate setup and DNS validation.

**State Account Role Permissions**:

The State Account role must have the following permissions (Route53 only, ACM
certificate access not needed since each account has its own certificate):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    }
  ]
}
```

**Deployment Account Role Permissions (for ACM Certificate):**

The Deployment Account role (or default credentials) must have ACM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

**State Account Role Trust Relationship**:

The State Account role must trust the Deployment Account role (or GitHub Actions
OIDC provider):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::DEPLOYMENT_ACCOUNT_ID:role/github-role",
          "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Note**: ExternalId is **not required** for State Account role assumption (by design).

> [!IMPORTANT]
>
> **Self-Assumption Statement**: The second statement allows the role to assume
> itself. This is required when the State Account role is used for both backend
> state operations and Route53/ACM access (when `state_account_role_arn` points
> to the same role). Without this statement, if a session is already running under
> `github-role` and Terraform tries to assume the same role again via `assume_role`
> in `providers.tf`, the operation will fail with an `AccessDenied` error.

**Result**: Enables secure cross-account access to Route53 hosted zones while maintaining
separation between state storage and resource deployment accounts. ACM certificates
must be in the Deployment Account due to EKS Auto Mode ALB controller limitations.

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
