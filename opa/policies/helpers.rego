package terraform.aws.helpers

import rego.v1

# Resources being created or updated (deleting is never a violation).
managed_resources contains res if {
	some res in input.resource_changes
	some action in res.change.actions
	action in {"create", "update"}
}

resources_of_type(type) := {res |
	some res in managed_resources
	res.type == type
}

# Statements of an IAM policy document supplied as a JSON string (normalised to a list).
policy_statements(doc) := statements if {
	parsed := json.unmarshal(doc)
	statements := _as_list(parsed.Statement)
}

_as_list(x) := x if is_array(x)

_as_list(x) := [x] if not is_array(x)

as_set(x) := {y | some y in x} if is_array(x)

as_set(x) := {x} if is_string(x)
