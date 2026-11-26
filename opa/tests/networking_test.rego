package terraform.aws.networking_test

import data.terraform.aws.networking
import rego.v1

_rule(from_port, to_port, cidrs) := {
	"address": "aws_security_group_rule.r",
	"type": "aws_security_group_rule",
	"change": {"actions": ["create"], "after": {"type": "ingress", "from_port": from_port, "to_port": to_port, "protocol": "tcp", "cidr_blocks": cidrs}},
}

test_ssh_from_internet_is_denied if {
	count(networking.deny) == 1 with input as {"resource_changes": [_rule(22, 22, ["0.0.0.0/0"])]}
}

test_rdp_from_internet_is_denied if {
	count(networking.deny) == 1 with input as {"resource_changes": [_rule(3389, 3389, ["0.0.0.0/0"])]}
}

test_wide_port_range_covering_ssh_is_denied if {
	count(networking.deny) == 1 with input as {"resource_changes": [_rule(0, 65535, ["0.0.0.0/0"])]}
}

test_ssh_from_private_cidr_is_allowed if {
	count(networking.deny) == 0 with input as {"resource_changes": [_rule(22, 22, ["10.0.0.0/8"])]}
}

test_https_from_internet_is_allowed if {
	count(networking.deny) == 0 with input as {"resource_changes": [_rule(443, 443, ["0.0.0.0/0"])]}
}

test_ipv6_open_ssh_is_denied if {
	r := {
		"address": "aws_security_group_rule.v6",
		"type": "aws_security_group_rule",
		"change": {"actions": ["create"], "after": {"type": "ingress", "from_port": 22, "to_port": 22, "protocol": "tcp", "cidr_blocks": [], "ipv6_cidr_blocks": ["::/0"]}},
	}
	count(networking.deny) == 1 with input as {"resource_changes": [r]}
}

test_vpc_ingress_rule_open_ssh_is_denied if {
	r := {
		"address": "aws_vpc_security_group_ingress_rule.r",
		"type": "aws_vpc_security_group_ingress_rule",
		"change": {"actions": ["create"], "after": {"from_port": 22, "to_port": 22, "cidr_ipv4": "0.0.0.0/0"}},
	}
	count(networking.deny) == 1 with input as {"resource_changes": [r]}
}

test_inline_security_group_open_ssh_is_denied if {
	sg := {
		"address": "aws_security_group.sg",
		"type": "aws_security_group",
		"change": {"actions": ["create"], "after": {"ingress": [{"from_port": 22, "to_port": 22, "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}]}},
	}
	count(networking.deny) == 1 with input as {"resource_changes": [sg]}
}

test_egress_rule_is_ignored if {
	r := {
		"address": "aws_security_group_rule.e",
		"type": "aws_security_group_rule",
		"change": {"actions": ["create"], "after": {"type": "egress", "from_port": 22, "to_port": 22, "protocol": "tcp", "cidr_blocks": ["0.0.0.0/0"]}},
	}
	count(networking.deny) == 0 with input as {"resource_changes": [r]}
}
