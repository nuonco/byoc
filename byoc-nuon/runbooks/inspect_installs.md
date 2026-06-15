<nuon-tabs>
  <nuon-tab name="Installs">

{{ $installsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_installs") }}
{{ $installsOutputs := default dict (dig "outputs" dict $installsAction) }}
{{ $installsActionID := dig "id" "" $installsAction }}
{{ $installsSteps := dig "steps" dict $installsOutputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $installsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $installsActionID }}">inspect_installs</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $installsAction (dig "populated" false $installsAction) (eq (dig "status" "" $installsAction) "finished") }}

{{ $installs := dig "installs" (dict) $installsSteps }}
{{ if gt (len $installs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Status</th>
              <th>App</th>
              <th>Org</th>
              <th>Platform</th>
              <th>Region</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $install := $installs}}
          {{ $appID := dig "app_id" "" $install }}
          {{ $appName := dig "app_name" "" $install }}
          {{ $orgID := dig "org_id" "" $install }}
          {{ $orgName := dig "org_name" "" $install }}
          {{ $installID := dig "id" "—" $install }}
          {{ $installName := dig "name" "—" $install }}
          {{ $runnerStatus := dig "runner_status" "" $install }}
          {{ $sandboxStatus := dig "sandbox_status" "" $install }}
          {{ $componentStatus := dig "component_status" "" $install }}
          {{ $themeMap := dict "active" "success" "healthy" "success" "finished" "success" "ready" "success" "failed" "error" "error" "error" "unhealthy" "error" "pending" "warn" "queued" "warn" "in_progress" "info" "deprovisioned" "neutral" "unknown" "neutral" }}
          <tr>
              <td>{{ $installName }}<br><small style="opacity:0.6;"><code>{{ $installID }}</code></small></td>
              <td style="white-space:nowrap;"><div style="display:flex;flex-direction:column;gap:0.25rem;align-items:flex-start;">{{ if $runnerStatus }}<nuon-label-badge theme="{{ dig (lower $runnerStatus) "neutral" $themeMap }}" label="runner:{{ $runnerStatus }}"></nuon-label-badge>{{ end }}{{ if $sandboxStatus }}<nuon-label-badge theme="{{ dig (lower $sandboxStatus) "neutral" $themeMap }}" label="sandbox:{{ $sandboxStatus }}"></nuon-label-badge>{{ end }}{{ if $componentStatus }}<nuon-label-badge theme="{{ dig (lower $componentStatus) "neutral" $themeMap }}" label="components:{{ $componentStatus }}"></nuon-label-badge>{{ end }}</div></td>
              <td style="white-space:nowrap;">{{ if $appName }}{{ $appName }}{{ else }}<code>{{ default "—" $appID }}</code>{{ end }}</td>
              <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else }}<code>{{ default "—" $orgID }}</code>{{ end }}</td>
              <td>{{ dig "platform" "—" $install }}</td>
              <td>{{ dig "region" "—" $install }}</td>
              <td>{{ with dig "created_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Install: {{ $installName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $installName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $installID }}</code></td></tr>
    <tr><td>Install Number</td><td>{{ dig "install_number" "—" $install }}</td></tr>
    <tr><td>Runner Status</td><td>{{ if $runnerStatus }}<nuon-status status="{{ $runnerStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Runner ID</td><td>{{ with dig "runner_id" "" $install }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Sandbox Status</td><td>{{ if $sandboxStatus }}<nuon-status status="{{ $sandboxStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Components Status</td><td>{{ if $componentStatus }}<nuon-status status="{{ $componentStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>App</td><td>{{ if $appName }}{{ $appName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>App ID</td><td><code>{{ default "—" $appID }}</code></td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td><code>{{ default "—" $orgID }}</code></td></tr>
    <tr><td>Platform</td><td>{{ dig "platform" "—" $install }}</td></tr>
    <tr><td>Runner Type</td><td>{{ dig "runner_type" "—" $install }}</td></tr>
    <tr><td>Region</td><td>{{ dig "region" "—" $install }}</td></tr>
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

  </nuon-tab>
  <nuon-tab name="Inspect Install">

{{ $installAction := default dict (index (default dict .nuon.actions.workflows) "inspect_install") }}
{{ $installOutputs := default dict (dig "outputs" dict $installAction) }}
{{ $installActionID := dig "id" "" $installAction }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "runner_status" "" $installOutputs }}<nuon-label-badge theme="{{ dig (lower .) "neutral" (dict "active" "success" "error" "error" "pending" "warn" "deprovisioned" "neutral") }}" label="runner:{{ . }}"></nuon-label-badge>{{ end }}{{ with dig "sandbox_status" "" $installOutputs }}<nuon-label-badge theme="{{ dig (lower .) "neutral" (dict "active" "success" "healthy" "success" "ready" "success" "error" "error" "pending" "warn") }}" label="sandbox:{{ . }}"></nuon-label-badge>{{ end }}{{ with dig "component_status" "" $installOutputs }}<nuon-label-badge theme="{{ dig (lower .) "neutral" (dict "active" "success" "error" "error" "pending" "warn") }}" label="components:{{ . }}"></nuon-label-badge>{{ end }}{{ with dig "updated_at" "" $installOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $installActionID }}">inspect_install</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "id" "" $installOutputs }}

<div style="display:flex;gap:1rem;align-items:flex-start;">
  <div style="flex:1 1 50%;min-width:0;">
<h3>Install</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ dig "name" "—" $installOutputs }}</td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $installOutputs }}</code></td></tr>
    <tr><td>Install Number</td><td>{{ dig "install_number" "—" $installOutputs }}</td></tr>
    <tr><td>Platform</td><td>{{ dig "platform" "—" $installOutputs }}</td></tr>
    <tr><td>Region</td><td>{{ dig "region" "—" $installOutputs }}</td></tr>
    <tr><td>Sandbox Mode</td><td>{{ dig "sandbox_mode" "—" $installOutputs }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $installOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $installOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

<h3>Runner</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Runner Type</td><td>{{ dig "runner_type" "—" $installOutputs }}</td></tr>
    <tr><td>Runner ID</td><td>{{ with dig "runner_id" "" $installOutputs }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Status description</td><td>{{ dig "runner_status_description" "—" $installOutputs }}</td></tr>
  </tbody>
</table>
  </div>
  <div style="flex:1 1 50%;min-width:0;">
<h3>App</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>App</td><td>{{ dig "app_name" "—" $installOutputs }}</td></tr>
    <tr><td>App ID</td><td><code>{{ dig "app_id" "—" $installOutputs }}</code></td></tr>
    <tr><td>App Config ID</td><td><code>{{ dig "app_config_id" "—" $installOutputs }}</code></td></tr>
    <tr><td>App Runner Config ID</td><td><code>{{ dig "app_runner_config_id" "—" $installOutputs }}</code></td></tr>
    <tr><td>App Sandbox Config ID</td><td><code>{{ dig "app_sandbox_config_id" "—" $installOutputs }}</code></td></tr>
  </tbody>
</table>

<h3>Org</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Org</td><td>{{ dig "org_name" "—" $installOutputs }}</td></tr>
    <tr><td>Org ID</td><td><code>{{ dig "org_id" "—" $installOutputs }}</code></td></tr>
  </tbody>
</table>
  </div>
</div>

<h3>Components</h3>

{{ $components := dig "components" (list) $installOutputs }}
{{ if gt (len $components) 0 }}
<table>
  <thead><tr><th>Name</th><th>Type</th><th>Status</th><th>Component ID</th><th>Install Component ID</th></tr></thead>
  <tbody>
  {{ range $components }}
    <tr>
      <td>{{ dig "component_name" "—" . }}</td>
      <td>{{ dig "component_type" "—" . }}</td>
      <td>{{ with dig "status" "" . }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "component_id" "—" . }}</code></td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No install components.</nuon-banner>{{ end }}

{{ $sandbox := dig "sandbox" dict $installOutputs }}
{{ $stack := dig "stack" dict $installOutputs }}
<div style="display:flex;gap:1rem;align-items:flex-start;">
  <div style="flex:1 1 50%;min-width:0;">
{{ if $sandbox }}
<h3>Sandbox</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $sandbox }}</code></td></tr>
    <tr><td>Status</td><td>{{ with dig "status" "" $sandbox }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Status description</td><td>{{ dig "status_description" "—" $sandbox }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $sandbox }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $sandbox }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>
{{ end }}
  </div>
  <div style="flex:1 1 50%;min-width:0;">
{{ if $stack }}
<h3>Stack</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $stack }}</code></td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $stack }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $stack }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>
{{ end }}
  </div>
</div>

{{ if $stack }}
{{ $outputs := dig "outputs" dict $stack }}
{{ if gt (len $outputs) 0 }}
<h3>Stack outputs</h3>
<table>
  <thead><tr><th>Key</th><th>Value</th></tr></thead>
  <tbody>
  {{ range $k, $v := $outputs }}
    <tr><td><code>{{ $k }}</code></td><td><code>{{ $v }}</code></td></tr>
  {{ end }}
  </tbody>
</table>
{{ end }}
{{ end }}

{{ else }}

<nuon-banner theme="info">Run the <code>inspect_install</code> action with an <code>INSTALL_ID</code> to populate this tab.</nuon-banner>

{{ end }}

  </nuon-tab>
</nuon-tabs>
