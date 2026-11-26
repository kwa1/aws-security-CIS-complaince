mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "archive" {}

override_module {
  target = module.kms
  outputs = {
    key_arn = "arn:aws:kms:us-east-1:111111111111:key/abc"
  }
}

variables {
  name_prefix = "test"
}

run "slack_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.slack) == 0 && length(aws_sns_topic_subscription.slack) == 0
    error_message = "No Slack resources should exist without a webhook secret."
  }

  assert {
    condition     = length(aws_sns_topic.alerts) == 2 && length(aws_sqs_queue.dlq) == 2
    error_message = "Config and Security Hub alert topics and DLQs must always exist."
  }
}

run "topics_and_queues_are_encrypted" {
  command = plan

  assert {
    condition     = alltrue([for t in aws_sns_topic.alerts : t.kms_master_key_id != null])
    error_message = "All SNS topics must be encrypted with the CMK."
  }

  assert {
    condition     = alltrue([for q in aws_sqs_queue.dlq : q.kms_master_key_id != null])
    error_message = "All DLQs must be encrypted with the CMK."
  }
}

run "slack_enabled_creates_forwarder" {
  command = plan

  variables {
    slack_webhook_secret_arn = "arn:aws:secretsmanager:us-east-1:111111111111:secret:slack-AbCdEf"
  }

  assert {
    condition     = length(aws_lambda_function.slack) == 1 && length(aws_sns_topic_subscription.slack) == 2
    error_message = "Slack forwarder must subscribe to both topics when enabled."
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.slack[0].environment[0].variables), "SLACK_WEBHOOK_URL")
    error_message = "The webhook URL must never be placed in an environment variable."
  }

  assert {
    condition     = aws_lambda_function.slack[0].tracing_config[0].mode == "Active" && aws_lambda_function.slack[0].reserved_concurrent_executions == var.lambda_reserved_concurrency
    error_message = "Tracing must be active and concurrency capped."
  }
}

run "email_subscriptions_fan_out_per_topic" {
  command = plan

  variables {
    alert_emails = ["a@example.com", "b@example.com"]
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 4
    error_message = "Each email must subscribe to each topic."
  }
}

run "rejects_invalid_email" {
  command = plan

  variables {
    alert_emails = ["not-an-email"]
  }

  expect_failures = [var.alert_emails]
}

run "rejects_short_log_retention" {
  command = plan

  variables {
    log_retention_days = 7
  }

  expect_failures = [var.log_retention_days]
}
