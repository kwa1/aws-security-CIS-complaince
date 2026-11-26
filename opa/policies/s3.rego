package terraform.aws.s3

import data.terraform.aws.helpers
import rego.v1

# Convention enforced here: a bucket and its hardening resources live in the same module instance
# (the secure-bucket module). Matching on module_address keeps the check independent of unknown
# values such as bucket IDs at plan time.

deny contains msg if {
	some bucket in helpers.resources_of_type("aws_s3_bucket")
	not _sibling_exists(bucket, "aws_s3_bucket_public_access_block")
	msg := sprintf("S3 bucket %s must have an aws_s3_bucket_public_access_block.", [bucket.address])
}

deny contains msg if {
	some pab in helpers.resources_of_type("aws_s3_bucket_public_access_block")
	some setting in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	pab.change.after[setting] != true
	msg := sprintf("%s must set %s = true.", [pab.address, setting])
}

deny contains msg if {
	some bucket in helpers.resources_of_type("aws_s3_bucket")
	not _sibling_exists(bucket, "aws_s3_bucket_server_side_encryption_configuration")
	msg := sprintf("S3 bucket %s must have server-side encryption configured.", [bucket.address])
}

deny contains msg if {
	some bucket in helpers.resources_of_type("aws_s3_bucket")
	not _versioning_enabled(bucket)
	msg := sprintf("S3 bucket %s must have versioning enabled.", [bucket.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_s3_bucket_acl")
	res.change.after.acl in {"public-read", "public-read-write", "authenticated-read"}
	msg := sprintf("%s must not use a public ACL.", [res.address])
}

_sibling_exists(bucket, type) if {
	some res in helpers.resources_of_type(type)
	object.get(res, "module_address", "") == object.get(bucket, "module_address", "")
}

_versioning_enabled(bucket) if {
	some res in helpers.resources_of_type("aws_s3_bucket_versioning")
	object.get(res, "module_address", "") == object.get(bucket, "module_address", "")
	res.change.after.versioning_configuration[_].status == "Enabled"
}
