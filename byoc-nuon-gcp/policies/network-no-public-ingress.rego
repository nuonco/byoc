# Network Exposure Policy (terraform_module)
#
# The control plane (databases, admin endpoints) lives inside the install VPC and
# must never be reachable from the public internet. This blocks firewall rules
# that open sensitive ports to 0.0.0.0/0.
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

is_public_ingress_firewall(rc) if {
	rc.type == "google_compute_firewall"
	is_ingress(rc.change.after)
	some cidr in object.get(rc.change.after, "source_ranges", [])
	cidr in open_cidrs
}

# `direction` defaults to INGRESS when unset.
is_ingress(after) if {
	after.direction == "INGRESS"
}

is_ingress(after) if {
	not after.direction
}

public_cidrs(rc) := {cidr |
	some cidr in object.get(rc.change.after, "source_ranges", [])
	cidr in open_cidrs
}

# A firewall `allow` rule with no `ports` list opens every port for the protocol.
rule_covers_port(rule, _) if {
	count(object.get(rule, "ports", [])) == 0
}

rule_covers_port(rule, port) if {
	some p in rule.ports
	not contains(p, "-")
	to_number(p) == port
}

rule_covers_port(rule, port) if {
	some p in rule.ports
	contains(p, "-")
	parts := split(p, "-")
	to_number(parts[0]) <= port
	port <= to_number(parts[1])
}

# ──────────────────────────────────────────────────────────────────────────────
# Deny public ingress on sensitive ports.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.change.actions[_] in ["create", "update"]
	is_public_ingress_firewall(rc)
	some cidr in public_cidrs(rc)
	some rule in object.get(rc.change.after, "allow", [])
	some port in sensitive_ports
	rule_covers_port(rule, port)
	msg := sprintf(
		"Firewall rule '%s' allows public ingress from %s on sensitive port %d. Restrict access to the VPC or specific CIDRs.",
		[rc.address, cidr, port],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Warn on any other public ingress.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.change.actions[_] in ["create", "update"]
	is_public_ingress_firewall(rc)
	some cidr in public_cidrs(rc)
	some rule in object.get(rc.change.after, "allow", [])
	not any_sensitive_port(rule)
	msg := sprintf(
		"Firewall rule '%s' allows public ingress from %s on ports %v. Confirm this endpoint is intended to be internet-facing.",
		[rc.address, cidr, object.get(rule, "ports", ["all"])],
	)
}

any_sensitive_port(rule) if {
	some port in sensitive_ports
	rule_covers_port(rule, port)
}
