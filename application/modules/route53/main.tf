locals {
  domain = var.domain_name
  # Removing trailing dot from domain
  domain_name = trimsuffix(local.domain, ".")
  zone_id = try(data.aws_route53_zone.this[0].zone_id, aws_route53_zone.this[0].zone_id)
}

data "aws_route53_zone" "this" {
  count = var.use_existing_route53_zone ? 1 : 0

  name         = local.domain_name
  private_zone = false
}

# Create Route53 hosted zone and ACM certificate
resource "aws_route53_zone" "this" {
  count = var.use_existing_route53_zone ? 0 : 1

  name = local.domain_name

  tags = {
    Name      = local.domain_name
    Env       = var.env
    Terraform = "true"
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.2.0"

  domain_name = local.domain_name
  zone_id     = local.zone_id

  subject_alternative_names = var.subject_alternative_names

  validation_method = "DNS"

  wait_for_validation = true
  validation_timeout  = "30m"

  tags = {
    Name      = local.domain_name
    Env       = var.env
    Terraform = "true"
  }
}