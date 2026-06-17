{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}
{{ $dash := dict }}{{ $dashActionID := "" }}{{ with index .nuon.actions.workflows "dashboard_status" }}{{ with .outputs }}{{ $dash = . }}{{ end }}{{ $dashActionID = dig "id" "" . }}{{ end }}
{{ $dashSteps := dig "steps" (dict) $dash }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $indicator := dig "ingress-healthcheck-dashboard-ui" "indicator" "" $dashSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="version:{{ dig "dashboard_ui_version" "unknown" $dash }}"></nuon-label-badge><nuon-label-badge
label="git:{{ dig "dashboard_ui_git_ref" "unknown" $dash }}"></nuon-label-badge><a href="https://app.{{ $public_domain }}">Open
↗</a>{{ with dig "updated_at" "" $dash }}<span style="margin-left:auto;font-size:0.85em;">Last updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $dashActionID }}">dashboard_status</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

**Links**

| Service   | URL                                                          |
| --------- | ------------------------------------------------------------ |
| Dashboard | [app.{{ $public_domain }}](https://app.{{ $public_domain }}) |
