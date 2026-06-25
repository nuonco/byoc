Steps to deprovision this install.

Nuon BYOC on AWS uses Postgres on RDS for the control-plane (`ctl-api`) and Temporal databases. These stateful databases
must be removed **before** you can run a tear-down job on their components — the `block-destructive-changes` policy
deliberately forbids the deploy/teardown job from ever destroying a database.

For each database the runbook detaches it from Terraform state and then deletes it via the AWS API, taking a final
snapshot so it stays recoverable. Detaching from state **first** means Terraform never observes the deletion as drift,
so the remaining resources (security group, parameter group) tear down cleanly afterwards.

> [!WARNING] > **Destructive, install-specific operation.** This permanently deletes the `ctl-api` and Temporal
> databases for install `{{ .nuon.install.id }}`. A final snapshot is taken for each, but the live databases will be
> gone. Run the steps in order.

> [!CAUTION] Each database is detached from state **before** it is deleted. If a run fails after the detach but before
> the delete, the database is still live in AWS but no longer tracked by Terraform — re-run the corresponding delete
> step to finish.

## CTL API RDS Cluster

Instance `nuon-{{ .nuon.install.id }}` (component `rds_cluster_nuon`).

### 1. Detach ctl-api RDS from state

Removes `module.db.module.db_instance.aws_db_instance.this[0]` from the `rds_cluster_nuon` Terraform state via the HTTP
backend — no destroy.

<nuon-action-card name="rds_state_rm_ctl_api"></nuon-action-card>

### 2. Delete ctl-api RDS

Deletes `nuon-{{ .nuon.install.id }}` via the AWS API, taking a timestamped final snapshot named
`nuon-{{ .nuon.install.id }}-final-` + the deletion time, as part of the deletion.

<nuon-action-card name="rds_delete_ctl_api"></nuon-action-card>

## Temporal RDS Cluster

Instance `temporal-{{ .nuon.install.id }}` (component `rds_cluster_temporal`).

### 3. Detach Temporal RDS from state

Removes `module.db.module.db_instance.aws_db_instance.this[0]` from the `rds_cluster_temporal` Terraform state via the
HTTP backend — no destroy.

<nuon-action-card name="rds_state_rm_temporal"></nuon-action-card>

### 4. Delete Temporal RDS

Deletes `temporal-{{ .nuon.install.id }}` via the AWS API, taking a timestamped final snapshot named
`temporal-{{ .nuon.install.id }}-final-` + the deletion time, as part of the deletion.

<nuon-action-card name="rds_delete_temporal"></nuon-action-card>

> [!NOTE] The delete steps run under the `{{ .nuon.install.id }}-rds-operations` role (tag-scoped RDS backup +
> destruction permissions), not the deploy/teardown role — so database deletion stays an explicit operator action.

> [!NOTE] The state-detach steps talk to the Nuon Terraform HTTP backend directly using the runner's inherited
> credentials. This is an interim mechanism until a first-class "terraform state rm" runbook step exists. It acquires
> the workspace lock, so it is serialized against deploys and drift.

> [!IMPORTANT] Final snapshots are **retained** — they are not deleted by this runbook. Use the `delete_rds_snapshots`
> action to remove them once they are no longer needed.
