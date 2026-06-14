# Deploy control plane

Runs the standard ECS deploy flow for the nuon-lite control plane.

1. **Provision Temporal Cloud namespaces** — terraform apply of `temporal_namespaces`. Creates one Temporal Cloud namespace per workflow domain plus a workload API key per namespace, stashed in AWS Secrets Manager and tagged for discovery by `ctl_api`.
2. **Aurora schema migrations** — `aws ecs run-task` against the `ctl_api_migrations` task definition. Runs `ctl-api migrate up` against the ctl_api database. ClickHouse schema is auto-migrated by ctl-api on its first boot, so no separate ClickHouse init step exists.
3. **Deploy ctl-api** — terraform apply of `ctl_api` (public/admin services + one worker service per Temporal namespace).
4. **Force new ctl-api deployment** — explicit `aws ecs update-service --force-new-deployment` to make sure new task defs are picked up even if image tags didn't change.
5. **Deploy dashboard** — terraform apply of `dashboard`.

If any step fails, fix and re-run from that step. Steps 1 and 2 are idempotent.

**Prerequisites before first install:**
- ClickHouse Cloud service exists; host/port/db/user supplied as inputs, password populated into the `clickhouse_cloud_password` secret.
- Temporal Cloud account API key with namespace + api-key admin scope populated into the `temporal_cloud_account_api_key` secret.
