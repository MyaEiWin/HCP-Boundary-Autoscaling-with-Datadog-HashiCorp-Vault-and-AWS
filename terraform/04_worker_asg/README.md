# Stage 4 — Self-managed Boundary worker ASG

This stage creates an ASG with one initial self-managed worker. Its bootstrap
polls Vault for an activation token written by Stage 5's token broker.

For this lab the worker uses the Stage 1 public subnet, because its proxy
address must be reachable by approved Boundary clients. Use private networking
and a deliberate ingress design in production.

For this proof of concept, no custom worker AMI is required. Terraform selects
the latest Ubuntu 24.04 AMI, then EC2 user data installs Boundary Enterprise,
Vault CLI, AWS CLI, and jq at startup. This makes the first worker slower to
become ready, but keeps the lab fully Terraform-driven.

Copy the required Stage 2 instance-profile name into `terraform.tfvars`.
Later, you can build a hardened worker AMI and set `worker_ami_id` to use it.

This lab reads the VPC ID, target subnet ID, and target security-group ID
automatically from Stage 1's local state file. You do not need to copy them
into `terraform.tfvars`. Stage 1 must remain applied and its state file must
remain in `../01_target/terraform.tfstate`.
