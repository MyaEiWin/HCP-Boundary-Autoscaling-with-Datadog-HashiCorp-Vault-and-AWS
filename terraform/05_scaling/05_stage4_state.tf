data "terraform_remote_state" "worker_asg" {
  backend = "local"
  config = {
    path = "${path.module}/../04_worker_asg/terraform.tfstate"
  }
}

locals {
  worker_asg_name = coalesce(var.asg_name, data.terraform_remote_state.worker_asg.outputs.asg_name)
}

