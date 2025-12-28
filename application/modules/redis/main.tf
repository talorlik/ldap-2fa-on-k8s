/**
 * Redis Module
 *
 * Deploys Redis using the Bitnami Helm chart for SMS OTP code storage
 * in the LDAP 2FA application. Provides TTL-based automatic expiration
 * and shared state across backend replicas.
 */

locals {
  name = "${var.prefix}-${var.region}-redis-${var.env}"

  # Build Redis Helm values (without secret reference to avoid circular dependency)
  redis_values_base = {
    architecture = "standalone"

    auth = {
      enabled                   = true
      existingSecretPasswordKey = "redis-password"
    }

    master = {
      persistence = merge(
        {
          enabled = var.persistence_enabled
          size    = var.storage_size
        },
        var.storage_class_name != "" ? { storageClass = var.storage_class_name } : {}
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

      containerSecurityContext = {
        enabled                  = true
        runAsUser                = 1001
        runAsNonRoot             = true
        allowPrivilegeEscalation = false
      }

      podSecurityContext = {
        enabled = true
        fsGroup = 1001
      }

      service = {
        type = "ClusterIP"
        ports = {
          redis = 6379
        }
      }
    }

    replica = {
      replicaCount = 0
    }

    metrics = {
      enabled = var.metrics_enabled
    }

    commonConfiguration = <<-EOT
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

  # Use values attribute for complex nested structures (recommended approach)
  # This follows the official Bitnami Redis Helm chart values structure
  values = [
    yamlencode(merge(
      local.redis_values_base,
      {
        auth = merge(
          local.redis_values_base.auth,
          {
            existingSecret = kubernetes_secret.redis_password[0].metadata[0].name
          }
        )
      }
    ))
  ]

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
