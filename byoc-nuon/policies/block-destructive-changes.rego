# Block Destructive Changes Policy (terraform_module)
#
# Prevents Terraform plans from deleting or replacing the stateful resources
# that hold the control plane and customer-install data. Deleting any of these
# is effectively unrecoverable in production.
#
# Checks:
#   - deny deletion of critical stateful resources   (deny)
#   - warn on replacement (delete + create)           (warn)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

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
# Block outright deletion of any critical resource.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type in critical_resources
	rc.change.actions[_] == "delete"
	# A pure replace is [delete, create]; a pure delete is just [delete].
	not is_replace(rc.change.actions)
	msg := sprintf(
		"Deletion of critical resource '%s' (type: %s) is not allowed. Remove the destroy from this plan or use a deliberate break-glass procedure.",
		[rc.address, rc.type],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Replacing a critical resource also destroys its data; warn loudly so an
# operator must consciously approve it.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type in critical_resources
	is_replace(rc.change.actions)
	msg := sprintf(
		"Critical resource '%s' (type: %s) will be REPLACED (destroyed and recreated). Confirm the data is backed up before applying.",
		[rc.address, rc.type],
	)
}

is_replace(actions) if {
	count(actions) == 2
	actions[0] == "delete"
	actions[1] == "create"
}

is_replace(actions) if {
	count(actions) == 2
	actions[0] == "create"
	actions[1] == "delete"
}
