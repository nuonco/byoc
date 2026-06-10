# RDS Data Protection Policy (terraform_module)
#
# Guards the two control-plane Postgres clusters (ctl-api + Temporal) against
# the most catastrophic production failure modes: losing or exposing the
# database that backs the entire Nuon install.
#
# Checks:
#   - deletion_protection must be enabled       (warn -> deny)
#   - rds.force_ssl must be "1" (require TLS)    (warn -> deny)
#   - backup_retention_period must be >= 7 days  (warn)
#   - skip_final_snapshot must be false          (deny)
#   - storage_encrypted must be true             (deny)
#
# Input: Terraform JSON plan (input.plan.resource_changes).

package nuon

import future.keywords.contains
import future.keywords.if
import future.keywords.in

min_backup_retention_days := 7

# ──────────────────────────────────────────────────────────────────────────────
# RDS deletion protection.
#
# Warns so installs that have not yet enabled deletion protection are not
# blocked. TODO: promote to `deny` once every RDS component sets
# deletion_protection = true.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_db_instance"
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.deletion_protection == false
	msg := sprintf(
		"RDS instance '%s' has deletion_protection disabled. The control-plane database must be protected from accidental deletion.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Enforce TLS for database connections via the rds.force_ssl parameter.
#
# Warns during the TLS rollout. TODO: promote to `deny` once every RDS parameter
# group sets rds.force_ssl = "1".
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_db_parameter_group"
	rc.change.actions[_] in ["create", "update"]
	some p in rc.change.after.parameter
	p.name == "rds.force_ssl"
	p.value == "0"
	msg := sprintf(
		"RDS parameter group '%s' sets rds.force_ssl=0, allowing unencrypted database connections. Set it to \"1\" to require TLS.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Backup retention window. Kept as a warning so the threshold stays tunable.
# ──────────────────────────────────────────────────────────────────────────────
warn contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_db_instance"
	rc.change.actions[_] in ["create", "update"]
	retention := rc.change.after.backup_retention_period
	retention < min_backup_retention_days
	msg := sprintf(
		"RDS instance '%s' has backup_retention_period=%d (< %d days). Increase retention to survive accidental data loss.",
		[rc.address, retention, min_backup_retention_days],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Never skip the final snapshot - it is the last line of defense on delete.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_db_instance"
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.skip_final_snapshot == true
	msg := sprintf(
		"RDS instance '%s' has skip_final_snapshot=true. A final snapshot must be taken so the database can be recovered after deletion.",
		[rc.address],
	)
}

# ──────────────────────────────────────────────────────────────────────────────
# Storage must be encrypted at rest.
# ──────────────────────────────────────────────────────────────────────────────
deny contains msg if {
	some rc in input.plan.resource_changes
	rc.type == "aws_db_instance"
	rc.change.actions[_] in ["create", "update"]
	rc.change.after.storage_encrypted == false
	msg := sprintf(
		"RDS instance '%s' has storage_encrypted=false. Control-plane databases must be encrypted at rest.",
		[rc.address],
	)
}
