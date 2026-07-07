package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_sg_rule(protocol) := {"plan": {"resource_changes": [{
	"type": "aws_security_group_rule",
	"address": "aws_security_group_rule.test",
	"change": {
		"actions": ["create"],
		"after": {"protocol": protocol, "type": "ingress"},
	},
}]}}

mock_sg_inline(protocol) := {"plan": {"resource_changes": [{
	"type": "aws_security_group",
	"address": "aws_security_group.test",
	"change": {
		"actions": ["create"],
		"after": {
			"ingress": [{"protocol": protocol, "from_port": 0, "to_port": 65535, "cidr_blocks": ["10.0.0.0/8"]}],
			"egress": [],
		},
	},
}]}}

# ── Deny: protocol = -1 on standalone rule ────────────────────────────────────

test_deny_all_protocol_rule if {
	count(deny) > 0 with input as mock_sg_rule("-1")
}

# ── Allow: specific protocol ──────────────────────────────────────────────────

test_allow_tcp_rule if {
	count(deny) == 0 with input as mock_sg_rule("tcp")
}

test_allow_protocol_6 if {
	count(deny) == 0 with input as mock_sg_rule("6")
}

# ── Deny: protocol = -1 on inline block ──────────────────────────────────────

test_deny_all_protocol_inline if {
	count(deny) > 0 with input as mock_sg_inline("-1")
}

# ── Allow: specific protocol inline ──────────────────────────────────────────

test_allow_tcp_inline if {
	count(deny) == 0 with input as mock_sg_inline("tcp")
}
