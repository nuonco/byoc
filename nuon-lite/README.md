# nuon-lite

Lean Fargate-based variant of Nuon BYOC. Uses **ClickHouse Cloud** and **Temporal Cloud** instead of self-hosting either, then puts the rest of the control plane (`ctl-api`, `dashboard`) on ECS Fargate with an Aurora Serverless v2 backing store.

Target hosting cost: **~$340–370/mo**; hard ceiling $500/mo. See [design.md](./docs/design.md) for the full breakdown and rationale.

## Architecture summary

| Layer | Where it runs |
|---|---|
| VPC, runner | CloudFormation install_stack (nested v0.4.0 templates) |
| Cluster, ALB, secrets, ctl-api, dashboard | ECS Fargate in this app |
| Postgres (`ctl_api` db) | Aurora Serverless v2 in this app |
| ClickHouse | ClickHouse Cloud (pre-created by operator) |
| Temporal | Temporal Cloud namespaces self-provisioned by the `temporal_namespaces` component |

## Prerequisites before installing

1. A **ClickHouse Cloud** service exists. Capture host/port/db/user and paste the password into the `clickhouse_cloud_password` Nuon secret.
2. A **Temporal Cloud** account-level API key with permission to create namespaces and workload API keys. Paste into the `temporal_cloud_account_api_key` Nuon secret.

ctl-api auto-migrates ClickHouse tables on its first boot; Temporal Cloud manages its own storage. No separate `clickhouse-init` or `temporal-init` step exists.

## Where to look next

- [Setup guide](./docs/setup.md) — operator instructions for every external dependency
- [Design + cost + open items](./docs/design.md)
- [ctl-api changes plan](./docs/ctl-api-changes.md) — code changes needed in ctl-api to run on ECS
- [Deploy control-plane runbook](./runbooks/deploy_control_plane.md)
- [Inputs](./inputs.toml)
