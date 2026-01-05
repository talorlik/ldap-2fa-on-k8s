# Route53 A (alias) record pointing to an ALB
resource "aws_route53_record" "this" {
  provider = aws.state_account

  zone_id = var.zone_id
  name    = var.name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = var.evaluate_target_health
  }

  lifecycle {
    create_before_destroy = true

    # Precondition: Ensure ALB DNS name is never null or empty
    precondition {
      condition     = var.alb_dns_name != null && var.alb_dns_name != ""
      error_message = "ALB DNS name must be available before creating Route53 record. Ensure the ALB has been provisioned."
    }
  }
}
