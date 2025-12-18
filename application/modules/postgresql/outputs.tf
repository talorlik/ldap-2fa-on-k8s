output "host" {
  description = "PostgreSQL service hostname"
  value       = "postgresql.${var.namespace}.svc.cluster.local"
}

output "port" {
  description = "PostgreSQL service port"
  value       = 5432
}

output "database" {
  description = "Database name"
  value       = var.database_name
}

output "username" {
  description = "Database username"
  value       = var.database_username
}

output "connection_url" {
  description = "PostgreSQL connection URL (without password)"
  value       = "postgresql+asyncpg://${var.database_username}@postgresql.${var.namespace}.svc.cluster.local:5432/${var.database_name}"
}

output "namespace" {
  description = "Kubernetes namespace where PostgreSQL is deployed"
  value       = var.namespace
}
