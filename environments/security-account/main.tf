locals {
  name_prefix = var.name_prefix

  tags = {
    Project     = "aws-cis-governance"
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "security-account"
  }
}

# --- Central AWS Config storage (home region only; the bucket is global to the org) ----------

module "central_storage" {
  source = "../../modules/config-central-storage"
  count  = var.is_home_region ? 1 : 0

  name_prefix          = local.name_prefix
  bucket_name          = var.config_bucket_name
  governed_account_ids = var.governed_account_ids
  tags                 = local.tags
}

# Non-home regions use the key created in the home region (pass its ARN via config_kms_key_arn).
locals {
  config_kms_key_arn = var.is_home_region ? module.central_storage[0].kms_key_arn : var.config_kms_key_arn
}

check "non_home_region_has_key" {
  assert {
    condition     = var.is_home_region || var.config_kms_key_arn != null
    error_message = "config_kms_key_arn must be set when is_home_region = false."
  }
}

# --- This account is also a governed account -------------------------------------------------

module "config" {
  source = "../../modules/config-baseline"

  name_prefix             = local.name_prefix
  config_bucket_name      = var.config_bucket_name
  config_kms_key_arn      = local.config_kms_key_arn
  record_global_resources = var.is_home_region
  tags                    = local.tags

  depends_on = [module.central_storage]
}

module "rules" {
  source = "../../modules/config-rules-cis"

  name_prefix         = local.name_prefix
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

# --- Central visibility ----------------------------------------------------------------------

module "aggregator" {
  source = "../../modules/config-aggregator"
  count  = var.is_home_region ? 1 : 0

  name_prefix = local.name_prefix
  tags        = local.tags

  depends_on = [module.config]
}

module "securityhub" {
  source = "../../modules/securityhub"

  cis_version                     = var.cis_version
  enable_cross_region_aggregation = var.is_home_region
  enable_organization_auto_enable = var.enable_organization_auto_enable && var.is_home_region
  tags                            = local.tags
}

module "notifications" {
  source = "../../modules/notifications"

  name_prefix              = local.name_prefix
  alert_emails             = var.alert_emails
  slack_webhook_secret_arn = var.slack_webhook_secret_arn
  slack_secret_kms_key_arn = var.slack_secret_kms_key_arn
  tags                     = local.tags
}

module "remediation" {
  source = "../../modules/remediation"
  count  = var.enable_remediation ? 1 : 0

  name_prefix = local.name_prefix
  rule_name   = module.rules.rule_names["s3_public_read"]
  automatic   = var.remediation_automatic
  tags        = local.tags
}
