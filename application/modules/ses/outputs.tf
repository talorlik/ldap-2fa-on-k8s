output "sender_email" {
  description = "Verified sender email address"
  value       = var.sender_email
}

output "sender_domain" {
  description = "Verified sender domain (if configured)"
  value       = var.sender_domain
}

output "iam_role_arn" {
  description = "ARN of the IAM role for SES access"
  value       = aws_iam_role.ses_sender.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for SES access"
  value       = aws_iam_role.ses_sender.name
}

output "email_identity_arn" {
  description = "ARN of the SES email identity"
  value       = var.sender_domain != null ? aws_ses_domain_identity.sender[0].arn : aws_ses_email_identity.sender[0].arn
}

output "verification_status" {
  description = "Instructions for email verification"
  value       = var.sender_domain == null ? "Check inbox of ${var.sender_email} and click verification link from AWS" : "Domain verification via DNS records"
}
