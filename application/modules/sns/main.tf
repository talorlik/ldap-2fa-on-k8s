# SNS Module for SMS-based 2FA Verification
#
# This module creates:
# - IAM Role for EKS Service Account (IRSA) to publish SMS via SNS
# - IAM Policy for direct SMS publishing (PhoneNumber=...)
#
# Uses Direct SMS (sns:Publish with PhoneNumber) - no SNS topic required. Topics
# are for broadcast to multiple subscribers; 2FA sends one-off codes to individual
# phones. See: https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html
#
# When sms_sender_country_code is set, fetches the Sender ID ARN from AWS End
# User Messaging (Pinpoint SMS Voice V2) for validation and reference.

locals {
  iam_role_name = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Fetch Sender ID ARN from AWS End User Messaging (Pinpoint SMS Voice V2).
# The sender ID must be pre-registered via AWS End User Messaging console
# (Configurations > Sender ID > Request originator) and shared with SNS.
# See docs/auxiliary/application_infra/guides/SMS_SENDER_ID_SETUP.md
data "external" "sender_id_arn" {
  program = ["sh", "${path.module}/scripts/get-sender-id-arn.sh"]
  query = {
    sender_id     = var.sms_sender_id
    country_code  = var.sms_sender_country_code
    region        = var.region
  }
}

# Data source to get EKS cluster OIDC provider
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# IAM Role for EKS Service Account (IRSA)
resource "aws_iam_role" "sns_publisher" {
  name = local.iam_role_name

  lifecycle {
    precondition {
      condition = (
        var.sms_sender_country_code == "" ||
        try(data.external.sender_id_arn.result.found, false) == "true"
      )
      error_message = <<-EOT
        SMS Sender ID "${var.sms_sender_id}" not found for country "${var.sms_sender_country_code}".
        Request a sender ID in AWS End User Messaging (Configurations > Sender ID > Request
        originator), share it with Amazon SNS, and ensure sms_sender_id and
        sms_sender_country_code match. See docs/auxiliary/application_infra/guides/
        SMS_SENDER_ID_SETUP.md
      EOT
    }
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for direct SMS publishing (sns:Publish with PhoneNumber - no topic)
resource "aws_iam_role_policy" "sns_publish" {
  name = "${local.iam_role_name}-policy"
  role = aws_iam_role.sns_publisher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDirectSMSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSNSCheckOptOut"
        Effect = "Allow"
        Action = [
          "sns:CheckIfPhoneNumberIsOptedOut",
          "sns:OptInPhoneNumber"
        ]
        Resource = "*"
      }
    ]
  })
}

# Set SMS attributes for the account (optional - for production use)
resource "aws_sns_sms_preferences" "sms_preferences" {
  count = var.configure_sms_preferences ? 1 : 0

  default_sender_id   = var.sms_sender_id
  default_sms_type    = var.sms_type
  monthly_spend_limit = var.sms_monthly_spend_limit

  # Note: delivery_status_iam_role_arn and delivery_status_success_sampling_rate
  # can be configured for SMS delivery status logging
}
