{{ $loopsSynced := false }}{{ with index (default dict .nuon.actions.workflows) "sync_loops_secret" }}{{ if eq .status "finished" }}{{ $loopsSynced = true }}{{ end }}{{ end }}

# Loops setup — {{ if $loopsSynced }}✅ Completed{{ else }}⏳ Pending{{ end }}

<nuon-banner theme="warn">Run this only after the install has finished provisioning. It assumes the ctl-api is
healthy.</nuon-banner>

Manual steps required to wire the Loops API key into this install **after it has been provisioned**.

<nuon-group gap="2" align="center" justify="start">{{ if $loopsSynced }}<nuon-status status="active" variant="badge"></nuon-status><nuon-label-badge label="status:synced"></nuon-label-badge>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status><nuon-label-badge label="status:not yet run"></nuon-label-badge>{{ end }}{{ with index (default dict .nuon.actions.workflows) "sync_loops_secret" }}{{ with dig "updated_at" "" . }}<span style="margin-left:auto;font-size:0.85em;">Last
synced <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}{{ end }}</nuon-group>

Process for delivering the Loops API key to `ctl-api`. The key is sourced from a central, vendor-owned secret store,
then pulled into the install's `ctl-api` namespace as the `ctl-api-loops-api-key` secret and mounted as the
`LOOPS_API_KEY` env var.

The flow spans two places:

- **[nuonco/mono/infra/byoc-secrets](https://github.com/nuonco/mono/tree/main/infra/byoc-secrets)** — the central AWS
  Secrets Manager entry (in the `byoc-infra-prod` account) at `nuon/byoc-nuon/{{ .nuon.install.id }}/loops` that holds
  this install's Loops API key. The same central store serves every install regardless of cloud.
- **this install** — the `loops_secret_arn` input and this runbook's `sync_loops_secret` step that pulls the secret
  into the install's `ctl-api` namespace.

<nuon-banner theme="info">The secret value never lives in Terraform state. Terraform only creates the empty secret container and the grants; the value is written out-of-band.</nuon-banner>

### Prerequisites

- The install is provisioned and the control plane is healthy.
- The install's federated secret-reader role (`{{ .nuon.install.id }}-secret-reader`) exists and its ARN is set on the
  `secrets_role_arn` input. This role is provisioned by `byoc-secrets` when the install is enrolled.
- You have credentials for the `byoc-infra-prod` AWS account.
- You can open PRs against `nuonco/mono`.

### 1. Provision the central secret

In `nuonco/mono`, the `infra/byoc-secrets` workspace creates a per-install Loops secret container. Every install already
in `var.installs` / `var.gcp_installs` gets a `nuon/byoc-nuon/<install_id>/loops` container — no per-install Terraform
edit is needed beyond having this install enrolled.

Once applied, note the **secret ARN** for this install from the `loops_secret_arns` output.

### 2. Populate the secret value

The Loops secret value is the **raw API key string** (no JSON wrapper). From a host with `byoc-infra-prod` credentials
run:

```bash
AWS_PROFILE=byoc-infra-prod.NuonPowerUser AWS_REGION=us-west-2 \
aws secretsmanager put-secret-value \
  --secret-id "nuon/byoc-nuon/{{ .nuon.install.id }}/loops" \
  --secret-string "<loops api key>"
```

### 3. Set the install input

Set the install's `loops_secret_arn` input (in the `email` input group) to the ARN from the `loops_secret_arns` output
in step 1. Leave it empty to keep Loops disabled.

```toml
# input.group: email
[[inputs]]
loops_secret_arn = '<arn from loops_secret_arns output>'
```

`sync_loops_secret` uses the `secrets_role_arn` input to federate into AWS.

### 4. Run the `Loops: Sync loops secret` step {{ if $loopsSynced }}✅ (completed){{ end }}

{{ if $loopsSynced }}<nuon-banner theme="success"> This step has at least one successful run. Re-run it only to pick up a
rotated key. </nuon-banner>{{ else }}<nuon-banner theme="info"> Not run yet. Run this runbook to complete this step.
</nuon-banner>{{ end }}

After the install sync applies, run this runbook. Its `Loops: Sync loops secret` step runs the `sync_loops_secret`
action, which:

- mints a Google-signed OIDC token for the runner service account and assumes
  `secrets_role_arn` via `sts:AssumeRoleWithWebIdentity`, then reads the central secret referenced by
  `loops_secret_arn`,
- writes `ctl-api-loops-api-key` into the install's `ctl-api` namespace,
- restarts `ctl-api` so it picks up the value.

If `loops_secret_arn` is empty, the action is a no-op and Loops stays disabled.

### Rotating the Loops API key

Re-run **step 2** with the new value, then re-run this runbook's `Loops: Sync loops secret` step. No Terraform change is
required.
