variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "boundary-autoscaling-lab"
}
variable "vpc_id" {
  description = "Optional override. By default this is read from Stage 1 state."
  type        = string
  default     = null
  nullable    = true
}
variable "worker_subnet_id" {
  description = "Optional override. By default this is read from Stage 1 state."
  type        = string
  default     = null
  nullable    = true
}
variable "target_security_group_id" {
  description = "Optional override. By default this is read from Stage 1 state."
  type        = string
  default     = null
  nullable    = true
}
variable "worker_instance_profile_name" { type = string }
variable "worker_ami_id" {
  description = "Optional custom worker AMI override. Leave null to use the latest Ubuntu 24.04 AMI."
  type        = string
  default     = null
  nullable    = true
}
variable "boundary_cluster_id" { type = string }
variable "vault_addr" { type = string }
variable "vault_aws_role" {
  type    = string
  default = "boundary-worker"
}
variable "allowed_client_cidrs" { type = list(string) }
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "min_size" {
  type    = number
  default = 1
}
variable "max_size" {
  type    = number
  default = 3
}
