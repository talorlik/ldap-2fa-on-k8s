/**
 * SES Module
 *
 * Configures AWS SES for sending verification emails in the LDAP 2FA application.
 * Includes IAM role for IRSA to allow the backend pod to send emails.
 */

locals {
  role_name = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
}

# Get EKS cluster data for IRSA
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# OIDC provider for IRSA
data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Verify sender email address (if not using domain verification)
resource "aws_ses_email_identity" "sender" {
  count = var.sender_domain == null ? 1 : 0
  email = var.sender_email
}

# Verify sender domain (if domain is provided)
resource "aws_ses_domain_identity" "sender" {
  count  = var.sender_domain != null ? 1 : 0
  domain = var.sender_domain
}

# Domain verification DNS record (if using domain verification and Route53)
resource "aws_route53_record" "ses_verification" {
  count   = var.sender_domain != null && var.route53_zone_id != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.sender_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.sender[0].verification_token]
}

# DKIM for domain (if using domain verification)
resource "aws_ses_domain_dkim" "sender" {
  count  = var.sender_domain != null ? 1 : 0
  domain = aws_ses_domain_identity.sender[0].domain
}

# DKIM DNS records (if using domain verification and Route53)
resource "aws_route53_record" "ses_dkim" {
  count   = var.sender_domain != null && var.route53_zone_id != null ? 3 : 0
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.sender[0].dkim_tokens[count.index]}._domainkey.${var.sender_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.sender[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# IAM policy for SES send email
resource "aws_iam_policy" "ses_send" {
  name        = "${local.role_name}-policy"
  description = "Allow sending emails via SES for LDAP 2FA verification"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.sender_email
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM role for IRSA
resource "aws_iam_role" "ses_sender" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.cluster.arn
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

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ses_send" {
  role       = aws_iam_role.ses_sender.name
  policy_arn = aws_iam_policy.ses_send.arn
}
