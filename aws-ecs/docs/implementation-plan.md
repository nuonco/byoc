# `aws-ecs` Implementation Plan

A phased plan for building the Fargate-based Nuon BYOC variant. Mirrors the `byoc-nuon` app-config structure (components/, inputs/, secrets/, stack.toml) but targets ECS Fargate + Aurora Serverless v2 + single-node ClickHouse on Fargate-with-managed-EBS instead of EKS + RDS + multi-node ClickHouse on K8s.

See [architecture.md](./architecture.md) for the target design and [aws-cost-estimate.md](./aws-cost-estimate.md) for cost context.

**Key decision:** keep ClickHouse, run it as a Fargate task with an attached managed EBS volume. Avoids upstream ctl-api changes and keeps everything on a single ECS deployment model — no EC2 to patch. The Aurora-only alternative is documented in `architecture.md` as a fallback if Fargate-EBS proves unreliable or cost ceiling becomes a problem.

---

## Phase 1 — App-config skeleton

Bootstrap the directory structure so future components have a place to land.

- `aws-ecs/stack.toml` — declare provider, region, runner, similar to `byoc-nuon/stack.toml`
- `aws-ecs/installer.toml`, `runner.toml`, `metadata.toml` — copy + adapt from byoc-nuon
- `aws-ecs/inputs/` — port relevant inputs (domains, ACM, Datadog opt-in, ClickHouse config)
- `aws-ecs/input_groups/` — collapse to fewer groups; keep `clickhouse.toml` (simpler shape — just host/creds, no operator/cluster sizing)
- `aws-ecs/secrets/` — DB creds + ClickHouse password
- `aws-ecs/sandbox.toml` + `sandbox.tfvars` — sandbox values for local iteration
- `aws-ecs/README.md` — pointer to docs

**Exit criteria:** `nuonctl stack validate` passes against the empty skeleton.

---

## Phase 2 — Foundational infrastructure components

Components run in numeric prefix order, same convention as byoc-nuon.

| Component | Type | Provides |
|---|---|---|
| `0-tf-management` | terraform | KMS keys, account-level shared resources |
| `0-tf-runner-repository` | terraform | ECR repos for ctl-api, dashboard-ui, temporal images |
| `1-cfn-vpc` | cloudformation | VPC, 2 AZs, 2 public + 2 private subnets, route tables, IGW |
| `1-tf-vpc-endpoints` | terraform | Interface endpoints (ECR API/DKR, Secrets Manager, Logs, STS); S3 gateway endpoint |
| `1-tf-fck-nat` | terraform | `t4g.nano` NAT-instance ASG in one public subnet, route from private subnets |
| `2-tf-aurora` | terraform | Aurora Serverless v2 cluster (min 0.5 / max 1 ACU), `ctl_api` + `temporal` databases, Secrets Manager entries for creds |
| `2-s3-buckets` | terraform | blob, install-templates, clickhouse-backups buckets |
| `3-tf-wildcard-cert` | terraform | ACM cert for `*.<domain>` (keep from byoc-nuon) |
| `3-tf-alb` | terraform | Public ALB, HTTPS listener with the wildcard cert, default 404 action |

**Exit criteria:** All foundational components apply cleanly into a sandbox account. Aurora is reachable from a test Fargate task; ALB serves a 404 over HTTPS.

---

## Phase 3 — ECS cluster + ClickHouse + database initialization

Cluster comes up first so the ClickHouse service can launch; then init tasks run schema migrations against both Aurora and ClickHouse.

| Component | Provides |
|---|---|
| `5-tf-ecs-cluster` | ECS cluster, default capacity providers (FARGATE + FARGATE_SPOT), Cloud Map namespace for service discovery |
| `6-tf-task-roles` | IAM task roles (ctl-api, temporal, dashboard, clickhouse) + execution role with managed-volume permissions |
| `7-tf-ecs-clickhouse` | ClickHouse task def + service (0.5 vCPU / 4 GB, on-demand only), managed EBS volume (50 GB gp3, retain-on-delete, KMS-encrypted), security group allowing 9000/8123 from the cluster SG, Cloud Map DNS as `clickhouse.nuon-byoc.local` |
| `8-ecs-aurora-init` | one-shot ECS task (run-task) — `temporal-sql-tool setup-schema` + `update-schema` against `temporal` DB; ctl-api migrations against `ctl_api` DB |
| `8-ecs-clickhouse-init` | one-shot ECS task that runs ctl-api's ClickHouse schema migrations against the Fargate ClickHouse service |

**Exit criteria:** ClickHouse service reaches steady state and responds to `SELECT 1` from a test task. All three databases (Aurora ctl_api, Aurora temporal, ClickHouse) have schemas applied, idempotent on re-run. Killing the ClickHouse task and letting ECS replace it preserves data (verifies the managed-EBS reattach flow).

---

## Phase 4 — Application services

| Component | Provides |
|---|---|
| `9-tf-ecs-temporal` | Temporal server task def + service (0.5 vCPU / 1 GB, Spot, single replica) + temporal-ui task def + service |
| `10-tf-ecs-ctl-api` | ctl-api-public + ctl-api-admin + ctl-api-workers task defs + services; ALB target groups + listener rules. Wires both Aurora and ClickHouse env vars + secrets. |
| `11-tf-ecs-dashboard` | dashboard-ui task def + service + ALB listener rule |

Each ECS service registers in Cloud Map so intra-cluster traffic uses service DNS instead of going through the ALB.

**Exit criteria:** All services reach steady state. `api.<domain>/health` returns 200; Temporal UI loads; dashboard loads; runner status page shows live heartbeats (verifies the CH path is wired).

---

## Phase 5 — DNS, observability, hardening

- `12-tf-route53` — A/AAAA records for `api`, `auth`, `runner`, `slack`, `app`, `admin` subdomains pointing at the ALB
- `13-tf-cloudwatch` — Log groups with 1-day retention, billing alarm at $290/mo on the account
- `13-tf-clickhouse-backup` — EventBridge schedule (daily) triggers an ECS run-task that execs `clickhouse-backup create_remote` against the ClickHouse service via ECS Exec, writing to the clickhouse-backups S3 bucket. Lifecycle policy on the bucket expires backups after 14 days.
- `14-tf-datadog` (optional, gated by input) — Datadog ECS integration if customer opted in

**Exit criteria:** All product subdomains resolve; logs flow to CloudWatch; billing alarm armed; ClickHouse backup verified by a successful restore drill in the sandbox.

---

## Phase 6 — Runbooks, policies, actions

Port from byoc-nuon, adapting for the ECS shape:

- `runbooks/deploy_control_plane.toml` — equivalent of EKS deploy runbook but for ECS service updates
- `policies/` — keep image-pinning, image-registry-trust, s3-data-protection, **clickhouse-backups-present** (still relevant)
- `actions/` — port relevant ops actions (rotate-creds, restart-service, drain-runner, clickhouse-restore-from-backup)
- `break_glass.toml` — keep, retarget at ECS Exec uniformly (no kubectl, no SSH) — same flow for every service including ClickHouse

**Exit criteria:** Standard ops flows (deploy, rollback, restart, exec, CH restore) work via runbooks.

---

## Phase 7 — Sandbox validation + cost verification

- Deploy to a clean sandbox AWS account
- Run end-to-end install flow: create org → register runner → install an app
- Let it idle 7 days, pull Cost Explorer report, compare against the ~$290 typical estimate
- Load test: simulate runner heartbeats at expected production rate, watch:
  - Aurora `ServerlessDatabaseCapacity` and `VolumeWriteIOPs` — if max ACU is pegged, decide between raising to 2 (over budget) or downsizing CH to keep ceiling under $300
  - ClickHouse task CPU + memory + EBS usage — if 0.5 vCPU / 4 GB is saturated or 50 GB fills, bump task size (Fargate resize requires task replacement; volume grow is online)
  - Managed-EBS reattach behavior: force-stop the CH task three times in a row, confirm data persists each time
- Verify ClickHouse restore: snapshot to S3, delete the managed volume, recreate the service, confirm restore + runner status dashboard recovers

**Exit criteria:** 7-day idle cost ≤ $300, all golden-path flows green, ClickHouse restore drill succeeds, managed-EBS reattach drill succeeds.

---

## Phase 8 — Future cold-storage migration (deferred, only if needed)

Out of scope for MVP. Triggered if ClickHouse on `t4g.small` is consistently saturated by OTel/policy-event volume:

1. Add an `EventStore` abstraction in ctl-api (ClickHouse / S3-Parquet implementations)
2. Dual-write `policy_report_events` + `otel_*` to S3 alongside ClickHouse; validate parity
3. Glue catalog + partition projection for the S3 tables
4. Migrate analytics dashboard reads to Athena (or to pre-aggregated rollups computed by a worker)
5. Stop ClickHouse writes for the cold tables; let TTL clean them out of CH

Hot-path tables (`runner_heart_beats`, `runner_health_checks`, MV) stay in ClickHouse permanently.

---

## Dependencies & risks

- **No upstream ctl-api dependency for MVP** — keeping ClickHouse means we use the existing config surface and driver unchanged.
- **ClickHouse is a single-AZ, single-task SPOF.** Managed EBS persists across task restarts but lives in one AZ. Backup discipline matters — Phase 5 backup automation + Phase 7 restore drill are non-optional gates.
- **Managed EBS for Fargate is a ~2-year-old feature** — orphan-volume risk if a service is mis-deleted. Use retain-on-delete + KMS encryption; verify reattach behavior in Phase 7.
- **Cost ceiling exceeds $300** under Aurora-pegged worst case (~$335). Steady state is ~$290. If real load drives Aurora to its max ACU repeatedly, choose: raise budget, lower Aurora max_capacity (degrades DB latency), or downsize the ClickHouse task.
- **Aurora I/O cost** — still a watch item even without OTel write load (now on ClickHouse). Billing alarm at $290/mo catches drift.
- **Worker consolidation** — running all ctl-api Temporal workers in one task is a step down from per-namespace pools. If the installs/runners queue starves the others under load, split into two worker tasks (~+$15/mo). Detectable via Temporal worker task-queue backlog metrics.
- **Fargate Spot interruption** — Temporal and ctl-api workers must reconnect cleanly. ClickHouse runs on-demand only (stateful, no Spot). Standard Temporal worker patterns handle this; verify in Phase 7.

---

## Open questions to resolve before Phase 1

1. Region: us-east-1 default, or follow each customer's preference? Affects whether VPC endpoints and pricing assumptions hold.
2. Do we want Aurora min ACU at 0 (scale-to-zero, $0 idle, ~15s cold start) for true dev sandboxes, separate from the BYOC profile?
3. Single shared ECS cluster per BYOC install, or one cluster per environment (sandbox vs prod)? Affects naming + IAM scoping.
4. ClickHouse upgrade strategy — manual blue/green via a second EC2 + DNS swap, or in-place with a maintenance window? Decide before Phase 5.
