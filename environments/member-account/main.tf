locals {
  tags = {
    Project     = "aws-cis-governance"
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "member-account"
  }
}

module "config" {
  source = "../../modules/config-baseline"

  name_prefix             = var.name_prefix
  config_bucket_name      = var.config_bucket_name
  config_kms_key_arn      = var.config_kms_key_arn
  record_global_resources = var.is_home_region
  tags                    = local.tags
}

module "rules" {
  source = "../../modules/config-rules-cis"

  name_prefix         = var.name_prefix
  deploy_global_rules = var.is_home_region
  disabled_rules      = var.disabled_rules
  tags                = local.tags

  depends_on = [module.config]
}

module "hardening" {
  source = "../../modules/account-hardening"

  manage_password_policy                = var.is_home_region
  manage_s3_account_public_access_block = var.is_home_region
}

# Findings are forwarded to the security account's aggregator (cross-region within this account here).
module "securityhub" {
  source = "../../modules/securityhub"

  cis_version                     = var.cis_version
  enable_cross_region_aggregation = var.is_home_region
  tags                            = local.tags
}

module "remediation" {
  source = "../../modules/remediation"
  count  = var.enable_remediation ? 1 : 0

  name_prefix = var.name_prefix
  rule_name   = module.rules.rule_names["s3_public_read"]
  automatic   = var.remediation_automatic
  tags        = local.tags
}
