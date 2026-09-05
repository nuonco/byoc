# Block Destructive Changes Policy (terraform_module)
#
# Prevents Terraform plans from deleting or replacing the stateful resources
# that hold the control plane and customer-install data. Destroy and replace
# are both denied: a replace is a destroy plus create, and the data on the
# original object is still lost.
#
# Checks:
#   - deny deletion of critical stateful resources    (deny)
#   - deny replacement of critical stateful resources (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).
#
# Intentional teardown must detach these addresses from state first
# (rds_state_rm_*, s3_state_rm) so Terraform never plans a destroy.

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Stateful resources whose loss is catastrophic in production.
critical_resources := {
	"aws_db_instance",
	"aws_rds_cluster",
	"aws_s3_bucket",
	"aws_kms_key",
	"aws_secretsmanager_secret",
}

# ──────────────────────────────────────────────────────────────────────────────
# Block destroy and replace of any critical resource.
# Terraform encodes replace as [delete, create] or [create, delete]; both
# include "delete" and must be denied the same as a pure destroy.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in critical_resources
	rc.change.actions[_] == "delete"
	msg := sprintf(
		"Destroy or replace of critical resource '%s' (type: %s) is not allowed. Remove it from this plan, or detach it from state first (see the deprovision runbook).",
		[rc.address, rc.type],
	)
}
