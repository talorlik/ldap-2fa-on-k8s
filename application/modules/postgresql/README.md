# PostgreSQL Module

Deploys PostgreSQL using the Bitnami Helm chart for the LDAP 2FA application
user storage.

## Features

- Standalone PostgreSQL deployment
- Persistent storage with configurable size
- Configurable resources
- ClusterIP service for internal access
- **ECR Image Support**: Uses ECR images instead of Docker Hub
(images mirrored via `mirror-images-to-ecr.sh`)

## Usage

```hcl
module "postgresql" {
  source = "./modules/postgresql"

  env    = "dev"
  region = "us-east-1"
  prefix = "ldap2fa"

  namespace         = "ldap-2fa"
  database_name     = "ldap2fa"
  database_username = "ldap2fa"
  database_password = var.postgresql_password

  storage_class = "gp3"
  storage_size  = "10Gi"

  # ECR image configuration
  ecr_registry   = local.ecr_registry
  ecr_repository = local.ecr_repository
  image_tag      = "postgresql-latest"  # Default, or use specific version like "postgresql-18.1.0"
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| namespace | Kubernetes namespace | `string` | `"ldap-2fa"` | no |
| secret_name | Name of the Kubernetes secret for PostgreSQL password | `string` | `"postgresql-secret"` | no |
| chart_version | Helm chart version | `string` | `"18.1.15"` | no |
| database_name | Database name | `string` | `"ldap2fa"` | no |
| database_username | Database username | `string` | `"ldap2fa"` | no |
| database_password | Database password | `string` | n/a | yes |
| storage_class | Storage class for PVC | `string` | `""` | no |
| storage_size | Storage size | `string` | `"8Gi"` | no |
| resources | Resource limits/requests | `object` | See variables.tf | no |
| ecr_registry | ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com) | `string` | n/a | yes |
| ecr_repository | ECR repository name | `string` | n/a | yes |
| image_tag | PostgreSQL image tag in ECR | `string` | `"postgresql-latest"` | no |

## Outputs

| Name | Description |
| ------ | ------------- |
| host | PostgreSQL service hostname |
| port | PostgreSQL service port |
| database | Database name |
| username | Database username |
| connection_url | Connection URL (without password) |
| namespace | Kubernetes namespace |

## ECR Image Configuration

This module uses ECR images instead of Docker Hub to eliminate Docker Hub rate
limiting and external dependencies. Images are automatically mirrored from Docker
Hub to ECR by the `mirror-images-to-ecr.sh` script before Terraform operations.

**Image Details:**

- **Source Image**: `bitnami/postgresql:latest` (from Docker Hub)
- **ECR Tag**: `postgresql-latest` (default) or specific version e.g. `postgresql-18.1.0`
- **ECR Registry/Repository**: Computed from `backend_infra` Terraform state
  (`ecr_url`)

**Implementation Note:**

The image configuration (registry, repository, and tag) is set using Terraform
`set` blocks instead of being included in the values block. This approach avoids
validation issues with the Terraform Helm provider when using custom ECR registries.

**Helm Chart Repository:**

The module uses the Bitnami PostgreSQL Helm chart from the OCI registry:

- Repository: `oci://registry-1.docker.io/bitnamicharts`
- Chart: `postgresql`
- Version: `18.1.15` (default)

**Image Mirroring:**

The `mirror-images-to-ecr.sh` script automatically:

1. Checks if the image exists in ECR (skips if already present)
2. Pulls the image from Docker Hub
3. Tags and pushes the image to ECR with the standardized tag
4. Cleans up local images after pushing

**Configuration:**

The ECR registry and repository are automatically computed from the `backend_infra`
Terraform state in the parent module (`application/main.tf`). You only need to
specify the `image_tag` if you want to use a different tag than the default.

For more information about image mirroring, see the [Application Infrastructure
README](../README.md#ecr-image-mirroring-automatic).

## Purpose

This module deploys PostgreSQL for the LDAP 2FA application to store:

- **User Registrations**: User data before LDAP activation (first name, last name,
username, email, phone, password hash, MFA method)
- **Verification Tokens**: Email verification tokens (UUID-based) and phone
verification codes
- **Profile State**: User profile state management (PENDING → COMPLETE → ACTIVE)
- **Group Assignments**: User-group relationships before LDAP activation

The database stores user registration data until an administrator approves the user,
at which point the user is created in LDAP and the database record is updated to
ACTIVE status.

## Connection

From within the cluster, connect using:

```text
postgresql://ldap2fa:<password>@postgresql.ldap-2fa.svc.cluster.local:5432/ldap2fa
```

For the async SQLAlchemy driver (used by FastAPI):

```text
postgresql+asyncpg://ldap2fa:<password>@postgresql.ldap-2fa.svc.cluster.local:5432/ldap2fa
```

## Database Schema

The application uses SQLAlchemy models to define the database schema.
Key tables include:

- **Users**: User registration data with profile fields and verification status
- **Verification Tokens**: Email and phone verification tokens with expiration
- **Groups**: LDAP group definitions
- **User Groups**: User-group relationships

For detailed schema information, see the application backend code in `application/backend/src/app/database/models.py`.

## Security

- **Password Authentication**: Database password is stored in Kubernetes Secret
(from GitHub Secrets)
- **Network**: ClusterIP service (not exposed externally)
- **Storage**: Persistent EBS-backed storage for data durability
- **Backup**: Consider implementing regular backups for production deployments
