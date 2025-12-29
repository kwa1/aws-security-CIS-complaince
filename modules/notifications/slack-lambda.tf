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
  source_code_hash = filebase64sha256("slack.zip")

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}


resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.config_alerts.arn
}
