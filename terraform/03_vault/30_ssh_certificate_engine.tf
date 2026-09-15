# Dynamic SSH credentials for Boundary credential injection. Vault retains the
# CA private key; the target receives only the public CA key from the output.
resource "vault_mount" "boundary_ssh" {
  path        = var.ssh_mount_path
  type        = "ssh"
  description = "SSH certificate signing for HCP Boundary target access"
}

resource "vault_ssh_secret_backend_ca" "boundary" {
  backend              = vault_mount.boundary_ssh.path
  generate_signing_key = true
  key_type             = "ed25519"
}

resource "vault_ssh_secret_backend_role" "boundary_target" {
  name                    = var.ssh_signing_role_name
  backend                 = vault_mount.boundary_ssh.path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = var.ssh_target_username
  default_user            = var.ssh_target_username
  ttl                     = var.ssh_certificate_ttl
  max_ttl                 = var.ssh_certificate_max_ttl
  not_before_duration     = "30s"

  allowed_user_key_config {
    type    = "ed25519"
    lengths = [0]
  }

  depends_on = [vault_ssh_secret_backend_ca.boundary]
}

# This reads public CA material only. Copy the value to the target's
# /etc/ssh/trusted-user-ca-keys.pem file before testing credential injection.
data "vault_generic_secret" "boundary_ssh_ca" {
  path       = "${vault_mount.boundary_ssh.path}/config/ca"
  depends_on = [vault_ssh_secret_backend_ca.boundary]
}
