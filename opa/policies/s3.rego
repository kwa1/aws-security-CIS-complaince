package terraform.aws.s3

deny[msg] {
  bucket := input.resource_changes[_]
  bucket.type == "aws_s3_bucket"
  not bucket.change.after.public_access_block
  msg := "S3 buckets must have public access block enabled."
}
