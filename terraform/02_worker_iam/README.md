# Stage 2 — Worker and token-broker IAM

This stage creates two separate identities:

- The EC2 worker role, used by each self-managed Boundary worker to log in to
  Vault using AWS IAM.
- The Lambda token-broker role, used later to create a fresh registration
  secret in Vault for a newly launched ASG instance.

Run after Stage 1:

```bash
terraform init
terraform plan
terraform apply
terraform output
```

Copy `worker_role_arn` and `token_broker_role_arn`; Stage 3 requires both.
