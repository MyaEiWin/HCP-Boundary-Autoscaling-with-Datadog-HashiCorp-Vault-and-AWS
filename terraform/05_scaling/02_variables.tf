variable "aws_region" { type = string }
variable "asg_name" {
  description = "Optional override. By default this is read from Stage 4 state."
  type        = string
  default     = null
  nullable    = true
}
variable "project_name" {
  type    = string
  default = "boundary-autoscaling-lab"
}
variable "enable_launch_hook" {
  description = "Enable only after the token-broker Lambda can create and store worker tokens."
  type        = bool
  default     = false
}
