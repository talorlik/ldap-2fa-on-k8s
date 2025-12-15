# Network Policies Module

This module creates Kubernetes Network Policies to secure internal cluster
communication using a **generic, service-agnostic approach**.

## Purpose

Network Policies enforce secure pod-to-pod communication rules within the
Kubernetes cluster, ensuring:

- **Encrypted Internal Communication**: Only secure ports (HTTPS 443, LDAPS 636,
etc.) are allowed between services
- **Generic Approach**: Any service can communicate with any service, as long as
it uses secure protocols
- **Future-Proof**: Works with any service you add later (2FA website, APIs,
etc.) without policy changes
- **Default Deny**: All traffic is denied by default, with explicit allow rules
for secure communication

## Design Philosophy

This module uses a **generic, service-agnostic approach** rather than
service-specific policies:

- ✅ **Any service can talk to any service** - No need to create new policies
when adding services
- ✅ **Only secure ports allowed** - Enforces encryption (HTTPS, LDAPS, etc.)
- ✅ **Works with future services** - Your 2FA website, APIs, or any other
service will work automatically
- ✅ **Simpler to maintain** - One policy instead of many service-specific
policies

## Network Policies Created

### 1. Namespace Secure Communication Policy

A single, generic policy that applies to **ALL pods** in the namespace:

**Allowed Ingress (from any pod in namespace):**

- HTTPS (port 443)
- LDAPS (port 636)
- Alternative HTTPS (port 8443)

**Allowed Ingress (from any pod in other namespaces):**

- HTTPS (port 443)
- LDAPS (port 636)
- Alternative HTTPS (port 8443)

> **Note**: Cross-namespace communication is enabled to allow services in other
namespaces to access the LDAP service. All communication must still use secure
ports (HTTPS, LDAPS).

**Allowed Egress (to any pod in namespace):**

- HTTPS (port 443)
- LDAPS (port 636)
- Alternative HTTPS (port 8443)

**Allowed External Egress:**

- DNS resolution (port 53 UDP/TCP)
- HTTPS (port 443) for external API calls
- HTTP (port 80) for external API calls (though HTTPS is preferred)

**Key Features:**

- Applies to all pods in the namespace (no label selectors)
- Only secure/encrypted ports are allowed
- Works with any service you add (PhpLdapAdmin, LTB-passwd, 2FA website, etc.)

### 2. Default Deny Policy

> **Note**: A separate default deny policy is **not created** in the current
implementation. The `namespace_secure_communication` policy achieves default
deny behavior by only allowing specific secure ports (443, 636, 8443). All other
ports are implicitly denied. This approach is simpler and avoids policy
conflicts while maintaining the same security posture.

The implementation achieves default deny behavior through:

- Only specific secure ports are explicitly allowed (443, 636, 8443)
- All other ports are implicitly denied by Kubernetes Network Policy behavior
- No separate default deny policy is needed

## Security Benefits

1. **Encrypted Internal Communication**: Forces all inter-service communication
to use secure ports (HTTPS, LDAPS)
2. **Generic and Flexible**: Works with any service without policy changes
3. **Future-Proof**: Your 2FA website and any future services will work
automatically
4. **Network Segmentation**: Services can only communicate on secure ports
5. **Default Deny**: All traffic is denied by default, with explicit allow rules
for secure communication
6. **External API Access**: Services can make HTTPS calls to external APIs (2FA
providers, etc.)

## Usage

The network policies are automatically applied when the module is included in
your Terraform configuration:

```hcl
module "network_policies" {
  source = "./modules/network-policies"

  namespace = "ldap"
}
```

## How It Works for Your 2FA Website

When you add your 2FA website:

1. **User Access**: Users navigate to your website via ALB (HTTPS on port 443)

   - ALB traffic comes from outside the cluster, so it's not restricted by
   Network Policies
   - Your website receives traffic normally

2. **LDAP Authentication**: Your website connects to OpenLDAP

   - ✅ **Allowed**: LDAPS (port 636) - encrypted communication
   - ❌ **Blocked**: LDAP (port 389) - unencrypted communication

3. **2FA Provider APIs**: Your website calls external 2FA provider APIs

   - ✅ **Allowed**: HTTPS (port 443) - encrypted communication
   - ✅ **Allowed**: HTTP (port 80) - for compatibility (though HTTPS is
   preferred)

4. **Service Discovery**: Your website resolves service names

   - ✅ **Allowed**: DNS (port 53) - required for Kubernetes service discovery

**No policy changes needed!** The generic policy already allows all of this.

## Important Notes

### Secure Ports

The policies allow these secure ports:

- **443**: HTTPS (for web services, APIs)
- **636**: LDAPS (for LDAP communication)
- **8443**: Alternative HTTPS port (for services that use non-standard HTTPS)

### Unencrypted Ports Are Blocked

These ports are **explicitly blocked**:

- **389**: LDAP (unencrypted) - Use LDAPS (636) instead
- **80**: HTTP (unencrypted) - Use HTTPS (443) instead
- **8080, 3000, etc.**: Unencrypted application ports - Use HTTPS (443) instead

### Service Configuration

Your services must be configured to:

- **Use HTTPS** for web services (not HTTP)
- **Use LDAPS** for LDAP communication (not LDAP)
- **Use secure ports** for inter-service communication

### ALB Traffic

**Important**: Traffic from the ALB comes from outside the cluster (from AWS
infrastructure), so it's **not subject to Network Policies**. The ALB
communicates with pods via the Kubernetes Service, and the Network Policies
control pod-to-pod communication within the cluster.

### Cross-Namespace Communication

The network policies **allow cross-namespace communication** to enable services
in other namespaces to access the LDAP service:

- ✅ **Allowed**: Services in any namespace can connect to LDAP service on secure
ports (443, 636, 8443)
- ✅ **Secure**: All cross-namespace communication must use encrypted ports
(HTTPS, LDAPS)
- ✅ **Generic**: Works with any service in any namespace without policy changes

**Example**: A service in the `production` namespace can connect to the LDAP
service in the `ldap` namespace using LDAPS (port 636):

```bash
Service Pod (production namespace)
    ↓ LDAPS (636) ✅ Allowed by Network Policy
LDAP Service (ldap namespace)
```

This enables microservices architectures where different services in different
namespaces can securely access the centralized LDAP service.

### DNS Requirements

The policies allow DNS resolution (port 53) which is required for:

- Service discovery within the cluster
- External DNS lookups if needed

## Example: 2FA Website Flow

```bash
User (Internet)
    ↓ HTTPS (443)
ALB (External - not restricted by Network Policies)
    ↓ HTTPS (443)
2FA Website Pod
    ↓ LDAPS (636) ✅ Allowed by Network Policy
OpenLDAP Pod
    ↓ HTTPS (443) ✅ Allowed by Network Policy
External 2FA Provider API
```

All communication uses secure ports, so everything works automatically!

## Troubleshooting

If services cannot communicate after applying network policies:

1. **Check Policy Status**:

   ```bash
   kubectl get networkpolicies -n ldap
   ```

2. **Verify Service Ports**:

   ```bash
   # Check what ports your services are using
   kubectl get services -n ldap
   kubectl describe service <service-name> -n ldap
   ```

   Ensure services use secure ports (443, 636, 8443).

3. **Test Connectivity**:

   ```bash
   # Test HTTPS connectivity
   kubectl exec -n ldap <pod-name> -- nc -zv <service-name> 443

   # Test LDAPS connectivity
   kubectl exec -n ldap <pod-name> -- nc -zv <service-name> 636
   ```

4. **Check Service Configuration**:
   - Ensure services are configured to use HTTPS (not HTTP)
   - Ensure LDAP services use LDAPS (not LDAP)
   - Verify service ports match allowed ports (443, 636, 8443)

5. **Check Policy Logs**:
   Network policies are enforced by the CNI plugin. Check CNI logs if policies
   aren't working.

## Adding New Secure Ports

If you need to allow additional secure ports, update the
`namespace_secure_communication` policy in `main.tf`:

```hcl
ingress {
  from {
    pod_selector {}
  }
  ports {
    port     = "YOUR_SECURE_PORT"
    protocol = "TCP"
  }
}
```

## References

- [Kubernetes Network Policies Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [AWS EKS Network Policies](https://docs.aws.amazon.com/eks/latest/userguide/network-policy.html)
