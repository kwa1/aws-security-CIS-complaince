resource "aws_iam_role" "remediation" {
  name = "config-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name = "config-auto-remediation"
  role          = aws_iam_role.remediation.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = "remediation.zip"
}
