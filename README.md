# HCP Boundary Worker Autoscaling with Datadog, Vault, and AWS

This is a build-from-scratch, work-in-progress lab for scaling self-managed
HCP Boundary workers from active-session demand. It uses Terraform to create an
AWS SSH target, the worker Auto Scaling Group (ASG), IAM roles, Vault AWS IAM
authentication, worker lifecycle automation, and Datadog-driven scale actions.

The design is proven one integration at a time. The ASG launches workers; each
new worker must authenticate to Vault, retrieve its uniquely scoped Boundary
activation token, and register with HCP Boundary before it can carry sessions.
Vault SSH certificate injection is the developer-to-target authentication
method. The repository includes worker-token creation, Datadog-to-ASG webhook
actions, and lifecycle deregistration automation; these require real
environment credentials and end-to-end validation before they can be claimed
as proven.




## Runnable implementation order

The Terraform stage READMEs are the runnable source of truth. The milestone
sections below explain the design and validation criteria.

| Order | Directory | Purpose |
| ---: | --- | --- |
| 1 | [`terraform/01_target`](terraform/01_target) | Target VPC and EC2 SSH host. |
| 2 | [`terraform/02_worker_iam`](terraform/02_worker_iam) | Worker and automation IAM roles. |
| 3 | [`terraform/03_vault`](terraform/03_vault) | Vault AWS auth and SSH certificate injection. |
| 4 | [`terraform/04_worker_asg`](terraform/04_worker_asg) | Worker launch template and ASG. |
| 5 | [`terraform/05_scaling`](terraform/05_scaling) | ASG policies and lifecycle hooks. |
| 6 | [`terraform/06_automation`](terraform/06_automation) | Session counter, token broker, and cleanup. |
| 7 | [`terraform/07_datadog`](terraform/07_datadog) | Monitors, webhook receiver, and scale actions. |
| 8 | [`load_testing`](load_testing) | Python and Locust validation. |


## Implementation direction

This project follows a production-inspired pattern, implemented in small
stages. Each integration must be proven with the real HCP, AWS, Vault, and
Datadog accounts before it is described as complete.

```text
1. Boundary SSH target works
2. Vault SSH certificate injection works
3. Worker bootstrap uses Vault AWS IAM auth
4. Datadog receives an accurate active-session metric
5. Datadog invokes protected ASG scale actions
6. Lifecycle cleanup deregisters workers safely
7. Private networking and production hardening
```

## Target architecture

~~~text
Scale out

Load generator
   -> Boundary sessions
   -> Datadog metric
   -> Datadog high-session monitor
   -> webhook / scale-action receiver
   -> ASG scale-out policy
   -> ASG launches EC2 worker
   -> worker authenticates to Vault with AWS IAM
   -> worker retrieves its one-time Boundary activation token
   -> worker registers with HCP Boundary
   -> worker is ready to proxy sessions

Scale in

Datadog low-session monitor
   -> webhook / scale-action receiver
   -> ASG scale-in policy
   -> selected worker enters Terminating:Wait
   -> worker cleanup process
   -> worker authenticates to Vault, if a deregistration credential is required
   -> worker deregisters from HCP Boundary
   -> CompleteLifecycleAction
   -> EC2 termination
~~~

`webhook / scale-action receiver` is implemented in Terraform Stage 07. It
uses API Gateway, a Lambda function, and a Vault-held shared secret. Configure
the Datadog webhooks only after Stage 07 is deployed.

## Developer access model — Vault secret injection

Stage 03 contains the Vault SSH certificate injection implementation, but it
must be validated against the real HCP Boundary target before it is claimed as
working. The Vault implementation supports both developer SSH certificate
injection and AWS IAM authentication for worker/bootstrap automation.

The SSH key configured by Terraform on the target EC2 instance is an
administrator bootstrap/break-glass key only; do not share it with developers.

~~~text
Developer SSO identity
-> Boundary authorization
-> Vault SSH secrets engine issues a short-lived certificate
-> Boundary worker injects the certificate into the SSH session
-> target EC2
~~~

When this milestone is complete, developers will not receive the target's
private key or a shared target password.

## Milestones

Do not continue until the current exit criterion works. This makes failures attributable to one layer instead of the whole system.

| Milestone | Scope | Exit criterion |
| --- | --- | --- |
| 1 | Boundary only | One SSH session works through Boundary. |
| 2 | Boundary + Vault | A manual EC2 worker uses its IAM role to read only its approved Vault secret. |
| 3 | Observability | Datadog reliably reports 0 -> 1 -> 2 -> 0 active sessions. |
| 4 | Worker automation | An ASG-launched instance registers without manual login. |
| 5 | Scale out | Session load changes desired capacity from 1 to 2. |
| 6 | Safe scale in | A worker enters Terminating:Wait, deregisters, then completes its lifecycle action. |
| 7 | Load tests | Python and Locust exercise the completed path. |
| 8 | Hardening | Failure cases, controls, alarms, and runbooks are tested. |

## Before you begin

You need an HCP Boundary cluster, an HCP Vault cluster (or managed Vault deployment), an AWS account, a Datadog organization with AWS integration, and an SSH host for the first target. Install and authenticate the Boundary, Vault, and AWS CLIs; Locust is only needed for Milestone 7.

The initial AWS SSH target can be created from the included [Terraform configuration](terraform/README.md). Complete that foundation before starting Milestone 1.

Both load generators are in [load_testing](load_testing/README.md). Run them
only after a single Vault-injected Boundary SSH session succeeds.

~~~bash
boundary version
vault version
aws --version
python3 --version
~~~

Set non-secret values in your shell. Keep actual identifiers in a private file or approved secret manager; do not commit them.

~~~bash
export AWS_PROFILE="aa-hellocloud"
export AWS_REGION="us-east-1"
export ASG_NAME="boundary-worker-asg"
export BOUNDARY_ADDR="https://YOUR-BOUNDARY-ADDRESS"
export BOUNDARY_TARGET_ID="tssh_xxxxxxxxxx"
export VAULT_ADDR="https://YOUR-VAULT-ADDRESS"
export VAULT_AWS_ROLE="boundary-worker"
~~~

Before automation, document:

- The Boundary worker registration method and its exact credential material.
- Worker networking: private subnets, security groups, DNS, and advertised proxy address.
- How Boundary session state reaches Datadog, including metric name, tags, aggregation, and reporting delay.
- How Datadog invokes a protected scale action: webhook receiver, Lambda, EventBridge, or another controlled component.
- Which identity can deregister a worker at termination.

Do not create a generic registration credential secret yet. Store only the values required by the registration method you select and prove.

---

## Milestone 1 — Prove Boundary first

### 1. Create HCP Boundary

Create an HCP project and Boundary cluster in the HCP portal. Record its address and configure the Boundary CLI using the lab authentication method. Keep administrative credentials outside this repository.

Create the minimum Boundary resources for an SSH test: scope, target, host set or host source, and authorization grant. The exact steps depend on your host-source and identity-provider choices.

### 2. Create an SSH target and connect manually

Use the administrator SSH key only to verify the EC2 target during bootstrap.
After credential injection is configured, developers authenticate with their
own Boundary identities and do not use this key. Ensure the target accepts SSH
from the worker network, then make one interactive connection:

~~~bash
boundary connect ssh \
  -target-id="$BOUNDARY_TARGET_ID" \
  -- -l ubuntu
~~~

In another terminal:

~~~bash
boundary sessions list
~~~

Close the connection and confirm the session disappears.

**Exit criterion:** one authorized SSH session reaches the target through Boundary and appears while active.

### 2a. Configure Vault SSH certificate injection

Complete this milestone before describing Vault secret injection as proven. For
this initial POC, use the HCP Vault **public endpoint** if it is reachable by
both HCP Boundary and the assigned worker. Move to the private endpoint only
after HCP HVN-to-AWS VPC connectivity, DNS, and routing are configured and
verified.

Set the Vault environment. HCP Vault Dedicated configuration is normally in
the `admin` namespace:

~~~bash
export VAULT_ADDR="https://YOUR-VAULT-PUBLIC-ENDPOINT:8200"
export VAULT_NAMESPACE="admin"
vault status
~~~

Then complete these steps:

1. Enable Vault's SSH secrets engine at a dedicated path, such as
   `boundary-ssh/`, and generate its certificate-authority (CA) signing key.

   ~~~bash
   vault secrets enable -path=boundary-ssh ssh
   vault write boundary-ssh/config/ca generate_signing_key=true
   vault read -field=public_key boundary-ssh/config/ca > vault-ssh-ca.pub
   ~~~

2. Create an SSH signing role, for example `boundary-ubuntu`. Permit only the
   intended target Linux principal, such as `ubuntu`, and use a
   short certificate TTL appropriate for the lab session length.

   ~~~bash
   vault write boundary-ssh/roles/boundary-ubuntu \
     key_type=ca \
     allow_user_certificates=true \
     allowed_users=ubuntu \
     default_user=ubuntu \
     ttl=30m \
     max_ttl=1h
   ~~~

3. Export the Vault SSH CA public key to the target and configure SSHD with
   `TrustedUserCAKeys`; restart SSH after validation.

   ~~~bash
   scp -i ~/.ssh/boundary-lab vault-ssh-ca.pub \
     ubuntu@"<TARGET_PUBLIC_IP>":/tmp/vault-ssh-ca.pub

   ssh -i ~/.ssh/boundary-lab ubuntu@"<TARGET_PUBLIC_IP>"
   sudo install -m 0644 /tmp/vault-ssh-ca.pub /etc/ssh/trusted-user-ca-keys.pem
   sudoedit /etc/ssh/sshd_config
   # Add: TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
   sudo sshd -t
   sudo systemctl restart ssh
   ~~~

4. Create a limited policy and a renewable Vault token for the HCP Boundary
   Vault credential store. Save this as
   `boundary-credential-store.hcl`; it can request certificates only from the
   intended signing role and manage its own token lease.

   ~~~hcl
   path "auth/token/lookup-self" {
     capabilities = ["read"]
   }

   path "auth/token/renew-self" {
     capabilities = ["update"]
   }

   path "auth/token/revoke-self" {
     capabilities = ["update"]
   }

   path "sys/leases/renew" {
     capabilities = ["update"]
   }

   path "sys/leases/revoke" {
     capabilities = ["update"]
   }

   path "boundary-ssh/sign/boundary-ubuntu" {
     capabilities = ["create", "update"]
   }
   ~~~

   Apply the policy and create a periodic token. Keep the resulting token out
   of Git and out of screenshots.

   ~~~bash
   vault policy write boundary-credential-store boundary-credential-store.hcl
   vault token create \
     -no-default-policy=true \
     -policy=boundary-credential-store \
     -orphan \
     -period=24h
   ~~~

5. Create a Vault SSH certificate credential library pointing to the signing
   path `boundary-ssh/sign/boundary-ubuntu`. Use the periodic token from the
   preceding step and an egress-worker filter that selects only workers able
   to reach both Vault and the target.
6. Create an SSH-type Boundary target and attach the library as an injected
   application credential.
7. Give developer users/groups Boundary session authorization; do not give them
   the target EC2 administrator private key.

**Credential-injection exit criterion:** a developer logs in to Boundary with
their own identity and connects to the target without seeing or supplying a
target SSH private key or password.

---

## Milestone 2 — Prove a single EC2 worker and Vault

### 3. Create the worker IAM role

Create an EC2 instance role, for example boundary-worker-ec2-role, and attach it through an instance profile. It needs only the lifecycle permissions used by the implementation. A lab starting policy is:

~~~json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:RecordLifecycleActionHeartbeat",
      "autoscaling:DescribeAutoScalingInstances"
    ],
    "Resource": "*"
  }]
}
~~~

Constrain resources and conditions in production. This instance role is also the identity Vault evaluates during AWS IAM authentication.

### 4. Configure Vault AWS authentication

An administrator enables the auth method once:

~~~bash
vault auth enable aws
vault auth list
~~~

For this implementation, the worker policy permits only registration paths:

~~~hcl
path "secret/data/boundary/registration/*" {
  capabilities = ["read"]
}
~~~

Save it as boundary-worker-policy.hcl and apply it:

~~~bash
vault policy write boundary-worker boundary-worker-policy.hcl
~~~

Bind the worker IAM role to the Vault role. Substitute the account ID:

~~~bash
vault write auth/aws/role/boundary-worker \
  auth_type=iam \
  bound_iam_principal_arn="arn:aws:iam::<ACCOUNT_ID>:role/boundary-worker-ec2-role" \
  policies="boundary-worker"
~~~

Configure the AWS-auth verification settings required by your Vault deployment. Use current Vault AWS-auth documentation for the selected auth type and trust model.

### 5. Store only required registration material

This repository uses controller-led worker registration. The Stage 06 token
broker creates one Boundary activation token for each ASG instance and writes
it only to:

~~~text
secret/boundary/registration/<instance-id>
~~~

The worker retrieves that token with AWS IAM authentication during bootstrap.
Do not create a generic `secret/boundary/worker` credential or store a Vault
root token or long-lived Boundary administrator token in a worker-readable
path.

### 6. Build one worker manually

Launch an EC2 test instance with the worker instance profile. Install Boundary and create persistent storage with the actual service account ownership:

~~~bash
sudo install -d -o boundary -g boundary /opt/boundary/worker
~~~

Build a supported HCP Boundary worker configuration for the selected registration method. Verify the proxy listener, advertised address, storage path, outbound HCP access, and security groups.

On the instance, confirm IAM identity and Vault access:

~~~bash
aws sts get-caller-identity
vault login -method=aws -role="$VAULT_AWS_ROLE"
# For an ASG worker, bootstrap reads:
# secret/boundary/registration/<its-instance-id>
~~~

Start the worker and check it from an authorized Boundary administration session:

~~~bash
sudo systemctl enable --now boundary
sudo systemctl status boundary --no-pager
boundary workers list
~~~

**Exit criterion:** the instance assumes its intended IAM role, reads only its permitted Vault path, registers as a healthy worker, and proxies a test session.

---

## Milestone 3 — Build a reliable Datadog session metric

### 7. Install and configure Datadog

Install the Datadog Agent on the manual worker using Datadog’s current installation instructions. Enable only needed signals. Tag data sufficiently to aggregate the fleet correctly:

~~~text
service:boundary
environment:lab
cluster:<boundary-cluster-id>
worker:<worker-id-or-instance-id>
~~~

A worker-local gauge is not automatically a fleet-wide session count. Account for worker restarts, multiple workers, and duplicate reports.

### 8. Publish and validate active sessions

Create one canonical metric, for example boundary.active_sessions, from a supported Boundary telemetry source, log pipeline, custom Agent check, or controlled collector. Record its source, tags, query, rollup, and expected reporting delay.

Manually validate:

~~~text
No sessions       -> 0
One SSH session   -> 1
Two SSH sessions  -> 2
Close both        -> 0
~~~

Test with more than one worker if possible. Confirm this is a cluster total rather than a double-counted sum.

**Exit criterion:** the Datadog query reliably follows 0 -> 1 -> 2 -> 0 with known latency and no double counting.

---

## Milestone 4 — Automate worker creation

### 9. Create bootstrap and cleanup artifacts

Move the proven manual steps into versioned scripts or cloud-init/user data:

1. Install and configure Boundary.
2. Authenticate to Vault using AWS auth without logging tokens.
3. Read only the approved registration material.
4. Write restrictive-permission configuration.
5. Start Boundary and wait for healthy registration.
6. Emit structured startup and failure logs.
7. Install a termination cleanup handler.

Bootstrap must be idempotent: retries and reboots cannot create duplicate registration state or unexpectedly overwrite durable worker data. Cleanup must be independently executable and log identity, lifecycle action, deregistration attempt, and result without secrets.

### 10. Create and prove the launch template

Create a launch template with the approved AMI, instance type, security groups, instance profile, tags, and bootstrap user data. Launch one test instance from it outside an ASG.

Verify cloud-init/user-data logs, Vault authentication, worker registration, and a real Boundary SSH session.

**Exit criterion:** a new instance from the template becomes a healthy worker without manual intervention.

---

## Milestone 5 — Add controlled scale out

### 11. Create the ASG

Create an ASG from the proven launch template. For the first test:

~~~text
Minimum: 1
Desired: 1
Maximum: 3
~~~

Wait for the instance to be healthy in AWS and Boundary:

~~~bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME"
boundary workers list
~~~

### 12. Implement the scale-out action

Create a scale-out policy that adds one to desired capacity. Connect the Datadog high-session monitor to a controlled component that validates the request and invokes that policy. Do not expose AWS credentials in a Datadog notification or static webhook URL.

For the first test:

~~~text
boundary.active_sessions > 5
~~~

Set an evaluation window and cooldown long enough to prevent repeated actions while a worker starts. Record monitor query, threshold, action, cooldown, and audit destination.

### 13. Test 1 worker to 2 workers

Use the Python test below to cross the threshold. Verify:

~~~text
Session metric crosses threshold
-> Datadog monitor alerts
-> Scale action is recorded
-> ASG desired capacity changes 1 -> 2
-> EC2 instance starts
-> Vault authentication succeeds
-> Second Boundary worker becomes healthy
~~~

EC2 running is not success; Boundary must show a usable worker.

**Exit criterion:** monitored load changes ASG desired capacity to 2 and both workers are healthy in Boundary.

---

## Milestone 6 — Add lifecycle-protected scale in

### 14. Create the termination lifecycle hook

Create this before automatic scale-in:

~~~bash
aws autoscaling put-lifecycle-hook \
  --lifecycle-hook-name boundary-worker-termination \
  --auto-scaling-group-name "$ASG_NAME" \
  --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING \
  --heartbeat-timeout 300 \
  --default-result CONTINUE
~~~

Select how the terminating instance receives the lifecycle event: EventBridge/SQS delivery to a local handler, an instance agent, or a supervisor. User data does not run automatically at termination.

### 15. Implement and prove cleanup

The handler must:

1. Identify the exact instance and lifecycle action.
2. Send heartbeats during cleanup.
3. Authenticate to Vault through the instance role if the design requires a secret.
4. Safely deregister or disable that exact Boundary worker.
5. Verify expected Boundary state.
6. Complete the lifecycle action with CONTINUE only after cleanup succeeds.

For IMDSv2 instance identity:

~~~bash
TOKEN=$(curl --fail --silent --show-error -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl --fail --silent --show-error \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
~~~

After confirmed cleanup:

~~~bash
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name boundary-worker-termination \
  --auto-scaling-group-name "$ASG_NAME" \
  --lifecycle-action-result CONTINUE \
  --instance-id "$INSTANCE_ID"
~~~

First create a controlled termination event. Observe Terminating:Wait, heartbeats, redacted Vault audit evidence if applicable, Boundary deregistration, and final termination.

### 16. Enable and test scale-in

Create a sustained low-session monitor that reduces desired capacity by one without crossing the ASG minimum:

~~~text
boundary.active_sessions < 2 for several minutes
~~~

Stop load and verify:

~~~text
Low-session monitor -> scale action -> desired capacity 2 -> 1
-> Terminating:Wait -> cleanup/heartbeats -> Boundary deregistration
-> CompleteLifecycleAction -> EC2 termination
~~~

**Exit criterion:** the terminating worker leaves Boundary before AWS terminates it, while the remaining worker continues serving sessions.

---

## Milestone 7 — Load testing

### 17. Python concurrent-session test

Save as boundary_load_test.py:

~~~python
import argparse
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--target-id", required=True)
parser.add_argument("--sessions", type=int, default=5)
parser.add_argument("--duration", type=int, default=300)
parser.add_argument("--delay", type=float, default=1)
parser.add_argument("--username", default="ubuntu")
args = parser.parse_args()

processes = []
try:
    for index in range(args.sessions):
        print(f"[{index + 1}/{args.sessions}] starting Boundary session")
        processes.append(subprocess.Popen([
            "boundary", "connect", "ssh", f"-target-id={args.target_id}",
            "--", "-l", args.username, "sleep", str(args.duration),
        ]))
        time.sleep(args.delay)
    for process in processes:
        process.wait()
except KeyboardInterrupt:
    print("Stopping sessions...")
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
~~~

Start small:

~~~bash
python3 boundary_load_test.py \
  --target-id "$BOUNDARY_TARGET_ID" --sessions 2 --duration 300 --delay 2
~~~

Then cross the scale-out threshold:

~~~bash
python3 boundary_load_test.py \
  --target-id "$BOUNDARY_TARGET_ID" --sessions 8 --duration 600 --delay 2
~~~

### 18. Locust test

Create an isolated environment:

~~~bash
python3 -m venv locust-env
source locust-env/bin/activate
pip install locust
~~~

Save as locustfile.py:

~~~python
import os
import subprocess
from locust import User, between, task

TARGET_ID = os.environ["BOUNDARY_TARGET_ID"]
BOUNDARY_USERNAME = os.getenv("BOUNDARY_USERNAME", "ubuntu")

class BoundaryUser(User):
    wait_time = between(1, 2)

    def on_start(self):
        self.process = subprocess.Popen([
            "boundary", "connect", "ssh", f"-target-id={TARGET_ID}",
            "--", "-l", BOUNDARY_USERNAME, "sleep", "600",
        ])

    @task
    def keep_session_alive(self):
        pass

    def on_stop(self):
        if self.process.poll() is None:
            self.process.terminate()
~~~

Run locust -f locustfile.py, open http://localhost:8089, and begin with two users at one user per second. Confirm the Datadog metric before testing ten users.

| Test | Sessions/users | Expected result |
| --- | ---: | --- |
| Baseline | 1 | One working Boundary session. |
| Metric | 2 | Datadog reports approximately two active sessions. |
| Below threshold | 4 | No scale-out. |
| Scale out | 6 | Monitor activates and capacity rises. |
| Sustained load | 10 | Two healthy workers remain available. |
| Scale in | 0 | Lifecycle-protected termination returns capacity to one. |

---

## Milestone 8 — Failure tests and production hardening

Test and document expected behavior for:

- Vault unavailable, expired token, denied policy, and AWS-auth failure.
- Boundary/HCP unavailable during startup and deregistration.
- Bootstrap failure, reboot, duplicate registration attempt, and unhealthy worker.
- Lifecycle timeout, failed cleanup, and failed lifecycle completion.
- Datadog metric delay, missing data, duplicate series, monitor flapping, and failed action delivery.
- Maximum capacity reached during high demand and a worker failure with active sessions.

Before production, require private worker subnets, narrowly scoped security groups, IMDSv2, least-privilege IAM and Vault policies, encrypted storage, secret rotation, audit logs, alerts for lifecycle/registration failures, worker-readiness checks, and a tested scaling rollback runbook.

## Evidence to capture

Never capture credentials or tokens. Capture:

- A manual Boundary connection and active session.
- EC2 IAM identity, redacted Vault audit event, and healthy Boundary worker.
- Datadog 0 -> 1 -> 2 -> 0 metric graph and monitor transitions.
- ASG desired capacity 1 -> 2 and the second healthy worker.
- Terminating:Wait, lifecycle heartbeats, worker deregistration, and capacity 2 -> 1.
- Python and Locust load runs.

## Definition of done

The lab is complete only when both paths work end to end:

~~~text
Load -> Boundary sessions -> Datadog -> scale out -> ASG instance
     -> Vault AWS auth -> healthy Boundary registration

Load ends -> Datadog -> scale in -> Terminating:Wait -> cleanup
          -> Boundary deregistration -> CompleteLifecycleAction -> termination

Developer -> Boundary authorization -> Vault SSH certificate injection
          -> Boundary worker -> target SSH access without a shared private key
~~~

Record the final registration choice, monitor queries, thresholds, cooldowns, policy locations, and operating runbook. That turns the lab into a repeatable implementation rather than a one-time demo.
