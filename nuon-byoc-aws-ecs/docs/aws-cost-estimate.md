# Current `byoc-nuon` EKS Architecture

**Compute — EKS w/ Karpenter (on-demand, autoscaling node pools):**
- Temporal: `c5.xlarge`
- ClickHouse keeper + installation: `t3a.medium`–`c5.large`
- CTL-API public + workers: `c5.large` / `c5.xlarge`
- Workload pools (apps/installs/runners): `c5.xlarge` / `c5.2xlarge`
- Karpenter scales from zero; pools have generous CPU/memory ceilings (workers up to ~5×c5.2xlarge)

**Databases (RDS Postgres, single-AZ by default, encrypted, Perf Insights on):**
- ctl-api: `db.r6gd.large` (2 vCPU/16 GB), 100 GB gp3
- Temporal: `db.m5.2xlarge` (8 vCPU/32 GB), 500 GB gp3

**Data stores:**
- ClickHouse on EKS — 2 replicas × 1 shard, 20 Gi gp3 EBS each, S3 backup disk
- S3: blob bucket, ClickHouse backups (KMS), install templates (versioned)
- Secrets Manager (Temporal DB creds + ClickHouse password)

**Networking:**
- VPC w/ 3 public + 3 private subnets (3 AZs), 3 NAT gateways
- ALBs: public (CTL-API: api/auth/runner/slack), admin (internal), optional dashboard
- Route53 public + private zones; ACM wildcard certs

**Workloads (Helm):**
- CTL-API: 3–10 API replicas + worker deployments per namespace (installs/runners at 4 replicas × 4 GiB, others 2× 512 MiB), HPA @ 75% CPU/mem
- Temporal server + UI + admin tools
- Dashboard UI: 2–5 replicas
- ClickHouse operator + cluster

**IAM/Misc:** IRSA roles for ctl-api / dashboard / clickhouse; optional breakglass cross-account role; optional Datadog.

---

# EKS Monthly Cost Estimate (us-east-1, on-demand, steady idle-to-light load)

| Category | Detail | Est. $/mo |
|---|---|---|
| EKS control plane | $0.10/hr | **$73** |
| RDS ctl-api | db.r6gd.large + 100 GB gp3 | **$220** |
| RDS Temporal | db.m5.2xlarge + 500 GB gp3 | **$570** |
| EKS nodes (baseline steady state) | ~1× c5.xlarge (temporal), 2× c5.large (CH), 2× c5.large (ctl-api public), 1–2× c5.xlarge (workers), misc | **$600–$900** |
| NAT gateways | 3 × ~$33 + data | **$110–$160** |
| ALBs | 2–3 ALBs + LCUs | **$50–$80** |
| EBS (CH + node root vols) | ~100–200 GB gp3 | **$15–$30** |
| S3 / KMS / Secrets / Route53 / ACM / CloudWatch | low volume | **$30–$60** |
| Inter-AZ + egress data transfer | CH replication, DB, app egress | **$50–$150** |

**Baseline total: ~$1,700–$2,250/month**, climbing quickly under real load (worker pool can scale to 5× c5.2xlarge ≈ $1,200/mo on its own).

The biggest fixed line items are **Temporal RDS (~$570)**, **EKS nodes (~$600+)**, **ctl-api RDS (~$220)**, and **3 NAT gateways (~$130)** — together already ~$1.5k before workload scaling.

---

See [architecture.md](./architecture.md) for the `aws-ecs` Fargate target architecture and its cost estimate.
