/**
 * PostgreSQL Module
 *
 * Deploys PostgreSQL using the Bitnami Helm chart for user storage
 * in the LDAP 2FA application signup system.
 */

locals {
  name = "${var.prefix}-${var.region}-postgresql-${var.env}"
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

# PostgreSQL Helm release
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = var.chart_version
  namespace  = kubernetes_namespace.postgresql.metadata[0].name

  # Authentication
  set {
    name  = "auth.database"
    value = var.database_name
  }

  set {
    name  = "auth.username"
    value = var.database_username
  }

  set_sensitive {
    name  = "auth.password"
    value = var.database_password
  }

  # Disable postgres superuser password (use username/password above)
  set {
    name  = "auth.enablePostgresUser"
    value = "false"
  }

  # Primary configuration
  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.size"
    value = var.storage_size
  }

  dynamic "set" {
    for_each = var.storage_class != "" ? [var.storage_class] : []
    content {
      name  = "primary.persistence.storageClass"
      value = set.value
    }
  }

  # Resources
  set {
    name  = "primary.resources.limits.cpu"
    value = var.resources.limits.cpu
  }

  set {
    name  = "primary.resources.limits.memory"
    value = var.resources.limits.memory
  }

  set {
    name  = "primary.resources.requests.cpu"
    value = var.resources.requests.cpu
  }

  set {
    name  = "primary.resources.requests.memory"
    value = var.resources.requests.memory
  }

  # Disable read replicas for simple deployment
  set {
    name  = "architecture"
    value = "standalone"
  }

  # Service configuration
  set {
    name  = "primary.service.type"
    value = "ClusterIP"
  }

  # Metrics (optional)
  set {
    name  = "metrics.enabled"
    value = "false"
  }

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}
