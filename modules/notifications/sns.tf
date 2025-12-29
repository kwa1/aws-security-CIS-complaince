#resource "aws_sns_topic" "config_alerts" {
#  name = "aws-config-security-alerts"
#}

# Optional email subscription (for audits)

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.config_alerts.arn
  protocol  = "email"
  endpoint  = var.security_email
}
