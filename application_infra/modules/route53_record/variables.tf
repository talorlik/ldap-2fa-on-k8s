variable "zone_id" {
  description = "Route53 hosted zone ID for creating DNS records"
  type        = string
}

variable "name" {
  description = "DNS record name (e.g., phpldapadmin.talorlik.com)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB to point the record to"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB canonical hosted zone ID for Route53 alias records. This should be computed from the region mapping."
  type        = string
}

variable "evaluate_target_health" {
  description = "Whether to evaluate target health for the alias record"
  type        = bool
  default     = true
}
