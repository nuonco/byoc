# warns on destructive changes to managed RDS databases. covers both
# rds_cluster_nuon and rds_cluster_temporal, which use the
# terraform-aws-modules/rds/aws module and produce aws_db_instance resources
# (not aws_rds_cluster, despite the component name).
#
# warn-only for the initial rollout; intent is to surface destructive plans
# during review without blocking deploys.

package nuon

# delete: outright removal of the DB instance
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.actions[_] == "delete"
	msg := sprintf("RDS deletion: '%s' is being deleted, which would destroy the database", [resource.address])
}

# replace: delete + create in the same plan (e.g. identifier change,
# engine version downgrade, storage type change forcing replacement)
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	actions := {a | a := resource.change.actions[_]}
	actions["delete"]
	actions["create"]
	msg := sprintf("RDS replacement: '%s' is being replaced (delete + create), which would destroy the database", [resource.address])
}

# storage shrink: AWS forbids this in-place and will force a replacement
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.actions[_] == "update"
	resource.change.after.allocated_storage < resource.change.before.allocated_storage
	msg := sprintf("RDS storage shrink: '%s' allocated_storage going from %d to %d would force replacement", [resource.address, resource.change.before.allocated_storage, resource.change.after.allocated_storage])
}

# backups disabled: going from any positive retention to 0 turns off
# automated backups
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.before.backup_retention_period > 0
	resource.change.after.backup_retention_period == 0
	msg := sprintf("RDS backups disabled: '%s' backup_retention_period going from %d to 0 would turn off automated backups", [resource.address, resource.change.before.backup_retention_period])
}

# deletion_protection flipped off: usually a precursor to a delete
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.before.deletion_protection == true
	resource.change.after.deletion_protection == false
	msg := sprintf("RDS deletion_protection disabled on '%s'", [resource.address])
}

# skip_final_snapshot during a delete: caller is opting out of the safety
# net that would otherwise let us recover
warn contains msg if {
	resource := input.plan.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.actions[_] == "delete"
	resource.change.after.skip_final_snapshot == true
	msg := sprintf("RDS '%s' is being deleted with skip_final_snapshot=true; no final snapshot will be taken", [resource.address])
}
