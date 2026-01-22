# OpenLDAP Deployment Requirements

## Overview

This document defines the requirements for deploying OpenLDAP directory service in the Kubernetes cluster, including security, networking, storage, and integration requirements.

> [!NOTE]
>
> For technical details about the Helm chart and its configuration options, see [OPENLDAP-README.md](./OPENLDAP-README.md).

## Functional Requirements

### REQ-1: LDAP Service Isolation

| ID | Requirement |
| ---- | ------------- |
| REQ-1.1 | LDAP service must be accessible only within the Kubernetes cluster |
| REQ-1.2 | LDAP ports (389, 636) must not be exposed externally |
| REQ-1.3 | LDAP service must use ClusterIP service type (not LoadBalancer or NodePort) |
| REQ-1.4 | LDAP service must be reachable via internal Kubernetes DNS |

### REQ-2: Management UI Exposure

| ID | Requirement |
| ---- | ------------- |
| REQ-2.1 | PhpLdapAdmin UI must be accessible via internet-facing ALB |
| REQ-2.2 | LTB-passwd UI must be accessible via internet-facing ALB |
| REQ-2.3 | Both UIs must use HTTPS with TLS termination at ALB |
| REQ-2.4 | Both UIs must share the same ALB (via IngressGroup) |
| REQ-2.5 | UIs must be accessible on configurable hostnames (e.g., `phpldapadmin.{domain}`, `passwd.{domain}`) |

### REQ-3: Persistent Storage

| ID | Requirement |
| ---- | ------------- |
| REQ-3.1 | OpenLDAP data must persist across pod restarts |
| REQ-3.2 | Storage must use EBS-backed PersistentVolumeClaims |
| REQ-3.3 | StorageClass must be configurable (provided by infrastructure) |
| REQ-3.4 | Minimum storage size must be configurable (default: 8Gi) |
| REQ-3.5 | Storage must use ReadWriteOnce access mode |

### REQ-4: Container Image Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-4.1 | Container images must be pulled from ECR (not Docker Hub) |
| REQ-4.2 | Images must be automatically mirrored from Docker Hub to ECR before deployment |
| REQ-4.3 | ECR registry and repository must be configurable via Terraform variables |
| REQ-4.4 | Image tags must follow standardized naming (e.g., `openldap-1.5.0`) |
| REQ-4.5 | Image mirroring must skip images that already exist in ECR |

### REQ-5: Credential Management

| ID | Requirement |
| ---- | ------------- |
| REQ-5.1 | LDAP admin password must be sourced from GitHub Secrets or AWS Secrets Manager |
| REQ-5.2 | LDAP config password must be sourced from GitHub Secrets or AWS Secrets Manager |
| REQ-5.3 | Passwords must not be hardcoded in Helm values files |
| REQ-5.4 | Passwords must be stored in Kubernetes Secrets |
| REQ-5.5 | Secret names must be configurable |

### REQ-6: LDAP Configuration

| ID | Requirement |
| ---- | ------------- |
| REQ-6.1 | LDAP domain must be configurable (e.g., `ldap.{domain}`) |
| REQ-6.2 | LDAP must use standard ports (389 for LDAP, 636 for LDAPS) |
| REQ-6.3 | LDAP base DN must be derived from configured domain |

### REQ-7: ALB Integration

| ID | Requirement |
| ---- | ------------- |
| REQ-7.1 | Ingress resources must use EKS Auto Mode ALB controller |
| REQ-7.2 | IngressClass must reference cluster-wide IngressClassParams |
| REQ-7.3 | ALB group name must be configurable (for sharing ALB across Ingresses) |
| REQ-7.4 | ACM certificate ARN must be configurable (from data source or variable) |
| REQ-7.5 | ALB must be internet-facing (not internal) |
| REQ-7.6 | ALB target type must be configurable (default: `ip`) |
| REQ-7.7 | HTTPS redirect must be enabled (HTTP to HTTPS) |

### REQ-8: DNS Integration

| ID | Requirement |
| ---- | ------------- |
| REQ-8.1 | Route53 A (alias) records must be created for phpldapadmin hostname |
| REQ-8.2 | Route53 A (alias) records must be created for ltb-passwd hostname |
| REQ-8.3 | DNS records must point to ALB DNS name |
| REQ-8.4 | DNS records must support cross-account deployment (State Account for Route53, Deployment Account for ALB) |

## Security Requirements

### SEC-1: Network Security

| ID | Requirement |
| ---- | ------------- |
| SEC-1.1 | LDAP service must not be exposed to public internet |
| SEC-1.2 | Only management UIs (PhpLdapAdmin, LTB-passwd) may be exposed via ALB |
| SEC-1.3 | All external traffic must use HTTPS with valid ACM certificates |
| SEC-1.4 | TLS termination must occur at ALB (not at pod level) |

### SEC-2: Credential Security

| ID | Requirement |
| ---- | ------------- |
| SEC-2.1 | Default passwords (e.g., `Not@SecurePassw0rd`) must not be used |
| SEC-2.2 | Passwords must meet minimum complexity requirements |
| SEC-2.3 | Passwords must be stored in Kubernetes Secrets (not in Helm values) |
| SEC-2.4 | Secrets must be created by Terraform (not by Helm chart) |

### SEC-3: Image Security

| ID | Requirement |
| ---- | ------------- |
| SEC-3.1 | Container images must be scanned for vulnerabilities |
| SEC-3.2 | Images must be pulled from trusted registry (ECR) |
| SEC-3.3 | Image pull secrets must be configurable if required |

## Integration Requirements

### INT-1: Terraform Integration

| ID | Requirement |
| ---- | ------------- |
| INT-1.1 | OpenLDAP must be deployed via Terraform module (`modules/openldap/`) |
| INT-1.2 | Module must create Kubernetes namespace |
| INT-1.3 | Module must create Kubernetes Secret for credentials |
| INT-1.4 | Module must deploy Helm chart with templated values |
| INT-1.5 | Module must accept ECR registry/repository from `backend_infra` remote state |
| INT-1.6 | Module must accept StorageClass name from `application_infra` remote state |
| INT-1.7 | Module must accept ALB configuration (IngressClass, certificate ARN) |

### INT-2: Infrastructure Dependencies

| ID | Requirement |
| ---- | ------------- |
| INT-2.1 | Deployment must depend on StorageClass resource |
| INT-2.2 | Deployment must depend on ALB module (IngressClass/IngressClassParams) |
| INT-2.3 | Deployment must depend on ECR repository existence |
| INT-2.4 | Route53 records must be created after ALB is provisioned |

### INT-3: ECR Image Mirroring

| ID | Requirement |
| ---- | ------------- |
| INT-3.1 | Image mirroring must execute automatically before Terraform operations |
| INT-3.2 | Mirroring script must support local deployment and GitHub Actions |
| INT-3.3 | Mirroring must handle cross-account access (State Account → Deployment Account) |
| INT-3.4 | Mirroring must verify image existence before pulling/pushing |
| INT-3.5 | Mirroring must clean up local images after pushing |

### INT-4: GitHub Repository Variables

| ID | Requirement |
| ---- | ------------- |
| INT-4.1 | `BACKEND_BUCKET_NAME` repository variable must be configured (S3 bucket name for Terraform state storage) |
| INT-4.2 | `APPLICATION_INFRA_PREFIX` repository variable must be configured (value: `application_infra_state/terraform.tfstate`) |
| INT-4.3 | Repository variables must be accessible to GitHub Actions workflows and local deployment scripts |
| INT-4.4 | State file key must use `APPLICATION_INFRA_PREFIX` to ensure isolation from application state |

## Non-Functional Requirements

### NFR-1: Availability

| ID | Requirement |
| ---- | ------------- |
| NFR-1.1 | OpenLDAP must support multi-master replication (default: 3 replicas) |
| NFR-1.2 | Data must persist across pod restarts |
| NFR-1.3 | Storage must support volume expansion if needed |

### NFR-2: Performance

| ID | Requirement |
| ---- | ------------- |
| NFR-2.1 | LDAP queries must respond within acceptable latency (< 100ms for simple queries) |
| NFR-2.2 | Storage must use EBS GP3 volumes for consistent performance |

### NFR-3: Maintainability

| ID | Requirement |
| ---- | ------------- |
| NFR-3.1 | Configuration must be templated via Terraform (not hardcoded) |
| NFR-3.2 | All sensitive values must be sourced from variables or secrets |
| NFR-3.3 | Helm values template must be version-controlled |

## Future Requirements

### FUT-1: Certificate Management

| ID | Requirement |
| ---- | ------------- |
| FUT-1.1 | OpenLDAP TLS certificates should be managed by cert-manager (future enhancement) |
| FUT-1.2 | Certificates should be automatically renewed |
| FUT-1.3 | Certificates should replace auto-generated self-signed certificates |

> [!NOTE]
>
> The cert-manager module exists in the codebase but is not currently used. This is a
> future enhancement requirement.

## Related Documentation

- [OPENLDAP-README.md](./OPENLDAP-README.md) - Technical reference for Helm chart configuration
- [PRD-ALB.md](./PRD-ALB.md) - ALB configuration requirements
- [PRD-DOMAIN.md](./PRD-DOMAIN.md) - Route53 and ACM certificate requirements
- [Application Infrastructure README](./README.md) - Complete infrastructure overview
