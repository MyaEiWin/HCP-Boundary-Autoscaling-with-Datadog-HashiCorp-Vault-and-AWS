# Stage 6 — Automation Lambdas

This stage deploys three Lambda functions and EventBridge rules:

- `session-counter`: counts active Boundary sessions every minute and publishes
  `boundary.active_sessions{service:boundary}` to Datadog.
- `token-broker`: handles the ASG launch lifecycle event, creates a unique
  controller-led Boundary worker activation token, and writes it to Vault.
- `cleanup`: handles the ASG termination lifecycle event, deletes the matching
  Boundary worker, then completes the lifecycle action.

## Before applying

Complete Stages 1 through 5. Do not enable the Stage 5 launch hook yet.

Populate these Vault KV v2 paths manually with dedicated, least-privilege
Boundary tokens and the Datadog API key. Do not put these values in Terraform:

```text
secret/boundary/automation/session-counter  boundary_token=<read-only-token>
secret/boundary/automation/token-broker     boundary_token=<worker-create-token>
secret/boundary/automation/cleanup          boundary_token=<worker-delete-token>
secret/boundary/automation/datadog          api_key=<Datadog-API-key>
```

The supplied post-apply script creates the three Vault AWS-auth roles and
least-privilege policies after the Lambda role ARNs exist.

## Deploy

```bash
cd terraform/06_automation
cp terraform.tfvars.example terraform.tfvars
# Edit only non-secret values.
terraform init
terraform plan
terraform apply
chmod +x scripts/configure-vault-lambda-auth.sh
./scripts/configure-vault-lambda-auth.sh
```

The script creates the three least-privilege policies and AWS IAM auth roles
after the Lambda role ARNs exist. It requires a Vault administrator login but
does not put a Vault token in Terraform or Git.

After this succeeds, update Stage 5 `terraform.tfvars`:

```hcl
enable_launch_hook = true
```

Then apply Stage 5 again. The token-broker Lambda must exist before enabling
this hook, otherwise new ASG workers will be abandoned.

## Test order

1. Invoke `session-counter` manually and confirm its Datadog metric.
2. Verify the metric shows `0 -> 1 -> 0` during one Boundary SSH session.
3. Continue with Stage 7 to configure the protected Datadog webhook receiver.
4. Increase ASG desired capacity by one and verify token broker registration.
5. Decrease capacity and verify the cleanup Lambda handles `Terminating:Wait`.

Review the Lambda CloudWatch logs after every test. This stage cannot be called
complete until the Boundary API permissions and the complete launch/termination
paths have been proven with real credentials.
