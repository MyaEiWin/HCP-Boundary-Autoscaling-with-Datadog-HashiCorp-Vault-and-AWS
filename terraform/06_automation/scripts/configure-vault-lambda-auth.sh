#!/usr/bin/env bash
# Configure least-privilege Vault AWS IAM auth roles for the Stage 06 Lambdas.
# Run on an administrator workstation after `terraform apply` in this folder.
set -euo pipefail

for command in vault jq terraform; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done
: "${VAULT_ADDR:?Set VAULT_ADDR to the HCP Vault endpoint.}"
: "${VAULT_NAMESPACE:=admin}"
export VAULT_NAMESPACE

for role_name in session-counter token-broker cleanup; do
  role_arn=$(terraform output -json automation_role_arns | jq -er --arg role "$role_name" '.[$role]')
  case "$role_name" in
    session-counter)
      policy="boundary-session-counter"
      capabilities='path "secret/data/boundary/automation/session-counter" { capabilities = ["read"] }
path "secret/data/boundary/automation/datadog" { capabilities = ["read"] }'
      ;;
    token-broker)
      policy="boundary-token-broker"
      capabilities='path "secret/data/boundary/automation/token-broker" { capabilities = ["read"] }
path "secret/data/boundary/registration/*" { capabilities = ["create", "update", "read"] }'
      ;;
    cleanup)
      policy="boundary-cleanup"
      capabilities='path "secret/data/boundary/automation/cleanup" { capabilities = ["read"] }'
      ;;
  esac

  vault policy write "$policy" - <<<"$capabilities"
  vault write "auth/aws/role/boundary-$role_name" \
    auth_type=iam \
    bound_iam_principal_arn="$role_arn" \
    policies="$policy" \
    resolve_aws_unique_ids=false >/dev/null
  echo "Configured Vault role boundary-$role_name for $role_arn"
done
