output "hub_arn" {
  description = "ARN of the Security Hub hub."
  value       = aws_securityhub_account.this.arn
}
