resource "aws_config_configuration_aggregator" "org" {
  name = "org-config-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn   = var.role_arn
  }
}
