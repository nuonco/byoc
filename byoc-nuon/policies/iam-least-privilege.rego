# IAM Least-Privilege Policy (terraform_module)
#
# The control plane provisions IAM policies for its service accounts and for the
# org/runner machinery. Over-broad grants here are a privilege-escalation risk in
# the customer's account. This nudges those grants toward least privilege.
#
# Checks:
#   - service-wide / full wildcard actions (e.g. "*", "ecr:*", "kms:*")  (warn -> deny)
#   - write/destructive actions on Resource "*"                           (warn)
#   - AdministratorAccess attached by a deployed component                (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

iam_policy_resources := {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy"}

# Service-wide / full wildcards that grant far more than any single workload needs.
admin_action_patterns := {"*", "*:*", "iam:*", "s3:*", "ec2:*", "ecr:*", "kms:*", "rds:*", "sts:*"}

# Prefixes of mutating actions we don't want paired with Resource "*".
write_action_prefixes := {"Create", "Delete", "Put", "Update", "Modify", "Attach", "Detach", "Write", "Terminate"}

# Helpers ─────────────────────────────────────────────────────────────────────
parse_policy(s) := json.unmarshal(s)

statements(doc) := s if {
	is_array(doc.Statement)
	s := doc.Statement
} else := [doc.Statement] if {
	is_object(doc.Statement)
}

to_set(x) := {x} if {
	is_string(x)
}

to_set(x) := {v | some v in x} if {
	is_array(x)
}

is_write_action(action) if {
	parts := split(action, ":")
	count(parts) == 2
	some prefix in write_action_prefixes
	startswith(parts[1], prefix)
}

# ──────────────────────────────────────────────────────────────────────────────
# Flag service-wide / full wildcard actions.
#
# Warns so existing broad grants are not blocked while they are scoped down.
# TODO: promote to `deny` once service-wide wildcard actions are removed.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type in iam_policy_resources
	rc.change.actions[_] in ["create", "update"]
	some stmt in statements(parse_policy(rc.change.after.policy))
	stmt.Effect == "Allow"
	some action in to_set(stmt.Action)
	action in admin_action_patterns
	msg := sprintf(
		"IAM policy '%s' grants wide action '%s'. Scope it to the specific actions the workload requires.",
		[rc.address, action],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Write/destructive actions on Resource "*". Kept as a warning.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type in iam_policy_resources
	rc.change.actions[_] in ["create", "update"]
	some stmt in statements(parse_policy(rc.change.after.policy))
	stmt.Effect == "Allow"
	some action in to_set(stmt.Action)
	is_write_action(action)
	"*" in to_set(stmt.Resource)
	msg := sprintf(
		"IAM policy '%s' allows mutating action '%s' on Resource \"*\". Restrict it to specific resource ARNs.",
		[rc.address, action],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# AdministratorAccess must only ever be granted via the dedicated break-glass
# role, never attached by a normally-applied Terraform component.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in ["aws_iam_role_policy_attachment", "aws_iam_user_policy_attachment", "aws_iam_policy_attachment"]
	rc.change.actions[_] in ["create", "update"]
	endswith(rc.change.after.policy_arn, ":policy/AdministratorAccess")
	msg := sprintf(
		"Attachment '%s' grants AdministratorAccess. Admin access must only come from the break-glass role, not a deployed component.",
		[rc.address],
	)
}
