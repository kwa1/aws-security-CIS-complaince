mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  name_prefix = "test"
}

run "regional_deployment_skips_global_rules" {
  command = plan

  variables {
    deploy_global_rules = false
  }

  assert {
    condition     = !contains(keys(aws_config_config_rule.cis), "root_mfa") && !contains(keys(aws_config_config_rule.cis), "cloudtrail_enabled")
    error_message = "Global rules must not be deployed outside the home region."
  }

  assert {
    condition     = contains(keys(aws_config_config_rule.cis), "s3_public_read") && contains(keys(aws_config_config_rule.cis), "restricted_ssh")
    error_message = "Regional rules must always be deployed."
  }
}

run "home_region_deploys_global_rules" {
  command = plan

  variables {
    deploy_global_rules = true
  }

  assert {
    condition     = contains(keys(aws_config_config_rule.cis), "root_mfa") && contains(keys(aws_config_config_rule.cis), "iam_password_policy")
    error_message = "Global rules must be deployed in the home region."
  }
}

run "periodic_rules_have_frequency_and_change_rules_do_not" {
  command = plan

  variables {
    deploy_global_rules = true
  }

  assert {
    condition     = aws_config_config_rule.cis["root_mfa"].maximum_execution_frequency == "TwentyFour_Hours"
    error_message = "Periodic rules need maximum_execution_frequency."
  }

  assert {
    condition     = aws_config_config_rule.cis["restricted_ssh"].maximum_execution_frequency == null
    error_message = "Change-triggered rules must not set maximum_execution_frequency."
  }
}

run "disabled_rules_are_skipped" {
  command = plan

  variables {
    disabled_rules = ["restricted_ssh"]
  }

  assert {
    condition     = !contains(keys(aws_config_config_rule.cis), "restricted_ssh")
    error_message = "Rules listed in disabled_rules must be skipped."
  }
}

run "password_policy_matches_cis" {
  command = plan

  variables {
    deploy_global_rules = true
  }

  assert {
    condition     = jsondecode(aws_config_config_rule.cis["iam_password_policy"].input_parameters).MinimumPasswordLength == "14"
    error_message = "Password policy rule must require at least 14 characters."
  }
}

run "every_rule_name_is_prefixed" {
  command = plan

  variables {
    deploy_global_rules = true
  }

  assert {
    condition     = alltrue([for r in aws_config_config_rule.cis : startswith(r.name, "test-")])
    error_message = "All rule names must carry the prefix."
  }
}
