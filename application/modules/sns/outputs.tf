output "iam_role_arn" {
  description = "ARN of the IAM role for SNS publishing"
  value       = aws_iam_role.sns_publisher.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.sns_publisher.name
}

output "service_account_annotation" {
  description = "Annotation to add to Kubernetes service account for IRSA"
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.sns_publisher.arn
  }
}

output "sms_sender_id_arn" {
  description = "ARN of the Sender ID from AWS End User Messaging (empty if not found or sms_sender_country_code not set)"
  value       = try(data.external.sender_id_arn.result.found, false) == "true" ? data.external.sender_id_arn.result.arn : ""
}
