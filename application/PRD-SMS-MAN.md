# SMS OTP Management with Redis - Product Requirements Document

## Overview

This document defines the requirements for implementing Redis-based SMS OTP code
management to replace the current in-memory storage mechanism in the 2FA backend
application.

### Problem Statement

The current SMS OTP implementation in [`routes.py`](backend/src/app/api/routes.py)
uses in-memory Python dictionaries for storing verification codes:

```python
# Current implementation (problematic)
_sms_codes: dict[str, dict] = {}
# Structure: {username: {"code": "...", "expires_at": timestamp, "phone_number": "..."}}
```

This approach has several critical limitations:

| Problem | Impact |
| --------- | -------- |
| **Data loss on restart** | All pending OTP codes are lost when pods restart or scale |
| **No automatic cleanup** | Expired codes only cleaned when accessed, leading to memory growth |
| **Not horizontally scalable** | Each backend replica has its own in-memory store |
| **No code sharing** | User must hit the same pod that generated the code |

### Solution Overview

Deploy Redis as a centralized, TTL-aware cache for SMS OTP codes, enabling:

- Automatic expiration of codes via Redis TTL
- Shared state across all backend replicas
- Persistence across pod restarts (RDB snapshots)
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

## Technical Architecture

### Architecture Diagram

```text
┌───────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                         │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              twofa-backend namespace                    │  │
│  │                                                         │  │
│  │   ┌──────────────┐         ┌──────────────┐             │  │
│  │   │  Backend     │         │  Backend     │             │  │
│  │   │  Pod 1       │         │  Pod 2       │             │  │
│  │   │              │         │              │             │  │
│  │   │ redis-py     │         │ redis-py     │             │  │
│  │   └──────┬───────┘         └──────┬───────┘             │  │
│  │          │                        │                     │  │
│  └──────────┼────────────────────────┼─────────────────────┘  │
│             │                        │                        │
│             │    SETEX/GET/DEL       │                        │
│             │    (with TTL)          │                        │
│             └───────────┬────────────┘                        │
│                         │                                     │
│                         ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   redis namespace                       │  │
│  │                                                         │  │
│  │   ┌──────────────────────────────────────────────────┐  │  │
│  │   │              Redis Standalone                    │  │  │
│  │   │                                                  │  │  │
│  │   │  ┌─────────────────┐    ┌─────────────────────┐  │  │  │
│  │   │  │  Redis Master   │───▶│  PersistentVolume   │  │  │  │
│  │   │  │  (Port 6379)    │    │  (RDB Snapshots)    │  │  │  │
│  │   │  └─────────────────┘    └─────────────────────┘  │  │  │
│  │   │                                                  │  │  │
│  │   └──────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### Data Flow

```text
1. User requests SMS code
   └─▶ Backend receives request
       └─▶ Generate 6-digit code
           └─▶ SETEX sms_otp:{username} {ttl} {code_data}
               └─▶ Redis stores with automatic TTL expiration

2. User submits verification code
   └─▶ Backend receives login request
       └─▶ GET sms_otp:{username}
           ├─▶ Key exists: Validate code, DEL on success
           └─▶ Key expired/missing: Return error
```

### Redis Key Schema

| Key Pattern | Value | TTL | Description |
| ------------- | ------- | ----- | ------------- |
| `sms_otp:{username}` | JSON: `{"code": "123456", "phone_number": "+1..."}` | 300s (configurable) | SMS verification code |

## Redis Deployment Specifications

### Helm Chart Configuration

| Setting | Value | Rationale |
| --------- | ------- | ----------- |
| **Chart** | `bitnami/redis` | Official, well-maintained, production-ready |
| **Version** | Latest stable (19.x+) | Security patches, bug fixes |
| **Architecture** | Standalone | Sufficient for OTP cache, simpler operations |
| **Namespace** | `redis` | Dedicated namespace for isolation |

### Resource Requirements

| Resource | Request | Limit | Rationale |
| ---------- | --------- | ------- | ----------- |
| CPU | 100m | 500m | OTP operations are lightweight |
| Memory | 128Mi | 256Mi | Small dataset (active OTPs only) |

### Persistence Configuration

| Setting | Value | Rationale |
| --------- | ------- | ----------- |
| **Enabled** | `true` | Survive pod restarts |
| **Storage Class** | Existing EBS CSI class | Consistent with cluster storage |
| **Size** | 1Gi | OTP data is small |
| **RDB** | Enabled | Point-in-time snapshots |
| **AOF** | Disabled | Not needed for OTP cache |

### Network Configuration

| Setting | Value |
| --------- | ------- |
| **Service Type** | ClusterIP |
| **Port** | 6379 |
| **Service Name** | `redis-master.redis.svc.cluster.local` |

## Backend Code Changes

### New Files

| File | Purpose |
| ------ | --------- |
| `app/redis/__init__.py` | Redis module initialization |
| `app/redis/client.py` | Redis client wrapper for OTP operations |

### Modified Files

| File | Changes |
| ------ | --------- |
| [`app/config.py`](backend/src/app/config.py) | Add Redis configuration settings |
| [`app/api/routes.py`](backend/src/app/api/routes.py) | Replace `_sms_codes` dict with Redis calls |
| [`requirements.txt`](backend/src/app/requirements.txt) | Add `redis` package |

### Configuration Settings

Add to [`config.py`](backend/src/app/config.py):

```python
# Redis Configuration
redis_enabled: bool = os.getenv("REDIS_ENABLED", "false").lower() == "true"
redis_host: str = os.getenv("REDIS_HOST", "redis-master.redis.svc.cluster.local")
redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
redis_password: str = os.getenv("REDIS_PASSWORD", "")
redis_db: int = int(os.getenv("REDIS_DB", "0"))
redis_ssl: bool = os.getenv("REDIS_SSL", "false").lower() == "true"
redis_key_prefix: str = os.getenv("REDIS_KEY_PREFIX", "sms_otp:")
```

### Redis Client Interface

```python
class RedisOTPClient:
    """Redis client for SMS OTP operations."""

    def store_code(
        self,
        username: str,
        code: str,
        phone_number: str,
        ttl_seconds: int
    ) -> bool:
        """Store OTP code with automatic TTL expiration."""
        ...

    def get_code(self, username: str) -> Optional[dict]:
        """Retrieve OTP code data if not expired."""
        ...

    def delete_code(self, username: str) -> bool:
        """Delete OTP code after successful verification."""
        ...

    def code_exists(self, username: str) -> bool:
        """Check if valid OTP code exists for user."""
        ...
```

### Backward Compatibility

The implementation must support graceful fallback:

| Scenario | Behavior |
| ---------- | ---------- |
| `REDIS_ENABLED=true` | Use Redis for OTP storage |
| `REDIS_ENABLED=false` | Fall back to in-memory storage |
| Redis connection failure | Log error, return 503 Service Unavailable |

## Infrastructure Changes

### Directory Structure

```text
application/
├── modules/
│   └── redis/                    # New Terraform module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── helm/
│   └── redis-values.tpl.yaml     # Redis Helm values template
└── main.tf                       # Add Redis module invocation
```

### Terraform Module: Redis

#### Resources Created

| Resource | Description |
| ---------- | ------------- |
| `kubernetes_namespace` | Dedicated `redis` namespace |
| `kubernetes_secret` | Redis password secret (from GitHub Secrets) |
| `helm_release` | Bitnami Redis deployment |

> **Note**: The Redis password is **not** randomly generated. It is sourced from
> GitHub Secrets and passed through Terraform variables, consistent with the
> existing LDAP admin password pattern.

#### Module Inputs

| Variable | Type | Default | Description |
| ---------- | ------ | --------- | ------------- |
| `enable_redis` | bool | `false` | Enable Redis deployment |
| `namespace` | string | `"redis"` | Kubernetes namespace |
| `redis_version` | string | `"19.6.4"` | Bitnami Redis chart version |
| `storage_class_name` | string | `""` | Storage class for PVC |
| `storage_size` | string | `"1Gi"` | PVC size |
| `redis_password` | string | **required** | Redis password (from GitHub Secrets via TF_VAR) |
| `replica_count` | number | `0` | Number of replicas (0 for standalone) |

#### Module Outputs

| Output | Description |
| -------- | ------------- |
| `redis_host` | Redis service hostname |
| `redis_port` | Redis service port |
| `redis_password_secret_name` | Name of K8s secret containing password |
| `redis_password_secret_key` | Key in secret for password |

### Backend Helm Chart Updates

Add to [`values.yaml`](backend/helm/ldap-2fa-backend/values.yaml):

```yaml
# Redis Configuration
redis:
  # Enable Redis for SMS OTP storage
  enabled: false
  # Redis service hostname
  host: "redis-master.redis.svc.cluster.local"
  # Redis service port
  port: 6379
  # Redis database number
  db: 0
  # Enable SSL/TLS
  ssl: false
  # Key prefix for OTP storage
  keyPrefix: "sms_otp:"
  # External secret for Redis password
  existingSecret:
    name: ""
    key: "redis-password"
```

### Network Policy Updates

Add to [`modules/network-policies/`](modules/network-policies/):

```yaml
# Allow backend pods to connect to Redis
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-redis
  namespace: redis
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: redis
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: twofa-backend
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: ldap-2fa-backend
      ports:
        - protocol: TCP
          port: 6379
```

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
> For complete secrets setup instructions, see [Secrets Requirements](SECRETS_REQUIREMENTS.md).

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

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `REDIS_ENABLED` | `false` | Enable Redis for OTP storage |
| `REDIS_HOST` | `redis-master.redis.svc.cluster.local` | Redis hostname |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_PASSWORD` | `` | Redis password (from Secret) |
| `REDIS_DB` | `0` | Redis database number |
| `REDIS_SSL` | `false` | Enable SSL/TLS |
| `REDIS_KEY_PREFIX` | `sms_otp:` | Key prefix for OTP storage |

### Terraform Variables

Add to [`variables.tf`](variables.tf):

```hcl
variable "enable_redis" {
  description = "Enable Redis deployment for SMS OTP storage"
  type        = bool
  default     = false
}

variable "redis_password" {
  description = "Redis authentication password (from GitHub Secrets via TF_VAR_redis_password environment variable, sourced from TF_VAR_REDIS_PASSWORD secret)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.enable_redis == false || length(var.redis_password) >= 8
    error_message = "Redis password must be at least 8 characters when Redis is enabled."
  }
}

variable "redis_storage_size" {
  description = "Redis PVC storage size"
  type        = string
  default     = "1Gi"
}

variable "redis_chart_version" {
  description = "Bitnami Redis Helm chart version"
  type        = string
  default     = "19.6.4"
}
```

### GitHub Actions Workflow Updates

Update [`.github/workflows/application_infra_provisioning.yaml`](.github/workflows/application_infra_provisioning.yaml):

```yaml
jobs:
  InfraProvision:
    # ... existing configuration ...
    env:
      AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
      # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
      TF_VAR_openldap_admin_password: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
      TF_VAR_openldap_config_password: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
      # Add Redis password from GitHub Secrets
      TF_VAR_redis_password: ${{ secrets.TF_VAR_REDIS_PASSWORD }}
```

### Required GitHub Secrets

> [!NOTE]
>
> See [Secrets Requirements](SECRETS_REQUIREMENTS.md) for complete setup instructions.

| Secret | Purpose | Requirements |
| -------- | --------- | -------------- |
| `TF_VAR_REDIS_PASSWORD` | Redis authentication | Min 8 chars, alphanumeric + special (exported as `TF_VAR_redis_password`) |

### Password Generation Recommendation

Generate a secure password using:

```bash
# Option 1: OpenSSL
openssl rand -base64 24

# Option 2: Python
python3 -c "import secrets; print(secrets.token_urlsafe(24))"

# Option 3: pwgen (if installed)
pwgen -s 24 1
```

## Testing Strategy

### Unit Tests

| Test Case | Description |
| ----------- | ------------- |
| `test_store_code` | Verify code stored with correct TTL |
| `test_get_code_valid` | Retrieve valid (non-expired) code |
| `test_get_code_expired` | Verify expired code returns None |
| `test_delete_code` | Verify code deletion |
| `test_fallback_inmemory` | Verify fallback when Redis disabled |
| `test_connection_failure` | Verify graceful handling of Redis failure |

### Integration Tests

| Test Case | Description |
| ----------- | ------------- |
| `test_sms_enrollment_redis` | Full enrollment flow with Redis |
| `test_sms_login_redis` | Full login flow with Redis |
| `test_code_expiration` | Verify automatic TTL expiration |
| `test_multi_replica` | Verify code sharing across pods |

### Manual Verification

| Step | Expected Result |
| ------ | ----------------- |
| 1. Deploy Redis via Terraform | `helm_release.redis` successful |
| 2. Verify Redis pod running | `kubectl get pods -n redis` shows Ready |
| 3. Test Redis connectivity | `redis-cli ping` returns PONG |
| 4. Enroll user with SMS | Code stored in Redis |
| 5. Wait for TTL expiration | Code automatically deleted |
| 6. Login with expired code | Returns "code expired" error |
| 7. Restart backend pod | Pending codes preserved |
| 8. Scale backend to 2 replicas | Code accessible from both pods |

## Rollout Plan

### Phase 0: GitHub Secrets Setup

> [!NOTE]
>
> See [Secrets Requirements](SECRETS_REQUIREMENTS.md) for complete secrets
> configuration instructions.

1. Generate a secure Redis password (minimum 8 characters)
2. Add `TF_VAR_REDIS_PASSWORD` to GitHub repository secrets (or AWS Secrets Manager
for local scripts)
3. Update GitHub Actions workflow to include the new secret

### Phase 1: Infrastructure (No Application Changes)

1. Create Redis Terraform module
2. Update `.github/workflows/application_infra_provisioning.yaml`
3. Deploy Redis to cluster with `enable_redis = true`
4. Verify Redis pod health and connectivity
5. Create network policies

### Phase 2: Backend Changes (Feature Flag)

1. Add Redis client code to backend
2. Add `REDIS_ENABLED` feature flag (default: false)
3. Deploy backend with Redis disabled
4. Verify no regression in existing functionality

### Phase 3: Enable Redis

1. Update backend Helm values: `redis.enabled = true`
2. Deploy backend with Redis enabled
3. Monitor logs for Redis connection success
4. Verify SMS OTP flow end-to-end

### Phase 4: Cleanup

1. Remove in-memory storage code (optional)
2. Update documentation
3. Close tracking issues

## Dependencies

### Prerequisites

| Dependency | Status | Notes |
| ------------ | -------- | ------- |
| EKS cluster | Existing | Auto Mode enabled |
| EBS CSI driver | Existing | For PersistentVolume |
| StorageClass | Existing | GP3 encrypted |
| SMS 2FA enabled | Existing | `enable_sms_2fa = true` |

### New Dependencies

| Dependency | Version | Purpose |
| ------------ | --------- | --------- |
| Bitnami Redis Helm chart | 19.6.4+ | Redis deployment |
| `redis` Python package | 5.0.0+ | Redis client library |

## Implementation Checklist

### GitHub Secrets Setup

> [!NOTE]
>
> See [Secrets Requirements](SECRETS_REQUIREMENTS.md) for complete setup instructions.

- [ ] Generate secure Redis password (min 8 characters)
- [ ] Add `TF_VAR_REDIS_PASSWORD` to GitHub repository secrets
(or AWS Secrets Manager for local scripts)
- [ ] Verify secret is accessible in Actions workflow

### Infrastructure

- [ ] Create `application/modules/redis/` Terraform module
  - [ ] `main.tf` with namespace, kubernetes_secret, and helm_release
  - [ ] `variables.tf` with module inputs (including `redis_password`)
  - [ ] `outputs.tf` with connection details
  - [ ] `README.md` with usage documentation
- [ ] Create `application/helm/redis-values.tpl.yaml` template
- [ ] Add Redis module invocation to `application/main.tf`
- [ ] Add Redis variables to `application/variables.tf`
- [ ] Update `.github/workflows/application_infra_provisioning.yaml` with `TF_VAR_REDIS_PASSWORD`
- [ ] Update network policies for Redis access

### Backend Application

- [ ] Add `redis` to `requirements.txt`
- [ ] Create `app/redis/__init__.py`
- [ ] Create `app/redis/client.py` with RedisOTPClient
- [ ] Add Redis configuration to `app/config.py`
- [ ] Update `app/api/routes.py` to use Redis client
- [ ] Add Redis environment variables to ConfigMap template
- [ ] Add Redis secret reference to deployment template
- [ ] Update `values.yaml` with Redis configuration section

### Testing

- [ ] Write unit tests for RedisOTPClient
- [ ] Write integration tests for SMS flow with Redis
- [ ] Manual end-to-end verification
- [ ] Multi-replica verification

### Documentation

- [ ] Update `README.md` with Redis configuration
- [ ] Update `CHANGELOG.md` with feature entry
- [ ] Add Redis troubleshooting guide

## Appendix

### Redis CLI Commands for Debugging

```bash
# Connect to Redis
kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD

# View all OTP keys
KEYS sms_otp:*

# Get specific OTP data
GET sms_otp:username

# Check TTL remaining
TTL sms_otp:username

# Manually delete a key
DEL sms_otp:username

# Monitor real-time commands
MONITOR
```

### Helm Values Reference (Bitnami Redis)

```yaml
# Minimal standalone configuration with external secret
architecture: standalone

auth:
  enabled: true
  # Reference Kubernetes secret created by Terraform
  # (password sourced from GitHub Secrets → TF_VAR_redis_password environment variable)
  existingSecret: "redis-secret"
  existingSecretPasswordKey: "redis-password"

master:
  persistence:
    enabled: true
    storageClass: "${storage_class_name}"
    size: 1Gi

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

  securityContext:
    enabled: true
    runAsUser: 1001
    runAsNonRoot: true

replica:
  replicaCount: 0  # Standalone mode

metrics:
  enabled: false  # Enable for production monitoring
```

### Comparison with LDAP Secret Pattern

| Aspect | LDAP Admin Password | Redis Password |
| -------- | --------------------- | ---------------- |
| GitHub Secret | `TF_VAR_OPENLDAP_ADMIN_PASSWORD` | `TF_VAR_REDIS_PASSWORD` |
| Terraform Variable | `var.openldap_admin_password` | `var.redis_password` |
| K8s Secret Name | `ldap-admin-secret` | `redis-secret` |
| K8s Secret Key | `LDAP_ADMIN_PASSWORD` | `redis-password` |
| Helm Reference | `externalSecret.secretName` | `auth.existingSecret` |
