module "config" {
  source        = "../../modules/config-baseline"
  config_bucket = "central-config-bucket"
}

module "rules" {
  source = "../../modules/config-rules-cis"
}
