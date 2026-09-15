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
