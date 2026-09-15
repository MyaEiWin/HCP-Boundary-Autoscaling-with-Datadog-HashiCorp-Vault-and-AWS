variable "aws_region" {
  description = "AWS region where the lab target is created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short prefix used in resource names."
  type        = string
  default     = "boundary-autoscaling-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public target subnet."
  type        = string
  default     = "10.50.10.0/24"
}

variable "availability_zone" {
  description = "Optional availability zone. Leave null to use the first available zone."
  type        = string
  default     = null
  nullable    = true
}

variable "admin_public_key" {
  description = "SSH public key contents for the ubuntu user. Provide the contents, not a filename."
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs permitted to SSH directly to the lab target, for example [\"203.0.113.10/32\"]."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Provide one or more specific trusted CIDRs. Do not expose SSH to 0.0.0.0/0."
  }
}

variable "target_instance_type" {
  description = "Instance type for the lab SSH target."
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}

