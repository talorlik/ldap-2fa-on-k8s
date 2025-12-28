# OpenLDAP Module

This module deploys OpenLDAP Stack HA using Helm, including phpLDAPadmin and
ltb-passwd web interfaces, with ALB ingress and Route53 DNS records.

## Features

- **OpenLDAP Stack HA**: Deploys OpenLDAP Stack HA Helm chart with multi-master
replication (3 replicas for high availability)
- **PhpLdapAdmin**: Web-based LDAP administration interface accessible via ALB
- **LTB-passwd**: Self-service password management UI accessible via ALB
- **Internal LDAP Service**: ClusterIP service (not exposed externally) for
secure cluster-internal access
- **Persistent Storage**: EBS-backed persistent storage for LDAP data
- **TLS Support**: TLS enabled with auto-generated self-signed certificates from
the osixia/openldap image
- **Network Policies**: Optionally applies network policies for secure inter-pod
communication
- **Route53 Integration**: Creates DNS records pointing to ALB for public access

## Usage

```hcl
module "openldap" {
  source = "./modules/openldap"

  env    = var.env
  region = var.region
  prefix = var.prefix

  app_name              = local.app_name  # Computed in main.tf as prefix-region-app_name-env
  openldap_ldap_domain  = var.openldap_ldap_domain
  openldap_admin_password = var.openldap_admin_password
  openldap_config_password = var.openldap_config_password
  storage_class_name    = local.storage_class_name

  phpldapadmin_host = var.phpldapadmin_host
  ltb_passwd_host   = var.ltb_passwd_host

  use_alb                = var.use_alb
  ingress_class_name     = module.alb[0].ingress_class_name
  alb_load_balancer_name = local.alb_load_balancer_name
  alb_target_type        = var.alb_target_type
  acm_cert_arn           = data.aws_acm_certificate.this.arn

  route53_zone_id = data.aws_route53_zone.this.zone_id
  alb_zone_id     = var.alb_zone_id  # Computed in main.tf from region mapping

  tags = local.tags

  depends_on = [
    kubernetes_storage_class_v1.this,
    module.alb,
  ]
}
```

## Requirements

- Kubernetes cluster with Helm provider configured
- ALB Ingress Controller installed (if using ALB)
- Route53 hosted zone
- ACM certificate
- StorageClass for PVCs

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| app_name | Full application name (computed in parent module as prefix-region-app_name-env) | `string` | n/a | yes |
| openldap_ldap_domain | OpenLDAP domain (e.g., ldap.talorlik.internal) | `string` | n/a | yes |
| openldap_admin_password | OpenLDAP admin password | `string` | n/a | yes |
| openldap_config_password | OpenLDAP config password | `string` | n/a | yes |
| storage_class_name | Name of the Kubernetes StorageClass to use for OpenLDAP PVC | `string` | n/a | yes |
| phpldapadmin_host | Hostname for phpLDAPadmin ingress | `string` | n/a | yes |
| ltb_passwd_host | Hostname for ltb-passwd ingress | `string` | n/a | yes |
| acm_cert_arn | ARN of the ACM certificate for HTTPS | `string` | n/a | yes |
| route53_zone_id | Route53 hosted zone ID for creating DNS records | `string` | n/a | yes |
| alb_load_balancer_name | Custom name for the AWS ALB | `string` | n/a | yes |
| openldap_secret_name | Name of the Kubernetes secret for OpenLDAP passwords | `string` | `"openldap-secret"` | no |
| namespace | Kubernetes namespace for OpenLDAP | `string` | `"ldap"` | no |
| use_alb | Whether to use ALB for ingress | `bool` | `true` | no |
| ingress_class_name | Name of the IngressClass for ALB | `string` | `null` | no |
| alb_target_type | ALB target type: ip or instance | `string` | `"ip"` | no |
| alb_zone_id | ALB canonical hosted zone ID for Route53 alias records | `string` | n/a | yes |
| helm_chart_version | OpenLDAP Helm chart version | `string` | `"4.0.1"` | no |
| helm_chart_repository | Helm chart repository URL | `string` | `"https://jp-gouin.github.io/helm-openldap"` | no |
| helm_chart_name | Helm chart name | `string` | `"openldap-stack-ha"` | no |
| helm_release_name | Helm release name | `string` | `"openldap-stack-ha"` | no |
| values_template_path | Path to the OpenLDAP values template file | `string` | `null` | no |
| enable_network_policies | Whether to enable network policies for the OpenLDAP namespace | `bool` | `true` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ------ | ------------- |
| namespace | Kubernetes namespace for OpenLDAP |
| secret_name | Name of the Kubernetes secret for OpenLDAP passwords |
| helm_release_name | Name of the Helm release |
| phpldapadmin_ingress_hostname | Hostname from phpLDAPadmin ingress (ALB DNS name) |
| ltb_passwd_ingress_hostname | Hostname from ltb-passwd ingress (ALB DNS name) |
| alb_dns_name | ALB DNS name (from either ingress) |
| phpldapadmin_route53_record_name | Route53 record name for phpLDAPadmin |
| ltb_passwd_route53_record_name | Route53 record name for ltb-passwd |

## Dependencies

- `kubernetes_storage_class_v1` - StorageClass for PVCs
- `module.alb` - ALB module for ingress (if using ALB)
- `data.aws_route53_zone` - Route53 hosted zone
- `data.aws_acm_certificate` - ACM certificate

## High Availability Configuration

The OpenLDAP Stack HA deployment includes:

- **Multi-Master Replication**: 3 replicas configured for high availability
- **StatefulSet**: Each replica has its own persistent volume for data durability
- **Automatic Failover**: If one replica fails, others continue serving requests
- **Data Consistency**: Multi-master replication ensures data consistency across
replicas

## TLS Configuration

TLS is enabled for secure LDAP communication:

- **Certificate Source**: Auto-generated self-signed certificates by the
osixia/openldap image
- **Certificate Location**: Certificates are stored in `/container/service/slapd/assets/certs/`
within the container
- **Certificate Files**: `ldap.crt`, `ldap.key`, and `ca.crt` (auto-generated on
first startup if they don't exist)
- **LDAP Ports**:
  - Port 389: LDAP (unencrypted, for internal use)
  - Port 636: LDAPS (encrypted, preferred for secure communication)
- **TLS Enforcement**: Configurable via Helm values (`LDAP_TLS_ENFORCE`,
default: `false` to allow both LDAP and LDAPS)

## Storage Configuration

- **StorageClass**: Uses the StorageClass created by the application infrastructure
- **Storage Size**: 8Gi per replica (configurable in Helm values)
- **Access Mode**: ReadWriteOnce (each replica has its own volume)
- **Volume Binding**: WaitForFirstConsumer (volume created when pod is scheduled)

## Internal LDAP Service

The LDAP service uses ClusterIP (not LoadBalancer or NodePort) to:

- Keep LDAP ports strictly internal to the cluster
- Prevent external access to LDAP
- Only allow access from pods within the cluster
- Follow security best practices for sensitive services

Services in other namespaces can access the LDAP service using:

- Service DNS: `openldap-stack-ha.ldap.svc.cluster.local`
- Port 636 (LDAPS) for encrypted communication

## Notes

- The module uses the osixia/openldap image (version 1.5.0) instead of the default
Bitnami image
- TLS is enabled with auto-generated self-signed certificates from the
osixia/openldap image (generated on first startup)
- Network policies are applied by default to secure inter-pod communication
- The module creates Route53 alias records pointing to the ALB for public access
- Chart version: 4.0.1 from `https://jp-gouin.github.io/helm-openldap`
- Helm release name: `openldap-stack-ha` (configurable)
