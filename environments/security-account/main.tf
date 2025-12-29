module "aggregator" {
  source   = "../../modules/config-aggregator"
  role_arn = module.config.role_arn
}

module "securityhub" {
  source = "../../modules/securityhub"
}
