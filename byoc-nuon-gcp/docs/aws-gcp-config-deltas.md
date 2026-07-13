# AWS ↔ GCP BYOC app config deltas

Comparison of the two Nuon BYOC app configs — `byoc-nuon` (AWS) and `byoc-nuon-gcp` (GCP) — which deploy the same
application and architecture (Kubernetes + Postgres + Temporal + ClickHouse + ctl-api/dashboard) on different clouds.
The deltas are mostly (a) cloud-primitive substitutions and (b) operational tooling that exists on one side but not the
other.

> Status as of the deprovision-safety work (the `deprovision` runbook + pre-teardown hooks + gated `-cloudsql-operations`
> / `-gcs-operations` roles on GCP). Items closed by that work are marked ✅.

## 1. Architecture substitutions (expected, at parity)

| Concern | AWS | GCP |
| --- | --- | --- |
| Relational DB | `rds_cluster_nuon`, `rds_cluster_temporal`, `rds_subnet` | `cloudsql_nuon`, `cloudsql_temporal`, `cloudsql_network` |
| Object storage | `s3_buckets` | `gcs_buckets` |
| TLS cert | `certificate` (ACM) | `wildcard-cert` (GCP cert-manager) |
| Pod→cloud identity | IAM IRSA (`ctl_api_role`, `dashboard_ui_role`) | Workload Identity (`ctl_api_wi`, `dashboard_ui_wi`) |
| DNS | external-dns bundled (Route53) | explicit `external_dns` component |
| LB ingress | ALB + IRSA | proxy-only subnet + GCLB |

Policy coverage tracks these well: `rds-data-protection` / `s3-data-protection` / `eks-endpoint-access` ↔
`cloudsql-data-protection` / `gcs-data-protection` / `gke-endpoint-access`, plus GCP-only `gke-node-pool-service-account`.

## 2. AWS-only capabilities GCP lacked

- **✅ Deprovision / gated destruction (was the biggest gap) — NOW CLOSED.** GCP now has:
  - pre-teardown hooks (`cloudsql_teardown_ctl_api`, `cloudsql_teardown_temporal`, `gcs_teardown`)
  - the `deprovision` break-glass runbook (detach → sandbox-deprovision → optional-delete pilot structure)
  - disabled-by-default destruction roles (`-cloudsql-operations` with final-backup perm, new `-gcs-operations`)
  - CloudSQL recoverability via **final backup** (the AWS-final-snapshot equivalent)
  - pilot improvements not yet on AWS: role-free state_rm, optional/deferred deletes, `sandbox_deprovision` step,
    install.id-derived resource names.
- **Still open — ctl-api endpoint diagnostic suite.** GCP has only `api_status`; no equivalent of
  `ctl_api_api_health_probe` + the 8 ALB/IRSA/ACM/per-endpoint probe actions.
- **✅ Nuon Access login flow — NOW CLOSED.** GCP has the `_nuon_access/enable` action, `nuon_access_enable` runbook,
  and `nuon_access_enabled` / `nuon_access_secret_arn` inputs. Unlike AWS (direct maintenance-role read), the action
  federates into AWS via web identity using the shared `secrets_role_arn` input — the same flow as
  `sync_slack_secrets`. A `runner_sa_unique_id` action emits the value byoc-secrets Terraform needs in `gcp_installs`.
- **Still open — node autoscaling tooling.** AWS has `karpenter-nodepools` + 4 karpenter actions + nodepool kubectl
  actions; GCP relies on native GKE autoscaling (defensible) but has no node-rotation/inspection actions.
- **Still open — other AWS-only:** RDS Performance-Insights runbooks (`rds_inspect_ctl_api/temporal`), `acm_operations`
  role, `helm_release_probe`, `cve_2026_46300_check`, `aws_subnet_ips`, RDS snapshot mgmt actions, `read-only`
  cluster-access inputs.

## 3. GCP-only capabilities AWS lacks

- **ClickHouse verification suite**: `verify_clickhouse` runbook + `ch_verify_storage` / `ch_verify_pod_spread` /
  `ch_verify_backups`. Worth back-porting to AWS.
- **`dns_setup`** runbook (NS delegation records).
- **`loops_setup`** + `sync_loops_secret`.
- **CloudSQL inspect** runbooks/actions, `ctl_api_grant_wi`, `workers-scale-down`.

## 4. Cross-cloud coupling

GCP still depends on AWS:

- Images `img_nuon_ctl_api` / `img_nuon_dashboard_ui` pull from **AWS ECR**.
- GCP inputs `install_stack_template_bucket*` + `secrets_role_arn` reference an **AWS S3 bucket + IAM role** (plus an
  `aws/s3_bucket` action/runbook on the GCP side).

## Bottom line

Provision paths were already at parity. Of the four day-2/teardown gaps originally identified:

1. **Deprovision safety system** — ✅ done (and now ahead of AWS via the pilot changes).
2. **Endpoint diagnostics** (`ctl_api_api_health_probe`) — still a GCP gap.
3. **Nuon Access** — still a GCP gap.
4. **ClickHouse verification** — still an *AWS* gap (GCP has it).

Natural next targets: #2 (port the probe suite to GKE/WI/cert), or — once the deprovision pilot is proven — back-porting
the pilot changes to AWS (role-free state_rm, deferred deletes, `sandbox_deprovision` phase).
