package terraform.aws.s3_test

import data.terraform.aws.s3
import rego.v1

_bucket := {
	"address": "module.logs.aws_s3_bucket.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket",
	"change": {"actions": ["create"], "after": {"bucket": "b"}},
}

_pab(value) := {
	"address": "module.logs.aws_s3_bucket_public_access_block.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket_public_access_block",
	"change": {"actions": ["create"], "after": {
		"block_public_acls": value,
		"block_public_policy": true,
		"ignore_public_acls": true,
		"restrict_public_buckets": true,
	}},
}

_sse := {
	"address": "module.logs.aws_s3_bucket_server_side_encryption_configuration.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket_server_side_encryption_configuration",
	"change": {"actions": ["create"], "after": {}},
}

_versioning(status) := {
	"address": "module.logs.aws_s3_bucket_versioning.this",
	"module_address": "module.logs",
	"type": "aws_s3_bucket_versioning",
	"change": {"actions": ["create"], "after": {"versioning_configuration": [{"status": status}]}},
}

test_compliant_bucket_has_no_violations if {
	count(s3.deny) == 0 with input as {"resource_changes": [_bucket, _pab(true), _sse, _versioning("Enabled")]}
}

test_bucket_without_public_access_block_is_denied if {
	msgs := s3.deny with input as {"resource_changes": [_bucket, _sse, _versioning("Enabled")]}
	count(msgs) == 1
}

test_public_access_block_with_setting_off_is_denied if {
	msgs := s3.deny with input as {"resource_changes": [_bucket, _pab(false), _sse, _versioning("Enabled")]}
	count(msgs) == 1
}

test_bucket_without_encryption_is_denied if {
	msgs := s3.deny with input as {"resource_changes": [_bucket, _pab(true), _versioning("Enabled")]}
	count(msgs) == 1
}

test_bucket_without_versioning_is_denied if {
	msgs := s3.deny with input as {"resource_changes": [_bucket, _pab(true), _sse]}
	count(msgs) == 1
}

test_suspended_versioning_is_denied if {
	msgs := s3.deny with input as {"resource_changes": [_bucket, _pab(true), _sse, _versioning("Suspended")]}
	count(msgs) == 1
}

test_public_acl_is_denied if {
	acl := {
		"address": "aws_s3_bucket_acl.x",
		"type": "aws_s3_bucket_acl",
		"change": {"actions": ["create"], "after": {"acl": "public-read"}},
	}
	msgs := s3.deny with input as {"resource_changes": [acl]}
	count(msgs) == 1
}

test_deleted_bucket_is_ignored if {
	gone := object.union(_bucket, {"change": {"actions": ["delete"], "after": null}})
	count(s3.deny) == 0 with input as {"resource_changes": [gone]}
}
