# ctl-api changes for nuon-lite

What needs to change in `ctl-api` (at [`nuon/services/ctl-api`](https://github.com/nuonco/nuon/tree/main/services/ctl-api)) before nuon-lite can run end-to-end on ECS Fargate + ClickHouse Cloud + Temporal Cloud.

Derived from a source-level audit (see [design.md](./design.md) for the higher-level context).

## Headline

ctl-api is **mostly portable** to ECS:

- It's a stateless Go service that reads all config via Viper/env.
- It makes **zero** live Kubernetes API calls outside the `kuberunner` package.
- The AWS SDK default credential chain already resolves ECS task-role credentials via `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` — no IRSA-specific code.

There are **three small code blockers** that prevent ctl-api from connecting to managed Temporal/ClickHouse, plus **one major refactor** (runner provisioning) that's a separate concern.

---

## Phase 1 — MVP blockers (control plane runs)

These are required for ctl-api to start, migrate, and serve traffic against Temporal Cloud + ClickHouse Cloud. Estimated total: ~50–150 LOC across a handful of files.

### 1. Temporal client: add TLS + API-key auth

**Files**
- `pkg/temporal/client/client.go` — `getOpts()` / `New()`
- `pkg/workflows/worker/client.go` — `getClient()`

**Today**
The client is built with only `HostPort`, `Namespace`, `Logger`, `DataConverter`, `ContextPropagators`, `MetricsHandler`. No `ConnectionOptions.TLS`, no `Credentials`. Workers and API-side clients both use this same minimal options struct, so the gap is symmetric.

**Change**
Add options to the client builder:
- `WithTLS()` — populates `ConnectionOptions.TLS` with system roots + ServerName from the host.
- `WithAPIKey(key string)` — sets `Credentials: tclient.NewAPIKeyStaticCredentials(key)` on `tclient.Options`.

Verify that `GetNamespaceClient` (which calls `NewClientFromExisting`) preserves the `Credentials` from the parent client. If it does not, switch to per-namespace `Dial` and cache the resulting clients in a map.

**Config knobs to add** to `internal.Config` + `pkg/workflows/worker.Config`:
- `TemporalTLSEnabled bool` (env `TEMPORAL_TLS_ENABLED`)
- `TemporalAPIKey string` (env `TEMPORAL_API_KEY`)

**Risk:** Low. Isolated to client construction. Existing in-cluster Temporal deployments keep working by leaving both new vars unset.

### 2. Temporal namespaces: drive from config, not Go constants

**Files**
- `internal/app/general/worker/worker.go` (and equivalent under `orgs/`, `apps/`, `components/`, `installs/`, `releases/`, `runners/`, `actions/`, `onboarding/`, `vcs/`, `emitters/`)
- `internal/app/general/worker/metrics_workflow.go` (iterates over the same list)

**Today**
Each worker package hardcodes `defaultNamespace = "general"` (or similar). The CLI `--namespace` flag selects which fx modules to register — it does **not** override the Temporal namespace string. On Cloud, the actual namespace ID is `<short>.<account>.tmprl.cloud`.

**Change**
Introduce a helper:

```go
// internal/pkg/temporal/namespace.go
func NamespaceFor(cfg Config, short string) string {
    if cfg.TemporalNamespaceSuffix == "" {
        return short
    }
    return short + "." + cfg.TemporalNamespaceSuffix
}
```

Replace every `defaultNamespace = "general"` constant with a call to `NamespaceFor(cfg, "general")`. Same for the other ten domains.

For the metrics workflow that iterates over all namespaces, collect the short names in a slice and map them through `NamespaceFor` at runtime.

**Config knob to add:**
- `TemporalNamespaceSuffix string` (env `TEMPORAL_NAMESPACE_SUFFIX`) — e.g. `nuon-abc.acme123.tmprl.cloud`. Empty → keep short names (compatible with in-cluster Temporal).

**Risk:** Low–medium. ~11 worker packages each need a one-line touch. Tests that assert namespace strings need updating.

**Alternative (preferred long-term but more invasive):** instead of a single suffix, accept a `TEMPORAL_NAMESPACE_MAP` JSON env (`{"general": "nuon-abc-general.acct.tmprl.cloud", ...}`) so per-namespace overrides are possible. Decide during implementation.

### 3. ClickHouse client: wire TLS, drop hardcoded cluster name

**Files**
- `internal/pkg/db/ch/ch.go` — `New()`
- `internal/pkg/db/ch/config.go` — `chOptions()`
- `internal/pkg/db/ch/migrator.go` — `NewCHMigrator`
- `internal/pkg/db/ch/migrations/*.sql` (audit for `ON CLUSTER simple` + explicit `ReplicatedMergeTree` engines)

**Today**
1. `UseTLS` is declared on the `database{}` literal but **never assigned** from `params.Cfg.ClickhouseDBUseTLS`. `CLICKHOUSE_DB_USE_TLS` is silently dead config; the client always dials plaintext native on 9000.
2. `chOptions()` sets `InsecureSkipVerify: true` unconditionally.
3. `migrator.go` and several migration files contain `CREATE OR REPLACE VIEW ... ON CLUSTER simple` plus a gorm option `table_cluster_options: on cluster simple`. Cloud has no user-defined cluster named `simple`; the DDL errors out on first deploy.

**Change**
- `ch.go` `New()`: populate `UseTLS: params.Cfg.ClickhouseDBUseTLS` on the `database{}` literal.
- `config.go` `chOptions()`: only set `InsecureSkipVerify` if a new `CLICKHOUSE_DB_TLS_INSECURE` config is true; otherwise rely on system roots + `ServerName` derived from the host.
- `migrator.go` + migrations: gate every `ON CLUSTER simple` and `ReplicatedMergeTree(...)` engine on a new `CLICKHOUSE_DB_CLUSTER` config. Empty → Cloud-mode (no `ON CLUSTER`, plain `MergeTree`). Non-empty → existing self-hosted behavior, with the value substituted in.

**Config knobs to add:**
- `ClickhouseDBClusterName string` (env `CLICKHOUSE_DB_CLUSTER`) — empty for Cloud.
- `ClickhouseDBTLSInsecure bool` (env `CLICKHOUSE_DB_TLS_INSECURE`) — default false.

**Risk:** Medium. The migration-engine change is touchy — a ReplicatedMergeTree-to-MergeTree swap on an existing self-hosted install is a destructive migration. Gate carefully and document; new installs only.

### 4. Confirm `TEMPORAL_API_KEY` mounts cleanly via Secrets Manager

Not a code change — but worth a smoke test. The Go AWS SDK default chain handles ECS task-role creds. ECS `valueFrom` populates env from Secrets Manager at task start. ctl-api just sees the API key as a string env var. No work, but worth verifying once the code changes above land.

---

## Phase 2 — Runner provisioning refactor

This is the **largest single change**. nuon-lite can install and serve dashboard/API traffic **without** this work — but it can't provision new org or build runners until it's done.

### Problem

`internal/app/runners/worker/kuberunner/*` is pure Helm-on-EKS + Karpenter:

- `provision.go` — calls Helm SDK
- `install_or_upgrade.go` — Helm release lifecycle
- `values.go` — chart values
- `cluster_info.go` — k8s ClusterInfo
- `op_install.go` / `op_upgrade.go` / `op_uninstall.go` — Temporal workflow ops wrapping the above
- `chart.go`, `workflow.go` — chart pinning + workflow registration

None of these primitives exist on ECS Fargate.

### Proposed abstraction

Introduce a single interface in a new package:

```go
// internal/pkg/runnerprov/provisioner.go
package runnerprov

type RunnerProvisioner interface {
    Provision(ctx context.Context, spec RunnerSpec) error  // idempotent install-or-upgrade
    Uninstall(ctx context.Context, runnerID string) error
    Status(ctx context.Context, runnerID string) (RunnerStatus, error)
}

type RunnerSpec struct {
    RunnerID   string
    OrgID      string
    Image      ImageRef            // registry URL + tag
    Env        map[string]string   // RUNNER_ID, RUNNER_API_TOKEN, RUNNER_API_URL, SETTINGS_REFRESH_TIMEOUT, ...
    IAMRoleARN string              // task role on ECS / SA annotation on EKS
    Resources  ResourceRequest     // CPU, Mem
    Tags       map[string]string
}

type RunnerStatus struct {
    State    string  // "pending", "running", "failed", "terminated"
    Message  string
    LastSeen time.Time
}
```

Then:

- The existing `kuberunner` package becomes a `HelmK8sProvisioner` implementation behind this interface, consuming the existing `ClusterInfo` + `NodePool` selection it already does.
- A new `EcsProvisioner` issues `ecs.RunTask` against a per-org cluster, assumes the org's task role, and polls `DescribeTasks` for `Status`.
- The `ProvisionRunner` Temporal workflow (currently importing `kuberunner` directly) imports `runnerprov` and dispatches by `cfg.RunnerBackend` (`helm-eks` | `ecs-fargate`).

### Prerequisite IAM change

The org-level runner role (currently `orgs/<orgID>/runner-<orgID>` with EKS IRSA-style trust) needs its trust policy updated to also trust `ecs-tasks.amazonaws.com`. Terraform-controlled in the mgmt account; not a ctl-api code change.

### Scope estimate

- Interface + dispatch shim: small (~half a day).
- `EcsProvisioner` implementation: 1–2 days for a working V1 (RunTask + RegisterTaskDefinition + role assumption + status polling).
- Refactoring `kuberunner` to fit the interface: half a day (mechanical).
- Workflow + fx wiring: half a day.

Call it **2–4 engineering days** total for someone familiar with both codebases.

---

## Things that do NOT need code changes (handled in nuon-lite already)

These were verified during the source audit:

| Concern | Resolution |
|---|---|
| Secrets injection | All `config:`-tagged secrets in `internal/config.go` come via env. nuon-lite supplies them through ECS `valueFrom` from AWS Secrets Manager. |
| AWS credentials | Go SDK default chain handles ECS task-role creds automatically. |
| `/tmp` writability | Fargate `/tmp` is writable by default; don't set `readOnlyRootFilesystem`. |
| In-cluster k8s API usage | None outside `kuberunner`. `pkg/kube/*` is only imported by runner provisioning. |
| Process model | Single binary, no init containers or sidecars required by ctl-api itself. |
| DNS | No `*.cluster.local` assumptions outside the k8s packages. Temporal/ClickHouse hosts come from config. |
| DogStatsD | ctl-api emits via UDP to `DD_AGENT_HOST`. On Fargate, add a `datadog-agent` sidecar to the task def (separate from ctl-api code). |

---

## Suggested implementation order

1. **ClickHouse fixes (#3)** — smallest, unblocks first-boot migrations. Test against ClickHouse Cloud directly.
2. **Temporal TLS + API key (#1)** — required before any worker can dial Cloud.
3. **Temporal namespace resolution (#2)** — required before workers can find their namespaces.
4. **Smoke-test on nuon-lite** — verify ctl-api boots, migrates, runs workflows in dev install.
5. **Runner abstraction (#4)** — separate PR after nuon-lite control plane is healthy.

Each of 1–3 should be its own PR, separately deployable to existing byoc-nuon installs without behavior change (all new config knobs default to the current behavior).

---

## Out of scope for this doc

- Datadog component (separate follow-up — see [design.md](./design.md)).
- Self-provisioned ClickHouse Cloud via TF provider (follow-up).
- Management + runner-repository fork (follow-up).
- Any optimization of the worker-count footprint (consolidating 10 workers onto fewer Fargate tasks — possible after refactor, not required).

## References

- ctl-api repo: <https://github.com/nuonco/nuon> (services/ctl-api)
- Temporal Cloud Go SDK auth: <https://docs.temporal.io/develop/go/temporal-clients#connect-to-temporal-cloud>
- ClickHouse Cloud connection guide: <https://clickhouse.com/docs/cloud/get-started/cloud-quick-start>
- ECS RunTask API: <https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_RunTask.html>
