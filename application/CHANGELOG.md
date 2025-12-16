# Changelog

All notable changes to the OpenLDAP application infrastructure will be
documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic
Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### [2025-12-14] - Deployment Versatility and Security Improvements

#### Changed

- **Network Policies: Enabled cross-namespace communication for LDAP service
access**
  - Updated network policies to allow services in other namespaces to access the
  LDAP service on secure ports (443, 636, 8443)
  - Added ingress rules using `namespace_selector {}` to enable cross-namespace
  communication
  - Maintains security by only allowing encrypted ports (HTTPS, LDAPS)
  - Updated documentation across all relevant files to reflect cross-namespace
  communication capability
  - Enables microservices in different namespaces to securely access the
  centralized LDAP service

- **Password management workflow**
  - OpenLDAP passwords are now exclusively managed through GitHub repository
  secrets
  - Removed dependency on local password files or manual environment variable
  setup
  - Setup script automatically handles password retrieval and export
  - Updated documentation to reflect new password management approach

- **Updated AWS provider configuration for multi-account architecture**
  - Removed `provider_profile` variable from `variables.tf` and
  `variables.tfvars`
  - Removed `profile = var.provider_profile` from `providers.tf`
  - Provider now uses role assumption via `deployment_account_role_arn` variable
  instead of AWS profiles
  - Aligns with environment-based role selection (production/development
  accounts)
  - Backend state operations use `AWS_STATE_ACCOUNT_ROLE_ARN` (configured in
  workflows/setup scripts)
  - Deployment operations use environment-specific role ARNs via `assume_role`
  configuration

- **Updated GitHub Actions workflows for application infrastructure**
  - `application_infra_provisioning.yaml`: Now uses `AWS_STATE_ACCOUNT_ROLE_ARN`
  for backend operations
  - `application_infra_destroying.yaml`: Now uses `AWS_STATE_ACCOUNT_ROLE_ARN`
  for backend operations
  - Both workflows automatically set `deployment_account_role_arn` variable
  based on selected environment:
    - `prod` environment → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
    - `dev` environment → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
  - Ensures proper separation between state account (S3) and deployment accounts
  (resource creation)

#### Added

- **Automated OpenLDAP password retrieval from GitHub secrets**
  - `setup-application.sh` now automatically retrieves OpenLDAP passwords from
  GitHub repository secrets
  - Script checks for `TF_VAR_OPENLDAP_ADMIN_PASSWORD` and
  `TF_VAR_OPENLDAP_CONFIG_PASSWORD` secrets
  - Automatically exports passwords as environment variables for Terraform
  - Supports both GitHub Actions (secrets automatically available) and local
  execution (requires exported environment variables)
  - Eliminates need for manual password file management

- **Unified application setup script**
  - New `setup-application.sh` script consolidates all application deployment
  steps
  - Handles role assumption, backend configuration, Terraform operations, and
  Kubernetes environment setup
  - Automatically retrieves all required secrets and variables from GitHub
  - Replaces previous `setup-backend.sh` and `setup-backend-api.sh` scripts
  - Includes comprehensive error handling and user guidance

#### Removed

- **Legacy setup scripts**
  - Removed `setup-backend.sh` (replaced by unified `setup-application.sh`)
  - Removed `setup-backend-api.sh` (replaced by unified `setup-application.sh`)
  - Consolidated functionality improves maintainability and reduces complexity

#### Fixed

- Corrected documentation to reflect new password management via GitHub
repository secrets
  - Updated README.md with accurate password setup instructions
  - Clarified local vs. GitHub Actions execution differences

### [2025-12-10] - Ingress Configuration Updates

#### Changed

- **Moved certificate ARN and group name to IngressClassParams (cluster-wide
configuration)**
  - Certificate ARN (`certificateARNs`) is now configured in IngressClassParams
  instead of Ingress annotations
  - ALB group name (`group.name`) is now configured in IngressClassParams
  instead of Ingress annotations
  - This centralizes TLS and group configuration at the cluster level, reducing
  annotation duplication
  - Updated `modules/alb/main.tf` to include `certificateARNs` and `group.name`
  in IngressClassParams
  - Updated Helm values template to remove `group.name` and `certificate-arn`
  from Ingress annotations
  - All Ingresses now use the same annotations (no leader/secondary distinction
  needed for group/certificate config)
  - Updated documentation in `PRD-ALB.md` and `README.md` to reflect new
  annotation strategy

#### Verified

- Multi-ingress single ALB configuration is correctly implemented with EKS Auto
Mode
  - Both Ingresses share the same ALB via `group.name` configured in
  IngressClassParams
  - Certificate ARN configured once in IngressClassParams (cluster-wide)
  - `load-balancer-name` annotation on both Ingresses (per-Ingress setting)
  - Per-Ingress settings (target-type, listen-ports, ssl-redirect) configured in
  Ingress annotations
  - Cluster-wide defaults (`scheme`, `ipAddressType`, `group.name`,
  `certificateARNs`) inherited from IngressClassParams

### [2025-12-08] - ALB and TLS Configuration Updates

#### Changed

- **Migrated from AWS Load Balancer Controller to EKS Auto Mode**
  - Updated ALB controller from `alb.ingress.kubernetes.io` to
  `eks.amazonaws.com/alb`
  - Changed IngressClassParams API group from `elbv2.k8s.aws` to
  `eks.amazonaws.com`
  - EKS Auto Mode provides built-in load balancer driver (no separate controller
  installation needed)
  - IAM permissions are automatically handled by EKS Auto Mode (no manual policy
  attachment required)
  - Updated `modules/alb/main.tf` to use EKS Auto Mode controller and API group

- **Improved ALB naming with separate group name and load balancer name**
  - Added distinction between `alb_group_name` (Kubernetes identifier, max 63
  chars) and `alb_load_balancer_name` (AWS resource name, max 32 chars)
  - Added automatic truncation logic to ensure names don't exceed Kubernetes (63
  chars) and AWS (32 chars) limits
  - Updated `main.tf` to handle name concatenation with prefix, region, and env,
  with proper truncation
  - Added `alb_load_balancer_name` variable to `variables.tf` with proper
  description
  - Updated Helm values template to use `alb_load_balancer_name` for AWS ALB
  name annotation

- **Optimized Ingress annotations to minimize duplication** (superseded by
cluster-wide IngressClassParams configuration)
  - Certificate ARN and group name moved to IngressClassParams (see latest
  changes above)
  - Ingress annotations now only contain per-Ingress settings
  (load-balancer-name, target-type, listen-ports, ssl-redirect)

- Updated TLS environment variables in `helm/openldap-values.tpl.yaml` to match
osixia/openldap image requirements
  - Changed `LDAP_TLS_CERT_FILE` → `LDAP_TLS_CRT_FILENAME` (filename only, not
  full path)
  - Changed `LDAP_TLS_KEY_FILE` → `LDAP_TLS_KEY_FILENAME` (filename only, not
  full path)
  - Changed `LDAP_TLS_CA_FILE` → `LDAP_TLS_CA_CRT_FILENAME` (filename only, not
  full path)
  - Added explicit `LDAP_TLS: "true"` to enable TLS
  - Updated comments to clarify osixia/openldap-specific behavior

#### Added

- **New variable `alb_load_balancer_name`** for custom AWS ALB naming
  - Allows separate control over Kubernetes group identifier vs AWS resource
  name
  - Supports AWS naming constraints (max 32 characters)
  - Defaults to `alb_group_name` (truncated to 32 chars if needed)

- **Comprehensive documentation updates in `PRD-ALB.md`**
  - Added detailed explanation of EKS Auto Mode vs AWS Load Balancer Controller
  differences
  - Added comparison table highlighting key differences between the two
  approaches
  - Documented IngressClassParams limitations (only `scheme` and `ipAddressType`
  supported in EKS Auto Mode)
  - Clarified annotation strategy and inheritance patterns
  - Added implementation details section explaining Terraform and Helm chart
  responsibilities

#### Fixed

- Fixed TLS configuration compatibility issue between Helm chart (designed for
Bitnami) and osixia/openldap image
  - osixia/openldap uses different environment variable names than Bitnami
  OpenLDAP
  - Certificates are now referenced by filename only (not full paths)
  - osixia/openldap will auto-generate self-signed certificates if they don't
  exist

## [2025-12-02] - Initial Configuration

### Added to date

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
- **TLS**: Auto-generated certificates for internal communication, ACM
certificates for ALB

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

- Use the same IngressClass (which references IngressClassParams with
`group.name` and `certificateARNs`)
- Point to the same ALB DNS name
- Have the same `alb.ingress.kubernetes.io/load-balancer-name` annotation

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

## Notes

### Certificate Auto-Generation

osixia/openldap will automatically generate self-signed certificates on first
startup if they don't exist. These certificates:

- ✅ Work for internal cluster communication
- ✅ Enable LDAPS (port 636)
- ⚠️ Won't be trusted by external clients (self-signed)
- ⚠️ Will be regenerated if the container is recreated without persistent
storage

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

- ✅ Both Ingresses share the same `group.name` (configured in
IngressClassParams)
- ✅ Certificate ARN configured once in IngressClassParams (cluster-wide)
- ✅ `load-balancer-name` annotation on both Ingresses (per-Ingress setting)
- ✅ Per-Ingress settings (target-type, listen-ports, ssl-redirect) in Ingress
annotations
- ✅ Host-based routing (different hosts for each service)

The ALB routes traffic based on the `Host` header:

- `phpldapadmin.talorlik.com` → phpLDAPadmin service
- `passwd.talorlik.com` → ltb-passwd service

## References

- [osixia/openldap GitHub](https://github.com/osixia/docker-openldap)
- [osixia/openldap TLS Documentation](https://github.com/osixia/docker-openldap#tls)
- [AWS Load Balancer Controller IngressGroups](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/#ingressgroup)
- [jp-gouin/helm-openldap GitHub](https://github.com/jp-gouin/helm-openldap)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
