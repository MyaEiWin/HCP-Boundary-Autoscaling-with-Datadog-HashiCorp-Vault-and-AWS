# Stage 7 — Datadog monitoring and scale actions

This single stage completes the Datadog control path:

```text
Boundary sessions
-> Stage 06 session-counter Lambda
-> Datadog metric: boundary.active_sessions{service:boundary}
-> Datadog monitor
-> Datadog webhook
-> API Gateway
-> scale-action Lambda
-> Stage 05 ASG policy
```

The Lambda accepts only `/scale-out` and `/scale-in`. It verifies a shared
secret read from Vault with AWS IAM authentication before it can execute a
scaling policy.

## Prerequisites

- Stage 05 is applied. Record its two policy outputs:

  ```bash
  cd ../05_scaling
  terraform output -raw scale_out_policy_arn
  terraform output -raw scale_in_policy_arn
  ```

- Stage 06 is applied and its Vault Lambda-auth script has run.
- The `session-counter` Lambda has proven that it publishes:

  ```text
  boundary.active_sessions{service:boundary}
  ```

- You have a Datadog API key and application key allowed to manage monitors
  and webhooks. Export them only in your terminal:

  ```bash
  export DATADOG_API_KEY="replace-with-api-key"
  export DATADOG_APP_KEY="replace-with-app-key"
  ```

- Your terminal is authenticated to Vault as an administrator. For HCP Vault
  Dedicated, normally use `VAULT_NAMESPACE=admin`.

## Deploy the AWS receiver and monitors

```bash
cd /home/mya/Documents/ACE/HCP-Boundary-Autoscaling-with-Datadog-HashiCorp-Vault-and-AWS/terraform/07_datadog
cp terraform.tfvars.example terraform.tfvars
```

In `terraform.tfvars`, set the real AWS region, ASG name, Vault address, and
the two Stage 05 policy ARNs. Keep these monitor notifications exactly as
shown; the webhook script creates the matching Datadog webhook names:

```hcl
scale_out_notification = "@webhook-boundary-scale-out"
scale_in_notification  = "@webhook-boundary-scale-in"
```

Deploy:

```bash
terraform init
terraform plan
terraform apply
```

## Configure Vault and Datadog webhooks

The first script generates the shared secret directly in Vault, creates the
Vault policy, and binds the scale-action Lambda IAM role to Vault AWS auth.
The second script reads that secret from Vault and creates or updates the two
Datadog webhooks. The secret never enters Terraform state or Git.

```bash
chmod +x scripts/*.sh
./scripts/configure-vault-webhook-auth.sh
./scripts/configure-datadog-webhooks.sh
```

If your Datadog site is not US1, set its API base URL before the second script.
For example:

```bash
export DD_API_URL="https://api.datadoghq.eu"
```

## Verify the receiver safely

Run one authenticated scale-out request before enabling a monitor-driven test:

```bash
endpoint=$(terraform output -raw scale_out_webhook_url)
secret=$(vault kv get -field=shared_secret secret/boundary/automation/datadog-webhook)
curl --fail -X POST "$endpoint" -H "X-Boundary-Webhook-Secret: $secret" -d '{}'
unset secret
```

Confirm the ASG activity history records the scale-out policy. A request with
no `X-Boundary-Webhook-Secret` header must return HTTP `401`.

Allow the ASG cooldown to finish. Then test the metric at `0 -> 1 -> 0`,
enable the Stage 05 launch hook only after the token broker is working, and
finally run the Python or Locust load test.
