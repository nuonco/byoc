{{ $installsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_installs") }}
{{ $appsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $orgsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $installsOutputs := default dict (dig "outputs" dict $installsAction) }}
{{ $installsActionID := dig "id" "" $installsAction }}
{{ $installsSteps := dig "steps" dict $installsOutputs }}
{{ $appsSteps := dig "steps" dict (default dict (dig "outputs" dict $appsAction)) }}
{{ $orgsSteps := dig "steps" dict (default dict (dig "outputs" dict $orgsAction)) }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $installsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $installsActionID }}">inspect_installs</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $installsAction (dig "populated" false $installsAction) (eq (dig "status" "" $installsAction) "finished") }}

{{ $installs := dig "installs" (dict) $installsSteps }} {{ $appsByID := dict }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $appsByID = set $appsByID (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $installOrgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $installOrgsByID = set $installOrgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ if gt (len $installs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Status</th>
              <th>App</th>
              <th>Org</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $install := $installs}}
          {{ $appID := dig "app_id" "" $install }}
          {{ $appName := dig $appID "" $appsByID }}
          {{ $orgID := dig "org_id" "" $install }}
          {{ $orgName := dig $orgID "" $installOrgsByID }}
          {{ $installID := dig "id" "—" $install }}
          {{ $installName := dig "name" "—" $install }}
          {{ $installStatus := dig "status" "" $install }}
          {{ $runnerStatus := dig "runner_status" "" $install }}
          {{ $sandboxStatus := dig "sandbox_status" "" $install }}
          {{ $componentStatus := dig "component_status" "" $install }}
          {{ $themeMap := dict "active" "success" "healthy" "success" "finished" "success" "ready" "success" "failed" "error" "error" "error" "unhealthy" "error" "pending" "warn" "queued" "warn" "in_progress" "info" "deprovisioned" "neutral" "unknown" "neutral" }}
          <tr>
              <td>{{ $installName }}<br><small style="opacity:0.6;"><code>{{ $installID }}</code></small></td>
              <td style="white-space:nowrap;"><div style="display:flex;flex-direction:column;gap:0.25rem;align-items:flex-start;">{{ if $runnerStatus }}<nuon-label-badge theme="{{ dig (lower $runnerStatus) "neutral" $themeMap }}" label="runner:{{ $runnerStatus }}"></nuon-label-badge>{{ end }}{{ if $sandboxStatus }}<nuon-label-badge theme="{{ dig (lower $sandboxStatus) "neutral" $themeMap }}" label="sandbox:{{ $sandboxStatus }}"></nuon-label-badge>{{ end }}{{ if $componentStatus }}<nuon-label-badge theme="{{ dig (lower $componentStatus) "neutral" $themeMap }}" label="components:{{ $componentStatus }}"></nuon-label-badge>{{ end }}</div></td>
              <td style="white-space:nowrap;">{{ if $appName }}{{ $appName }}{{ else }}<code>{{ default "—" $appID }}</code>{{ end }}</td>
              <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else }}<code>{{ default "—" $orgID }}</code>{{ end }}</td>
              <td>{{ with dig "created_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Install: {{ $installName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $installName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $installID }}</code></td></tr>
    <tr><td>Runner Status</td><td>{{ if $runnerStatus }}<nuon-status status="{{ $runnerStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Sandbox Status</td><td>{{ if $sandboxStatus }}<nuon-status status="{{ $sandboxStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Components Status</td><td>{{ if $componentStatus }}<nuon-status status="{{ $componentStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>App</td><td>{{ if $appName }}{{ $appName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>App ID</td><td><code>{{ default "—" $appID }}</code></td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td><code>{{ default "—" $orgID }}</code></td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

              </td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No installs reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_installs action. Run it to populate this runbook.</nuon-banner>

{{ end }}
