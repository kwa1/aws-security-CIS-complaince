# ----------------------------
# Optional email subscriptions- for audit purposes
# ----------------------------
resource "aws_sns_topic_subscription" "config_email" {
  topic_arn = aws_sns_topic.config_alerts.arn
  protocol  = "email"
  endpoint  = var.config_email
}

resource "aws_sns_topic_subscription" "securityhub_email" {
  topic_arn = aws_sns_topic.securityhub_alerts.arn
  protocol  = "email"
  endpoint  = var.securityhub_email
}

# ----------------------------
# Variables
# ----------------------------
variable "environment" {
  description = "Environment name (prod, dev, etc.)"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "config_email" {
  description = "Email for AWS Config alerts"
  type        = string
  default     = "your-config-email@example.com"
}

variable "securityhub_email" {
  description = "Email for Security Hub alerts"
  type        = string
  default     = "your-securityhub-email@example.com"
}
