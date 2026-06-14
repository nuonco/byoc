# nuon-lite — setup guide

Everything an operator needs to wire up before running an install of nuon-lite. Each section covers one external dependency: what it is, why nuon-lite needs it, how to provision it, and where to put the resulting values.

For why the app is shaped this way, see [design.md](./design.md).

## Dependency overview

| Dependency | Provisioned by | What nuon-lite consumes |
|---|---|---|
| ClickHouse Cloud service | Operator (pre-created) | Host, port, db, user, TLS flag, password secret |
| Temporal Cloud account | Operator (account API key only) | Account API key secret; the `temporal_namespaces` component provisions the rest |
| OIDC identity provider | Operator | Provider type, issuer URL, client ID, allowed-domains; companion `nuon_auth_client_secret` secret |
| Loops *(optional)* | Operator | API key secret; ctl-api skips email if absent |
| GitHub App *(optional)* | Operator | App ID/client ID/name inputs + `github_app_key` PEM secret |
| Slack App *(optional)* | Operator | Client ID + redirect URL inputs + three Slack secrets |

The AWS account, Nuon org/install, and the public DNS zone are handled by Nuon + the install_stack — no operator setup needed beyond creating the install.

---

## 1. ClickHouse Cloud

ctl-api stores analytics + event data in ClickHouse. nuon-lite expects a **pre-created** ClickHouse Cloud service — the operator creates it in the Cloud UI, and the app config just connects.

### Create the service

1. Sign in at <https://console.clickhouse.cloud>.
2. From the onboarding wizard (or **Services → New service**):
   - **Region** — match your AWS install region to minimize latency + NAT egress.
   - **Service name** — `nuon-lite-<install-id>` is a reasonable convention.
   - **Tier** — pick **Basic** for cost-target installs (~$67/mo small dev service, single-AZ, 1 TB cap, no idle-to-zero). Pick **Scale** if you need multi-AZ + idle-to-zero (~$500/mo floor — blows the $500 hosting ceiling on its own).
3. Click **Create service**.
4. When the service-creation modal shows the **generated password**, copy it immediately. ClickHouse Cloud does not show plaintext passwords again after this point.

### Collect connection details

Open the service in the console. In the left nav, click **Connect** — a modal opens with the full connection string.

| nuon-lite input | Where it comes from |
|---|---|
| `clickhouse_host` | The `Hostname` field, e.g. `abc123xyz.us-east-1.aws.clickhouse.cloud`. |
| `clickhouse_port` | `9440` (native TCP + TLS — recommended for ctl-api's clickhouse-go driver). Use `8443` only if your client speaks HTTPS. |
| `clickhouse_database` | `default` unless you created another database. |
| `clickhouse_username` | `default` (the service's initial user). Optional: create a dedicated `ctl_api` user (below). |
| `clickhouse_tls` | `true`. Cloud requires TLS on both 9440 and 8443. |

### Populate the password secret

The `clickhouse_cloud_password` Nuon secret has `auto_generate = false` — Nuon will not invent one, because the password has to match what Cloud already issued.

In the Nuon dashboard for this install:
1. Open **Secrets → clickhouse_cloud_password**.
2. Paste the password you saved.
3. Save. Nuon writes it into AWS Secrets Manager in the install account; ctl-api reads it via `valueFrom` at task start.

If you lost the password, reset it in the ClickHouse Cloud console (**Service → Settings → Reset password**, or **Users → default → Reset password**), then update the Nuon secret.

### (Optional) Dedicated ctl_api user

Using `default` is fine for the MVP. For least-privilege:

1. In the Cloud console, open the service → **SQL console**.
2. Run:
   ```sql
   CREATE USER ctl_api IDENTIFIED WITH sha256_password BY '<strong-password>';
   GRANT ALL ON default.* TO ctl_api;
   ```
3. Set `clickhouse_username = ctl_api`.
4. Update the `clickhouse_cloud_password` Nuon secret to the new user's password.

ctl-api auto-creates its tables on first boot via `ch.NewCHMigrator`, so no upfront DDL beyond user creation.

### (Optional) Lock down network access

ClickHouse Cloud accepts connections from any IP by default. To restrict:

- **IP allowlist** — after the install_stack provisions the VPC, note the NAT gateways' Elastic IPs and add them under **Service → Settings → IP Access List**.
- **AWS PrivateLink** — supported on Cloud's Scale and Enterprise tiers; removes the public-internet hop. Configuring PrivateLink for nuon-lite is a follow-up; see [design.md](./design.md).

---

## 2. Temporal Cloud

ctl-api uses Temporal for workflow orchestration. nuon-lite **self-provisions namespaces and workload API keys** via the `temporal_namespaces` component, using the `temporalio/temporalcloud` Terraform provider. The only thing the operator provides is an **account-level API key**.

### Sign up + verify your account

1. Sign in at <https://cloud.temporal.io>.
2. If you don't already have an account, complete signup + email verification. Choose a billing plan — the **Essentials** plan ($100/mo minimum, 1M actions included) is appropriate for low-volume nuon-lite installs.
3. Note your **account ID** — visible in the Cloud UI top-right; you'll see it appear in namespace IDs (`<namespace>.<account_id>`).

### Pick the region

- **Input to set:** `tc_region` — e.g. `aws-us-east-1`, `aws-us-west-2`, `gcp-us-central1`.
- Use the same region as your AWS install to minimize round-trip latency from ctl-api workers to Temporal.

### Create an account-level API key

This is a privileged key that can create namespaces + workload API keys on your behalf. It is consumed **only** by the `temporal_namespaces` component, never by ctl-api.

1. In the Cloud console, go to **Settings → API Keys** (or **Service Accounts → API Keys**, depending on the UI version).
2. Click **Create API Key**.
3. Scope it to allow **namespace admin** + **API key admin** actions on the account.
4. Set an expiry that matches your rotation policy (e.g. 1 year). Set a calendar reminder.
5. Copy the key value. Temporal Cloud only shows it once.

### Populate the account-API-key secret

In the Nuon dashboard for this install:

1. Open **Secrets → temporal_cloud_account_api_key**.
2. Paste the API key.
3. Save. Nuon writes it into AWS Secrets Manager; the `temporal_namespaces` component reads it once at apply via `data "aws_secretsmanager_secret_version"` and passes it to the `temporalcloud` Terraform provider. The key never reaches ctl-api task definitions.

### Other Temporal Cloud inputs

| Input | Default | Notes |
|---|---|---|
| `tc_region` | `aws-us-east-1` | Where namespaces live. |
| `tc_retention_days` | `7` | Per-namespace workflow retention. `vcs` and `emitters` get 30 days regardless, matching byoc-nuon's policy. |
| `tc_namespace_prefix` | `{{ .nuon.install.name }}` | Final namespace names are `<prefix>-<domain>`, e.g. `<install-name>-orgs`. |

### What gets created on apply

The `temporal_namespaces` component creates one namespace per ctl-api workflow domain: `orgs`, `actions`, `apps`, `components`, `installs`, `releases`, `general`, `runners`, `vcs`, `emitters`. Each gets:

- A `temporalcloud_namespace` (API-key auth method).
- A `temporalcloud_apikey` scoped to that namespace.
- An AWS Secrets Manager secret (`n-<install_id>-temporal-<domain>-apikey`) holding the workload key, tagged with `nuon.co/temporal-{domain,namespace-id,endpoint}` so `ctl_api` can tag-discover them.

ctl-api gets one Fargate worker service per namespace.

---

## 3. OIDC identity provider

ctl-api authenticates dashboard users via OIDC. **Google OAuth is the only supported provider today**; generic OIDC config is present but unverified. ctl-api will not start without an issuer + client ID.

### Pick a provider

- **Google OAuth** — easiest path. Set `nuon_auth_provider_type = google` and leave `nuon_auth_issuer_url` empty.
- **Generic OIDC** — set `nuon_auth_provider_type = oidc` and provide the issuer URL. Use only if you've verified compatibility with ctl-api.

### Create an OAuth client (Google example)

1. Open Google Cloud Console → **APIs & Services → Credentials**.
2. **Create credentials → OAuth client ID** → **Web application**.
3. **Authorized redirect URIs:** `https://auth.<install_id>.<domain>/auth/callback`.
4. Save the **Client ID** and **Client secret**.

### Populate the install

| Input | Value |
|---|---|
| `nuon_auth_provider_type` | `google` (or `oidc`) |
| `nuon_auth_issuer_url` | Empty for Google; e.g. `https://login.example.com/` for OIDC |
| `nuon_auth_client_id` | The OAuth client ID |
| `nuon_auth_allow_all_users` | `true` to let anyone in `nuon_auth_allowed_domains` register |
| `nuon_auth_allowed_domains` | Comma-delimited, e.g. `acme.co,partner.com` |

| Secret | Source |
|---|---|
| `nuon_auth_client_secret` | The OAuth client secret you saved |
| `nuon_auth_session_key` | Auto-generated by Nuon — no action required |

---

## 4. (Optional) Loops — transactional email

ctl-api uses [Loops](https://loops.so) to send invite / password-reset emails. If you skip this, ctl-api logs a warning and continues without sending mail.

1. Sign in at <https://app.loops.so> → **Settings → API**.
2. Create an API key with `transactionalEmail` scope.
3. Paste it into the Nuon secret `loops_api_key`.

The `loops_api_key_secret_arn` is wired into ctl-api conditionally — if the secret is empty, the `LOOPS_API_KEY` env var is omitted and ctl-api's email module short-circuits.

---

## 5. (Optional) GitHub App

ctl-api integrates with GitHub via a GitHub App for VCS workflows. Skip this section entirely if you're not using the GitHub integration; the inputs default to empty and ctl-api's VCS module short-circuits.

1. Create a GitHub App in your org → **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Set the webhook URL to `https://runner.<install_id>.<domain>/github/webhook` (matches the listener rules in `ctl-api`).
3. Note the **App ID**, **Client ID**, and **app slug** (the last segment of the app's URL).
4. Generate a private key and download the `.pem`.

Populate:

| Input | From GitHub App settings |
|---|---|
| `github_app_id` | The numeric App ID |
| `github_app_client_id` | The OAuth client ID |
| `github_app_name` | The app slug (used in install URLs) |

| Secret | Source |
|---|---|
| `github_app_key` | Paste the contents of the `.pem` file |

---

## 6. (Optional) Slack App

ctl-api integrates with Slack for notifications. Leave `slack_client_id` empty to skip.

1. Create a Slack app at <https://api.slack.com/apps>.
2. **OAuth & Permissions** → Redirect URLs: add `https://slack.<install_id>.<domain>/slack/oauth/callback`.
3. From **Basic Information**, note the **Client ID** and **Signing Secret**.

Populate:

| Input | From Slack app |
|---|---|
| `slack_client_id` | Basic Information → App Credentials → Client ID |
| `slack_oauth_redirect_url` | Defaults to the URL above; override only if you customized routing |

| Secret | Source |
|---|---|
| `slack_client_secret` | Basic Information → App Credentials → Client Secret |
| `slack_signing_secret` | Basic Information → App Credentials → Signing Secret |
| `slack_state_jwt_secret` | Auto-generated by Nuon if you mark it auto-gen; otherwise generate a random 32-byte string |

---

## Final checklist

Before triggering an install:

- [ ] ClickHouse Cloud service exists; `clickhouse_*` inputs filled; `clickhouse_cloud_password` secret populated
- [ ] Temporal Cloud account exists; `tc_*` inputs filled; `temporal_cloud_account_api_key` secret populated
- [ ] OIDC client created; `nuon_auth_*` inputs filled; `nuon_auth_client_secret` secret populated
- [ ] `nuon` meta inputs set (`env`, `admin_dashboard_enabled`)
- [ ] Optional Loops/GitHub/Slack inputs + secrets populated only if those integrations are enabled

After the install: follow [`runbooks/deploy_control_plane.md`](../runbooks/deploy_control_plane.md) to bring the control plane up.

## References

- [ClickHouse Cloud quick start](https://clickhouse.com/docs/cloud/get-started/cloud-quick-start)
- [ClickHouse Cloud pricing](https://clickhouse.com/pricing)
- [ClickHouse port reference](https://oneuptime.com/blog/post/2026-03-31-clickhouse-listen-ports-network/view)
- [Temporal Cloud get started](https://docs.temporal.io/cloud/get-started)
- [Temporal Cloud API keys](https://docs.temporal.io/cloud/api-keys)
- [Temporal Cloud pricing](https://temporal.io/pricing)
