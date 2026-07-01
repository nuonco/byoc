{{ $slackSynced := false }}{{ with index (default dict .nuon.actions.workflows) "sync_slack_secrets" }}{{ if eq .status "finished" }}{{ $slackSynced = true }}{{ end }}{{ end }}

# Slack setup — {{ if $slackSynced }}✅ Completed{{ else }}⏳ Pending{{ end }}

<nuon-banner theme="warn">Run this only after the install has finished provisioning. It assumes the ctl-api is
healthy.</nuon-banner>

Manual steps required to enable the Slack integration on this install **after it has been provisioned**.

<nuon-group gap="2" align="center" justify="start">{{ if $slackSynced }}<nuon-status status="active" variant="badge"></nuon-status><nuon-label-badge label="status:synced"></nuon-label-badge>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status><nuon-label-badge label="status:not yet run"></nuon-label-badge>{{ end }}{{ with index (default dict .nuon.actions.workflows) "sync_slack_secrets" }}{{ with dig "updated_at" "" . }}<span style="margin-left:auto;font-size:0.85em;">Last
synced <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}{{ end }}</nuon-group>

Process for enabling the Nuon Slack integration for an install. This deploys the `slack` service, exposes it at
`slack.{{ .nuon.inputs.inputs.root_domain }}`, and ensures `api-slack` is wired to a Slack app's OAuth + signing
credentials.

The flow spans three places:

- **[api.slack.com](https://api.slack.com/apps)** — the Slack app itself (Client ID, Client Secret, Signing Secret,
  redirect URL).
- **[nuonco/mono/infra/byoc-secrets](https://github.com/nuonco/mono/tree/main/infra/byoc-secrets)** — the central AWS
  Secrets Manager entry (in the `byoc-infra-prod` account) that holds the Slack credentials. The same central store
  serves every install regardless of cloud. For a GCP install it also provisions a per-install **AWS IAM role** whose
  trust policy is bound to this install's runner GCP service account; that role is granted read access to the
  secret + CMK.
- **this install** — the install inputs and this runbook's `sync_slack_secrets` step that pulls the secret into the
  install's `ctl-api` namespace.

<nuon-banner theme="info">Unlike an AWS install (whose maintenance IAM role is granted on the secret directly), a GCP install has no AWS identity. The runner mints a Google-signed OIDC token for its GCP identity (the runner service account, <code>{{ .nuon.install_stack.outputs.runner_service_account_email }}</code>) and exchanges it for temporary AWS credentials via <code>sts:AssumeRoleWithWebIdentity</code>. The only difference from the AWS flow is the reading principal.</nuon-banner>

<div style="height:0.75rem;"></div>

<nuon-banner theme="info">The secret value never lives in Terraform state. Terraform only creates the empty secret container and the cross-account grants; the value is written out-of-band.</nuon-banner>

### Prerequisites

- The install is provisioned and the control plane is healthy.
- You know this install's `root_domain` and its runner GCP service account (`{{ .nuon.install_stack.outputs.runner_service_account_email }}`).
- You have credentials for the `byoc-infra-prod` AWS account.
- You can open PRs against `nuonco/mono`.

### 1. Create the Slack app

Each install needs its own Slack app. On <https://api.slack.com/apps>: **Create New App** → **From a manifest**, pick
the target workspace, and paste the manifest below. It is already interpolated for **this install** — every URL points
at `slack.{{ .nuon.inputs.inputs.root_domain }}`, which is where this install serves its Slack service and verifies
requests with its own signing secret.

```json
{
  "display_information": {
    "name": "Nuon BYOC {{ .nuon.install.name }}",
    "description": "Nuon BYOC deployment notifications in Slack for {{ .nuon.install.name }}",
    "background_color": "#0b0b0f",
    "long_description": "Nuon BYOC posts deployment lifecycle events from your installs, sandboxes, runners, and actions into the Slack channels you choose. Subscribe per org, filter by interest (failures, components, sandboxes, runners, actions)."
  },
  "features": {
    "bot_user": {
      "display_name": "Nuon BYOC",
      "always_online": true
    },
    "slash_commands": [
      {
        "command": "/nuon-byoc",
        "url": "https://slack.{{ .nuon.inputs.inputs.root_domain }}/slack/commands/nuon",
        "description": "Manage Nuon BYOC notifications in Slack",
        "usage_hint": "subscribe [install] | unsubscribe | status | help",
        "should_escape": false
      }
    ]
  },
  "oauth_config": {
    "redirect_urls": ["https://slack.{{ .nuon.inputs.inputs.root_domain }}/slack/oauth/callback"],
    "scopes": {
      "bot": ["chat:write", "chat:write.public", "channels:read", "groups:read", "team:read", "commands"]
    },
    "pkce_enabled": false
  },
  "settings": {
    "event_subscriptions": {
      "request_url": "https://slack.{{ .nuon.inputs.inputs.root_domain }}/slack/events",
      "bot_events": ["app_uninstalled", "channel_archive", "channel_left", "channel_rename", "tokens_revoked"]
    },
    "interactivity": {
      "is_enabled": true,
      "request_url": "https://slack.{{ .nuon.inputs.inputs.root_domain }}/slack/interactions",
      "message_menu_options_url": "https://slack.{{ .nuon.inputs.inputs.root_domain }}/slack/interactions"
    },
    "org_deploy_enabled": false,
    "socket_mode_enabled": false,
    "token_rotation_enabled": false,
    "is_mcp_enabled": false
  }
}
```

After creating the app, from **Basic Information → App Credentials** collect:

- **Client ID** → goes in the install input `slack_client_id`.
- **Client Secret** → goes in the central secret `client_secret` field.
- **Signing Secret** → goes in the central secret `signing_secret` field.

### 2. Provision the central secret and federated role

{{ $runnerUID := dig "runner_service_account_unique_id" "" .nuon.install_stack.outputs }}In `nuonco/mono`, edit
`infra/byoc-secrets/installs.auto.tfvars` and add this GCP install to `var.gcp_installs`, supplying its **runner**
service account's numeric unique id (its OIDC `sub`) so Terraform can bind the federated AWS role's trust policy to it.
The value below is interpolated from this install's stack outputs:

{{ if not $runnerUID }}<nuon-banner theme="warn">This install's stack outputs don't include
<code>runner_service_account_unique_id</code> yet, so the value below renders empty. Re-apply the install stack so it
reports the runner service account's numeric id, then reload this runbook.</nuon-banner>{{ end }}

```hcl
gcp_installs = {
  "{{ .nuon.install.id }}" = { gcp_service_account_unique_id = "{{ $runnerUID }}" }
  # ...
}
```

Once merged, Terraform Cloud creates the empty Slack secret container at `nuon/byoc-nuon/{{ .nuon.install.id }}/slack`,
creates a per-install `{{ .nuon.install.id }}-secret-reader` IAM role trusting that GCP service account (via the built-in
`accounts.google.com` provider), and grants the role `secretsmanager:GetSecretValue` + `kms:Decrypt` on the secret and
CMK. Note the **secret ARN** and the **role ARN** from the `slack_secret_arns` / `secret_reader_role_arns` outputs.

### 3. Populate the secret value

From a host with `byoc-infra-prod` credentials run:

```bash
AWS_PROFILE=byoc-infra-prod.NuonPowerUser AWS_REGION=us-west-2 \
aws secretsmanager put-secret-value \
  --secret-id "nuon/byoc-nuon/{{ .nuon.install.id }}/slack" \
  --secret-string "$(jq -nc \
    --arg client_secret  "<slack client secret>" \
    --arg signing_secret "<slack signing secret>" \
    '{client_secret:$client_secret, signing_secret:$signing_secret}')"
```

The JSON must contain `client_secret` and `signing_secret` — those are the keys `sync_slack_secrets` reads.

### 4. Set the install inputs

Set the install's Slack inputs in the install config file. The relevant inputs:

| Input                      | Value                                                       |
| -------------------------- | ----------------------------------------------------------- |
| `slack_enabled`     | `true`                                                            |
| `slack_client_id`   | the Slack app's Client ID from step 1                             |
| `slack_secrets_arn` | the ARN from the `slack_secret_arns` output in step 2             |
| `secrets_role_arn`  | the ARN from the `secret_reader_role_arns` output in step 2       |

Set these in the install config file. `slack_enabled`, `slack_client_id`, and
`slack_secrets_arn` live in the `slack` input group; `secrets_role_arn` lives in the `secrets` input group (it is the
shared central-secrets federation role, not Slack-specific). Fill in the Client ID from step 1 and the ARNs from step 2:

```toml
# input.group: slack
[[inputs]]
slack_enabled     = 'true'
slack_client_id   = '<slack client id>'
slack_secrets_arn = '<arn from slack_secret_arns output>'

# input.group: secrets
[[inputs]]
secrets_role_arn = '<arn from secret_reader_role_arns output>'
```

The OAuth redirect URL is **not** an input — ctl-api derives it as
`https://slack.<root_domain>/slack/oauth/callback`, which matches the URL registered in the Slack app manifest (step 1).

### 5. Run the `Slack: Sync slack secrets` step {{ if $slackSynced }}✅ (completed){{ end }}

{{ if $slackSynced }}<nuon-banner theme="success"> This step has at least one successful run. Re-run it only to pick up
rotated credentials. </nuon-banner>{{ else }}<nuon-banner theme="info"> Not run yet. Run this runbook to complete this
step. </nuon-banner>{{ end }}

After the install sync applies, run this runbook. Its `Slack: Sync slack secrets` step runs the `sync_slack_secrets`
action, which:

- mints a Google-signed OIDC token for the runner service account and assumes
  `secrets_role_arn` via `sts:AssumeRoleWithWebIdentity`, then reads the central secret referenced by
  `slack_secrets_arn`,
- writes `ctl-api-slack-client-secret` and `ctl-api-slack-signing-secret` into the install's `ctl-api` namespace,
- restarts `api-slack` so it picks up the values.

<nuon-banner theme="info"><code>ctl-api-slack-state-jwt-secret</code> is intentionally left alone — it is auto-generated
when the stack is provisioned.</nuon-banner>

### 6. Verify

The `Slack: Verify` step runs the `verify_slack` action, which checks that `api-slack` pods are ready in the `ctl-api`
namespace and that `slack.{{ .nuon.inputs.inputs.root_domain }}` resolves and serves. It runs automatically after the
sync step when you run this runbook; re-run it any time to re-check.

Then confirm the end-to-end flow manually:

- Complete the Slack OAuth install flow from the dashboard / Slack app and confirm the callback succeeds (validates the
  redirect URL and Client ID/Secret).
- Confirm signed Slack requests (events / slash commands / interactivity) are accepted (validates the Signing Secret).

### Rotating Slack credentials

Re-run **step 3** with the new value, then re-run this runbook's `Slack: Sync slack secrets` step. No Terraform change
is required. If the Client ID changes, also update the `slack_client_id` input (step 4).
