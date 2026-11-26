"""Forward AWS Config / Security Hub alerts from SNS to Slack.

The Slack webhook URL is read from AWS Secrets Manager at runtime (never from an
environment variable) and is never logged. Failures raise so Lambda's async retry
and the SQS dead-letter queue capture undelivered alerts.
"""

import json
import logging
import os
import urllib.request
from urllib.parse import urlparse

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

ALLOWED_HOSTS = {"hooks.slack.com"}
REQUEST_TIMEOUT_SECONDS = 10
MAX_MESSAGE_CHARS = 2800

_webhook_url_cache = None


def _log(level, message, **fields):
    LOGGER.log(level, json.dumps({"message": message, **fields}))


def _get_webhook_url():
    """Fetch (and cache for the container lifetime) the Slack webhook URL."""
    global _webhook_url_cache
    if _webhook_url_cache is None:
        import boto3  # imported lazily so unit tests do not need AWS libraries

        client = boto3.client("secretsmanager")
        secret = client.get_secret_value(SecretId=os.environ["SLACK_WEBHOOK_SECRET_ARN"])
        _webhook_url_cache = secret["SecretString"].strip()

    parsed = urlparse(_webhook_url_cache)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError("Configured webhook is not an https Slack webhook URL")
    return _webhook_url_cache


def format_message(raw_message):
    """Render an SNS message body as a Slack-safe, size-bounded code block."""
    try:
        body = json.dumps(json.loads(raw_message), indent=2, sort_keys=True)
    except (TypeError, ValueError):
        body = str(raw_message)

    body = body.replace("```", "'''")
    if len(body) > MAX_MESSAGE_CHARS:
        body = body[:MAX_MESSAGE_CHARS] + "\n... (truncated)"
    return f":rotating_light: *AWS Security Alert*\n```{body}```"


def _post(url, text):
    request = urllib.request.Request(  # noqa: S310 - scheme and host validated above
        url,
        data=json.dumps({"text": text}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:  # noqa: S310
        return response.status


def lambda_handler(event, context):
    records = event.get("Records", [])
    url = _get_webhook_url()

    for record in records:
        status = _post(url, format_message(record["Sns"]["Message"]))
        if status != 200:
            raise RuntimeError(f"Slack returned HTTP {status}")

    _log(logging.INFO, "Alerts forwarded", count=len(records))
    return {"statusCode": 200, "delivered": len(records)}
