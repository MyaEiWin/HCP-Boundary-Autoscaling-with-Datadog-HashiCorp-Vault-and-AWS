#!/usr/bin/env bash
# Creates an HCP Boundary Vault credential store and SSH certificate library,
# then associates the library with an existing SSH target. Secrets are read
# only from environment variables and never written to disk.
set -euo pipefail

for command in boundary jq; do
  command -v "$command" >/dev/null || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

: "${BOUNDARY_PROJECT_ID:?Set the HCP Boundary project scope ID.}"
: "${BOUNDARY_TARGET_ID:?Set the existing SSH target ID.}"
: "${VAULT_ADDR:?Set the Vault address used by Boundary.}"
: "${BOUNDARY_VAULT_CREDENTIAL_STORE_TOKEN:?Set the periodic token created by create-boundary-credential-store-token.sh.}"

VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"
VAULT_SSH_SIGNING_PATH="${VAULT_SSH_SIGNING_PATH:-boundary-ssh/sign/boundary-ubuntu}"
SSH_TARGET_USERNAME="${SSH_TARGET_USERNAME:-ubuntu}"
BOUNDARY_WORKER_FILTER="${BOUNDARY_WORKER_FILTER:-}"

target_json=$(boundary targets read -id "$BOUNDARY_TARGET_ID" -format json)
target_type=$(jq -er '.item.type' <<<"$target_json")
if [[ "$target_type" != "ssh" ]]; then
  echo "Target $BOUNDARY_TARGET_ID is type '$target_type'. Vault credential injection requires an SSH target." >&2
  exit 1
fi

store_args=(
  -name "vault-ssh-certificates"
  -description "Vault SSH certificate injection for Boundary SSH targets"
  -scope-id "$BOUNDARY_PROJECT_ID"
  -vault-address "$VAULT_ADDR"
  -vault-namespace "$VAULT_NAMESPACE"
  -vault-token "$BOUNDARY_VAULT_CREDENTIAL_STORE_TOKEN"
)

if [[ -n "$BOUNDARY_WORKER_FILTER" ]]; then
  store_args+=(-worker-filter "$BOUNDARY_WORKER_FILTER")
fi

store_json=$(boundary credential-stores create vault "${store_args[@]}" -format json)
credential_store_id=$(jq -er '.item.id' <<<"$store_json")

library_json=$(boundary credential-libraries create vault-ssh-certificate \
  -name "vault-ssh-certificates" \
  -description "Short-lived Vault SSH certificates for ${SSH_TARGET_USERNAME}" \
  -credential-store-id "$credential_store_id" \
  -vault-path "$VAULT_SSH_SIGNING_PATH" \
  -username "$SSH_TARGET_USERNAME" \
  -key-type ed25519 \
  -extension permit-pty \
  -format json)
credential_library_id=$(jq -er '.item.id' <<<"$library_json")

boundary targets add-credential-sources \
  -id "$BOUNDARY_TARGET_ID" \
  -injected-application-credential-source "$credential_library_id" >/dev/null

echo "Vault credential store created: $credential_store_id"
echo "Vault SSH certificate library created: $credential_library_id"
echo "Credential injection was attached to target: $BOUNDARY_TARGET_ID"
