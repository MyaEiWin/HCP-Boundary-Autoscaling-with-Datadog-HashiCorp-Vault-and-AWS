variable "worker_role_arn" { type = string }
variable "token_broker_role_arn" { type = string }
variable "vault_aws_role_name" {
  type    = string
  default = "boundary-worker"
}
variable "vault_broker_role_name" {
  type    = string
  default = "boundary-token-broker"
}

variable "ssh_mount_path" {
  description = "Vault mount path for the SSH certificate signing engine."
  type        = string
  default     = "boundary-ssh"
}

variable "ssh_signing_role_name" {
  description = "Vault SSH signing role used by the Boundary credential library."
  type        = string
  default     = "boundary-ubuntu"
}

variable "ssh_target_username" {
  description = "Linux username accepted by the SSH target for Vault-signed certificates."
  type        = string
  default     = "ubuntu"
}

variable "ssh_certificate_ttl" {
  description = "Requested Vault SSH certificate lifetime. Keep it at least as long as the Boundary target session maximum."
  type        = string
  default     = "30m"
}

variable "ssh_certificate_max_ttl" {
  description = "Maximum Vault SSH certificate lifetime."
  type        = string
  default     = "1h"
}
