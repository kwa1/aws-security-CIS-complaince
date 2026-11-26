"""Unit tests for the Slack notifier. Run: python -m pytest modules/notifications/lambda/tests"""

import json
import sys
import urllib.request
from pathlib import Path
from unittest import mock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import handler  # noqa: E402

GOOD_URL = "https://hooks.slack.com/services/T000/B000/XXXX"


@pytest.fixture(autouse=True)
def _reset_cache():
    handler._webhook_url_cache = None
    yield
    handler._webhook_url_cache = None


def _event(message):
    return {"Records": [{"Sns": {"Message": message}}]}


def _fake_boto3(secret):
    client = mock.Mock()
    client.get_secret_value.return_value = {"SecretString": secret}
    fake = mock.Mock()
    fake.client.return_value = client
    return fake, client


def test_format_message_pretty_prints_json_and_escapes_fences():
    text = handler.format_message(json.dumps({"RuleName": "r", "x": "```evil```"}))
    assert text.startswith(":rotating_light:")
    assert "```evil```" not in text
    assert '"RuleName": "r"' in text


def test_format_message_truncates_long_messages():
    text = handler.format_message("a" * 10_000)
    assert "(truncated)" in text
    assert len(text) < handler.MAX_MESSAGE_CHARS + 200


def test_format_message_handles_non_json():
    assert "plain text" in handler.format_message("plain text")


def test_handler_posts_each_record_and_reads_secret_once(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_SECRET_ARN", "arn:aws:secretsmanager:us-east-1:1:secret:s")
    fake, client = _fake_boto3(GOOD_URL + "\n")
    monkeypatch.setitem(sys.modules, "boto3", fake)

    response = mock.MagicMock()
    response.status = 200
    response.__enter__.return_value = response

    with mock.patch.object(urllib.request, "urlopen", return_value=response) as urlopen:
        event = {"Records": [{"Sns": {"Message": "{}"}}, {"Sns": {"Message": "{}"}}]}
        assert handler.lambda_handler(event, None)["delivered"] == 2
        assert urlopen.call_count == 2
        request = urlopen.call_args.args[0]
        assert request.full_url == GOOD_URL
        assert urlopen.call_args.kwargs["timeout"] == handler.REQUEST_TIMEOUT_SECONDS

    client.get_secret_value.assert_called_once()


@pytest.mark.parametrize(
    "bad_url",
    [
        "http://hooks.slack.com/services/x",
        "https://evil.example.com/services/x",
        "https://hooks.slack.com.evil.example/x",
        "file:///etc/passwd",
    ],
)
def test_handler_rejects_non_slack_webhook(monkeypatch, bad_url):
    monkeypatch.setenv("SLACK_WEBHOOK_SECRET_ARN", "arn")
    fake, _ = _fake_boto3(bad_url)
    monkeypatch.setitem(sys.modules, "boto3", fake)

    with mock.patch.object(urllib.request, "urlopen") as urlopen:
        with pytest.raises(ValueError):
            handler.lambda_handler(_event("{}"), None)
        urlopen.assert_not_called()


def test_handler_raises_when_slack_returns_error_status(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_SECRET_ARN", "arn")
    fake, _ = _fake_boto3(GOOD_URL)
    monkeypatch.setitem(sys.modules, "boto3", fake)

    response = mock.MagicMock()
    response.status = 500
    response.__enter__.return_value = response

    with mock.patch.object(urllib.request, "urlopen", return_value=response):
        with pytest.raises(RuntimeError):
            handler.lambda_handler(_event("{}"), None)


def test_handler_does_not_log_webhook_url(monkeypatch, caplog):
    monkeypatch.setenv("SLACK_WEBHOOK_SECRET_ARN", "arn")
    fake, _ = _fake_boto3(GOOD_URL)
    monkeypatch.setitem(sys.modules, "boto3", fake)

    response = mock.MagicMock()
    response.status = 200
    response.__enter__.return_value = response

    with caplog.at_level("INFO"), mock.patch.object(urllib.request, "urlopen", return_value=response):
        handler.lambda_handler(_event("{}"), None)

    assert GOOD_URL not in caplog.text