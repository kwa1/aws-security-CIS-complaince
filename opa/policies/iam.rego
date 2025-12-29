package terraform.aws.iam

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_role_policy"
  msg := "Inline IAM policies are not allowed. Use managed policies."
}
