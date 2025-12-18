output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "vpc_endpoint_ssm_id" {
  description = "VPC endpoint ID for SSM"
  value       = aws_vpc_endpoint.private_link_ssm.id
}

output "vpc_endpoint_ssmmessages_id" {
  description = "VPC endpoint ID for SSM Messages"
  value       = aws_vpc_endpoint.private_link_ssmmessages.id
}

output "vpc_endpoint_ec2messages_id" {
  description = "VPC endpoint ID for EC2 Messages"
  value       = aws_vpc_endpoint.private_link_ec2messages.id
}

output "vpc_endpoint_sts_id" {
  description = "VPC endpoint ID for STS (IRSA)"
  value       = var.enable_sts_endpoint ? aws_vpc_endpoint.private_link_sts[0].id : null
}

output "vpc_endpoint_sns_id" {
  description = "VPC endpoint ID for SNS (SMS 2FA)"
  value       = var.enable_sns_endpoint ? aws_vpc_endpoint.private_link_sns[0].id : null
}

output "vpc_endpoint_ids" {
  description = "List of all VPC endpoint IDs"
  value = compact([
    aws_vpc_endpoint.private_link_ssm.id,
    aws_vpc_endpoint.private_link_ssmmessages.id,
    aws_vpc_endpoint.private_link_ec2messages.id,
    var.enable_sts_endpoint ? aws_vpc_endpoint.private_link_sts[0].id : null,
    var.enable_sns_endpoint ? aws_vpc_endpoint.private_link_sns[0].id : null,
  ])
}
