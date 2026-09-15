resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

resource "vault_aws_auth_backend_role" "worker" {
  backend                  = vault_auth_backend.aws.path
  role                     = var.vault_aws_role_name
  auth_type                = "iam"
  resolve_aws_unique_ids   = false
  bound_iam_principal_arns = [var.worker_role_arn]
  token_policies           = [vault_policy.worker.name]
}

resource "vault_aws_auth_backend_role" "token_broker" {
  backend                  = vault_auth_backend.aws.path
  role                     = var.vault_broker_role_name
  auth_type                = "iam"
  resolve_aws_unique_ids   = false
  bound_iam_principal_arns = [var.token_broker_role_arn]
  token_policies           = [vault_policy.token_broker.name]
}

