resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name = "config-noncompliant-rule"

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

resource "aws_cloudwatch_event_target" "config_to_sns" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.config_alerts.arn
}
