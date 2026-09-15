output "vault_ssh_signing_path" {
  description = "Vault API path configured in the Boundary SSH certificate credential library."
  value       = "${vault_mount.boundary_ssh.path}/sign/${vault_ssh_secret_backend_role.boundary_target.name}"
}

output "vault_ssh_ca_public_key" {
  description = "Vault SSH CA public key. Install it on the target as TrustedUserCAKeys; it is public material but marked sensitive to reduce accidental console exposure."
  value       = data.vault_generic_secret.boundary_ssh_ca.data["public_key"]
  sensitive   = true
}
