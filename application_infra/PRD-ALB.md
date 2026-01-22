# Application Load Balancer (ALB) Requirements

## Overview

This document defines the requirements for deploying a single internet-facing
Application Load Balancer (ALB) on EKS to serve multiple applications via
host-based routing.

## Functional Requirements

### REQ-1: ALB Architecture

| ID | Requirement |
| ---- | ------------- |
| REQ-1.1 | ALB must be internet-facing (not internal) |
| REQ-1.2 | ALB must support HTTPS on port 443 |
| REQ-1.3 | ALB must use ACM certificate for TLS termination |
| REQ-1.4 | ALB must support multiple hostnames via host-based routing |
| REQ-1.5 | Multiple Ingresses must share a single ALB via IngressGroup |
| REQ-1.6 | ALB must be managed by EKS Auto Mode (not AWS Load Balancer Controller) |

### REQ-2: EKS Auto Mode Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-2.1 | ALB must use EKS Auto Mode built-in load balancer driver |
| REQ-2.2 | IngressClass must reference `eks.amazonaws.com/alb` controller |
| REQ-2.3 | IngressClassParams must be used for cluster-wide ALB configuration |
| REQ-2.4 | IAM permissions must be handled automatically by EKS Auto Mode |

### REQ-3: IngressClass Configuration

| ID | Requirement |
| ---- | ------------- |
| REQ-3.1 | IngressClass must be created at cluster level |
| REQ-3.2 | IngressClass must reference IngressClassParams for ALB defaults |
| REQ-3.3 | IngressClass can be set as default (optional) |

### REQ-4: IngressClassParams Configuration

| ID | Requirement |
| ---- | ------------- |
| REQ-4.1 | IngressClassParams must define cluster-wide ALB defaults |
| REQ-4.2 | IngressClassParams must support `scheme` (internet-facing/internal) |
| REQ-4.3 | IngressClassParams must support `ipAddressType` (ipv4/dualstack) |
| REQ-4.4 | IngressClassParams must support `group.name` (ALB group name) |
| REQ-4.5 | IngressClassParams must support `certificateARNs` (ACM certificate ARNs) |

### REQ-5: Ingress Annotations

| ID | Requirement |
| ---- | ------------- |
| REQ-5.1 | Each Ingress must specify per-Ingress settings via annotations |
| REQ-5.2 | `load-balancer-name` annotation must be supported (max 32 characters) |
| REQ-5.3 | `target-type` annotation must be supported (ip or instance) |
| REQ-5.4 | `listen-ports` annotation must support HTTP and HTTPS ports |
| REQ-5.5 | `ssl-redirect` annotation must support HTTPS redirect configuration |
| REQ-5.6 | `group.name` and `certificate-arn` must NOT be in annotations (configured in IngressClassParams) |

### REQ-6: Certificate Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-6.1 | ACM certificate must be Public ACM certificate (Amazon-issued) |
| REQ-6.2 | Certificate must be requested in Deployment Account |
| REQ-6.3 | Certificate must be validated via DNS records in State Account Route53 |
| REQ-6.4 | Certificate must be automatically renewed by ACM |
| REQ-6.5 | Certificate must cover root domain and wildcard subdomains (e.g., `*.domain.com`) |

### REQ-7: Multi-Ingress Support

| ID | Requirement |
| ---- | ------------- |
| REQ-7.1 | Multiple Ingresses must share single ALB via `group.name` |
| REQ-7.2 | Each Ingress must define its own routing rules (hosts, paths) |
| REQ-7.3 | All Ingresses using same IngressClass must inherit IngressClassParams defaults |

## Security Requirements

### SEC-1: Network Security

| ID | Requirement |
| ---- | ------------- |
| SEC-1.1 | ALB must terminate TLS at load balancer (not at pod level) |
| SEC-1.2 | HTTP traffic must redirect to HTTPS |
| SEC-1.3 | ALB must use secure SSL policy |

## Integration Requirements

### INT-1: Terraform Integration

| ID | Requirement |
| ---- | ------------- |
| INT-1.1 | ALB module must create IngressClass resource |
| INT-1.2 | ALB module must create IngressClassParams resource |
| INT-1.3 | ALB module must accept ACM certificate ARN as input |
| INT-1.4 | ALB module must accept ALB group name as input |
| INT-1.5 | ALB module must accept ALB scheme and IP address type as inputs |

## Non-Functional Requirements

### NFR-1: Performance

| ID | Requirement |
| ---- | ------------- |
| NFR-1.1 | ALB must support IP target type for direct pod targeting |
| NFR-1.2 | ALB must handle multiple concurrent connections |

### NFR-2: Maintainability

| ID | Requirement |
| ---- | ------------- |
| NFR-2.1 | ALB configuration must be centralized in IngressClassParams |
| NFR-2.2 | Per-Ingress settings must be minimal and clearly documented |

## Related Documentation

For implementation details, configuration examples, and technical reference, see:

- [ALB Module Documentation](modules/alb/README.md) - Implementation guide and
configuration examples
- [Application Infrastructure README](./README.md) - Complete infrastructure overview
- [Cross-Account Access Documentation](./CROSS-ACCOUNT-ACCESS.md) - Certificate
setup instructions
