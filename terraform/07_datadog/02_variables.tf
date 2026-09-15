variable "datadog_api_url" {
  type    = string
  default = "https://api.datadoghq.com/"
}
variable "scale_out_notification" { type = string }
variable "scale_in_notification" { type = string }

variable "aws_region" {
  type = string
}

variable "project_name" {
  type    = string
  default = "boundary-autoscaling-lab"
}

variable "asg_name" {
  type        = string
  description = "The Stage 4 worker Auto Scaling Group name."
}

variable "scale_out_policy_arn" {
  type        = string
  description = "Stage 5 scale_out_policy_arn output."
}

variable "scale_in_policy_arn" {
  type        = string
  description = "Stage 5 scale_in_policy_arn output."
}

variable "vault_addr" {
  type        = string
  description = "HCP Vault endpoint reachable by Lambda."
}

variable "vault_namespace" {
  type    = string
  default = "admin"
}
