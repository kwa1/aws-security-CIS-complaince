package terraform.aws.networking

deny[msg] {
  sg := input.resource_changes[_]
  sg.type == "aws_security_group_rule"
  sg.change.after.from_port == 22
  sg.change.after.cidr_blocks[_] == "0.0.0.0/0"
  msg := "SSH from 0.0.0.0/0 is not allowed."
}
