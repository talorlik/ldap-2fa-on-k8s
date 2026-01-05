output "record_name" {
  description = "Route53 record name"
  value       = aws_route53_record.this.name
}

output "record_fqdn" {
  description = "Fully qualified domain name (FQDN) of the Route53 record"
  value       = aws_route53_record.this.fqdn
}

output "record_id" {
  description = "Route53 record ID"
  value       = aws_route53_record.this.id
}
