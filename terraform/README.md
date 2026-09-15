# Staged Terraform deployment

Each numbered directory is an independent Terraform root module. Run a stage
only after the previous stage has been applied and verified. Terraform reads all
`.tf` files *inside the selected stage directory* together; do not run files
individually.

| Stage | Directory | Purpose | Status |
| --- | --- | --- | --- |
| 1 | `01_target` | VPC, public subnet, security group, and Ubuntu SSH target. | Ready to run. |
| 2 | `02_worker_iam` | IAM role and instance profile for Boundary workers. | Add after target verification. |
| 3 | `03_vault` | Vault AWS auth method, worker policy, and role. | Add after worker IAM role exists. |
| 4 | `04_worker_asg` | Private worker networking, launch template, and ASG. | Requires the selected Boundary registration design. |
| 5 | `05_scaling` | Scaling policies and termination lifecycle hook. | Add after one ASG worker is healthy. |
| 6 | `06_datadog` | Optional Datadog monitor automation. | Add after the session metric is proven. |

## Run a stage

### Generate the administrator bootstrap key

Generate this key once on your local computer. Terraform receives only its
public half and registers it with the EC2 target. Keep the private half local;
developers use Boundary and Vault-issued SSH certificates instead.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/boundary-lab -C "boundary-lab"
cat ~/.ssh/boundary-lab.pub
```

Copy the complete output of the `.pub` file into the `admin_public_key` value
in Stage 1's `terraform.tfvars` file. Never commit or share
`~/.ssh/boundary-lab`.

For example, run Stage 1 from its own directory:

```bash
cd 01_target
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars before continuing.
terraform init
terraform plan
terraform apply
```

Each stage will have its own `.terraform` folder and state file. Do not run
`terraform apply` from this parent directory.

### Stage 2 — Create worker IAM roles

After Stage 1 target creation and direct SSH validation succeed, create the
worker instance profile and token-broker Lambda role:

```bash
cd ../02_worker_iam
terraform init
terraform plan
terraform apply
terraform output
```

Save these outputs in private notes; Stage 3 requires the two role ARNs and
Stage 4 requires the instance-profile name:

```text
worker_role_arn
worker_instance_profile_name
token_broker_role_arn
```

Stage 2 creates IAM resources only. It does not launch an EC2 instance.

## Stage 1 files

| File | Purpose |
| --- | --- |
| `00_versions.tf` | Terraform and AWS provider version requirements. |
| `01_providers.tf` | AWS provider and common resource tags. |
| `02_variables.tf` | Configurable lab inputs. |
| `10_vpc.tf` | VPC and internet gateway. |
| `20_subnets.tf` | Public target subnet and routing. |
| `30_security_group.tf` | Restricted SSH security group for the target. |
| `40_ec2_target.tf` | Ubuntu AMI lookup, SSH key pair, and target EC2 instance. |
| `90_outputs.tf` | Addresses and IDs needed by later stages. |

## Prerequisites

- Terraform 1.6 or later.
- AWS credentials configured locally with permission to create VPC, EC2,
  security-group, route-table, internet-gateway, and key-pair resources.
- An SSH public key. Generate one if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/boundary-lab -C "boundary-lab"
```

## Deploy

From this directory:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Set `admin_public_key` to the complete contents of your `.pub` file.
- Set `allowed_ssh_cidrs` to your current public IP with `/32`.
- Optionally change the region and project prefix.

Then review the proposed resources and apply only if they are correct:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Get the target addresses:

```bash
terraform output
```

Directly verify the instance before adding Boundary:

```bash
ssh -i ~/.ssh/boundary-lab ubuntu@$(terraform output -raw target_public_ip)
```

## Important networking note

The target is public temporarily so you can prove SSH and bootstrap the lab.
Its security group does **not** allow SSH from the internet. It permits only
the CIDRs in `allowed_ssh_cidrs`.

When the self-managed Boundary worker is added, it should run in a private
subnet. Update the target security group to allow TCP 22 from the worker
security group, then configure the Boundary target with `target_private_ip`.

## Cleanup

After the lab, remove the resources with:

```bash
terraform destroy
```

Review the destroy plan carefully before confirming it.
