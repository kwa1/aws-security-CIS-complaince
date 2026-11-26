package terraform.aws.encryption

import data.terraform.aws.helpers
import rego.v1

deny contains msg if {
	some res in helpers.resources_of_type("aws_ebs_volume")
	not res.change.after.encrypted == true
	msg := sprintf("%s: EBS volumes must be encrypted.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_db_instance")
	not res.change.after.storage_encrypted == true
	msg := sprintf("%s: RDS instances must have storage_encrypted = true.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_db_instance")
	res.change.after.publicly_accessible == true
	msg := sprintf("%s: RDS instances must not be publicly accessible.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_sns_topic")
	not _has_cmk(res.change, "kms_master_key_id")
	msg := sprintf("%s: SNS topics must be encrypted with a customer managed KMS key.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_sqs_queue")
	not _has_cmk(res.change, "kms_master_key_id")
	msg := sprintf("%s: SQS queues must be encrypted with a customer managed KMS key.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_cloudwatch_log_group")
	not _has_cmk(res.change, "kms_key_id")
	msg := sprintf("%s: log groups must be encrypted with a customer managed KMS key.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_kms_key")
	not res.change.after.enable_key_rotation == true
	msg := sprintf("%s: KMS keys must have automatic rotation enabled.", [res.address])
}

# A key id is "known after apply" at plan time (reported in change.after_unknown); treat unknown as configured.
_has_cmk(change, attr) if is_string(change.after[attr])

_has_cmk(change, attr) if change.after_unknown[attr] == true
