# output "alb_dns_name" {
#   description = "Application Load Balancer DNS Name"
#   value = (
#     length(kubernetes_ingress_v1.ingress_alb.status) > 0 &&
#     length(kubernetes_ingress_v1.ingress_alb.status[0].load_balancer) > 0 &&
#     length(kubernetes_ingress_v1.ingress_alb.status[0].load_balancer[0].ingress) > 0
#   ) ? kubernetes_ingress_v1.ingress_alb.status[0].load_balancer[0].ingress[0].hostname : "ALB is still provisioning"
# }

output "ingress_class_name" {
  description = "Name of the IngressClass for shared ALB"
  value       = kubernetes_ingress_class_v1.ingressclass_alb.metadata[0].name
}

output "ingress_class_params_name" {
  description = "Name of the IngressClassParams for ALB configuration"
  value       = local.ingressclassparams_alb_name
}

output "alb_scheme" {
  description = "ALB scheme configured in IngressClassParams"
  value       = var.alb_scheme
}

output "alb_ip_address_type" {
  description = "ALB IP address type configured in IngressClassParams"
  value       = var.alb_ip_address_type
}
