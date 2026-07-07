# IAM AssumeRole Scope Policy (terraform_module)
#
# sts:AssumeRole on Resource:"*" in a permission policy allows a workload to
# assume ANY role in the customer's account — including provision, deprovision,
# and break-glass roles. This is the most direct privilege-escalation vector in
# the control plane: one compromised pod → full account takeover.
#
# Checks:
#   - sts:AssumeRole on Resource "*" in a permission policy   (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

iam_policy_resources := {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy"}

assume_role_actions := {"sts:AssumeRole", "sts:*"}

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

# ──────────────────────────────────────────────────────────────────────────────
# Deny sts:AssumeRole on Resource "*" in permission policies.
#
# Trust policies (aws_iam_role.assume_role_policy) define who can assume a role
# and are not caught here — they use a different resource type. Permission
# policies (aws_iam_policy) define what the role can do — sts:AssumeRole on *
# there means the workload can assume any role in the account.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in iam_policy_resources
	rc.change.actions[_] in ["create", "update"]
	some stmt in statements(parse_policy(rc.change.after.policy))
	stmt.Effect == "Allow"
	some action in to_set(stmt.Action)
	action in assume_role_actions
	"*" in to_set(stmt.Resource)
	msg := sprintf(
		"IAM policy '%s' grants '%s' on Resource \"*\". A compromised workload could assume any role in the account (including admin/break-glass). Restrict Resource to specific role ARNs.",
		[rc.address, action],
	)
}
