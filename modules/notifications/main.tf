data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition
  region        = data.aws_region.current.region
  slack_enabled = var.slack_webhook_secret_arn != null

  alerts = {
    config = {
      rule_name   = "${var.name_prefix}-config-noncompliant"
      description = "AWS Config rule compliance changed to NON_COMPLIANT"
      pattern = {
        source        = ["aws.config"]
        "detail-type" = ["Config Rules Compliance Change"]
        detail        = { newEvaluationResult = { complianceType = ["NON_COMPLIANT"] } }
      }
      input_paths = {
        rule_name     = "$.detail.configRuleName"
        resource_type = "$.detail.resourceType"
        resource_id   = "$.detail.resourceId"
        status        = "$.detail.newEvaluationResult.complianceType"
        account       = "$.account"
        region        = "$.region"
        time          = "$.time"
      }
      input_template = <<-EOT
        {"AlertType":"Config Non-Compliant","Account":<account>,"Region":<region>,"RuleName":<rule_name>,"ResourceType":<resource_type>,"ResourceId":<resource_id>,"Status":<status>,"Time":<time>}
      EOT
    }
    securityhub = {
      rule_name   = "${var.name_prefix}-securityhub-high-critical"
      description = "Security Hub findings with HIGH or CRITICAL severity"
      pattern = {
        source        = ["aws.securityhub"]
        "detail-type" = ["Security Hub Findings - Imported"]
        detail = {
          findings = {
            Severity    = { Label = ["HIGH", "CRITICAL"] }
            Workflow    = { Status = ["NEW"] }
            RecordState = ["ACTIVE"]
            Compliance  = { Status = ["FAILED"] }
          }
        }
      }
      input_paths = {
        finding_id    = "$.detail.findings[0].Id"
        severity      = "$.detail.findings[0].Severity.Label"
        resource_type = "$.detail.findings[0].Resources[0].Type"
        resource_id   = "$.detail.findings[0].Resources[0].Id"
        title         = "$.detail.findings[0].Title"
        account       = "$.detail.findings[0].AwsAccountId"
        time          = "$.detail.findings[0].UpdatedAt"
      }
      input_template = <<-EOT
        {"AlertType":"Security Hub High/Critical","Account":<account>,"FindingId":<finding_id>,"Severity":<severity>,"ResourceType":<resource_type>,"ResourceId":<resource_id>,"Title":<title>,"Time":<time>}
      EOT
    }
  }
}

# --- Encryption key for SNS, SQS, Lambda environment and logs --------------------------------

data "aws_iam_policy_document" "key" {
  statement {
    sid       = "AllowEventBridgeAndSnsToUseKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sns.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogs"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.name_prefix}-*"]
    }
  }
}

module "kms" {
  source = "../kms-key"

  alias_name                  = "${var.name_prefix}-alerts"
  description                 = "Encrypts security alert topics, queues and notifier logs"
  additional_policy_documents = [data.aws_iam_policy_document.key.json]
  tags                        = var.tags
}

# --- SNS topics + DLQs -----------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  for_each = local.alerts

  name              = "${var.name_prefix}-${each.key}-alerts"
  kms_master_key_id = module.kms.key_arn
  tags              = var.tags
}

resource "aws_sqs_queue" "dlq" {
  for_each = local.alerts

  name                      = "${var.name_prefix}-${each.key}-alerts-dlq"
  kms_master_key_id         = module.kms.key_arn
  message_retention_seconds = 1209600
  tags                      = var.tags
}

data "aws_iam_policy_document" "topic" {
  for_each = local.alerts

  statement {
    sid       = "AllowEventBridgePublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.alerts[each.key].arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish", "sns:Subscribe"]
    resources = [aws_sns_topic.alerts[each.key].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  for_each = local.alerts

  arn    = aws_sns_topic.alerts[each.key].arn
  policy = data.aws_iam_policy_document.topic[each.key].json
}

data "aws_iam_policy_document" "dlq" {
  for_each = local.alerts

  statement {
    sid       = "AllowEventBridgeSendToDlq"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.alerts[each.key].arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.dlq[each.key].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  for_each = local.alerts

  queue_url = aws_sqs_queue.dlq[each.key].url
  policy    = data.aws_iam_policy_document.dlq[each.key].json
}

# --- EventBridge rules and targets -----------------------------------------------------------

resource "aws_cloudwatch_event_rule" "alerts" {
  for_each = local.alerts

  name          = each.value.rule_name
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)
  tags          = var.tags
}

resource "aws_cloudwatch_event_target" "alerts" {
  for_each = local.alerts

  rule      = aws_cloudwatch_event_rule.alerts[each.key].name
  target_id = "sns"
  arn       = aws_sns_topic.alerts[each.key].arn

  dead_letter_config {
    arn = aws_sqs_queue.dlq[each.key].arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 8
  }

  input_transformer {
    input_paths    = each.value.input_paths
    input_template = trimspace(each.value.input_template)
  }

  depends_on = [aws_sns_topic_policy.alerts, aws_sqs_queue_policy.dlq]
}

# --- Email subscriptions ---------------------------------------------------------------------

resource "aws_sns_topic_subscription" "email" {
  for_each = {
    for pair in setproduct(keys(local.alerts), var.alert_emails) : "${pair[0]}|${pair[1]}" => {
      topic = pair[0]
      email = pair[1]
    }
  }

  topic_arn = aws_sns_topic.alerts[each.value.topic].arn
  protocol  = "email"
  endpoint  = each.value.email
}

# --- Slack forwarder (optional) --------------------------------------------------------------

data "archive_file" "slack" {
  count = local.slack_enabled ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/slack.zip"
  excludes    = ["__pycache__", "tests"]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "slack" {
  count = local.slack_enabled ? 1 : 0

  name               = "${var.name_prefix}-slack-notifier"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_cloudwatch_log_group" "slack" {
  count = local.slack_enabled ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-slack-notifier"
  retention_in_days = var.log_retention_days
  kms_key_id        = module.kms.key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "slack" {
  count = local.slack_enabled ? 1 : 0

  statement {
    sid       = "WriteOwnLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.slack[0].arn}:*"]
  }

  statement {
    sid       = "ReadWebhookSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.slack_webhook_secret_arn]
  }

  dynamic "statement" {
    for_each = var.slack_secret_kms_key_arn == null ? [] : [var.slack_secret_kms_key_arn]

    content {
      sid       = "DecryptWebhookSecret"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }

  statement {
    sid       = "UseAlertsKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [module.kms.key_arn]
  }

  statement {
    sid       = "SendToDeadLetterQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.slack_dlq[0].arn]
  }
}

resource "aws_iam_policy" "slack" {
  count = local.slack_enabled ? 1 : 0

  name   = "${var.name_prefix}-slack-notifier"
  policy = data.aws_iam_policy_document.slack[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "slack" {
  count = local.slack_enabled ? 1 : 0

  role       = aws_iam_role.slack[0].name
  policy_arn = aws_iam_policy.slack[0].arn
}

resource "aws_sqs_queue" "slack_dlq" {
  count = local.slack_enabled ? 1 : 0

  name                      = "${var.name_prefix}-slack-notifier-dlq"
  kms_master_key_id         = module.kms.key_arn
  message_retention_seconds = 1209600
  tags                      = var.tags
}

resource "aws_lambda_function" "slack" {
  #checkov:skip=CKV_AWS_117:No VPC resources are reachable or required; function only calls Slack and AWS APIs over TLS.
  #checkov:skip=CKV_AWS_116:DLQ is configured via dead_letter_config.
  #checkov:skip=CKV_AWS_272:Code signing is optional and not enforced at baseline.
  count = local.slack_enabled ? 1 : 0

  function_name                  = "${var.name_prefix}-slack-notifier"
  role                           = aws_iam_role.slack[0].arn
  handler                        = "handler.lambda_handler"
  runtime                        = "python3.13"
  architectures                  = ["arm64"]
  filename                       = data.archive_file.slack[0].output_path
  source_code_hash               = data.archive_file.slack[0].output_base64sha256
  timeout                        = 15
  memory_size                    = 128
  reserved_concurrent_executions = 5
  kms_key_arn                    = module.kms.key_arn

  environment {
    variables = {
      SLACK_WEBHOOK_SECRET_ARN = var.slack_webhook_secret_arn
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.slack_dlq[0].arn
  }

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.slack[0].name
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.slack]
}

resource "aws_lambda_permission" "sns" {
  for_each = local.slack_enabled ? local.alerts : {}

  statement_id  = "AllowSns-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts[each.key].arn
}

resource "aws_sns_topic_subscription" "slack" {
  for_each = local.slack_enabled ? local.alerts : {}

  topic_arn = aws_sns_topic.alerts[each.key].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack[0].arn

  depends_on = [aws_lambda_permission.sns]
}
