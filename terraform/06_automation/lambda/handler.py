"""Runtime handlers for the Boundary autoscaling lab.

Secrets are deliberately read from Vault paths at invocation time. Populate the
paths documented in Stage 6 README; never place those values in Lambda env vars.
"""
import base64, json, os, time
from urllib import request, parse

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def http_json(url, method="GET", body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    req = request.Request(url, data=data, headers=headers or {}, method=method)
    with request.urlopen(req, timeout=20) as response:
        return json.loads(response.read() or b"{}")


def vault_token():
    region = os.environ.get("AWS_REGION", "us-east-1")
    sts_request = AWSRequest(method="POST", url="https://sts.amazonaws.com/", data="Action=GetCallerIdentity&Version=2011-06-15")
    SigV4Auth(boto3.Session().get_credentials().get_frozen_credentials(), "sts", region).add_auth(sts_request)
    payload = {
        "role": os.environ["VAULT_AWS_ROLE"],
        "iam_http_request_method": "POST",
        "iam_request_url": base64.b64encode(b"https://sts.amazonaws.com/").decode(),
        "iam_request_body": base64.b64encode(b"Action=GetCallerIdentity&Version=2011-06-15").decode(),
        "iam_request_headers": base64.b64encode(json.dumps(dict(sts_request.headers)).encode()).decode(),
    }
    response = http_json(os.environ["VAULT_ADDR"].rstrip("/") + "/v1/auth/aws/login", "POST", payload, {"X-Vault-Namespace": os.environ.get("VAULT_NAMESPACE", "admin")})
    return response["auth"]["client_token"]


def vault_secret(token, path):
    response = http_json(os.environ["VAULT_ADDR"].rstrip("/") + "/v1/" + path, headers={"X-Vault-Token": token, "X-Vault-Namespace": os.environ.get("VAULT_NAMESPACE", "admin")})
    return response["data"]["data"]


def boundary_headers(token): return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def session_counter(event, context):
    vault = vault_token()
    boundary = vault_secret(vault, "secret/data/boundary/automation/session-counter")["boundary_token"]
    datadog = vault_secret(vault, "secret/data/boundary/automation/datadog")["api_key"]
    query = parse.urlencode({"scope_id": os.environ["BOUNDARY_SCOPE_ID"], "recursive": "true", "page_size": "1000"})
    sessions = http_json(os.environ["BOUNDARY_ADDR"].rstrip("/") + "/v1/sessions?" + query, headers=boundary_headers(boundary)).get("items", [])
    active = sum(item.get("status") == "active" for item in sessions)
    payload = {"series": [{"metric": "boundary.active_sessions", "points": [[int(time.time()), active]], "type": "gauge", "tags": ["service:boundary"]}]}
    http_json(f"https://api.{os.environ['DD_SITE']}/api/v1/series", "POST", payload, {"DD-API-KEY": datadog, "Content-Type": "application/json"})
    return {"active_sessions": active}


def token_broker(event, context):
    # Controller-led worker creation is intentionally protected by a Boundary
    # automation token stored in Vault. Boundary API details are kept here so
    # every launched instance receives a unique, one-time activation token.
    detail = event["detail"]
    instance_id = detail["EC2InstanceId"]
    vault = vault_token()
    boundary = vault_secret(vault, "secret/data/boundary/automation/token-broker")["boundary_token"]
    worker = http_json(os.environ["BOUNDARY_ADDR"].rstrip("/") + "/v1/workers:create:controller-led", "POST", {"scope_id": "global", "name": f"aws-asg-{instance_id}"}, boundary_headers(boundary))
    item = worker.get("item", worker)
    activation = item.get("controller_generated_activation_token") or item.get("attributes", {}).get("controller_generated_activation_token")
    if not activation: raise RuntimeError("Boundary did not return a controller-led activation token")
    http_json(os.environ["VAULT_ADDR"].rstrip("/") + f"/v1/secret/data/boundary/registration/{instance_id}", "POST", {"data": {"activation_token": activation}}, {"X-Vault-Token": vault, "X-Vault-Namespace": os.environ.get("VAULT_NAMESPACE", "admin")})
    boto3.client("autoscaling").complete_lifecycle_action(AutoScalingGroupName=detail["AutoScalingGroupName"], LifecycleHookName=detail["LifecycleHookName"], LifecycleActionToken=detail["LifecycleActionToken"], LifecycleActionResult="CONTINUE")
    return {"worker": item.get("id"), "instance": instance_id}


def cleanup(event, context):
    detail = event["detail"]; instance_id = detail["EC2InstanceId"]
    vault = vault_token(); boundary = vault_secret(vault, "secret/data/boundary/automation/cleanup")["boundary_token"]
    query = parse.urlencode({"scope_id": "global", "filter": f'"/name" == "aws-asg-{instance_id}"'})
    workers = http_json(os.environ["BOUNDARY_ADDR"].rstrip("/") + "/v1/workers?" + query, headers=boundary_headers(boundary)).get("items", [])
    if workers:
        worker = workers[0]
        http_json(os.environ["BOUNDARY_ADDR"].rstrip("/") + f"/v1/workers/{worker['id']}?version={worker['version']}", "DELETE", headers=boundary_headers(boundary))
    boto3.client("autoscaling").complete_lifecycle_action(AutoScalingGroupName=detail["AutoScalingGroupName"], LifecycleHookName=detail["LifecycleHookName"], LifecycleActionToken=detail["LifecycleActionToken"], LifecycleActionResult="CONTINUE")
    return {"instance": instance_id, "deleted": bool(workers)}
