mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name_prefix = "test"
  rule_name   = "test-s3-public-read"
}

run "defaults_to_manual_remediation" {
  command = plan

  assert {
    condition     = aws_config_remediation_configuration.s3_public.automatic == false
    error_message = "Remediation must be manual unless explicitly enabled."
  }
}

run "automatic_remediation_is_opt_in" {
  command = plan

  variables {
    automatic = true
  }

  assert {
    condition     = aws_config_remediation_configuration.s3_public.automatic == true && aws_config_remediation_configuration.s3_public.maximum_automatic_attempts == 3
    error_message = "Automatic remediation must apply bounded retries."
  }
}

run "rejects_unbounded_retries" {
  command = plan

  variables {
    maximum_automatic_attempts = 100
  }

  expect_failures = [var.maximum_automatic_attempts]
}
