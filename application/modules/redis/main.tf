/**
 * Redis Module
 *
 * Deploys Redis using the Bitnami Helm chart for SMS OTP code storage
 * in the LDAP 2FA application. Provides TTL-based automatic expiration
 * and shared state across backend replicas.
 */

locals {
  name = "${var.prefix}-${var.region}-redis-${var.env}"
}

# Create namespace for Redis
resource "kubernetes_namespace" "redis" {
  count = var.enable_redis ? 1 : 0

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

# Create Kubernetes secret for Redis password
# Password is sourced from GitHub Secrets via TF_VAR_redis_password
resource "kubernetes_secret" "redis_password" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace.redis[0].metadata[0].name

    labels = {
      app         = "redis"
      environment = var.env
      managed-by  = "terraform"
    }
  }

  data = {
    "redis-password" = var.redis_password
  }

  type = "Opaque"
}

# Redis Helm release using Bitnami chart
resource "helm_release" "redis" {
  count = var.enable_redis ? 1 : 0

  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = var.chart_version
  namespace  = kubernetes_namespace.redis[0].metadata[0].name

  # Architecture: standalone for OTP cache (no HA needed)
  set {
    name  = "architecture"
    value = "standalone"
  }

  # Authentication using existing secret
  set {
    name  = "auth.enabled"
    value = "true"
  }

  set {
    name  = "auth.existingSecret"
    value = kubernetes_secret.redis_password[0].metadata[0].name
  }

  set {
    name  = "auth.existingSecretPasswordKey"
    value = "redis-password"
  }

  # Master configuration
  set {
    name  = "master.persistence.enabled"
    value = tostring(var.persistence_enabled)
  }

  set {
    name  = "master.persistence.size"
    value = var.storage_size
  }

  dynamic "set" {
    for_each = var.storage_class_name != "" ? [var.storage_class_name] : []
    content {
      name  = "master.persistence.storageClass"
      value = set.value
    }
  }

  # Resources for master
  set {
    name  = "master.resources.limits.cpu"
    value = var.resources.limits.cpu
  }

  set {
    name  = "master.resources.limits.memory"
    value = var.resources.limits.memory
  }

  set {
    name  = "master.resources.requests.cpu"
    value = var.resources.requests.cpu
  }

  set {
    name  = "master.resources.requests.memory"
    value = var.resources.requests.memory
  }

  # Security context - run as non-root
  set {
    name  = "master.containerSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "master.containerSecurityContext.runAsUser"
    value = "1001"
  }

  set {
    name  = "master.containerSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "master.containerSecurityContext.allowPrivilegeEscalation"
    value = "false"
  }

  # Pod security context
  set {
    name  = "master.podSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "master.podSecurityContext.fsGroup"
    value = "1001"
  }

  # Service configuration
  set {
    name  = "master.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "master.service.ports.redis"
    value = "6379"
  }

  # Disable replicas (standalone mode)
  set {
    name  = "replica.replicaCount"
    value = "0"
  }

  # Disable metrics (optional for production monitoring)
  set {
    name  = "metrics.enabled"
    value = tostring(var.metrics_enabled)
  }

  # Redis configuration - optimize for OTP cache use case
  set {
    name  = "commonConfiguration"
    value = <<-EOT
      # Enable RDB persistence for data recovery
      save 900 1
      save 300 10
      save 60 10000
      # Disable AOF (not needed for OTP cache)
      appendonly no
      # Max memory policy - evict keys with TTL first
      maxmemory-policy volatile-lru
      # Connection timeout
      timeout 300
    EOT
  }

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.redis[0],
    kubernetes_secret.redis_password[0],
  ]
}

# Network Policy: Allow backend pods to connect to Redis
# This policy restricts Redis access to only the backend namespace/pods
resource "kubernetes_network_policy_v1" "allow_backend_to_redis" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = "allow-backend-to-redis"
    namespace = kubernetes_namespace.redis[0].metadata[0].name

    labels = {
      app         = "redis"
      environment = var.env
      managed-by  = "terraform"
    }
  }

  spec {
    # Apply to Redis pods
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "redis"
      }
    }

    policy_types = ["Ingress"]

    # Allow ingress from backend namespace on Redis port
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.backend_namespace
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "ldap-2fa-backend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }

    # Allow ingress from within the Redis namespace (for Redis probes, etc.)
    ingress {
      from {
        pod_selector {}
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }
  }

  depends_on = [
    kubernetes_namespace.redis[0],
    helm_release.redis[0],
  ]
}
