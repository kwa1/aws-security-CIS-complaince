mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
}

variables {
  cis_version = "3.0.0"
}

run "cis_and_fsbp_subscribed_by_default" {
  command = plan

  assert {
    condition     = length(aws_securityhub_standards_subscription.cis) == 1 && length(aws_securityhub_standards_subscription.fsbp) == 1
    error_message = "CIS and FSBP must be subscribed by default."
  }

  assert {
    condition     = aws_securityhub_standards_subscription.cis[0].standards_arn == "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/3.0.0"
    error_message = "CIS ARN must be region-scoped and use the selected version."
  }

  assert {
    condition     = aws_securityhub_account.this.control_finding_generator == "SECURITY_CONTROL"
    error_message = "Consolidated control findings must be enabled."
  }
}

run "org_auto_enable_is_opt_in" {
  command = plan

  assert {
    condition     = length(aws_securityhub_organization_configuration.this) == 0
    error_message = "Organization configuration must not be created unless requested."
  }
}

run "rejects_unknown_cis_version" {
  command = plan

  variables {
    cis_version = "9.9.9"
  }

  expect_failures = [var.cis_version]
}
