Break-glass steps to deprovision this install by hand.

> [!IMPORTANT] **This runbook is a manual fallback.** During a normal deprovision, each stateful component deletes its
> own resources automatically via a `pre-teardown-component` hook (`cloudsql_teardown_ctl_api`,
> `cloudsql_teardown_temporal`, `gcs_teardown`) that runs immediately before that component's Terraform destroy. Those
> hooks are gated by the `-cloudsql-operations` / `-gcs-operations` roles, which are **disabled by default** — the
> customer must enable them before a deprovision can delete these resources, so deletion can never happen by accident.
> Use the steps below only to drive the same actions by hand if a hook fails mid-teardown.

Nuon BYOC on GCP uses Postgres on Cloud SQL for the control-plane (`ctl-api`) and Temporal databases, and GCS buckets
for blob/clickhouse/template storage. These stateful resources are protected — the `block-destructive-changes` policy
and `prevent_destroy` deliberately forbid the deploy/teardown job from ever destroying them.

The runbook works in three phases:

1. **Detach from state (steps 1–3).** Detach each critical resource from Terraform state — safe and reversible
   (**nothing in the cloud is touched**). Once detached, the sandbox deprovision in phase 2 can tear the components down
   without tripping `block-destructive-changes` / `prevent_destroy`, and the **live cloud resources survive**.
2. **Deprovision the sandbox (step 4).** Tears down the install — its components and the sandbox (GKE cluster,
   networking, runner infrastructure). The Cloud SQL instances and GCS buckets were detached from state in phase 1, so
   they **survive** this.
3. **Delete (steps 5–7) — OPTIONAL.** Permanently delete the live cloud resources that survived phases 1–2. You may not
   always want this (e.g. tear everything down but keep the databases/buckets, or delete out-of-band). Cloud SQL deletes
   take a final backup; GCS deletes are irreversible.

> [!WARNING] **Steps 5–7 are destructive and install-specific.** They permanently delete the `ctl-api` and Temporal
> databases and the GCS buckets for install `{{ .nuon.install.id }}`. A final backup is taken for each Cloud SQL
> instance, but the live databases will be gone, and GCS has no snapshot.

> [!NOTE] **GCP backup semantics differ from AWS.** Deleting a Cloud SQL instance also deletes its automated and
> on-demand backups. A *final backup* (`--enable-final-backup`) is the one artifact that survives the deletion — that is
> what the delete step takes, and it is the GCP equivalent of an AWS final DB snapshot.

## Phase 1 — Detach from state

### 1. Detach ctl-api Cloud SQL from state

Removes `google_sql_database_instance.nuon` (plus its database and user) from the `cloudsql_nuon` Terraform state via
the HTTP backend — no destroy. Instance `nuon-{{ .nuon.install.id }}`.

<nuon-action-card name="cloudsql_state_rm_ctl_api"></nuon-action-card>

### 2. Detach Temporal Cloud SQL from state

Removes `google_sql_database_instance.temporal` (plus its database and user) from the `cloudsql_temporal` Terraform
state via the HTTP backend — no destroy. Instance `temporal-{{ .nuon.install.id }}`.

<nuon-action-card name="cloudsql_state_rm_temporal"></nuon-action-card>

### 3. Detach gcs_buckets from state

Removes the three buckets (`{{ .nuon.install.id }}-byoc-nuon-install-blob`, `{{ .nuon.install.id }}-nuon-clickhouse`,
`{{ .nuon.install.id }}-byoc-nuon-install-templates`) and the public-read IAM member from the `gcs_buckets` Terraform
state via the HTTP backend — no destroy.

<nuon-action-card name="gcs_state_rm"></nuon-action-card>

## Phase 2 — Deprovision the sandbox

### 4. Deprovision sandbox

Tears down the install — its components and the sandbox (GKE cluster, networking, runner infrastructure). The Cloud SQL
instances and GCS buckets were detached from Terraform state in phase 1, so they survive this step and are deleted
(optionally) in phase 3.

## Phase 3 — Delete (OPTIONAL, destructive)

> [!CAUTION] These steps permanently delete the cloud resources that survived phases 1–2. Run them only when you
> actually want the resources gone. Each delete derives its instance/bucket names from `install.id`; if a delete fails,
> the resource is still live in GCP but no longer tracked by Terraform — re-run the delete step to finish.

### 5. Delete ctl-api Cloud SQL

Deletes `nuon-{{ .nuon.install.id }}` via the gcloud API, taking a final backup (default 30-day retention) as part of
the deletion.

<nuon-action-card name="cloudsql_delete_ctl_api"></nuon-action-card>

### 6. Delete Temporal Cloud SQL

Deletes `temporal-{{ .nuon.install.id }}` via the gcloud API, taking a final backup (default 30-day retention) as part
of the deletion.

<nuon-action-card name="cloudsql_delete_temporal"></nuon-action-card>

### 7. Delete gcs buckets

Empties and deletes the three buckets via the gcloud API. **Irreversible — GCS has no snapshot.** (No KMS step: the
buckets use Google-managed encryption.)

<nuon-action-card name="gcs_delete"></nuon-action-card>

> [!NOTE] The detach steps (phase 1) run with the runner's own credentials and need no cloud role — they only talk to
> the Nuon Terraform HTTP backend. The delete steps (phase 3) run under the `{{ .nuon.install.id }}-cloudsql-operations`
> / `{{ .nuon.install.id }}-gcs-operations` roles — not the deploy/teardown role — so resource deletion stays an
> explicit operator action. Both ops roles are disabled by default.

> [!NOTE] The state-detach steps talk to the Nuon Terraform HTTP backend directly using the runner's inherited
> credentials. This is an interim mechanism until a first-class "terraform state rm" runbook step exists. It acquires
> the workspace lock, so it is serialized against deploys and drift.

> [!IMPORTANT] Final backups are **retained** for their retention window — they are not deleted by this runbook.
