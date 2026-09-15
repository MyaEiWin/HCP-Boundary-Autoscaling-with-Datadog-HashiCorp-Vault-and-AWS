# This lab uses local Terraform state. Stage 4 reads the VPC, subnet, and
# target security-group outputs created by Stage 1. For team/production use,
# replace this with a protected remote backend such as S3 plus state locking.
data "terraform_remote_state" "target" {
  backend = "local"

  config = {
    path = "${path.module}/../01_target/terraform.tfstate"
  }
}

locals {
  target_vpc_id = coalesce(var.vpc_id, data.terraform_remote_state.target.outputs.vpc_id)
  worker_subnet_id = coalesce(
    var.worker_subnet_id,
    data.terraform_remote_state.target.outputs.target_subnet_id,
  )
  target_security_group_id = coalesce(
    var.target_security_group_id,
    data.terraform_remote_state.target.outputs.target_security_group_id,
  )
}

