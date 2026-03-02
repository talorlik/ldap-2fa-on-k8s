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
# Uses assume-github-role.sh to assume the correct deployment account role based on
# var.env (same as ArgoCD external). Credentials come from env (GitHub Actions) or
# AWS Secrets Manager (local). See docs/auxiliary/application_infra/guides/SMS_SENDER_ID_SETUP.md
data "external" "sender_id_arn" {
  program = ["bash", "-c", <<-EOT
    set -u -o pipefail
    export AWS_PAGER=""
    ARN=""
    FOUND="false"
    ERR=""

    QUERY=$(cat)
    SENDER_ID=$(echo "$QUERY" | jq -r '.sender_id // empty')
    COUNTRY_CODE=$(echo "$QUERY" | jq -r '.country_code // empty')
    REGION=$(echo "$QUERY" | jq -r '.region // "us-east-1"')

    if [ -z "$SENDER_ID" ] || [ -z "$COUNTRY_CODE" ]; then
      jq -n --arg arn "" --arg found "false" --arg err "$ERR" '{arn:$arn,found:$found,error:$err}'
      exit 0
    fi

    ENV_LOWER="$(echo "${var.env}" | tr '[:upper:]' '[:lower:]')"
    if [ "$ENV_LOWER" = "prod" ]; then
      ACCOUNT_TYPE="prod"
    else
      ACCOUNT_TYPE="dev"
    fi

    SCRIPT_PATH="${path.root}/../scripts/assume-github-role.sh"
    if [ ! -x "$SCRIPT_PATH" ]; then
      SCRIPT_PATH="../scripts/assume-github-role.sh"
    fi

    if [ ! -x "$SCRIPT_PATH" ]; then
      ERR="assume_script_not_found"
    else
      TMP="$(mktemp 2>/dev/null || echo "/tmp/sender_id_assume_$$")"
      set +e
      source "$SCRIPT_PATH" "$ACCOUNT_TYPE" >"$TMP" 2>&1
      SCRIPT_RC=$?
      set -e

      SCRIPT_ERROR_CHECK=$(env | grep '^SCRIPT_ERROR=' || echo "")
      if [ -n "$SCRIPT_ERROR_CHECK" ] && echo "$SCRIPT_ERROR_CHECK" | grep -q 'SCRIPT_ERROR=true'; then
        SCRIPT_ERROR_MSG_CHECK=$(env | grep '^SCRIPT_ERROR_MSG=' || echo "")
        MSG=$(echo "$SCRIPT_ERROR_MSG_CHECK" | sed 's/^SCRIPT_ERROR_MSG=//' || echo "")
        if [ -z "$MSG" ]; then
          MSG="$(head -c 400 "$TMP" 2>/dev/null | tr -d '\n\r' || true)"
        fi
        ERR="failed_to_assume_role:$${MSG}"
      else
        AWS_AKID_CHECK=$(env | grep '^AWS_ACCESS_KEY_ID=' || echo "")
        AWS_SAK_CHECK=$(env | grep '^AWS_SECRET_ACCESS_KEY=' || echo "")
        AWS_ST_CHECK=$(env | grep '^AWS_SESSION_TOKEN=' || echo "")
        if [ -z "$AWS_AKID_CHECK" ] || [ -z "$AWS_SAK_CHECK" ] || [ -z "$AWS_ST_CHECK" ]; then
          MSG="$(head -c 400 "$TMP" 2>/dev/null | tr -d '\n\r' || true)"
          if [ -n "$MSG" ]; then
            ERR="failed_to_assume_role_exit_$${SCRIPT_RC}:$${MSG}"
          else
            ERR="failed_to_assume_role_exit_$${SCRIPT_RC}_no_output"
          fi
        fi
      fi
      rm -f "$TMP" 2>/dev/null || true
    fi

    if [ -z "$ERR" ]; then
      ARN=$(aws pinpoint-sms-voice-v2 describe-sender-ids \
        --sender-ids "SenderId=$SENDER_ID,IsoCountryCode=$COUNTRY_CODE" \
        --region "$REGION" \
        --no-paginate \
        --query 'SenderIds[0].SenderIdArn' \
        --output text 2>/dev/null || true)
      if [ -n "$ARN" ] && [ "$ARN" != "None" ]; then
        FOUND="true"
      else
        ARN=""
      fi
    fi

    jq -n \
      --arg arn "$ARN" \
      --arg found "$FOUND" \
      --arg error "$ERR" \
      '{arn:$arn,found:$found,error:$error}'
    exit 0
  EOT
  ]

  query = {
    sender_id    = var.sms_sender_id
    country_code = var.sms_sender_country_code
    region       = var.region
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
        try(data.external.sender_id_arn.result.found, "false") == "true"
      )
      error_message = <<-EOT
        SMS Sender ID "${var.sms_sender_id}" not found for country "${var.sms_sender_country_code}".
        If using cross-account access, ensure assume-github-role.sh can assume the deployment
        account (env vars or Secrets Manager). Request a sender ID in AWS End User Messaging
        (Configurations > Sender ID > Request originator), share it with Amazon SNS, and ensure
        sms_sender_id and sms_sender_country_code match. See docs/auxiliary/application_infra/
        guides/SMS_SENDER_ID_SETUP.md
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
