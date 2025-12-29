import json
import urllib.request
import os

SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]

def lambda_handler(event, context):
    try:
        message = event["Records"][0]["Sns"]["Message"]

        payload = {
            "text": f":rotating_light: *AWS Security Alert*\n```{message}```"
        }

        req = urllib.request.Request(
            SLACK_WEBHOOK_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )

        urllib.request.urlopen(req)

        return {
            "statusCode": 200,
            "body": "Alert sent successfully"
        }

    except Exception as e:
        print(f"Error: {e}")
        raise
