# Stage 6 — Datadog monitors

This stage creates two Datadog monitors from the Boundary session metric:

- **Scale out:** more than 5 active sessions for 5 minutes.
- **Scale in:** fewer than 2 active sessions for 10 minutes.

It creates the monitors only. A Datadog monitor does **not** increase or
decrease the worker Auto Scaling Group until a webhook receiver is configured.

## Prerequisites

Complete these checks before applying this stage.

1. A Datadog organization is available and you can create monitors and API/app
   keys. Use the same Datadog site for the keys and API URL. The default in
   this project is the US1 site: `https://app.datadoghq.com`.

2. Stages 1 through 5 have been applied in the same AWS account and region.
   The target should be running. Stage 4's worker ASG should exist. Stage 5 is
   optional for creating the monitors, but is required before a later webhook
   can trigger ASG scaling.

3. At least one self-managed Boundary worker is registered and healthy. The
   worker must be able to proxy a Boundary connection to the target.

4. A process is already sending this exact metric to Datadog:

   ```text
   boundary.active_sessions{service:boundary}
   ```

   Open **Metrics → Explorer** in Datadog and confirm that the metric appears
   and changes during a manual Boundary session test (`0 → 1 → 0`). Do not
   apply this stage until that works. This Terraform folder creates monitors;
   it does not install the Datadog Agent or create the metric.

5. Your laptop has Terraform installed. For later AWS testing, authenticate to
   the intended AWS account too:

   ```bash
   aws sso login --profile aa-hellocloud
   export AWS_PROFILE=aa-hellocloud
   ```

## Create Datadog credentials

In Datadog, create an **API key** and an **application key** with permission
to manage monitors. Keep both private. Do not put either key in
`terraform.tfvars` or commit them to Git.

Export them only in the shell where Terraform will run:

```bash
export DATADOG_API_KEY="replace-with-your-api-key"
export DATADOG_APP_KEY="replace-with-your-app-key"
```

If your Datadog organization is not US1, set the matching API URL in
`terraform.tfvars`. For example, the EU site uses:

```hcl
datadog_api_url = "https://api.datadoghq.eu/"
```

## Choose notifications for the POC

The values beginning with `@webhook-` are Datadog notification handles. They
refer to webhook integrations configured in the Datadog UI; they are not URLs
and Terraform does not create them in this project.

For the current POC, use your email address so monitor alerts are visible
without attempting automatic scaling:

```hcl
scale_out_notification = "@your-email@example.com"
scale_in_notification  = "@your-email@example.com"
```

Later, replace these values with the actual handles after creating two
Datadog webhooks, for example:

```hcl
scale_out_notification = "@webhook-boundary-scale-out"
scale_in_notification  = "@webhook-boundary-scale-in"
```

Those webhooks need a receiver (normally API Gateway + Lambda) that invokes
the Stage 5 scale-out or scale-in policy. That automation is intentionally not
part of this POC stage yet.

## Configure and apply

Create your local variables file from the example:

```bash
cd /home/mya/Documents/ACE/HCP-Boundary-Autoscaling-with-Datadog-HashiCorp-Vault-and-AWS/terraform/06_datadog
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your selected notification values and, only if
needed, the correct `datadog_api_url`. Then run:

```bash
terraform init
terraform plan
terraform apply
```

## Verify

After the apply succeeds, find these monitors in Datadog:

- `Boundary active sessions high`
- `Boundary active sessions low`

Run a small Boundary session test. Confirm the monitor receives data and sends
the POC email notification when its threshold is crossed. Only add the webhook
scaling action after this monitoring behavior is proven.
