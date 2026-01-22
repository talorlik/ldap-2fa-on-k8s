# OpenLDAP Image Requirements Analysis

## Overview

You are using the **osixia/openldap:1.5.0** Docker image with the
**jp-gouin/helm-openldap** Helm chart. The chart is designed for Bitnami
OpenLDAP, which has different environment variables and TLS configuration than
osixia/openldap.

## Key Differences: osixia/openldap vs Bitnami OpenLDAP

### Environment Variables

**osixia/openldap** uses different environment variable names than Bitnami:

| osixia/openldap | Bitnami (chart default) | Current Config | Status |
| ---------------- | ------------------------ | ---------------- | -------- |
| `LDAP_TLS` | `LDAP_TLS` | ❌ Missing | **NEEDS FIX** |
| `LDAP_TLS_CRT_FILENAME` | N/A | ❌ Wrong (`LDAP_TLS_CERT_FILE`) | **NEEDS FIX** |
| `LDAP_TLS_KEY_FILENAME` | N/A | ❌ Wrong (`LDAP_TLS_KEY_FILE`) | **NEEDS FIX** |
| `LDAP_TLS_CA_CRT_FILENAME` | N/A | ❌ Wrong (`LDAP_TLS_CA_FILE`) | **NEEDS FIX** |
| `LDAP_TLS_ENFORCE` | `LDAP_TLS_ENFORCE` | ✅ Correct | OK |
| `LDAP_TLS_VERIFY_CLIENT` | `LDAP_TLS_VERIFY_CLIENT` | ✅ Correct | OK |

### TLS Certificate Handling

**osixia/openldap** expects:

- Certificates mounted at `/container/service/slapd/assets/certs/`
- Certificate filenames specified via environment variables (not paths)
- Auto-generation of self-signed certificates if certificates don't exist (when
`LDAP_TLS=true`)

**Bitnami** (chart default):

- Uses `initTLSSecret.tls_enabled` and `initTLSSecret.secret` to mount
certificates
- Different certificate paths and initialization process

## Required Changes

### 1. Fix TLS Environment Variables

**Current (INCORRECT):**

```yaml
env:
  LDAP_TLS_CA_FILE: "/container/service/slapd/assets/certs/ca.crt"
  LDAP_TLS_CERT_FILE: "/container/service/slapd/assets/certs/ldap.crt"
  LDAP_TLS_KEY_FILE: "/container/service/slapd/assets/certs/ldap.key"
```

**Should be (CORRECT for osixia/openldap):**

```yaml
env:
  LDAP_TLS: "true"  # Enable TLS (defaults to true, but explicit is better)
  LDAP_TLS_CRT_FILENAME: "ldap.crt"  # Filename only, not full path
  LDAP_TLS_KEY_FILENAME: "ldap.key"  # Filename only, not full path
  LDAP_TLS_CA_CRT_FILENAME: "ca.crt"  # Filename only, not full path
  LDAP_TLS_ENFORCE: "false"  # Don't enforce TLS (allows both LDAP and LDAPS)
  LDAP_TLS_VERIFY_CLIENT: "never"  # Don't require client certificates
```

### 2. Certificate Mounting Strategy

Since the helm chart's `initTLSSecret` feature is designed for Bitnami, you have
two options:

#### Option A: Use Auto-Generated Certificates (Simplest)

osixia/openldap will auto-generate self-signed certificates if they don't exist.
This works for internal cluster communication but certificates won't be trusted
by external clients.

**Configuration:**

```yaml
env:
  LDAP_TLS: "true"
  LDAP_TLS_ENFORCE: "false"
  LDAP_TLS_VERIFY_CLIENT: "never"
  # No certificate filenames needed - will auto-generate
```

#### Option B: Mount Custom Certificates via Volume

Mount certificates from a Kubernetes Secret using `extraVolumes` and
`extraVolumeMounts`:

**1. Create a Secret with certificates:**

```bash
kubectl create secret generic openldap-tls-certs \
  --from-file=ldap.crt=/path/to/cert.pem \
  --from-file=ldap.key=/path/to/key.pem \
  --from-file=ca.crt=/path/to/ca.pem \
  -n ldap
```

**2. Update Helm values:**

```yaml
env:
  LDAP_TLS: "true"
  LDAP_TLS_CRT_FILENAME: "ldap.crt"
  LDAP_TLS_KEY_FILENAME: "ldap.key"
  LDAP_TLS_CA_CRT_FILENAME: "ca.crt"
  LDAP_TLS_ENFORCE: "false"
  LDAP_TLS_VERIFY_CLIENT: "never"

extraVolumes:
  - name: tls-certs
    secret:
      secretName: openldap-tls-certs

extraVolumeMounts:
  - name: tls-certs
    mountPath: /container/service/slapd/assets/certs
    readOnly: true
```

### 3. Multi-Ingress Single ALB Configuration

Your current ALB configuration is **correct** with the following setup:

#### ✅ Correct Configuration

- `group.name` and `certificateARNs` configured in IngressClassParams
(cluster-wide)
- Both Ingresses use the same IngressClass (which references IngressClassParams)
- Both Ingresses have `alb.ingress.kubernetes.io/load-balancer-name` annotation
- Per-Ingress settings (target-type, listen-ports, ssl-redirect) configured in
Ingress annotations
- `scheme` and `ipAddressType` inherited from IngressClassParams

**Current implementation:**

```yaml
ltb-passwd:
  ingress:
    annotations:
      # Note: group.name and certificate-arn are in IngressClassParams
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
      alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      # scheme, ipAddressType, group.name, and certificateARNs inherited from IngressClassParams

phpldapadmin:
  ingress:
    annotations:
      # Same annotations as ltb-passwd - group.name and certificate-arn are in IngressClassParams
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
      alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
```

## Summary of Required Changes

### Priority 1: Fix TLS Environment Variables

1. Change `LDAP_TLS_CERT_FILE` → `LDAP_TLS_CRT_FILENAME`
2. Change `LDAP_TLS_KEY_FILE` → `LDAP_TLS_KEY_FILENAME`
3. Change `LDAP_TLS_CA_FILE` → `LDAP_TLS_CA_CRT_FILENAME`
4. Remove full paths, use only filenames
5. Add `LDAP_TLS: "true"` explicitly

### Priority 2: Certificate Mounting

- Choose Option A (auto-generated) or Option B (custom certificates)
- If using Option B, add `extraVolumes` and `extraVolumeMounts` configuration

### Priority 3: ALB Optimization (Optional)

- Remove duplicate TLS annotations from higher-order Ingress
- Ensure scheme is only set in IngressClassParams, not Ingress annotations

## References

- [osixia/openldap GitHub](https://github.com/osixia/docker-openldap)
- [osixia/openldap TLS Documentation](https://github.com/osixia/docker-openldap#tls)
- [jp-gouin/helm-openldap GitHub](https://github.com/jp-gouin/helm-openldap)
