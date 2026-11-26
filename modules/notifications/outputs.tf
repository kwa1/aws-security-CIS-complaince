output "topic_arns" {
  description = "Map of alert type to SNS topic ARN."
  value       = { for key, topic in aws_sns_topic.alerts : key => topic.arn }
}

output "dlq_arns" {
  description = "Map of alert type to EventBridge dead-letter queue ARN."
  value       = { for key, queue in aws_sqs_queue.dlq : key => queue.arn }
}

output "kms_key_arn" {
  description = "KMS key encrypting alert resources."
  value       = module.kms.key_arn
}
