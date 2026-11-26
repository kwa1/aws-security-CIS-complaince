data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  standards_base = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.region}::standards"
}

resource "aws_securityhub_account" "this" {
  # Standards are managed explicitly below so enablement is auditable in code.
  enable_default_standards  = false
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_standards_subscription" "cis" {
  count = var.enable_cis ? 1 : 0

  standards_arn = "${local.standards_base}/cis-aws-foundations-benchmark/v/${var.cis_version}"

  depends_on = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  count = var.enable_fsbp ? 1 : 0

  standards_arn = "${local.standards_base}/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.this]
}

resource "aws_securityhub_finding_aggregator" "this" {
  count = var.enable_cross_region_aggregation ? 1 : 0

  linking_mode = "ALL_REGIONS"

  depends_on = [aws_securityhub_account.this]
}

# Only valid when this account is the Security Hub delegated administrator.
resource "aws_securityhub_organization_configuration" "this" {
  count = var.enable_organization_auto_enable ? 1 : 0

  auto_enable           = true
  auto_enable_standards = "NONE"

  depends_on = [aws_securityhub_account.this, aws_securityhub_finding_aggregator.this]
}
