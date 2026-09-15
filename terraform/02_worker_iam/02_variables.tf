variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "boundary-autoscaling-lab"
}
variable "tags" {
  type    = map(string)
  default = {}
}
