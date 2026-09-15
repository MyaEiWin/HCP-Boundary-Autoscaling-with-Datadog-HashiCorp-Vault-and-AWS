#!/usr/bin/env bash
# Creates the two Datadog webhooks without storing their shared secret in Terraform state.
# Run from this folder after configure-vault-webhook-auth.sh.
set -euo pipefail

for command in curl jq vault terraform; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done
: "${VAULT_ADDR:?Set VAULT_ADDR.}"
: "${VAULT_NAMESPACE:=admin}"
: "${DATADOG_API_KEY:?Set DATADOG_API_KEY in this shell.}"
: "${DATADOG_APP_KEY:?Set DATADOG_APP_KEY in this shell.}"
export VAULT_NAMESPACE
DD_API_URL="${DD_API_URL:-https://api.datadoghq.com}"

secret=$(vault kv get -field=shared_secret secret/boundary/automation/datadog-webhook)
webhook_collection="$DD_API_URL/api/v1/integration/webhooks/configuration/webhooks"
for action in scale-out scale-in; do
  endpoint=$(terraform output -raw "${action}_webhook_url")
  body=$(jq -n \
    --arg name "boundary-${action}" \
    --arg url "$endpoint" \
    --arg headers "$(jq -cn --arg secret "$secret" '{"X-Boundary-Webhook-Secret": $secret}')" \
    --arg payload '{"source":"datadog","monitor":"{{monitor.name}}","status":"{{alert_status}}"}' \
    '{name: $name, url: $url, encode_as: "json", custom_headers: $headers, payload: $payload}')
  webhook_name="boundary-${action}"
  if curl --fail --silent \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
    "$webhook_collection/$webhook_name" >/dev/null 2>&1; then
    method="PUT"
    webhook_url="$webhook_collection/$webhook_name"
  else
    method="POST"
    webhook_url="$webhook_collection"
  fi

  curl --fail --silent --show-error \
    -X "$method" "$webhook_url" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
    -H "Content-Type: application/json" \
    --data "$body" >/dev/null
  echo "Configured Datadog webhook $webhook_name."
done
unset secret
