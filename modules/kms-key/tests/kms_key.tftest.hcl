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
  alias_name  = "test-key"
  description = "test"
}

run "rotation_always_enabled" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Automatic key rotation must be enabled."
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Default deletion window must be the 30-day maximum."
  }

  assert {
    condition     = aws_kms_alias.this.name == "alias/test-key"
    error_message = "Alias must be prefixed with alias/."
  }
}

run "rejects_aws_reserved_alias" {
  command = plan

  variables {
    alias_name = "aws/s3"
  }

  expect_failures = [var.alias_name]
}

run "rejects_short_deletion_window" {
  command = plan

  variables {
    deletion_window_in_days = 3
  }

  expect_failures = [var.deletion_window_in_days]
}
