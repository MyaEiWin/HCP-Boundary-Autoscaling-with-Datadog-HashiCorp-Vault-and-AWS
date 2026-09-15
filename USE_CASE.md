# Use Case: Autoscaling HCP Boundary Workers

> Status: end-to-end integration validation is still in progress.

## Scenario

An organization uses HCP Boundary to provide secure SSH access to internal
servers. During normal operations, a small number of engineers connect through
Boundary. During incidents, deployments, support windows, or training events,
many engineers may need access at the same time.

One Boundary worker can become a capacity and availability bottleneck as
session demand grows. This project is designed to add worker capacity when
active Boundary sessions rise, and to remove unused capacity safely after
demand falls.

## How it works

```text
Normal demand
Few active sessions -> one Boundary worker handles access

High demand
More active sessions
-> Datadog detects a sustained high session count
-> a protected scaling action requests AWS Auto Scaling capacity
-> AWS Auto Scaling launches another EC2 instance
-> the instance proves its identity with AWS IAM
-> Vault returns only the approved Boundary registration material
-> the new worker registers with HCP Boundary
-> more worker capacity is available

Low demand
Session count remains low
-> Datadog requests scale-in
-> AWS puts a selected instance in Terminating:Wait
-> the worker deregisters safely from Boundary
-> the lifecycle action completes
-> AWS terminates the instance
```

Developer authentication follows a separate, complementary flow:

```text
Developer -> HCP Boundary authorization
-> Vault SSH secrets engine issues a short-lived SSH certificate
-> Boundary injects the certificate into the SSH session
-> Boundary worker proxies the session to the target
```

The developer does not receive a shared target private key or long-lived target
password.

## Example

An operations team normally has five engineers using Boundary. One worker is
enough. During a production incident, 30 engineers connect to investigate
servers at once.

The active-session metric crosses the configured threshold. Datadog alerts the
protected scaling component, which increases the Auto Scaling Group desired
capacity from one worker to two. The second worker bootstraps and registers
before it is used.

After the incident, sessions fall and remain below the low threshold. AWS does
not immediately destroy a worker: the lifecycle hook pauses termination so the
worker can remove itself from Boundary cleanly. Capacity then returns from two
workers to one.

## Benefits

- Adapts Boundary worker capacity to changing remote-access demand.
- Reduces the risk that one worker becomes a bottleneck or single point of
  failure during busy periods.
- Avoids paying for maximum worker capacity all the time.
- Uses AWS IAM and Vault instead of embedding long-lived credentials in an AMI
  or launch-template user data.
- Uses Vault-issued, short-lived SSH certificates so developers do not need a
  shared target SSH private key.
- Uses lifecycle hooks to reduce the risk of terminating a worker before its
  Boundary cleanup is complete.
- Creates useful audit and troubleshooting signals in Datadog, Vault, AWS, and
  Boundary.

## Drawbacks and risks

- The solution has operational complexity across Boundary, Vault, AWS, IAM,
  Datadog, networking, and lifecycle automation.
- Scaling is not immediate; an EC2 instance needs time to boot, authenticate,
  fetch its configuration, start Boundary, and register.
- Session count is only a proxy for load. A production design may also need CPU,
  memory, network throughput, proxy latency, and connection error signals.
- Delayed or noisy metrics can cause unnecessary scale actions. Thresholds,
  cooldowns, and sustained evaluation windows need testing.
- Scale-in can disrupt users if a worker is selected while it still has useful
  work. The POC must prove its cleanup behavior; a production design should
  also include explicit connection draining before deregistration.
- At least one worker usually remains running, so the solution is not zero-cost
  during idle periods.

## Best fit

This architecture is a good fit when secure remote-access demand is variable,
high availability matters, and the organization already operates AWS, Vault,
and Datadog or has equivalent services.

It may be unnecessary for a small team with stable, low session demand. In that
case, one well-managed Boundary worker can be simpler, cheaper, and easier to
operate.
