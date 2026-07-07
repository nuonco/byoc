# Cloud SQL PITR restore

Recover **one** control-plane Cloud SQL instance to a point in time and repoint its app at the recovered instance. The
`target_component` input selects which instance the runbook operates on:

| `target_component` | Source Cloud SQL instance | Redeployed component | Override input             |
| ------------------ | ------------------------- | -------------------- | -------------------------- |
| `ctl_api`          | `cloudsql_nuon`           | `ctl_api`            | `db_host_override`         |
| `temporal`         | `cloudsql_temporal`       | `temporal`           | `temporal_db_host_override`|

Point-in-time recovery (PITR) is enabled on both instances, so their transaction logs are archived continuously and you
can restore to any moment within the `transaction_log_retention_days` window (default 7 days).

> **PITR is not in-place.** GCP implements PITR as a *clone*: it replays the source instance's transaction logs up to the
> chosen timestamp into a **brand-new** instance and never touches the live one. Recovery is clone → repoint, not an
> in-place rollback.

<div style="padding-bottom: 1rem;"><nuon-banner theme="warn">This runbook has a manual operator step between step 1 (clone) and step 2 (repoint). Step 1 creates the recovered instance and reports its private IP; you must set the override input to that IP before step 2 takes effect. If the runbook runs straight through, set the input and re-run step 2.</nuon-banner></div>

## Inputs

- `target_component` — `ctl_api` or `temporal` (see table above). Drives both the clone and the repoint.
- `point_in_time` — RFC 3339 UTC timestamp, e.g. `2026-07-06T14:30:00Z`. Must be within the retention window and not in
  the future.
- `pitr_target_instance_name` *(optional)* — name for the recovered instance. Defaults to `<source>-pitr-<timestamp>`.

## Step 1 — PITR clone

Clones the selected source instance into the new instance and prints the recovered instance's **name** and **private IP**
(also surfaced as the `CLOUDSQL_PITR_TARGET_INSTANCE` / `CLOUDSQL_PITR_TARGET_ADDRESS` action outputs). The live instance
is not modified.

## Operator step — set the override

Using the address reported by step 1, set the matching install input (see the table):

```toml
# target_component = ctl_api
db_host_override = "<recovered instance private IP>"

# target_component = temporal
temporal_db_host_override = "<recovered instance private IP>"
```

`ctl-api.yaml` resolves `DB_HOST` / `DB_REPLICA_HOST` from `db_host_override`, and the `temporal` component resolves
`db_instance_address` from `temporal_db_host_override`, each falling back to the Terraform-managed instance when unset.
The recovered instance is a full clone, so its database, users (including IAM auth), and credentials all carry over — no
credential changes are needed.

## Step 2 — repoint (redeploy)

Redeploys the selected component (`component_name` is templated from `target_component`) so its DB host re-renders to the
override address. The app is now serving from the recovered instance.

## Reverting

Clear the override input and redeploy the component. The DB host falls back to the Terraform-managed instance.

## Caveats

- The recovered instance is **not** managed by Terraform. It will not receive future config changes from the
  `cloudsql_*` component and will not be torn down by a normal deprovision. Once you have confirmed recovery, either
  promote it into Terraform (a state swap — out of scope here) or migrate the data back into the managed instance and
  delete the recovered one.
- Both instances run and are billed separately until you delete one.
- This runbook does not delete the original instance. It stays intact so you can revert.
- For `temporal`, `temporal_init_db` (schema setup) does not need re-running — the recovered clone already contains the
  schema.
- **Platform note:** step 2 relies on `component_deploy.component_name` accepting the `{{ .runbook_inputs.target_component }}`
  template. This is the first runbook here to template a step field — verify it resolves on the first run; if the engine
  does not template `component_name`, split step 2 into two role/condition-guarded deploy steps or repoint manually.
