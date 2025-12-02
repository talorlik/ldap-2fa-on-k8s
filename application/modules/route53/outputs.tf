output "acm_cert_arn" {
  description = "ACM certificate ARN (validated and ready for use)"
  value       = module.acm.acm_certificate_arn
}

output "domain_name" {
  description = "Root domain name"
  value       = local.domain_name
}

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.zone_id
}

output "name_servers" {
  description = "Route53 name servers for the hosted zone (for registrar configuration)"
  value       = try(data.aws_route53_zone.this[0].name_servers, aws_route53_zone.this[0].name_servers)
}
