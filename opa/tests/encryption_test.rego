package terraform.aws.encryption_test

import data.terraform.aws.encryption
import rego.v1

_res(type, after) := {
	"address": sprintf("%s.x", [type]),
	"type": type,
	"change": {"actions": ["create"], "after": after, "after_unknown": {}},
}

test_unencrypted_ebs_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_ebs_volume", {"encrypted": false})]}
}

test_encrypted_ebs_is_allowed if {
	count(encryption.deny) == 0 with input as {"resource_changes": [_res("aws_ebs_volume", {"encrypted": true})]}
}

test_unencrypted_rds_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_db_instance", {"storage_encrypted": false, "publicly_accessible": false})]}
}

test_public_rds_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_db_instance", {"storage_encrypted": true, "publicly_accessible": true})]}
}

test_sns_without_cmk_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_sns_topic", {"name": "t"})]}
}

test_sns_with_cmk_is_allowed if {
	count(encryption.deny) == 0 with input as {"resource_changes": [_res("aws_sns_topic", {"kms_master_key_id": "arn:aws:kms:us-east-1:1:key/k"})]}
}

test_sns_with_key_unknown_until_apply_is_allowed if {
	t := {"address": "aws_sns_topic.x", "type": "aws_sns_topic", "change": {"actions": ["create"], "after": {"name": "t"}, "after_unknown": {"kms_master_key_id": true}}}
	count(encryption.deny) == 0 with input as {"resource_changes": [t]}
}

test_sqs_without_cmk_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_sqs_queue", {"name": "q"})]}
}

test_log_group_without_cmk_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_cloudwatch_log_group", {"name": "l"})]}
}

test_kms_key_without_rotation_is_denied if {
	count(encryption.deny) == 1 with input as {"resource_changes": [_res("aws_kms_key", {"enable_key_rotation": false})]}
}

test_kms_key_with_rotation_is_allowed if {
	count(encryption.deny) == 0 with input as {"resource_changes": [_res("aws_kms_key", {"enable_key_rotation": true})]}
}
