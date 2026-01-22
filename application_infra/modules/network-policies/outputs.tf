output "network_policy_name" {
  description = "Name of the network policy for secure namespace communication"
  value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].name
}

output "network_policy_namespace" {
  description = "Namespace where the network policy is applied"
  value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].namespace
}

output "network_policy_uid" {
  description = "UID of the network policy resource"
  value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].uid
}
