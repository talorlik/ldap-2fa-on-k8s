#!/usr/bin/env sh
# Fetches the ARN of an SMS Sender ID from AWS End User Messaging (Pinpoint SMS Voice V2).
# For manual testing only. Terraform uses inline bash with assume-github-role.sh (see
# modules/sns/main.tf) to fetch credentials from env or Secrets Manager.
#
# Input (JSON on stdin): {"sender_id":"TALO2FA","country_code":"IL","region":"us-east-1"}
# Output (JSON on stdout): {"arn":"arn:aws:sms-voice:...","found":"true"} or {"arn":"","found":"false"}
# Note: external data source requires all values to be strings.
#
# Manual use (requires jq, aws; uses current AWS credentials):
#   echo '{"sender_id":"TALORLIKAWS","country_code":"IL","region":"us-east-1"}' | ./get-sender-id-arn.sh
# For cross-account: from repo root, source scripts/assume-github-role.sh prod first.

set -e
QUERY=$(cat)
SENDER_ID=$(echo "$QUERY" | jq -r '.sender_id // empty')
COUNTRY_CODE=$(echo "$QUERY" | jq -r '.country_code // empty')
REGION=$(echo "$QUERY" | jq -r '.region // "us-east-1"')

if [ -z "$SENDER_ID" ] || [ -z "$COUNTRY_CODE" ]; then
  jq -n '{arn: "", found: "false"}'
  exit 0
fi

ARN=$(aws pinpoint-sms-voice-v2 describe-sender-ids \
  --sender-ids "SenderId=${SENDER_ID},IsoCountryCode=${COUNTRY_CODE}" \
  --region "$REGION" \
  --no-paginate \
  --query 'SenderIds[0].SenderIdArn' \
  --output text 2>/dev/null || true)

if [ -z "$ARN" ] || [ "$ARN" = "None" ]; then
  jq -n '{arn: "", found: "false"}'
else
  jq -n --arg arn "$ARN" '{arn: $arn, found: "true"}'
fi
