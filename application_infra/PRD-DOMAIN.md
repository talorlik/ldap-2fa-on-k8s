# Domain and DNS Requirements

## Overview

This document defines the requirements for domain management, DNS configuration,
and TLS certificate setup for the LDAP 2FA application infrastructure.

> [!NOTE]
>
> The current implementation uses **data sources** to reference existing Route53
> hosted zone and ACM certificate resources. The Route53 module exists but is
> commented out. If you want to create these resources via Terraform, uncomment
> the module and update the code accordingly.

## Functional Requirements

### REQ-1: Route53 Hosted Zone

| ID | Requirement |
| ---- | ------------- |
| REQ-1.1 | Route53 hosted zone must exist for the root domain |
| REQ-1.2 | Hosted zone can be in State Account (cross-account access supported) |
| REQ-1.3 | Hosted zone must be accessible via Terraform data source |
| REQ-1.4 | Name servers must be configurable at domain registrar |

### REQ-2: ACM Certificate

| ID | Requirement |
| ---- | ------------- |
| REQ-2.1 | ACM certificate must be Public ACM certificate (Amazon-issued) |
| REQ-2.2 | Certificate must be requested in Deployment Account |
| REQ-2.3 | Certificate must cover root domain and wildcard subdomains (e.g., `*.domain.com`) |
| REQ-2.4 | Certificate must be validated via DNS validation |
| REQ-2.5 | DNS validation records must be created in State Account Route53 hosted zone |
| REQ-2.6 | Certificate must be in `ISSUED` status before use |
| REQ-2.7 | Certificate must be in the same region as EKS cluster |
| REQ-2.8 | Certificate must be automatically renewed by ACM |

### REQ-3: Route53 DNS Records

| ID | Requirement |
| ---- | ------------- |
| REQ-3.1 | Route53 A (alias) records must be created for each subdomain |
| REQ-3.2 | DNS records must point to ALB DNS name |
| REQ-3.3 | DNS records must support cross-account deployment (State Account for Route53, Deployment Account for ALB) |
| REQ-3.4 | DNS records must be created after ALB is provisioned |
| REQ-3.5 | DNS records must use ALB zone ID mapping for proper alias configuration |

### REQ-4: Subdomain Configuration

| ID | Requirement |
| ---- | ------------- |
| REQ-4.1 | PhpLdapAdmin must be accessible via configurable hostname (e.g., `phpldapadmin.{domain}`) |
| REQ-4.2 | LTB-passwd must be accessible via configurable hostname (e.g., `passwd.{domain}`) |
| REQ-4.3 | 2FA application must be accessible via configurable hostname (e.g., `app.{domain}`) |
| REQ-4.4 | Hostnames must be configurable via Terraform variables |

## Security Requirements

### SEC-1: Certificate Security

| ID | Requirement |
| ---- | ------------- |
| SEC-1.1 | Certificates must be browser-trusted (Public ACM certificates) |
| SEC-1.2 | Certificate validation must use DNS validation (not email) |
| SEC-1.3 | Certificate private keys must be managed by AWS (not accessible) |

### SEC-2: DNS Security

| ID | Requirement |
| ---- | ------------- |
| SEC-2.1 | DNS records must use alias records (not CNAME) for ALB |
| SEC-2.2 | DNS updates must be atomic (create before destroy) |

## Integration Requirements

### INT-1: Terraform Integration

| ID | Requirement |
| ---- | ------------- |
| INT-1.1 | Route53 hosted zone must be accessible via data source |
| INT-1.2 | ACM certificate must be accessible via data source |
| INT-1.3 | Route53 record module must support cross-account access |
| INT-1.4 | Route53 record module must validate ALB exists before record creation |
| INT-1.5 | Route53 record module must support ALB zone ID mapping |

### INT-2: Cross-Account Access

| ID | Requirement |
| ---- | ------------- |
| INT-2.1 | Route53 hosted zone can be in State Account |
| INT-2.2 | ACM certificate must be in Deployment Account |
| INT-2.3 | DNS validation records must be created in State Account Route53 |
| INT-2.4 | Route53 records must be created in State Account |
| INT-2.5 | ALB must be in Deployment Account |

## Non-Functional Requirements

### NFR-1: Availability

| ID | Requirement |
| ---- | ------------- |
| NFR-1.1 | DNS records must be highly available |
| NFR-1.2 | Certificate renewal must not cause service interruption |

### NFR-2: Maintainability

| ID | Requirement |
| ---- | ------------- |
| NFR-2.1 | Domain configuration must be centralized in Terraform variables |
| NFR-2.2 | Certificate setup must be documented and repeatable |

## Related Documentation

For implementation details, setup instructions, and technical reference, see:

- [Route53 Record Module Documentation](modules/route53_record/README.md) - Implementation
guide and configuration examples
- [Cross-Account Access Documentation](./CROSS-ACCOUNT-ACCESS.md) - Public ACM certificate
setup instructions with step-by-step AWS CLI commands
- [Application Infrastructure README](./README.md) - Complete infrastructure overview

Below is a linear Terraform-centric setup.

## 1. Route53 hosted zone for `talorlik.com`

In `backend_infra`:

```hcl
resource "aws_route53_zone" "talo_ldap" {
  name = "talorlik.com"
}
```

If the domain is registered elsewhere, point the registrar's NS records at
`aws_route53_zone.talo_ldap.name_servers`.

## 2. ACM certificate with DNS validation

ALB needs an ACM cert in the same region as the ALB / EKS cluster.

> [!IMPORTANT]
>
> **Public ACM Certificate Architecture**: The current implementation uses
> **Public ACM certificates** (Amazon-issued) with DNS validation:
>
> - Public ACM certificates are requested in each deployment account
>   (development, production)
> - DNS validation records are created in Route53 hosted zone in the State Account
> - Certificates are stored in their respective deployment accounts (not State
>   Account)
> - This eliminates cross-account certificate access complexity
> - Certificates are automatically renewed by ACM (no manual intervention required)
> - Browser-trusted certificates (no security warnings)
>
> See [Public ACM Certificate Setup and DNS Validation](./CROSS-ACCOUNT-ACCESS.md#public-acm-certificate-setup-and-dns-validation)
> for detailed setup instructions with step-by-step AWS CLI commands.
