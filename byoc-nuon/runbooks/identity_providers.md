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

{{ $action := default dict (index (default dict .nuon.actions.workflows) "sync_auth_providers") }}
{{ $outputs := default dict (dig "outputs" dict $action) }} {{ $actionID := dig "id" "" $action }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ if dig "applied" 0 $outputs }}<nuon-status status="active" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ with dig "updated_at" "" $outputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $actionID }}">sync_auth_providers</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "applied" 0 $outputs }}

| Field   | Value                              |
| ------- | ---------------------------------- |
| applied | {{ dig "applied" 0 $outputs }}     |

{{ else }}

<nuon-banner theme="warn">Run the step above to reconcile the identity providers from the secret.</nuon-banner>

{{ end }}

## Adding a provider

Run the **`sync_auth_providers`** action with `PROVIDER_SECRET_ARN` pointing at a secret
that holds every provider for this install — one secret and one run covers the whole set:

```json
{
  "providers": [
    {
      "provider_type": "oidc",
      "name": "Microsoft",
      "openid_config": {
        "client_id": "...",
        "client_secret": "...",
        "issuer_url": "https://<tenant>/",
        "auth_url": "https://<tenant>/authorize?connection=<name>"
      }
    }
  ]
}
```

A bare single-provider object is also accepted, which is the shape older secrets use. Providers
already on the control plane but absent from the secret are left alone, and the sync lists them as
unmanaged so the drift is visible.

Credentials are read at runtime and never passed as action inputs: action env vars are persisted on
the run and displayed in the dashboard, so a secret supplied that way would be stored and visible to
anyone who can see this install's action history.

`redirect_url` is not read from the secret — it is templated from this install's own DNS, so it
follows a `root_domain` change instead of going stale.

`auth_url` is optional and overrides the endpoint discovery supplies. Some IdPs show their own
account picker unless the authorize URL names a connection; pinning it there sends the user straight
through.

Set `name` in the secret: it is the button label, and the only thing distinguishing two providers of
the same type. Without one the button falls back to a generic name derived from the type.

The action is idempotent, matching on `client_id`, so re-running it updates rather than duplicating.
For `oidc` the API runs discovery against `ISSUER_URL` and rejects the request if it cannot reach
it — a `400` here usually means egress from the cluster to the issuer is blocked, not that the
credentials are wrong.

Whoever owns the IdP must allow `https://auth.<root-domain>/auth` as a redirect URI. Every provider
shares that one callback.

## Inspecting, enabling and disabling

Nuon staff can see every provider and toggle it from **Admin controls → Identity providers** in the
dashboard, without an AWS round trip. Disabling removes the button from the sign-in page; existing
sessions keep working until they expire and linked accounts are untouched, so re-enabling restores
access without anyone re-linking.

That toggle is a break-glass lever, not a config change: the secret is the source of truth, so the
next sync restores whatever it declares. To disable something permanently, set `"enabled": false`
on its entry in the secret and re-run the sync.

The `env` provider has no database row, so it cannot be toggled at all — change the install's
`NUON_AUTH_*` inputs instead.

## Who is allowed to sign in

Two independent gates, both of which must pass:

1. **`nuon_auth_allowed_domains`** — an install input, applied to every provider. An email outside
   the list is rejected no matter which provider it came from.
2. **`nuon_auth_allow_all_users`** — when `false`, a user needs an existing account or a pending org
   invite. A provider can override this for itself with `ALLOW_ALL_USERS`, which is how one provider
   stays invite-only while another allows self-signup.
