# Network Exposure Policy (terraform_module)
#
# The control plane (databases, admin endpoints) lives inside the install VPC and
# must never be reachable from the public internet. This blocks security-group
# rules that open sensitive ports to 0.0.0.0/0.
#
# Checks:
#   - deny public (0.0.0.0/0 or ::/0) ingress on sensitive ports   (deny)
#   - warn public ingress on any other port                         (warn)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Ports that must never be exposed to the public internet.
sensitive_ports := {22, 23, 3389, 5432, 3306, 1433, 6379, 27017, 9000, 2379, 9440}

open_cidrs := {"0.0.0.0/0", "::/0"}

# Normalize ingress rules from both the inline `ingress` block (aws_security_group)
# and the standalone aws_security_group_rule / aws_vpc_security_group_ingress_rule.
ingress_rules(rc) := rules if {
	rc.type == "aws_security_group"
	rules := {r | some r in rc.change.after.ingress}
}

ingress_rules(rc) := rules if {
	rc.type in ["aws_security_group_rule", "aws_vpc_security_group_ingress_rule"]
	rc.change.after.type == "ingress"
	rules := {rc.change.after}
}

ingress_rules(rc) := rules if {
	rc.type == "aws_vpc_security_group_ingress_rule"
	not rc.change.after.type
	rules := {rc.change.after}
}

rule_cidrs(rule) := cidrs if {
	cidrs := {c | some c in rule.cidr_blocks}
}

rule_cidrs(rule) := cidrs if {
	not rule.cidr_blocks
	cidrs := {rule.cidr_ipv4}
}

port_in_range(port, rule) if {
	rule.from_port <= port
	port <= rule.to_port
}

# ──────────────────────────────────────────────────────────────────────────────
# Deny public ingress on sensitive ports.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.change.actions[_] in ["create", "update"]
	some rule in ingress_rules(rc)
	some cidr in rule_cidrs(rule)
	cidr in open_cidrs
	some port in sensitive_ports
	port_in_range(port, rule)
	msg := sprintf(
		"Security group '%s' allows public ingress from %s on sensitive port %d. Restrict access to the VPC or specific CIDRs.",
		[rc.address, cidr, port],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Warn on any other public ingress.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.change.actions[_] in ["create", "update"]
	some rule in ingress_rules(rc)
	some cidr in rule_cidrs(rule)
	cidr in open_cidrs
	not any_sensitive_port(rule)
	msg := sprintf(
		"Security group '%s' allows public ingress from %s on ports %d-%d. Confirm this endpoint is intended to be internet-facing.",
		[rc.address, cidr, rule.from_port, rule.to_port],
	)
}

any_sensitive_port(rule) if {
	some port in sensitive_ports
	port_in_range(port, rule)
}
