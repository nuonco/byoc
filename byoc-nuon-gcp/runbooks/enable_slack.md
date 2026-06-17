Pulls the install's Slack Client Secret and Signing Secret from the central GCP Secret Manager secret referenced by the
`slack_secrets_name` input, writes them into the `ctl-api` namespace, and restarts `api-slack` so it picks them up.

Use this after the central secret is provisioned (in the central project, with an IAM binding that grants this install's
maintenance service account `secretmanager.versions.access` on the secret) and after `slack_enabled`, `slack_client_id`,
and `slack_secrets_name` are set on the install. Also re-run after rotating the Slack Client Secret or Signing Secret.

`ctl-api-slack-state-jwt-secret` is intentionally untouched — Nuon auto-generates and kubernetes-syncs it.

**Actions**

| Action               | Populates                                                                            |
| -------------------- | ------------------------------------------------------------------------------------ |
| `sync_slack_secrets` | `ctl-api-slack-client-secret`, `ctl-api-slack-signing-secret`, and rolls `api-slack` |
