# Boundary load testing

Run these tests only after Vault SSH certificate injection works and the target
is an SSH-type Boundary target (`tssh_...`). Authenticate with the Boundary CLI
before starting either test.

## Python concurrent sessions

```bash
cd load_testing
python3 boundary_load_test.py \
  --target-id "$BOUNDARY_TARGET_ID" \
  --sessions 2 \
  --duration 300 \
  --delay 2 \
  --username ubuntu
```

Build gradually: `1`, then `2`, then `4`, then the Datadog threshold. Stop
with `Ctrl+C`; the script terminates its child Boundary processes.

## Locust users

```bash
cd load_testing
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export BOUNDARY_TARGET_ID="tssh_xxxxxxxxx"
export BOUNDARY_USERNAME="ubuntu"
export BOUNDARY_SESSION_DURATION="600"
locust -f locustfile.py
```

Open `http://localhost:8089`. Start with two users at one user per second.
Each Locust user holds one Boundary SSH session. Click **Stop** to close users
and their child SSH processes.

## What to verify

```text
Boundary sessions list
-> active-session metric changes in Datadog
-> only after Stage 7 is fully configured: ASG scale-out and scale-in
```

Never begin the large-load test before confirming a single SSH certificate
injection session works.
