resource "aws_config_remediation_configuration" "this" {
  config_rule_name = var.rule_name
  target_type      = "SSM_DOCUMENT"
  target_id        = aws_ssm_document.block_s3_public.name
  automatic        = true
}
