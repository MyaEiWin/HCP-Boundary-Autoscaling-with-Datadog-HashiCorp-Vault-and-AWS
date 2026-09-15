"""Authenticated Datadog webhook receiver for Boundary worker scaling."""
import base64
import hmac
import json
import os
from urllib import request

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
    credentials = boto3.Session().get_credentials().get_frozen_credentials()
    SigV4Auth(credentials, "sts", region).add_auth(sts_request)
    payload = {
        "role": os.environ["VAULT_AWS_ROLE"],
        "iam_http_request_method": "POST",
        "iam_request_url": base64.b64encode(b"https://sts.amazonaws.com/").decode(),
        "iam_request_body": base64.b64encode(b"Action=GetCallerIdentity&Version=2011-06-15").decode(),
        "iam_request_headers": base64.b64encode(json.dumps(dict(sts_request.headers)).encode()).decode(),
    }
    response = http_json(
        os.environ["VAULT_ADDR"].rstrip("/") + "/v1/auth/aws/login",
        "POST",
        payload,
        {"X-Vault-Namespace": os.environ.get("VAULT_NAMESPACE", "admin")},
    )
    return response["auth"]["client_token"]


def webhook_secret():
    response = http_json(
        os.environ["VAULT_ADDR"].rstrip("/") + "/v1/secret/data/boundary/automation/datadog-webhook",
        headers={
            "X-Vault-Token": vault_token(),
            "X-Vault-Namespace": os.environ.get("VAULT_NAMESPACE", "admin"),
        },
    )
    return response["data"]["data"]["shared_secret"]


def response(status, body):
    return {"statusCode": status, "headers": {"content-type": "application/json"}, "body": json.dumps(body)}


def lambda_handler(event, context):
    supplied = (event.get("headers") or {}).get("x-boundary-webhook-secret", "")
    if not hmac.compare_digest(supplied, webhook_secret()):
        return response(401, {"message": "unauthorized"})

    path = event.get("rawPath", "")
    policies = {"/scale-out": os.environ["SCALE_OUT_POLICY_NAME"], "/scale-in": os.environ["SCALE_IN_POLICY_NAME"]}
    policy = policies.get(path)
    if policy is None:
        return response(404, {"message": "unknown action"})

    boto3.client("autoscaling").execute_policy(
        AutoScalingGroupName=os.environ["ASG_NAME"],
        PolicyName=policy,
        HonorCooldown=True,
    )
    return response(202, {"message": "scaling policy requested", "policy": policy})
