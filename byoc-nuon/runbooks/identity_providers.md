# Identity Providers

Every provider this control plane will accept a sign-in from. Each one is a button on
`https://auth.<root-domain>`.

Providers come from two places:

| Source     | Where it lives                          | Managed by                                    |
| ---------- | --------------------------------------- | --------------------------------------------- |
| `env`      | the install's `NUON_AUTH_*` inputs      | install inputs — cannot be changed from here  |
| `database` | the `identity_providers` table          | the actions below                             |

Several providers may share a type, so a deployment can offer (for example) two OIDC
providers pointing at different issuers.

{{ $action := default dict (index (default dict .nuon.actions.workflows) "ctl_api_get_identity_providers") }}
{{ $outputs := default dict (dig "outputs" dict $action) }} {{ $actionID := dig "id" "" $action }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ if dig "count" 0 $outputs }}<nuon-status status="active" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ with dig "updated_at" "" $outputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $actionID }}">ctl_api_get_identity_providers</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "count" 0 $outputs }}

| Name | Type | Source | Enabled | ID |
| ---- | ---- | ------ | ------- | -- |
{{ range dig "providers" (list) $outputs }}| {{ or .name "—" }} | {{ .provider_type }} | {{ or .source "database" }} | {{ .enabled }} | `{{ .id }}` |
{{ end }}

{{ else }}

<nuon-banner theme="warn">Run the step above to list the configured identity providers.</nuon-banner>

{{ end }}

## Adding a provider

Run the **`ctl_api_add_identity_provider`** action. Set `CLIENT_ID`, `CLIENT_SECRET` and — for
`oidc` — `ISSUER_URL`. `REDIRECT_URL` already defaults to this install's own callback.

Give it a `PROVIDER_NAME`: it is the button label, and it is the only thing distinguishing two
providers of the same type. Without one the button falls back to a generic name derived from the
type.

The action is idempotent, matching on `client_id`, so re-running it updates rather than duplicating.
For `oidc` the API runs discovery against `ISSUER_URL` and rejects the request if it cannot reach
it — a `400` here usually means egress from the cluster to the issuer is blocked, not that the
credentials are wrong.

Whoever owns the IdP must allow `https://auth.<root-domain>/auth` as a redirect URI. Every provider
shares that one callback.

## Enabling, disabling and renaming

Run the **`ctl_api_update_identity_provider`** action, identifying the provider by
`IDENTITY_PROVIDER_ID` or `CLIENT_ID`, and set only what you want to change.

Disabling removes the button from the sign-in page. Existing sessions keep working until they
expire, and linked accounts are left intact, so re-enabling restores access without anyone having
to re-link.

The `env` provider has no database row and cannot be disabled this way — change the install's
`NUON_AUTH_*` inputs instead.

## Who is allowed to sign in

Two independent gates, both of which must pass:

1. **`nuon_auth_allowed_domains`** — an install input, applied to every provider. An email outside
   the list is rejected no matter which provider it came from.
2. **`nuon_auth_allow_all_users`** — when `false`, a user needs an existing account or a pending org
   invite. A provider can override this for itself with `ALLOW_ALL_USERS`, which is how one provider
   stays invite-only while another allows self-signup.
