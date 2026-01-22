# Redis Module

Deploys Redis using the Bitnami Helm chart for SMS OTP code storage in the
LDAP 2FA application.

## Purpose

This module replaces the in-memory SMS OTP storage with Redis, providing:

- **TTL-based expiration**: Automatic cleanup of expired OTP codes
- **Shared state**: OTP codes accessible from any backend replica
- **Persistence**: Data survives pod restarts via RDB snapshots
- **Horizontal scaling**: Enable multiple backend replicas
- **ECR Image Support**: Uses ECR images instead of Docker Hub
(images mirrored via `mirror-images-to-ecr.sh`)

## Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              twofa-backend namespace                       │  │
│  │                                                            │  │
│  │   ┌──────────────┐         ┌──────────────┐                │  │
│  │   │  Backend     │         │  Backend     │                │  │
│  │   │  Pod 1       │         │  Pod 2       │                │  │
│  │   │              │         │              │                │  │
│  │   │ redis-py     │         │ redis-py     │                │  │
│  │   └──────┬───────┘         └──────┬───────┘                │  │
│  │          │                        │                        │  │
│  └──────────┼────────────────────────┼────────────────────────┘  │
│             │                        │                           │
│             │    SETEX/GET/DEL       │                           │
│             │    (with TTL)          │                           │
│             └───────────┬────────────┘                           │
│                         │                                        │
│                         ▼                                        │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                   redis namespace                          │  │
│  │                                                            │  │
│  │   ┌──────────────────────────────────────────────────┐     │  │
│  │   │              Redis Standalone                    │     │  │
│  │   │                                                  │     │  │
│  │   │  ┌─────────────────┐    ┌─────────────────────┐  │     │  │
│  │   │  │  Redis Master   │───▶│  PersistentVolume   │  │     │  │
│  │   │  │  (Port 6379)    │    │  (RDB Snapshots)    │  │     │  │
│  │   │  └─────────────────┘    └─────────────────────┘  │     │  │
│  │   │                                                  │     │  │
│  │   └──────────────────────────────────────────────────┘     │  │
│  │                                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
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

  # ECR image configuration
  ecr_registry   = local.ecr_registry
  ecr_repository = local.ecr_repository
  image_tag      = "redis-latest"  # Default, or use specific version
}
```

## ECR Image Configuration

This module uses ECR images instead of Docker Hub to eliminate Docker Hub rate
limiting and external dependencies. Images are automatically mirrored from Docker
Hub to ECR by the `mirror-images-to-ecr.sh` script in `application_infra/` before
Terraform operations.

**Image Details:**

- **Source Image**: `bitnami/redis:latest` (from Docker Hub, or specific version
like `bitnami/redis:8.4.0-debian-12-r6`)
- **ECR Tag**: `redis-latest` (default, or specific version like `redis-8.4.0`)
- **ECR Registry/Repository**: Computed from `backend_infra` Terraform state
  (`ecr_url`)

**Image Mirroring:**

The `mirror-images-to-ecr.sh` script in `application_infra/` automatically:

1. Checks if the image exists in ECR (skips if already present)
2. Pulls the image from Docker Hub
3. Tags and pushes the image to ECR with the standardized tag
4. Cleans up local images after pushing

**Configuration:**

The ECR registry and repository are automatically computed from the `backend_infra`
Terraform state in the parent module (`application/main.tf`). You only need to
specify the `image_tag` if you want to use a different tag than the default.

For more information about image mirroring, see the [Application Infrastructure
README](../../application_infra/README.md#ecr-image-mirroring-automatic).

## Requirements

| Name | Version |
| ------ | --------- |
| terraform | >= 1.0 |
| kubernetes | >= 2.0 |
| helm | >= 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| enable_redis | Enable Redis deployment | `bool` | `false` | no |
| namespace | Kubernetes namespace | `string` | `"redis"` | no |
| secret_name | Name of K8s secret for password | `string` | `"redis-secret"` | no |
| redis_password | Redis password (min 8 chars) | `string` | n/a | yes |
| chart_version | Bitnami chart version | `string` | `"24.0.9"` | no |
| storage_class_name | Storage class for PVC | `string` | `""` | no |
| storage_size | Storage size for PVC | `string` | `"1Gi"` | no |
| persistence_enabled | Enable data persistence | `bool` | `true` | no |
| resources | CPU/memory limits/requests | `object` | See variables.tf | no |
| metrics_enabled | Enable Prometheus metrics | `bool` | `false` | no |
| ecr_registry | ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com) | `string` | n/a | yes |
| ecr_repository | ECR repository name | `string` | n/a | yes |
| image_tag | Redis image tag in ECR | `string` | `"redis-latest"` | no |
| backend_namespace | Namespace where backend pods are deployed (for network policy) | `string` | `"twofa-backend"` | no |

## Outputs

| Name | Description |
| ------ | ------------- |
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
| ------------- | ------- | ----- | ------------- |
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
- Network policies are configured within this module (see `main.tf`)
