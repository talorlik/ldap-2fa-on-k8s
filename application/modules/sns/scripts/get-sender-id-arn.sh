#!/usr/bin/env sh
# Fetches the ARN of an SMS Sender ID from AWS End User Messaging (Pinpoint SMS Voice V2).
# Used by Terraform external data source to validate sender ID exists and get its ARN.
# Input (JSON on stdin): {"sender_id":"TALO2FA","country_code":"IL","region":"us-east-1"}
# Output (JSON on stdout): {"arn":"arn:aws:sms-voice:...","found":"true"} or {"arn":"","found":"false"}
# Note: external data source requires all values to be strings.

set -e
QUERY=$(cat)
SENDER_ID=$(echo "$QUERY" | jq -r '.sender_id // empty')
COUNTRY_CODE=$(echo "$QUERY" | jq -r '.country_code // empty')
REGION=$(echo "$QUERY" | jq -r '.region // "us-east-1"')

if [ -z "$SENDER_ID" ] || [ -z "$COUNTRY_CODE" ]; then
  echo '{"arn":"","found":"false"}'
  exit 0
fi

ARN=$(aws pinpoint-sms-voice-v2 describe-sender-ids \
  --sender-ids "SenderId=${SENDER_ID},IsoCountryCode=${COUNTRY_CODE}" \
  --region "$REGION" \
  --no-paginate \
  --query 'SenderIds[0].SenderIdArn' \
  --output text 2>/dev/null || true)

if [ -z "$ARN" ] || [ "$ARN" = "None" ]; then
  echo '{"arn":"","found":"false"}'
else
  echo "{\"arn\":\"${ARN}\",\"found\":\"true\"}"
fi
