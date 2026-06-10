{{ $appsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $orgsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $appsOutputs := default dict (dig "outputs" dict $appsAction) }}
{{ $appsActionID := dig "id" "" $appsAction }}
{{ $appsSteps := dig "steps" dict $appsOutputs }}
{{ $orgsSteps := dig "steps" dict (default dict (dig "outputs" dict $orgsAction)) }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $appsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $appsActionID }}">inspect_apps</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $appsAction (dig "populated" false $appsAction) (eq (dig "status" "" $appsAction) "finished") }}

{{ $apps := dig "apps" (dict) $appsSteps }} {{ $orgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $orgsByID = set $orgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ if gt (len $apps) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Org</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $app := $apps}}
          {{ $orgID := dig "org_id" "" $app }}
          {{ $orgName := dig $orgID "" $orgsByID }}
          {{ $appID := dig "id" "—" $app }}
          {{ $appName := dig "name" "—" $app }}
          <tr>
              <td>{{ $appName }}<br><small style="opacity:0.6;"><code>{{ $appID }}</code></small></td>
              <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else }}<code>{{ default "—" $orgID }}</code>{{ end }}</td>
              <td>{{ with dig "created_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="App: {{ $appName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $appName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $appID }}</code></td></tr>
    <tr><td>Slug</td><td>{{ with dig "slug" "" $app }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td><code>{{ default "—" $orgID }}</code></td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $app }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

              </td>
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
