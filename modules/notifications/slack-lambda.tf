resource "aws_iam_role" "slack" {
  name = "slack-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "slack" {
  function_name = "security-slack-notifier"
  role          = aws_iam_role.slack.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = "slack.zip"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}
