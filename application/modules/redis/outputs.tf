output "redis_enabled" {
  description = "Whether Redis is enabled"
  value       = var.enable_redis
}

output "redis_host" {
  description = "Redis service hostname"
  value       = var.enable_redis ? "redis-master.${var.namespace}.svc.cluster.local" : ""
}

output "redis_port" {
  description = "Redis service port"
  value       = 6379
}

output "redis_namespace" {
  description = "Kubernetes namespace where Redis is deployed"
  value       = var.enable_redis ? var.namespace : ""
}

output "redis_password_secret_name" {
  description = "Name of the Kubernetes secret containing Redis password"
  value       = var.enable_redis ? var.secret_name : ""
}

output "redis_password_secret_key" {
  description = "Key in the secret for Redis password"
  value       = "redis-password"
}

output "redis_connection_url" {
  description = "Redis connection URL (without password)"
  value       = var.enable_redis ? "redis://redis-master.${var.namespace}.svc.cluster.local:6379/0" : ""
}
