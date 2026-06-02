Pulls the install's Slack Client Secret and Signing Secret from the central AWS Secrets Manager entry referenced by the `slack_secrets_arn` input, writes them into the `ctl-api` namespace, and restarts `api-slack` so it picks them up.

Use this after the central secret is provisioned (in `infra-shared-prod`, with a per-install CMK and resource policy that names this install's `*-maintenance` role) and after `slack_enabled`, `slack_client_id`, and `slack_secrets_arn` are set on the install. Also re-run after rotating the Slack Client Secret or Signing Secret.

`ctl-api-slack-state-jwt-secret` is intentionally untouched — Nuon auto-generates and kubernetes-syncs it.

**Actions**

| Action | Populates |
|---|---|
| `sync_slack_secrets` | `ctl-api-slack-client-secret`, `ctl-api-slack-signing-secret`, and rolls `api-slack` |
