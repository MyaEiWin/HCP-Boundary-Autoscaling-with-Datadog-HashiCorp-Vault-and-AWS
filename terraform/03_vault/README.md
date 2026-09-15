# Stage 3 — Vault AWS authentication

This stage enables Vault AWS IAM auth, creates separate Vault roles for
workers and the Lambda token broker, and configures the Vault SSH certificate
authority used for Boundary credential injection. It requires an administrator
Vault token; keep it in the `VAULT_TOKEN` environment variable, never in a
tfvars file.

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

The apply creates the `boundary-ssh/` SSH secrets engine, its CA signing key,
the `boundary-ubuntu` signing role, and the limited
`boundary-credential-store` policy. Export the public CA key and install it on
the Stage 1 target before creating the Boundary credential library:

```bash
terraform output -raw vault_ssh_ca_public_key > vault-ssh-ca.pub

scp -i ~/.ssh/boundary-lab vault-ssh-ca.pub \
  ubuntu@"<TARGET_PUBLIC_IP>":/tmp/vault-ssh-ca.pub

scp -i ~/.ssh/boundary-lab scripts/install-target-ssh-ca.sh \
  ubuntu@"<TARGET_PUBLIC_IP>":/tmp/install-target-ssh-ca.sh

ssh -i ~/.ssh/boundary-lab ubuntu@"<TARGET_PUBLIC_IP>"
sudo /tmp/install-target-ssh-ca.sh /tmp/vault-ssh-ca.pub
```

Stage 3 does not create the HCP Boundary credential store because its Vault
token must be entered through a protected process and must not be placed in
Terraform configuration or local state. The next implementation stage will
use this policy to create a periodic token, then configure the Boundary Vault
credential store, SSH certificate library, and SSH target association.

## Configure HCP Boundary credential injection

Use the supplied scripts for actions that require a Vault token. They keep the
token out of Terraform state and source control.

The target identified by `BOUNDARY_TARGET_ID` must be an **SSH target**
(`tssh_...`), not a TCP target (`ttcp_...`). SSH credential injection is not
supported for TCP targets.

```bash
chmod +x scripts/*.sh
./scripts/create-boundary-credential-store-token.sh
# Copy the displayed token into the current terminal only:
export BOUNDARY_VAULT_CREDENTIAL_STORE_TOKEN="<periodic-token>"

export BOUNDARY_PROJECT_ID="p_xxxxxxxxx"
export BOUNDARY_TARGET_ID="tssh_xxxxxxxxx"
export VAULT_SSH_SIGNING_PATH="$(terraform output -raw vault_ssh_signing_path)"
export SSH_TARGET_USERNAME="ubuntu"

./scripts/configure-boundary-ssh-injection.sh
```

For this public-Vault POC, leave `BOUNDARY_WORKER_FILTER` unset. When you move
to a private Vault endpoint, set it to a filter matching a worker that can
reach Vault, for example:

```bash
export BOUNDARY_WORKER_FILTER='"vault" in "/tags/type"'
```

After the script succeeds, test the existing SSH target with `boundary connect
ssh`. Do not add `-i ~/.ssh/boundary-lab`; a successful connection proves that
Boundary injected a short-lived Vault SSH certificate.

Before Stage 5, manually store the Boundary API credential used only by the
token broker at `secret/boundary/token-broker`. Do not grant this credential to
the worker role.

> Lab limitation: all workers with the shared IAM role can read registration
> paths. A production design needs per-instance delivery controls or a brokered
> one-time response; do not treat this policy as production-ready.
