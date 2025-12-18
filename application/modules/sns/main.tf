# SNS Module for SMS-based 2FA Verification
#
# This module creates:
# - SNS Topic for SMS notifications
# - IAM Role for EKS Service Account (IRSA) to publish to SNS
# - IAM Policy for SNS SMS publishing

locals {
  sns_topic_name = "${var.prefix}-${var.region}-${var.sns_topic_name}-${var.env}"
  iam_role_name  = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get EKS cluster OIDC provider
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# SNS Topic for SMS messages
resource "aws_sns_topic" "sms" {
  name         = local.sns_topic_name
  display_name = var.sns_display_name

  tags = var.tags
}

# SNS Topic Policy - allows the IAM role to publish
resource "aws_sns_topic_policy" "sms" {
  arn = aws_sns_topic.sms.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SNSTopicPolicy"
    Statement = [
      {
        Sid    = "AllowPublishFromIAMRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.sns_publisher.arn
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.sms.arn
      }
    ]
  })
}

# IAM Role for EKS Service Account (IRSA)
resource "aws_iam_role" "sns_publisher" {
  name = local.iam_role_name

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

# IAM Policy for SNS SMS publishing
resource "aws_iam_role_policy" "sns_publish" {
  name = "${local.iam_role_name}-policy"
  role = aws_iam_role.sns_publisher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.sms.arn
      },
      {
        Sid    = "AllowDirectSMSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "sns:Protocol" = "sms"
          }
        }
      },
      {
        Sid    = "AllowSNSSubscribe"
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:ConfirmSubscription",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic"
        ]
        Resource = aws_sns_topic.sms.arn
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
