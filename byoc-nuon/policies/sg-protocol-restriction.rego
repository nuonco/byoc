# Security Group Protocol Restriction Policy (terraform_module)
#
# A security group rule with protocol = "-1" (all protocols, all ports) from any
# source grants unrestricted network access. Even when scoped to a single source
# SG, this is over-broad — a compromised runner or node can reach every port on
# every node in the cluster (kubelet 10250, node ports, etcd 2379, etc.).
#
# Checks:
#   - deny security group rules with protocol "-1" (all traffic)   (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

sg_rule_resources := {
	"aws_security_group_rule",
	"aws_vpc_security_group_ingress_rule",
	"aws_vpc_security_group_egress_rule",
}

# ──────────────────────────────────────────────────────────────────────────────
# Deny security group rules that allow all protocols / all ports.
#
# protocol = "-1" means all IP protocols (TCP, UDP, ICMP, etc.) on all ports.
# This is almost never what is intended — it should be scoped to port 443
# (API server), port 10250 (kubelet), or whatever the workload actually needs.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in sg_rule_resources
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.protocol == "-1"
	msg := sprintf(
		"Security group rule '%s' uses protocol=-1 (all protocols, all ports). Restrict to the specific ports the workload requires (e.g. 443 for API server).",
		[rc.address],
	)
}

# Also catch inline ingress/egress blocks inside aws_security_group resources.
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_security_group"
	rc.change.actions[_] in ["create", "update"]
	some rule in array.concat(
		object.get(rc.change.after, "ingress", []),
		object.get(rc.change.after, "egress", []),
	)
	rule.protocol == "-1"
	msg := sprintf(
		"Security group '%s' has an inline rule with protocol=-1 (all protocols, all ports). Restrict to the specific ports the workload requires.",
		[rc.address],
	)
}
