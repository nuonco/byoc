<nuon-tabs>
  <nuon-tab name="Apps">

{{ $appsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $appsOutputs := default dict (dig "outputs" dict $appsAction) }} {{ $appsActionID := dig "id" "" $appsAction }}
{{ $appsSteps := dig "steps" dict $appsOutputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $appsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $appsActionID }}">inspect_apps</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $appsAction (dig "populated" false $appsAction) (eq (dig "status" "" $appsAction) "finished") }}

{{ $apps := dig "apps" (dict) $appsSteps }} {{ if gt (len $apps) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Org ID</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>ID</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $app := $apps}}
          {{ $orgID := dig "org_id" "" $app }}
          {{ $appID := dig "id" "—" $app }}
          {{ $appName := dig "name" "—" $app }}
          <tr>
              <td>{{ $appName }}<br><small style="opacity:0.6;"><code>{{ $appID }}</code></small></td>
              <td style="white-space:nowrap;"><code>{{ default "—" $orgID }}</code></td>
              <td>{{ with dig "created_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td><code>{{ $appID }}</code></td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No apps reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_apps action. Run it to populate this runbook.</nuon-banner>

{{ end }}

  </nuon-tab>
  <nuon-tab name="Inspect App">

{{ $appAction := default dict (index (default dict .nuon.actions.workflows) "inspect_app") }}
{{ $appOutputs := default dict (dig "outputs" dict $appAction) }} {{ $appActionID := dig "id" "" $appAction }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $appOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $appActionID }}">inspect_app</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "id" "" $appOutputs }}

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ dig "name" "—" $appOutputs }}</td></tr>
    <tr><td>Display name</td><td>{{ dig "display_name" "—" $appOutputs }}</td></tr>
    <tr><td>Description</td><td>{{ dig "description" "—" $appOutputs }}</td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $appOutputs }}</code></td></tr>
    <tr><td>Org ID</td><td><code>{{ dig "org_id" "—" $appOutputs }}</code></td></tr>
    <tr><td>Created by ID</td><td><code>{{ dig "created_by_id" "—" $appOutputs }}</code></td></tr>
    <tr><td>Cloud platform</td><td>{{ dig "cloud_platform" "—" $appOutputs }}</td></tr>
    <tr><td>Runner type</td><td>{{ dig "runner_type" "—" $appOutputs }}</td></tr>
    <tr><td>Config repo</td><td><code>{{ dig "config_repo" "—" $appOutputs }}</code></td></tr>
    <tr><td>Config directory</td><td><code>{{ dig "config_directory" "—" $appOutputs }}</code></td></tr>
    <tr><td>Status</td><td>{{ dig "status" "—" $appOutputs }}</td></tr>
    <tr><td>Status description</td><td>{{ dig "status_description" "—" $appOutputs }}</td></tr>
    <tr><td>Created At</td><td>{{ dig "created_at" "—" $appOutputs }}</td></tr>
    <tr><td>Updated At</td><td>{{ dig "updated_at" "—" $appOutputs }}</td></tr>
  </tbody>
</table>

<h3>Components</h3>

{{ $components := dig "components" (list) $appOutputs }} {{ if gt (len $components) 0 }}

<table>
  <thead><tr><th>Name</th><th>Type</th><th>Status</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $components }}
    <tr>
      <td>{{ dig "name" "—" . }}</td>
      <td>{{ dig "type" "—" . }}</td>
      <td>{{ dig "status" "—" . }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ end }}

{{ else }}

<nuon-banner theme="info">Run the inspect_app action with an APP_ID to inspect a single app.</nuon-banner>

{{ end }}

  </nuon-tab>
</nuon-tabs>
