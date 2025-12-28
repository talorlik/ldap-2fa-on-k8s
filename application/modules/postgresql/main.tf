/**
 * PostgreSQL Module
 *
 * Deploys PostgreSQL using the Bitnami Helm chart for user storage
 * in the LDAP 2FA application signup system.
 */

locals {
  name = "${var.prefix}-${var.region}-postgresql-${var.env}"

  # Build PostgreSQL Helm values (without secret reference to avoid circular dependency)
  postgresql_values_base = {
    architecture = "standalone"

    auth = {
      database                  = var.database_name
      username                  = var.database_username
      enablePostgresUser        = false
      existingSecretPasswordKey = "postgresql-password"
    }

    primary = {
      persistence = merge(
        {
          enabled = true
          size    = var.storage_size
        },
        var.storage_class != "" ? { storageClass = var.storage_class } : {}
      )

      resources = {
        limits = {
          cpu    = var.resources.limits.cpu
          memory = var.resources.limits.memory
        }
        requests = {
          cpu    = var.resources.requests.cpu
          memory = var.resources.requests.memory
        }
      }

      service = {
        type = "ClusterIP"
      }
    }

    metrics = {
      enabled = false
    }
  }
}

# Create namespace if it doesn't exist
resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      environment = var.env
      managed-by  = "terraform"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# Create Kubernetes secret for PostgreSQL password
# Password is sourced from GitHub Secrets via TF_VAR_postgresql_database_password
resource "kubernetes_secret" "postgresql_password" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace.postgresql.metadata[0].name

    labels = {
      app         = "postgresql"
      environment = var.env
      managed-by  = "terraform"
    }
  }

  data = {
    "postgresql-password" = var.database_password
  }

  type = "Opaque"
}

# PostgreSQL Helm release
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = var.chart_version
  namespace  = kubernetes_namespace.postgresql.metadata[0].name

  # Use values attribute for complex nested structures (recommended approach)
  # This follows the official Bitnami PostgreSQL Helm chart values structure
  values = [
    yamlencode(merge(
      local.postgresql_values_base,
      {
        auth = merge(
          local.postgresql_values_base.auth,
          {
            existingSecret = kubernetes_secret.postgresql_password.metadata[0].name
          }
        )
      }
    ))
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.postgresql,
    kubernetes_secret.postgresql_password,
  ]
}
