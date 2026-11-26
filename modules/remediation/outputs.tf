output "document_name" {
  description = "Name of the SSM Automation document."
  value       = aws_ssm_document.block_s3_public.name
}

output "role_arn" {
  description = "IAM role assumed by the Automation document."
  value       = aws_iam_role.automation.arn
}
