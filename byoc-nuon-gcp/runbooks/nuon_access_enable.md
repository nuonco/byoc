# Nuon Access Enable

Adds or enables the Nuon Access identity provider on the Auth service.

{{ $action := default dict (index (default dict .nuon.actions.workflows) "nuon_access_enable") }}
{{ $outputs := default dict (dig "outputs" dict $action) }} {{ $actionID := dig "id" "" $action }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ if dig "enabled" false $outputs }}<nuon-status status="active" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ with dig "updated_at" "" $outputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $actionID }}">nuon_access_enable</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "id" "" $outputs }}

| Field   | Value                              |
| ------- | ---------------------------------- |
| created | {{ dig "created" false $outputs }} |
| enabled | {{ dig "enabled" false $outputs }} |
| id      | `{{ dig "id" "—" $outputs }}`      |

{{ else }}

<nuon-banner theme="warn">Waiting on the nuon_access_enable action. Run it to populate this runbook.</nuon-banner>

{{ end }}
