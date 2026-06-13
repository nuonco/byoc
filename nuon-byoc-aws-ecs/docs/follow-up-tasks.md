# Follow-up tasks

Work deferred from earlier phases. Re-add as standalone PRs when the surrounding components need them.

## Phase 5 caveats

### Billing alarm has no subscription

`13-tf-cloudwatch` creates an SNS topic + `EstimatedCharges` alarm at $290, but nothing subscribes to the topic. Add a subscription input (email, Slack webhook via Lambda, or wire to the Datadog integration once `14-tf-datadog` lands).

### ClickHouse backup task command won't shell-expand

`13-tf-clickhouse-backup` task def passes `["create_remote", "scheduled-$(date -u +%Y%m%dT%H%M%S)"]` as the container command. ECS does not invoke a shell, so `$(date ...)` is taken literally. Fix one of:
- Wrap with `["sh", "-c", "create_remote scheduled-$(date ...)"]`
- Let `clickhouse-backup` auto-name the backup (drop the second arg)

### Datadog component deferred

The `datadog` input group + `datadog_enabled` / API key inputs exist, but there's no `14-tf-datadog` component module yet. Add when a customer opts in.

## Fork `management` + `runner-repository` modules for ECS

Both modules live in `byoc-nuon/src/components/` and assume EKS. They were removed from `nuon-byoc-aws-ecs/components/` so the directory would sync; re-add them once forked into `nuon-byoc-aws-ecs/src/components/`.

### EKS-specific surface in `management`

From `byoc-nuon/src/components/management/variables.tf` + `management.tfvars`:

| Variable | EKS-specific? | Why |
|---|---|---|
| `region`, `management_account_id`, `install_id`, `org_id` | No | Generic |
| `root_domain`, `nuon_dns_domain` | No | Generic |
| `cluster` (object) | **Yes** | `arn`, `certificate_authority_data`, `endpoint`, `name`, `platform_version`, `oidc_provider`, `oidc_provider_arn` — EKS cluster fields. ECS clusters have only `name` + `arn`; no OIDC provider, no CA data, no platform version. |
| `ecr` (object) | No | Generic ECR passthrough |
| `ctl_api_role_arn` | **Yes, indirectly** | Refers to a k8s service-account IAM role (IRSA). For ECS we use an ECS task role instead. |

### What the module does with those fields

- `ecr_access_role.tf` — uses `cluster.oidc_provider_arn` to build an IRSA trust policy so the in-cluster service account can pull from ECR
- `org_access_role.tf` — same OIDC pattern
- `route53_zone_access_role.tf` — same OIDC pattern for the dashboard's k8s SA to manage DNS

The EKS-specific surface is concentrated in the IRSA trust policies. For ECS, every one of those trust policies needs to be rewritten to trust an **ECS task role ARN** instead of an OIDC web-identity federation, because Fargate tasks get credentials from a task role, not an OIDC-federated SA.

### Fork work

- Drop the `cluster` variable entirely (or shrink to `{name, arn}` if anything needs it)
- Replace `ctl_api_role_arn` (k8s SA role) with `ctl_api_task_role_arn` (ECS task role)
- Rewrite each `*_access_role.tf` to trust the ECS task role principal (`Service: ecs-tasks.amazonaws.com` + condition on the task role ARN) instead of the OIDC federated principal

Nothing else in the module is EKS-bound.

### Verify ctl-api migration CLI subcommands

The init tasks (`ecs-aurora-init`, `ecs-clickhouse-init`) invoke:
- `ctl-api migrate up` against Aurora
- `ctl-api migrate-clickhouse up` against ClickHouse

Confirm these subcommand names against the ctl-api source. If they differ, update the `command` arrays in `src/components/ecs-aurora-init/main.tf` and `src/components/ecs-clickhouse-init/main.tf`.

Also need a runbook step (Phase 6) that calls `aws ecs run-task --task-definition <family>` against each init task def post-apply.

### `runner-repository`

Lighter-weight — only consumes `install_id`, `org_id`, `region`, and ECR passthrough. Audit `ctl_api_role_arn` usage (if any) and apply the same task-role swap.

### Re-add checklist

1. Fork modules into `nuon-byoc-aws-ecs/src/components/{management,runner-repository}/`
2. Drop EKS variables, add task-role variables
3. Rewrite trust policies
4. Create `nuon-byoc-aws-ecs/components/{0-tf-management,0-tf-runner-repository}.toml` pointing at the forked modules
5. Create `nuon-byoc-aws-ecs/components/values/{management,runner-repository}.tfvars` consuming sandbox outputs (no `cluster.oidc_provider`)
