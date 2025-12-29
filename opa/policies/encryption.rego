package terraform.aws.encryption

deny[msg] {
  res := input.resource_changes[_]
  res.type == "aws_ebs_volume"
  not res.change.after.encrypted
  msg := "EBS volumes must be encrypted."
}
