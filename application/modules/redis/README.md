# Redis Module

Deploys Redis using the Bitnami Helm chart for SMS OTP code storage in the
LDAP 2FA application.

## Purpose

This module replaces the in-memory SMS OTP storage with Redis, providing:

- **TTL-based expiration**: Automatic cleanup of expired OTP codes
- **Shared state**: OTP codes accessible from any backend replica
- **Persistence**: Data survives pod restarts via RDB snapshots
- **Horizontal scaling**: Enable multiple backend replicas

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              twofa-backend namespace                        │ │
│  │                                                             │ │
│  │   ┌──────────────┐         ┌──────────────┐                 │ │
│  │   │  Backend     │         │  Backend     │                 │ │
│  │   │  Pod 1       │         │  Pod 2       │                 │ │
│  │   │              │         │              │                 │ │
│  │   │ redis-py     │         │ redis-py     │                 │ │
│  │   └──────┬───────┘         └──────┬───────┘                 │ │
│  │          │                        │                         │ │
│  └──────────┼────────────────────────┼─────────────────────────┘ │
│             │                        │                           │
│             │    SETEX/GET/DEL       │                           │
│             │    (with TTL)          │                           │
│             └───────────┬────────────┘                           │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   redis namespace                           │ │
│  │                                                             │ │
│  │   ┌──────────────────────────────────────────────────┐      │ │
│  │   │              Redis Standalone                     │      │ │
│  │   │                                                   │      │ │
│  │   │  ┌─────────────────┐    ┌─────────────────────┐  │      │ │
│  │   │  │  Redis Master   │───▶│  PersistentVolume   │  │      │ │
│  │   │  │  (Port 6379)    │    │  (RDB Snapshots)    │  │      │ │
│  │   │  └─────────────────┘    └─────────────────────┘  │      │ │
│  │   │                                                   │      │ │
│  │   └──────────────────────────────────────────────────┘      │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "redis" {
  source = "./modules/redis"

  count = var.enable_redis ? 1 : 0

  env    = var.env
  region = var.region
  prefix = var.prefix

  enable_redis       = var.enable_redis
  namespace          = "redis"
  redis_password     = var.redis_password
  storage_class_name = local.storage_class_name
  storage_size       = var.redis_storage_size
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes | >= 2.0 |
| helm | >= 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| enable_redis | Enable Redis deployment | `bool` | `false` | no |
| namespace | Kubernetes namespace | `string` | `"redis"` | no |
| secret_name | Name of K8s secret for password | `string` | `"redis-secret"` | no |
| redis_password | Redis password (min 16 chars) | `string` | n/a | yes |
| chart_version | Bitnami chart version | `string` | `"19.6.4"` | no |
| storage_class_name | Storage class for PVC | `string` | `""` | no |
| storage_size | Storage size for PVC | `string` | `"1Gi"` | no |
| persistence_enabled | Enable data persistence | `bool` | `true` | no |
| resources | CPU/memory limits/requests | `object` | See variables.tf | no |
| metrics_enabled | Enable Prometheus metrics | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| redis_enabled | Whether Redis is enabled |
| redis_host | Redis service hostname |
| redis_port | Redis service port |
| redis_namespace | Namespace where Redis is deployed |
| redis_password_secret_name | Name of password secret |
| redis_password_secret_key | Key in secret for password |
| redis_connection_url | Connection URL (without password) |

## Security

- **Authentication**: Password authentication required (`auth.enabled=true`)
- **Secret Management**: Password from GitHub Secrets via `TF_VAR_redis_password`
- **Network**: ClusterIP service (not exposed externally)
- **Container Security**: Runs as non-root user (UID 1001)
- **Network Policy**: Should be combined with network policies to restrict access

## Redis Key Schema

| Key Pattern | Value | TTL | Description |
|-------------|-------|-----|-------------|
| `sms_otp:{username}` | JSON data | 300s | SMS verification code |

Example value:
```json
{
  "code": "123456",
  "phone_number": "+1234567890"
}
```

## Debugging

```bash
# Connect to Redis CLI
kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD

# View all OTP keys
KEYS sms_otp:*

# Get specific OTP data
GET sms_otp:username

# Check TTL remaining
TTL sms_otp:username

# Monitor real-time commands
MONITOR
```

## Related Files

- `application/backend/src/app/redis/client.py` - Python Redis client
- `application/backend/helm/ldap-2fa-backend/values.yaml` - Redis config values
- `application/modules/network-policies/main.tf` - Network policies
