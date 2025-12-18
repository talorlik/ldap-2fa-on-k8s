output "sns_topic_arn" {
  description = "ARN of the SNS topic for SMS"
  value       = aws_sns_topic.sms.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.sms.name
}

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
