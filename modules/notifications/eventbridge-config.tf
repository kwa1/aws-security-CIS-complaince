# ----------------------------
# SNS Topics
# ----------------------------
resource "aws_sns_topic" "config_alerts" {
  name = "prod-config-alerts"
}

resource "aws_sns_topic" "securityhub_alerts" {
  name = "prod-securityhub-alerts"
}

# ----------------------------
# DLQs for reliability
# ----------------------------
resource "aws_sqs_queue" "config_dlq" {
  name = "prod-config-alerts-dlq"
}

resource "aws_sqs_queue" "securityhub_dlq" {
  name = "prod-securityhub-alerts-dlq"
}

# ----------------------------
# CloudWatch Event Rule - Config Non-Compliant
# ----------------------------
resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name = "prod-config-noncompliant-rule"

  event_pattern = jsonencode({
    source = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

# Target with input transformer and DLQ
resource "aws_cloudwatch_event_target" "config_to_sns" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "ConfigToSNS"
  arn       = aws_sns_topic.config_alerts.arn
  dead_letter_config {
    arn = aws_sqs_queue.config_dlq.arn
  }

  input_transformer {
    input_paths = {
      rule_name       = "$.detail.configRuleName"
      resource_type   = "$.detail.resourceType"
      resource_id     = "$.detail.resourceId"
      new_status      = "$.detail.newEvaluationResult.complianceType"
      timestamp       = "$.time"
    }
    input_template = <<EOF
{
  "AlertType": "Config Non-Compliant",
  "RuleName": "<rule_name>",
  "ResourceType": "<resource_type>",
  "ResourceId": "<resource_id>",
  "Status": "<new_status>",
  "Time": "<timestamp>"
}
EOF
  }
}

# ----------------------------
# CloudWatch Event Rule - Security Hub High/Critical
# ----------------------------
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name = "prod-securityhub-high-critical"

  event_pattern = jsonencode({
    source = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })
}

# Target with input transformer and DLQ
resource "aws_cloudwatch_event_target" "securityhub_to_sns" {
  rule      = aws_cloudwatch_event_rule.securityhub_findings.name
  target_id = "SecurityHubToSNS"
  arn       = aws_sns_topic.securityhub_alerts.arn
  dead_letter_config {
    arn = aws_sqs_queue.securityhub_dlq.arn
  }

  input_transformer {
    input_paths = {
      finding_id      = "$.detail.findings[0].Id"
      severity_label  = "$.detail.findings[0].Severity.Label"
      resource_type   = "$.detail.findings[0].Resources[0].Type"
      resource_id     = "$.detail.findings[0].Resources[0].Id"
      title           = "$.detail.findings[0].Title"
      timestamp       = "$.detail.findings[0].UpdatedAt"
    }
    input_template = <<EOF
{
  "AlertType": "Security Hub High/Critical",
  "FindingId": "<finding_id>",
  "Severity": "<severity_label>",
  "ResourceType": "<resource_type>",
  "ResourceId": "<resource_id>",
  "Title": "<title>",
  "Time": "<timestamp>"
}
EOF
  }
}

