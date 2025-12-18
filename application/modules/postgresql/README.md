# PostgreSQL Module

Deploys PostgreSQL using the Bitnami Helm chart for the LDAP 2FA application user storage.

## Features

- Standalone PostgreSQL deployment
- Persistent storage with configurable size
- Configurable resources
- ClusterIP service for internal access

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
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| env | Deployment environment | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Name prefix for resources | `string` | n/a | yes |
| namespace | Kubernetes namespace | `string` | `"ldap-2fa"` | no |
| chart_version | Helm chart version | `string` | `"16.2.1"` | no |
| database_name | Database name | `string` | `"ldap2fa"` | no |
| database_username | Database username | `string` | `"ldap2fa"` | no |
| database_password | Database password | `string` | n/a | yes |
| storage_class | Storage class for PVC | `string` | `""` | no |
| storage_size | Storage size | `string` | `"8Gi"` | no |
| resources | Resource limits/requests | `object` | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| host | PostgreSQL service hostname |
| port | PostgreSQL service port |
| database | Database name |
| username | Database username |
| connection_url | Connection URL (without password) |
| namespace | Kubernetes namespace |

## Connection

From within the cluster, connect using:
```
postgresql://ldap2fa:<password>@postgresql.ldap-2fa.svc.cluster.local:5432/ldap2fa
```

For the async SQLAlchemy driver:
```
postgresql+asyncpg://ldap2fa:<password>@postgresql.ldap-2fa.svc.cluster.local:5432/ldap2fa
```
