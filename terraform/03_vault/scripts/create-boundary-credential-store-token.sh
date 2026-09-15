#!/usr/bin/env bash
# Creates the renewable orphan token used by one HCP Boundary Vault credential
# store. Run this from a trusted terminal after Stage 3 has applied.
set -euo pipefail

for command in vault jq; do
  command -v "$command" >/dev/null || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

: "${VAULT_ADDR:?Set VAULT_ADDR to your HCP Vault endpoint.}"
: "${VAULT_NAMESPACE:=admin}"
export VAULT_NAMESPACE

token_json=$(vault token create \
  -no-default-policy=true \
  -policy=boundary-credential-store \
  -orphan \
  -period=24h \
  -format=json)

echo "Copy the token below directly into BOUNDARY_VAULT_CREDENTIAL_STORE_TOKEN."
echo "Do not save it in Terraform files, Git, screenshots, or shell history."
printf '%s\n' "$token_json" | jq -r '.auth.client_token'
