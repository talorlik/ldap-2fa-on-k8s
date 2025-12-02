output "alb_dns_name" {
  description = "DNS name of the shared ALB created by Ingress resources"
  value       = local.alb_dns_name
}

# output "alb_dns_name" {
#   description = "DNS name of the ALB (if created)"
#   value       = var.use_alb ? module.alb[0].alb_dns_name : "(ALB not provisioned)"
# }

output "route53_acm_cert_arn" {
  description = "ACM certificate ARN (validated and ready for use)"
  value       = data.aws_acm_certificate.this.arn
}

output "route53_domain_name" {
  description = "Root domain name"
  value       = var.domain_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.this.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers (for registrar configuration)"
  value       = data.aws_route53_zone.this.name_servers
}
