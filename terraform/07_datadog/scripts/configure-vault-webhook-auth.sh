#!/usr/bin/env bash
# Creates the Vault secret and AWS IAM auth role used by the Datadog webhook Lambda.
# Run from this folder on an administrator workstation after Terraform apply.
set -euo pipefail

for command in vault openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done
: "${VAULT_ADDR:?Set VAULT_ADDR to the HCP Vault endpoint.}"
: "${VAULT_NAMESPACE:=admin}"
export VAULT_NAMESPACE

if vault kv get secret/boundary/automation/datadog-webhook >/dev/null 2>&1; then
  echo "Existing Datadog webhook secret retained."
else
  webhook_secret=$(openssl rand -hex 32)
  vault kv put secret/boundary/automation/datadog-webhook shared_secret="$webhook_secret" >/dev/null
  unset webhook_secret
  echo "Created the Datadog webhook secret in Vault."
fi

role_arn=$(terraform output -raw scale_action_role_arn)
vault policy write boundary-datadog-scale-action - <<'EOF'
path "secret/data/boundary/automation/datadog-webhook" {
  capabilities = ["read"]
}
EOF

vault write auth/aws/role/boundary-datadog-scale-action \
  auth_type=iam \
  bound_iam_principal_arn="$role_arn" \
  policies="boundary-datadog-scale-action" \
  resolve_aws_unique_ids=false >/dev/null

echo "Configured Vault AWS auth role boundary-datadog-scale-action."
