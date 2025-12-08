# Changelog

All notable changes to the OpenLDAP application infrastructure will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Migrated from AWS Load Balancer Controller to EKS Auto Mode**
  - Updated ALB controller from `alb.ingress.kubernetes.io` to `eks.amazonaws.com/alb`
  - Changed IngressClassParams API group from `elbv2.k8s.aws` to `eks.amazonaws.com`
  - EKS Auto Mode provides built-in load balancer driver (no separate controller installation needed)
  - IAM permissions are automatically handled by EKS Auto Mode (no manual policy attachment required)
  - Updated `modules/alb/main.tf` to use EKS Auto Mode controller and API group

- **Improved ALB naming with separate group name and load balancer name**
  - Added distinction between `alb_group_name` (Kubernetes identifier, max 63 chars) and `alb_load_balancer_name` (AWS resource name, max 32 chars)
  - Added automatic truncation logic to ensure names don't exceed Kubernetes (63 chars) and AWS (32 chars) limits
  - Updated `main.tf` to handle name concatenation with prefix, region, and env, with proper truncation
  - Added `alb_load_balancer_name` variable to `variables.tf` with proper description
  - Updated Helm values template to use `alb_load_balancer_name` for AWS ALB name annotation

- **Optimized Ingress annotations to minimize duplication**
  - Removed duplicate TLS annotations from secondary Ingress (phpldapadmin)
  - Clarified annotation strategy: leader Ingress (lowest `group.order`) contains all group-wide ALB configuration
  - Secondary Ingresses now only require `group.name` and `group.order` - all other settings are inherited from leader
  - Updated comments in `helm/openldap-values.tpl.yaml` to document annotation inheritance pattern

- Updated TLS environment variables in `helm/openldap-values.tpl.yaml` to match osixia/openldap image requirements
  - Changed `LDAP_TLS_CERT_FILE` → `LDAP_TLS_CRT_FILENAME` (filename only, not full path)
  - Changed `LDAP_TLS_KEY_FILE` → `LDAP_TLS_KEY_FILENAME` (filename only, not full path)
  - Changed `LDAP_TLS_CA_FILE` → `LDAP_TLS_CA_CRT_FILENAME` (filename only, not full path)
  - Added explicit `LDAP_TLS: "true"` to enable TLS
  - Updated comments to clarify osixia/openldap-specific behavior

### Added

- **New variable `alb_load_balancer_name`** for custom AWS ALB naming
  - Allows separate control over Kubernetes group identifier vs AWS resource name
  - Supports AWS naming constraints (max 32 characters)
  - Defaults to `alb_group_name` (truncated to 32 chars if needed)

- **Comprehensive documentation updates in `PRD-ALB.md`**
  - Added detailed explanation of EKS Auto Mode vs AWS Load Balancer Controller differences
  - Added comparison table highlighting key differences between the two approaches
  - Documented IngressClassParams limitations (only `scheme` and `ipAddressType` supported in EKS Auto Mode)
  - Clarified annotation strategy and inheritance patterns
  - Added implementation details section explaining Terraform and Helm chart responsibilities

### Fixed

- Fixed TLS configuration compatibility issue between Helm chart (designed for Bitnami) and osixia/openldap image
  - osixia/openldap uses different environment variable names than Bitnami OpenLDAP
  - Certificates are now referenced by filename only (not full paths)
  - osixia/openldap will auto-generate self-signed certificates if they don't exist

### Verified

- Multi-ingress single ALB configuration is correctly implemented with EKS Auto Mode
  - Both Ingresses use the same `alb.ingress.kubernetes.io/group.name`
  - Different `group.order` values (10 for ltb-passwd, 20 for phpldapadmin)
  - `load-balancer-name` annotation only on leader Ingress (lowest order)
  - Group-wide ALB settings (TLS, ports, SSL policy) inherited from leader Ingress
  - `scheme` and `ipAddressType` inherited from IngressClassParams (cluster-wide defaults)

## [2025-01-XX] - Initial Configuration

### Added

- Initial OpenLDAP deployment using osixia/openldap:1.5.0 image
- Helm chart from jp-gouin/helm-openldap (version 4.0.1)
- Multi-master replication configuration (3 replicas)
- Persistent storage with EBS volumes (8Gi, ReadWriteOnce)
- ALB configuration with IngressGroup for multiple Ingresses
- TLS termination at ALB using ACM certificates
- Two Ingress resources:
  - phpldapadmin.talorlik.com → phpLDAPadmin service
  - passwd.talorlik.com → ltb-passwd service
- Route53 DNS records for both hostnames pointing to ALB

### Configuration Details

- **Image**: osixia/openldap:1.5.0 (overriding chart's default Bitnami image)
- **Replication**: Multi-master replication enabled
- **Storage**: Persistent volumes with gp3 storage class
- **ALB**: Internet-facing, IP target type, TLS 1.2/1.3 only
- **TLS**: Auto-generated certificates for internal communication, ACM certificates for ALB

---

## Planned Changes

### [Future] - Custom Certificate Support

- [ ] Add support for mounting custom TLS certificates from Kubernetes Secrets
- [ ] Implement cert-manager integration for automatic certificate management
- [ ] Add documentation for using ACM certificates with OpenLDAP

### [Future] - Security Enhancements

- [ ] Enforce TLS for all LDAP connections (`LDAP_TLS_ENFORCE: "true"`)
- [ ] Implement client certificate verification for enhanced security
- [ ] Add network policies for stricter pod-to-pod communication

### [Future] - Monitoring and Observability

- [ ] Add Prometheus metrics export for OpenLDAP
- [ ] Implement logging aggregation for LDAP operations
- [ ] Add health check endpoints for better monitoring

### [Future] - High Availability Improvements

- [ ] Evaluate read-only replica configuration
- [ ] Implement backup automation for LDAP data
- [ ] Add disaster recovery procedures

---

## Verification Steps

After applying changes, verify the configuration:

### TLS Configuration Verification

```bash
kubectl get configmap -n ldap openldap-stack-ha-openldap-env -o yaml | grep LDAP_TLS
```

Expected output:

- `LDAP_TLS: "true"`
- `LDAP_TLS_CRT_FILENAME: "ldap.crt"`
- `LDAP_TLS_KEY_FILENAME: "ldap.key"`
- `LDAP_TLS_CA_CRT_FILENAME: "ca.crt"`

### ALB Configuration Verification

```bash
kubectl get ingress -n ldap
kubectl describe ingress -n ldap openldap-stack-ha-ltb-passwd
kubectl describe ingress -n ldap openldap-stack-ha-phpldapadmin
```

Both Ingresses should:

- Have the same `alb.ingress.kubernetes.io/group.name`
- Point to the same ALB DNS name
- Have different `group.order` values

### TLS Connection Testing

```bash
# Test LDAPS connection (port 636)
ldapsearch -x -H ldaps://openldap-stack-ha-openldap-0.openldap-stack-ha-openldap-headless.ldap.svc.cluster.local:636 -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w <password>

# Test LDAP connection (port 389)
ldapsearch -x -H ldap://openldap-stack-ha-openldap-0.openldap-stack-ha-openldap-headless.ldap.svc.cluster.local:389 -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w <password>
```

### ALB TLS Verification

```bash
# Check ALB listeners
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>
```

Expected:

- HTTP listener on port 80 (redirecting to HTTPS)
- HTTPS listener on port 443 with ACM certificate

---

## Notes

### Certificate Auto-Generation

osixia/openldap will automatically generate self-signed certificates on first startup if they don't exist. These certificates:

- ✅ Work for internal cluster communication
- ✅ Enable LDAPS (port 636)
- ⚠️ Won't be trusted by external clients (self-signed)
- ⚠️ Will be regenerated if the container is recreated without persistent storage

### Using Custom Certificates

To use custom certificates (e.g., from cert-manager or ACM):

1. Create a Kubernetes Secret:

```bash
kubectl create secret generic openldap-tls-certs \
  --from-file=ldap.crt=/path/to/cert.pem \
  --from-file=ldap.key=/path/to/key.pem \
  --from-file=ca.crt=/path/to/ca.pem \
  -n ldap
```

2. Add volume mounts to Helm values:

```yaml
extraVolumes:
  - name: tls-certs
    secret:
      secretName: openldap-tls-certs

extraVolumeMounts:
  - name: tls-certs
    mountPath: /container/service/slapd/assets/certs
    readOnly: true
```

### Multi-Ingress Single ALB

The configuration implements a single ALB with multiple Ingresses:

- ✅ Both Ingresses use the same `group.name`
- ✅ Different `group.order` values (10 and 20)
- ✅ `load-balancer-name` only on lowest order Ingress
- ✅ TLS configuration on both Ingresses
- ✅ Host-based routing (different hosts for each service)

The ALB routes traffic based on the `Host` header:

- `phpldapadmin.talorlik.com` → phpLDAPadmin service
- `passwd.talorlik.com` → ltb-passwd service

---

## References

- [osixia/openldap GitHub](https://github.com/osixia/docker-openldap)
- [osixia/openldap TLS Documentation](https://github.com/osixia/docker-openldap#tls)
- [AWS Load Balancer Controller IngressGroups](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#ingressgroup)
- [jp-gouin/helm-openldap GitHub](https://github.com/jp-gouin/helm-openldap)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
