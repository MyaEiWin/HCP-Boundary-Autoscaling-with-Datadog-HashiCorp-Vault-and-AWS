variable "aws_region" { type = string }
variable "project_name" {
  type    = string
  default = "boundary-autoscaling-lab"
}
variable "asg_name" { type = string }
variable "vault_addr" { type = string }
variable "vault_namespace" {
  type    = string
  default = "admin"
}
variable "boundary_addr" { type = string }
variable "boundary_scope_id" {
  type    = string
  default = "global"
}
variable "datadog_site" {
  type    = string
  default = "datadoghq.com"
}
