output "namespace" {
  description = "Kubernetes namespace for OpenLDAP"
  value       = kubernetes_namespace.openldap.metadata[0].name
}

output "secret_name" {
  description = "Name of the Kubernetes secret for OpenLDAP passwords"
  value       = kubernetes_secret.openldap_passwords.metadata[0].name
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.openldap.name
}

output "phpldapadmin_ingress_hostname" {
  description = "Hostname from phpLDAPadmin ingress (ALB DNS name)"
  value       = try(data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "ltb_passwd_ingress_hostname" {
  description = "Hostname from ltb-passwd ingress (ALB DNS name)"
  value       = try(data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "alb_dns_name" {
  description = "ALB DNS name (from either ingress)"
  value = try(
    data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname,
    ""
  )
}

output "phpldapadmin_route53_record_name" {
  description = "Route53 record name for phpLDAPadmin"
  value       = aws_route53_record.phpldapadmin.name
}

output "ltb_passwd_route53_record_name" {
  description = "Route53 record name for ltb-passwd"
  value       = aws_route53_record.ltb_passwd.name
}
