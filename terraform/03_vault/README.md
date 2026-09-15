# Stage 3 — Vault AWS authentication

This stage enables Vault AWS IAM auth and creates separate Vault roles for
workers and the Lambda token broker. It requires an administrator Vault token;
keep it in the `VAULT_TOKEN` environment variable, never in a tfvars file.

## Prerequisites

Complete these before running this stage:

- A running **HCP Vault cluster** or a self-managed HashiCorp Vault cluster.
- A Vault endpoint reachable from the computer running Terraform.
- Vault CLI installed locally: `vault version`.
- A Vault administrator token with permission to enable auth methods, create
  policies, and create AWS auth roles.
- Stage 2 successfully applied, with `worker_role_arn` and
  `token_broker_role_arn` recorded.
- AWS IAM Identity Center/CLI authentication still active for the AWS roles
  that Stage 2 created.

For this lab, create the Vault cluster first in HCP, wait until it is running,
then obtain the endpoint and a temporary administrator token through your
approved HCP Vault administration process. Do not use a Vault root token for
normal day-to-day work and never add any Vault token to Git or a tfvars file.

## Select the Vault endpoint

Set `VAULT_ADDR` to the endpoint reachable from the computer running
Terraform. For this lab, when Terraform runs on your laptop, use the HCP Vault
**public cluster endpoint**:

```bash
export VAULT_ADDR="https://YOUR-HCP-VAULT-PUBLIC-ENDPOINT"
```

Use the private Vault endpoint only when Terraform runs in the private network
or your laptop has private connectivity, such as through a VPN. This address is
not the HCP Boundary cluster address.

Later, the EC2 Boundary worker must use a Vault endpoint reachable from its
VPC. The lab initially uses the public endpoint; a production private-network
design should use the private endpoint and appropriate DNS/connectivity.

```bash
export VAULT_ADDR="https://YOUR-VAULT-ADDRESS"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="<temporary-admin-token>"
cp terraform.tfvars.example terraform.tfvars
# Paste Stage 2 output ARNs into terraform.tfvars.
terraform init
terraform plan
terraform apply
```

Before Stage 5, manually store the Boundary API credential used only by the
token broker at `secret/boundary/token-broker`. Do not grant this credential to
the worker role.

> Lab limitation: all workers with the shared IAM role can read registration
> paths. A production design needs per-instance delivery controls or a brokered
> one-time response; do not treat this policy as production-ready.
