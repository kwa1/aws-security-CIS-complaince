package terraform.aws.iam

import data.terraform.aws.helpers
import rego.v1

# Wildcard Allow on all actions AND all resources (full admin) is never permitted.
deny contains msg if {
	some res in _policy_documents
	some stmt in helpers.policy_statements(res.doc)
	stmt.Effect == "Allow"
	"*" in helpers.as_set(stmt.Action)
	"*" in helpers.as_set(object.get(stmt, "Resource", []))
	msg := sprintf("%s grants Action:* on Resource:* (administrator access).", [res.address])
}

# Service-wide wildcards (e.g. "s3:*") on Resource "*" need an explicit, reviewed exception.
# Only the CI apply policy created by bootstrap is allowed to carry these.
deny contains msg if {
	some res in _policy_documents
	not endswith(res.address, "aws_iam_policy.apply")
	some stmt in helpers.policy_statements(res.doc)
	stmt.Effect == "Allow"
	some action in helpers.as_set(stmt.Action)
	endswith(action, ":*")
	action != "*"
	"*" in helpers.as_set(object.get(stmt, "Resource", []))
	msg := sprintf("%s allows %s on all resources; scope the resource or request an exception.", [res.address, action])
}

# IAM users must not be created by this repository; use roles and federation.
deny contains msg if {
	some res in helpers.resources_of_type("aws_iam_user")
	msg := sprintf("%s: IAM users are not allowed. Use roles with short-lived credentials.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_iam_access_key")
	msg := sprintf("%s: long-lived IAM access keys are not allowed.", [res.address])
}

# Trust policies for service roles must be constrained against confused-deputy attacks.
deny contains msg if {
	some res in helpers.resources_of_type("aws_iam_role")
	doc := res.change.after.assume_role_policy
	is_string(doc)
	some stmt in helpers.policy_statements(doc)
	stmt.Effect == "Allow"
	stmt.Principal.AWS == "*"
	msg := sprintf("%s trusts any AWS principal (Principal: *).", [res.address])
}

_policy_documents contains {"address": res.address, "doc": doc} if {
	some res in helpers.resources_of_type("aws_iam_policy")
	doc := res.change.after.policy
	is_string(doc)
}

_policy_documents contains {"address": res.address, "doc": doc} if {
	some res in helpers.resources_of_type("aws_iam_role_policy")
	doc := res.change.after.policy
	is_string(doc)
}
