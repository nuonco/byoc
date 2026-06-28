Diagnose why a ctl-api HTTP endpoint is unreachable for install `{{ .nuon.install.id }}`.

Use this when an endpoint won't answer — e.g. the `ctl_api_post_deploy` **runners-update-version** step failing with
"admin API never became reachable", or a 5xx / DNS failure on `api`, `runner`, or `auth`. Every step is **read-only**.

> [!NOTE] This runbook covers **HTTP / ingress-backed** ctl-api endpoints only (public, admin, runner, auth). Non-HTTP
> or non-ingress services (Temporal gRPC, ClickHouse, anything on a Service/NLB rather than an ALB ingress) don't fit
> this funnel and need a different approach.

## How it works

The funnel has two layers. **Steps 1–4 are the cluster-wide backbone** — there is one AWS Load Balancer Controller per
cluster, so if it can't build ALBs (or the shared TLS cert isn't issued), *every* endpoint fails at once. They run
first, ordered symptom → root cause. **Steps 5–8 probe each endpoint individually** (reachability → DNS → ingress/ALB).
All steps run even if an earlier one finds the fault, so one pass gives the full picture.

### 1. Are ALBs being built at all? — `ctl_api_alb_ingress_status`

kubectl only. Lists every ctl-api ingress with its ALB address and `FailedBuildModel` event count. `alb=<none>` +
`FailedBuildModel` on *every* ingress = controller-wide; on just one = endpoint-specific.

### 2. Is the LB controller running and is its IRSA actually wired? — `ctl_api_alb_controller`

kubectl only. The AWS Load Balancer Controller pod, its ServiceAccount `role-arn` annotation, the injected `AWS_ROLE_ARN`
/ token path, and credential errors in its logs. No `AWS_ROLE_ARN` env ⇒ the SA annotation is missing; env present but a
`403` in the logs ⇒ the env is fine and STS is rejecting the assume (continue to step 3).

### 3. Can the controller actually assume its role? — `ctl_api_alb_irsa_trust`

Runs under the `{{ .nuon.install.id }}-provision` role (IAM/EKS reads). Compares the **cluster OIDC issuer ↔ registered
IAM OIDC providers ↔ the controller role's trust policy**. Distinguishes: OIDC provider missing, trust-policy
`Federated`/`sub`/`aud` mismatch, or a deleted role (AWS returns the same 403 either way — confirm the role exists).

### 4. Is the shared wildcard TLS cert issued? — `ctl_api_acm_cert`

Runs under the `{{ .nuon.install.id }}-provision` role (ACM read). The https endpoints (public/runner/auth) share one
wildcard ACM cert; until it is `ISSUED` their ALBs can't terminate TLS. (The admin endpoint is plain http and doesn't
depend on it.)

### 5–8. Per-endpoint probes — `ctl_api_probe_{public,admin,runner,auth}`

Each checks one endpoint: a `curl` to its health path (treating 2xx–4xx as reachable — 401/403 just means up-but-unauthed),
DNS resolution in the expected zone, and the ingress's ALB address / annotations / events.

| endpoint | host | zone | scheme |
| --- | --- | --- | --- |
| public | `api.<public_domain>` | public (internet-facing) | https |
| admin | `admin.<internal_domain>` | internal (private zone, VPC-only) | http |
| runner | `runner.<public_domain>` | public (internet-facing) | https |
| auth | `auth.<public_domain>` | public (internet-facing) | https |

## Reading the output

- **All endpoints show "no ALB address" + step 1 shows `FailedBuildModel` everywhere** → cluster-wide. Read step 3's
  trust chain:
  - cluster OIDC issuer has **no matching IAM OIDC provider** → the provider is missing (register it / re-provision IRSA).
  - provider exists but the role's trust policy `Federated`/`:sub`/`:aud` don't match → fix the role trust policy.
  - the same 403 (`Not authorized to perform sts:AssumeRoleWithWebIdentity`) also appears if the controller's IAM **role
    was deleted** — AWS returns an identical error whether the trust mismatches or the role is absent, so confirm the
    role actually exists.
- **https endpoints down but step 4's ACM cert is `PENDING_VALIDATION`** → the cert's DNS validation records are missing;
  the https ALBs won't come up until it's `ISSUED`.
- **One endpoint down, others fine, steps 1–4 healthy** → endpoint-specific: check that ingress's events, its
  `external-dns` hostname annotation, and whether its record landed in the right zone (internal vs public).

> [!IMPORTANT] These checks are read-only. The fixes for cluster-wide failures (IRSA role / OIDC provider / ACM
> validation) live in the install / runner infrastructure, **not** the byoc-nuon app components.
