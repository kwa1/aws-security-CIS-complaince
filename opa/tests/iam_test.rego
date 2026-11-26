package terraform.aws.iam_test

import data.terraform.aws.iam
import rego.v1

_policy(address, doc) := {
	"address": address,
	"type": "aws_iam_policy",
	"change": {"actions": ["create"], "after": {"policy": json.marshal(doc)}},
}

_allow(action, resource) := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": action, "Resource": resource}]}

test_scoped_policy_is_allowed if {
	p := _policy("aws_iam_policy.ok", _allow(["s3:GetObject"], "arn:aws:s3:::bucket/*"))
	count(iam.deny) == 0 with input as {"resource_changes": [p]}
}

test_full_admin_is_denied if {
	p := _policy("aws_iam_policy.admin", _allow("*", "*"))
	count(iam.deny) >= 1 with input as {"resource_changes": [p]}
}

test_service_wildcard_on_all_resources_is_denied if {
	p := _policy("aws_iam_policy.broad", _allow(["s3:*"], ["*"]))
	msgs := iam.deny with input as {"resource_changes": [p]}
	count(msgs) == 1
}

test_service_wildcard_allowed_for_ci_apply_policy_exception if {
	p := _policy("aws_iam_policy.apply", _allow(["s3:*"], ["*"]))
	count(iam.deny) == 0 with input as {"resource_changes": [p]}
}

test_single_statement_object_form_is_handled if {
	p := _policy("aws_iam_policy.single", {"Version": "2012-10-17", "Statement": {"Effect": "Allow", "Action": "*", "Resource": "*"}})
	count(iam.deny) >= 1 with input as {"resource_changes": [p]}
}

test_iam_user_is_denied if {
	u := {"address": "aws_iam_user.bob", "type": "aws_iam_user", "change": {"actions": ["create"], "after": {}}}
	count(iam.deny) == 1 with input as {"resource_changes": [u]}
}

test_access_key_is_denied if {
	k := {"address": "aws_iam_access_key.k", "type": "aws_iam_access_key", "change": {"actions": ["create"], "after": {}}}
	count(iam.deny) == 1 with input as {"resource_changes": [k]}
}

test_wildcard_principal_trust_is_denied if {
	r := {
		"address": "aws_iam_role.open",
		"type": "aws_iam_role",
		"change": {"actions": ["create"], "after": {"assume_role_policy": json.marshal({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "sts:AssumeRole", "Principal": {"AWS": "*"}}]})}},
	}
	count(iam.deny) == 1 with input as {"resource_changes": [r]}
}

test_service_principal_trust_is_allowed if {
	r := {
		"address": "aws_iam_role.svc",
		"type": "aws_iam_role",
		"change": {"actions": ["create"], "after": {"assume_role_policy": json.marshal({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "sts:AssumeRole", "Principal": {"Service": "lambda.amazonaws.com"}}]})}},
	}
	count(iam.deny) == 0 with input as {"resource_changes": [r]}
}
