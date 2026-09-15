resource "vault_policy" "worker" {
  name   = "boundary-worker"
  policy = <<-EOT
    path "secret/data/boundary/registration/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "token_broker" {
  name   = "boundary-token-broker"
  policy = <<-EOT
    path "secret/data/boundary/token-broker" {
      capabilities = ["read"]
    }
    path "secret/data/boundary/registration/*" {
      capabilities = ["create", "update", "read"]
    }
  EOT
}

# This policy is used only by HCP Boundary's Vault credential store. It can
# request a certificate from one signing role and renew/revoke its own token;
# it cannot read unrelated Vault secrets.
resource "vault_policy" "boundary_credential_store" {
  name   = "boundary-credential-store"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
    path "auth/token/revoke-self" {
      capabilities = ["update"]
    }
    path "sys/leases/renew" {
      capabilities = ["update"]
    }
    path "sys/leases/revoke" {
      capabilities = ["update"]
    }
    path "${var.ssh_mount_path}/sign/${var.ssh_signing_role_name}" {
      capabilities = ["create", "update"]
    }
  EOT
}
