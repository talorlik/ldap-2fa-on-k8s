output "ecr_name" {
  value = aws_ecr_repository.ecr.name
}

output "ecr_arn" {
  value = aws_ecr_repository.ecr.arn
}

output "ecr_url" {
  value = aws_ecr_repository.ecr.repository_url
}

output "ecr_registry" {
  description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
  value       = split("/", aws_ecr_repository.ecr.repository_url)[0]
}

output "ecr_repository" {
  description = "ECR repository name (without registry prefix)"
  value       = split("/", aws_ecr_repository.ecr.repository_url)[1]
}