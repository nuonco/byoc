# nuon-lite — Design

A lean BYOC variant. Same shape as `nuon-byoc-aws-ecs` (ECS Fargate + Aurora Serverless v2), but ClickHouse and Temporal are rented from their managed clouds instead of self-hosted on ECS.

Cost target: ideally ~$300/mo, hard ceiling $500/mo.

## Architecture

| Layer | Component | Notes |
|---|---|---|
| Network | VPC nested stack (v0.4.0) | Same as prototype |
| Compute | ECS Fargate cluster + Cloud Map | Same as prototype |
| DB | Aurora Serverless v2 Postgres (`ctl_api` db only) | min 0.5 ACU |
| Ingress | ALB + ACM cert | Same as prototype |
| Services | `ctl-api` (multi-worker), `dashboard` | No `clickhouse`, no `temporal` |
| Init | `ecs-ctl-api-init` runs `ctl-api migrate up` against Aurora | ClickHouse schema is auto-migrated by ctl-api on boot |
| Observability | CloudWatch billing alarm | Same as prototype |
| External | ClickHouse Cloud, Temporal Cloud | See "Managed-service config" below |

## Components

1. `cluster` — ECS cluster, Cloud Map ns, log group, subnet discovery
2. `task-roles` — execution role + ctl-api task role
3. `aurora` — ctl_api Postgres
4. `alb` — public ALB + ACM cert
5. `temporal-cloud` — provisions Temporal Cloud namespaces + workload API keys via the `temporalio/temporalcloud` TF provider
6. `ecs-ctl-api-init` — one-shot Fargate task running `ctl-api migrate up` against Aurora
7. `ecs-ctl-api` — ctl-api long-running services + per-namespace worker task defs
8. `ecs-dashboard` — dashboard UI
9. `cloudwatch` — billing alarm

Dropped vs prototype: `ecs-clickhouse`, `ecs-clickhouse-init`, `ecs-temporal`, `clickhouse-backup`, `ecs-aurora-init` (folded into ctl-api-init).

## Managed-service config

### ClickHouse Cloud (pre-created by operator)

Operator creates a ClickHouse Cloud service in the UI before install. Connection details enter the app as a `clickhouse_cloud` input group (`host`, `port`, `database`, `username`, `password`, `tls`). The password is a Nuon secret → install_stack secret → `valueFrom` in ctl-api task defs.

ctl-api auto-migrates its ClickHouse tables on startup via its `startup` subcommand (`ch.NewCHMigrator` + `chmigrations.New`). No separate ClickHouse init component is needed. First boot of ctl-api applies the schema.

Why pre-created (not self-provisioned): the ClickHouse Cloud TF provider is younger/less mature than Temporal's, and ctl-api only needs connection info to an existing service. Self-provisioning the service can land as a follow-up.

### Temporal Cloud (self-provisioned via TF provider)

A `temporal-cloud` component uses the `temporalio/temporalcloud` TF provider to create the namespaces + workload API keys for this install.

Input group `temporal_cloud`:
- `tc_account_api_key` — account-level API key used only by this component (sensitive)
- `tc_region` — e.g. `aws-us-east-1`
- `tc_retention_days` — default 7 (per-namespace, with overrides for `vcs`/`emitters` matching byoc-nuon's 30-day setting)
- `tc_namespace_prefix` — defaults to `{{ .nuon.install.name }}`; final namespace names are `<prefix>-<domain>`

ctl-api needs **multiple** namespaces (one per workflow domain), matching byoc-nuon's design. The set is approximately:

`orgs`, `actions`, `apps`, `components`, `installs`, `releases`, `general`, `runners`, `vcs`, `emitters`

The `temporal-cloud` component creates one `temporalcloud_namespace` per name plus a workload-scoped API key per namespace (or one shared key if the provider supports it — verify), and writes each key into AWS Secrets Manager. Outputs expose the gRPC address, namespace IDs, and secret ARNs to `ecs-ctl-api`.

ctl-api workers continue to pick a namespace via `TEMPORAL_NAMESPACE`, one per worker task def. Account-level API key never reaches ctl-api — only workload keys do.

Custom search attributes: verify during wiring whether ctl-api registers any. If it does, the component also creates `temporalcloud_namespace_search_attribute` resources. byoc-nuon does not appear to register any today.

## Carryover from `nuon-byoc-aws-ecs` prototype

- `nuonco/aws-min-sandbox` as the install sandbox
- Single-file `inputs.toml` with `[[group]]`/`[[input]]` blocks
- Tag-based subnet discovery in TF modules (`data "aws_subnets"` filtering on `install.nuon.co/id` + `network.nuon.co/domain`); modules never receive a subnet list via tfvars
- Secret ARNs come from `install_stack.outputs.<secret_name>_arn`; modules `data "aws_secretsmanager_secret_version"` when plaintext is required, otherwise pass the ARN to ECS `valueFrom`
- Wildcard IAM in `maintenance-base.json` for the ECS surface
- Pattern from `nuonco/example-app-configs/ecs-simple`
- ALB outputs use `public_domain_certificate_arn` (not `acm_certificate_arn`)

## Cost estimate

| Item | Est. monthly |
|---|---|
| Aurora Serverless v2 (0.5 ACU baseline) | ~$45 |
| ECS Fargate (10 worker variants + ctl-api API + dashboard, all small) | ~$60–90 |
| ALB | ~$22 |
| NAT (1 AZ) or VPC endpoints | ~$32 or less |
| ClickHouse Cloud Basic (smallest dev service, runs 24/7) | ~$67 |
| Temporal Cloud Essentials (plan minimum at low volume) | ~$100 |
| Misc (Secrets Manager, CloudWatch, data transfer) | ~$15 |
| **Total** | **~$340–370/mo** |

Headroom under the $500 ceiling, above the $300 ideal. Largest swing factor: consolidating the 10 worker task defs onto fewer Fargate tasks (e.g., a single multi-container task running several workers in one Fargate footprint).

## Pricing references

### Temporal Cloud
Sources: <https://temporal.io/pricing>, <https://docs.temporal.io/cloud/pricing>

- **No per-namespace fee.** Billing dimensions are actions, storage, and a support-plan minimum.
- Essentials plan: greater of **$100/mo** or 5% of usage. 1M actions, 1GB active, 40GB retained included.
- Business plan: greater of **$500/mo** or 10% of usage. 2.5M actions, 2.5GB active, 100GB retained.
- Actions: **$50/M** first 5M, declining to $25/M over 200M.
- Storage: **$0.042/GBh active**, **$0.00105/GBh retained**.
- For nuon-lite low-volume installs, Temporal Cloud cost ≈ Essentials minimum (**$100/mo**), regardless of namespace count.

### ClickHouse Cloud
Sources: <https://clickhouse.com/pricing>, <https://www.getbeton.ai/blog/clickhouse-pricing-teardown/>

- **Basic (Development)** — single AZ, 1 replica, 1 TB cap, no idle-to-zero.
  - Compute: **$0.2181/unit-hr** (8–12 GiB RAM, 2 vCPU, fixed)
  - Storage: **$25.30/TB-month**
  - Small 24/7 dev service ≈ **~$67/mo**
- **Scale (Production)** — multi-AZ, configurable, scales to zero.
  - Compute: **$0.2985/unit-hr**; example bills start ~$500/mo
- **Enterprise (Dedicated)** — SAML/SSO, HIPAA/PCI, CMEK; $2.7k–$9.7k/mo examples.

For nuon-lite, the Basic tier fits the budget; Scale alone would eat most of the $500 ceiling.

## Open items to confirm during build

- ClickHouse Cloud port — native (9440) vs HTTPS (8443) depending on which ctl-api client lib is used.
- Whether the `temporalio/temporalcloud` TF provider supports per-namespace workload API keys.
- Whether ctl-api registers Temporal custom search attributes anywhere.
- Whether dropping NAT in favor of VPC endpoints is worth the complexity.
- Whether 10 worker variants must each be a separate Fargate task, or can be consolidated.

## Follow-up tasks (after MVP)

- Self-provision ClickHouse Cloud service via TF provider when mature enough.
- Wire a subscriber to the CloudWatch billing alarm.
- Datadog component (carryover from prototype follow-ups).
- Management + runner-repository fork (carryover from prototype follow-ups).
- Investigate ctl-api code change to consolidate workers onto a single Temporal namespace with task-queue separation.
