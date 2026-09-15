# Stage 5 — Scaling and lifecycle hooks

Creates scale-out/in policies and the termination lifecycle hook. Run only
after Stage 4 has created the ASG. The ASG name is read automatically from
Stage 4 local state.

For the POC, leave `enable_launch_hook = false`. Do not enable the launch hook
until a token-broker Lambda writes a fresh activation token and completes the
lifecycle action; otherwise new workers are abandoned.
