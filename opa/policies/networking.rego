package terraform.aws.networking

import data.terraform.aws.helpers
import rego.v1

_world_v4 := "0.0.0.0/0"

_world_v6 := "::/0"

_admin_ports := {22, 3389}

# Standalone ingress rule resources.
deny contains msg if {
	some res in helpers.resources_of_type("aws_security_group_rule")
	res.change.after.type == "ingress"
	_exposes_admin_port(res.change.after.from_port, res.change.after.to_port)
	_world_open(res.change.after)
	msg := sprintf("%s opens an administrative port (SSH/RDP) to the internet.", [res.address])
}

deny contains msg if {
	some res in helpers.resources_of_type("aws_vpc_security_group_ingress_rule")
	_exposes_admin_port(res.change.after.from_port, res.change.after.to_port)
	_world_open_single(res.change.after)
	msg := sprintf("%s opens an administrative port (SSH/RDP) to the internet.", [res.address])
}

# Inline ingress blocks on aws_security_group.
deny contains msg if {
	some res in helpers.resources_of_type("aws_security_group")
	some rule in res.change.after.ingress
	_exposes_admin_port(rule.from_port, rule.to_port)
	_world_open(rule)
	msg := sprintf("%s opens an administrative port (SSH/RDP) to the internet.", [res.address])
}

# All traffic from anywhere is never acceptable.
deny contains msg if {
	some res in helpers.resources_of_type("aws_security_group_rule")
	res.change.after.type == "ingress"
	res.change.after.protocol == "-1"
	_world_open(res.change.after)
	msg := sprintf("%s allows all protocols from the internet.", [res.address])
}

# The range [from, to] includes any administrative port (covers 0-65535 and 20-30 style ranges).
_exposes_admin_port(from_port, to_port) if {
	some port in _admin_ports
	from_port <= port
	port <= to_port
}

# A from/to of 0/0 with protocol -1 means all ports.
_exposes_admin_port(from_port, to_port) if {
	from_port == 0
	to_port == 0
}

_world_open(obj) if _world_v4 in object.get(obj, "cidr_blocks", [])

_world_open(obj) if _world_v6 in object.get(obj, "ipv6_cidr_blocks", [])

_world_open_single(obj) if object.get(obj, "cidr_ipv4", "") == _world_v4

_world_open_single(obj) if object.get(obj, "cidr_ipv6", "") == _world_v6
