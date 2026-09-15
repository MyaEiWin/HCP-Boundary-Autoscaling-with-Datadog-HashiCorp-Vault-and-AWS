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

