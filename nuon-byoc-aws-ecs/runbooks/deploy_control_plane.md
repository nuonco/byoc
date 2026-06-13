# Deploy control plane

Runs the standard ECS deploy flow for the Nuon control plane.

1. **Aurora schema migrations** — `aws ecs run-task` against the `ecs_aurora_init` task definition. Runs ctl-api Aurora migrations and `temporal-sql-tool setup-schema && update-schema`.
2. **ClickHouse schema migrations** — `aws ecs run-task` against the `ecs_clickhouse_init` task definition.
3. **Deploy Temporal** — terraform apply of `ecs_temporal`. Force-replaces task defs; ECS rolls services.
4. **Deploy ctl-api** — terraform apply of `ecs_ctl_api` (public/admin/workers).
5. **Force new ctl-api deployment** — explicit `aws ecs update-service --force-new-deployment` to make sure new task defs are picked up even if image tags didn't change.
6. **Deploy dashboard** — terraform apply of `ecs_dashboard`.

If any step fails, fix and re-run from that step. Steps 1 and 2 are idempotent.
