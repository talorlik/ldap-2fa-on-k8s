# SMS OTP Management with Redis - Product Requirements Document

## Overview

This document defines the requirements for implementing Redis-based SMS OTP code
management to replace the current in-memory storage mechanism in the 2FA backend
application.

## Problem Statement

The SMS OTP implementation must address the following limitations of in-memory storage:

| Problem | Impact |
| --------- | -------- |
| **Data loss on restart** | All pending OTP codes are lost when pods restart or scale |
| **No automatic cleanup** | Expired codes only cleaned when accessed, leading to memory growth |
| **Not horizontally scalable** | Each backend replica has its own in-memory store |
| **No code sharing** | User must hit the same pod that generated the code |

## Solution Requirements

The SMS OTP storage solution must provide:

- Automatic expiration of codes via TTL
- Shared state across all backend replicas
- Persistence across pod restarts
- Native support for atomic operations

## Goals and Non-Goals

### Goals

| ID | Goal |
| ---- | ------ |
| G-01 | Deploy Bitnami Redis Helm chart via Terraform |
| G-02 | Replace in-memory `_sms_codes` dict with Redis client |
| G-03 | Leverage Redis TTL for automatic code expiration |
| G-04 | Enable horizontal scaling of backend pods |
| G-05 | Maintain data across pod restarts via persistence |
| G-06 | Secure Redis with password authentication |
| G-07 | Restrict network access to backend pods only |

### Non-Goals

| ID | Non-Goal |
| ---- | ---------- |
| NG-01 | High availability Redis (Sentinel/Cluster) - standalone is sufficient for OTP cache |
| NG-02 | Migrating TOTP secrets to Redis - they remain in-memory (stateless by design) |
| NG-03 | Redis as a general-purpose cache - scoped to SMS OTP only |
| NG-04 | External Redis access - internal cluster use only |

## Functional Requirements

### REQ-1: Storage Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-1.1 | SMS OTP codes must be stored in a centralized cache |
| REQ-1.2 | Codes must automatically expire after configurable TTL |
| REQ-1.3 | Codes must be accessible from all backend replicas |
| REQ-1.4 | Codes must persist across pod restarts |
| REQ-1.5 | Storage must support atomic operations |

### REQ-2: Key Schema Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-2.1 | Keys must use a consistent naming pattern (e.g., `sms_otp:{username}`) |
| REQ-2.2 | Values must include code and phone number |
| REQ-2.3 | TTL must be configurable (default: 300 seconds) |

### REQ-3: Redis Deployment Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-3.1 | Redis must be deployed via Helm chart |
| REQ-3.2 | Redis must use standalone architecture (no HA required) |
| REQ-3.3 | Redis must be deployed in dedicated namespace |
| REQ-3.4 | Redis must use ECR images (not Docker Hub) |
| REQ-3.5 | Redis must have persistent storage enabled |
| REQ-3.6 | Redis must use ClusterIP service type (not exposed externally) |
| REQ-3.7 | Redis must require password authentication |

### REQ-4: Backend Integration Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-4.1 | Backend must support Redis client for OTP storage |
| REQ-4.2 | Backend must support graceful fallback to in-memory storage |
| REQ-4.3 | Backend must handle Redis connection failures gracefully |
| REQ-4.4 | Backend must support configurable Redis connection settings |
| REQ-4.5 | Backend must support feature flag to enable/disable Redis |

### REQ-5: Infrastructure Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-5.1 | Redis must be deployed via Terraform module |
| REQ-5.2 | Redis password must be sourced from GitHub Secrets or AWS Secrets Manager |
| REQ-5.3 | Redis password must be stored in Kubernetes Secret |
| REQ-5.4 | Network policies must restrict Redis access to backend pods only |
| REQ-5.5 | Backend Helm chart must support Redis configuration |

## Security Requirements

| ID | Requirement | Implementation |
| ---- | ------------- | ---------------- |
| SEC-R01 | Redis must require password authentication | `auth.enabled=true` in Helm values |
| SEC-R02 | Redis password stored in Kubernetes Secret | `kubernetes_secret` resource via Terraform |
| SEC-R03 | Redis password sourced from GitHub Secrets | `TF_VAR_redis_password` environment variable (from GitHub Secret `TF_VAR_REDIS_PASSWORD`) |
| SEC-R04 | Redis not exposed outside cluster | `service.type=ClusterIP` |
| SEC-R05 | Network policy restricts access to backend only | NetworkPolicy with namespace/pod selector |
| SEC-R06 | Redis runs as non-root user | `securityContext` in Helm values |
| SEC-R07 | No public Ingress for Redis | No Ingress resource created |
| SEC-R08 | TLS for Redis connections (optional) | `tls.enabled=true` if required |

### Secret Management Flow

The Redis password follows the same pattern as the LDAP admin password:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                            Secret Management Flow                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  GitHub Secrets              GitHub Actions            Terraform             │
│  ┌──────────────────┐       ┌──────────────────┐      ┌──────────────────┐   │
│  │ TF_VAR_REDIS_    │──────▶│ env:             │─────▶│ var.redis_       │   │
│  │ PASSWORD         │       │   TF_VAR_redis_  │      │ password         │   │
│  │                  │       │   password       │      │                  │   │
│  └──────────────────┘       └──────────────────┘      └────────┬─────────┘   │
│                                                                 │            │
│                                                                 ▼            │
│  Kubernetes                  Bitnami Redis Helm        Terraform K8s Secret  │
│  ┌──────────────────┐       ┌──────────────────┐      ┌──────────────────┐   │
│  │ Backend Pod      │       │ auth:            │      │ kubernetes_      │   │
│  │                  │       │   existingSecret:│◀─────│ secret.redis_    │   │
│  │ REDIS_PASSWORD   │◀──────│     redis-secret │      │ password         │   │
│  │ (from secret)    │       │                  │      │                  │   │
│  └──────────────────┘       └──────────────────┘      └──────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### GitHub Secrets Configuration

> [!NOTE]
>
> For complete secrets setup instructions, see [Secrets Requirements](../SECRETS_REQUIREMENTS.md).

Add the following secret to your GitHub repository:

| Secret Name | Description | Example |
| ------------- | ------------- | --------- |
| `TF_VAR_REDIS_PASSWORD` | Redis authentication password | Strong password (min 8 chars, exported as `TF_VAR_redis_password`) |

### Terraform Secret Resource

```hcl
# Create Kubernetes secret for Redis password
resource "kubernetes_secret" "redis_password" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
  }

  data = {
    "redis-password" = var.redis_password
  }

  type = "Opaque"
}
```

### Bitnami Redis Helm Configuration

```yaml
auth:
  enabled: true
  existingSecret: "redis-secret"
  existingSecretPasswordKey: "redis-password"
```

### Backend Deployment Secret Reference

```yaml
# In deployment.yaml - reference the same secret
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-secret
      key: redis-password
```

### REQ-6: Configuration Requirements

| ID | Requirement |
| ---- | ------------- |
| REQ-6.1 | Redis connection settings must be configurable via environment variables |
| REQ-6.2 | Redis password must be sourced from Kubernetes Secret |
| REQ-6.3 | Redis feature flag must be configurable (enable/disable) |
| REQ-6.4 | Redis password must meet minimum complexity requirements (8+ characters) |

### REQ-7: Dependencies

| ID | Requirement |
| ---- | ------------- |
| REQ-7.1 | EKS cluster with Auto Mode must be deployed |
| REQ-7.2 | EBS CSI driver must be available |
| REQ-7.3 | StorageClass must exist for persistent storage |
| REQ-7.4 | SMS 2FA must be enabled in application configuration |

## Related Documentation

For implementation details, configuration examples, and technical reference, see:

- [Redis Module Documentation](modules/redis/README.md) - Implementation guide and configuration examples
- [Application README](./README.md) - Complete application overview
- [Secrets Requirements](../SECRETS_REQUIREMENTS.md) - Secrets configuration instructions
