<nuon-tabs>
  <nuon-tab name="Orgs">

{{ $orgsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $orgsOutputs := default dict (dig "outputs" dict $orgsAction) }}
{{ $orgsActionID := dig "id" "" $orgsAction }}
{{ $orgsSteps := dig "steps" dict $orgsOutputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $orgsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $orgsActionID }}">inspect_orgs</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $orgsAction (dig "populated" false $orgsAction) (eq (dig "status" "" $orgsAction) "finished") }}

{{ $orgs := dig "orgs" (dict) $orgsSteps }}
{{ if gt (len $orgs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Status</th>
              <th>Apps</th>
              <th>Installs</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $org := $orgs}}
          {{ $orgID := dig "id" "—" $org }}
          {{ $orgName := dig "name" "—" $org }}
          {{ $status := dig "status" "" $org }}
          <tr>
              <td>{{ $orgName }}<br><small style="opacity:0.6;"><code>{{ $orgID }}</code></small></td>
              <td>{{ with $status }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
              <td>{{ dig "app_count" 0 $org }}</td>
              <td>{{ dig "install_count" 0 $org }}</td>
              <td>{{ with dig "created_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Org: {{ $orgName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $orgName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $orgID }}</code></td></tr>
    <tr><td>Status</td><td>{{ with $status }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Sandbox Mode</td><td>{{ dig "sandbox_mode" false $org }}</td></tr>
    <tr><td>Apps</td><td>{{ dig "app_count" 0 $org }}</td></tr>
    <tr><td>Installs</td><td>{{ dig "install_count" 0 $org }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

              </td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No orgs reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_orgs action. Run it to populate this runbook.</nuon-banner>

{{ end }}

  </nuon-tab>
  <nuon-tab name="Inspect Org">

{{ $orgAction := default dict (index (default dict .nuon.actions.workflows) "inspect_org") }}
{{ $orgOutputs := default dict (dig "outputs" dict $orgAction) }}
{{ $orgActionID := dig "id" "" $orgAction }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "status" "" $orgOutputs }}<nuon-label-badge theme="{{ dig (lower .) "neutral" (dict "active" "success" "error" "error" "pending" "warn") }}" label="status:{{ . }}"></nuon-label-badge>{{ end }}{{ with dig "updated_at" "" $orgOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $orgActionID }}">inspect_org</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if dig "id" "" $orgOutputs }}

<div style="display:flex;gap:1rem;align-items:flex-start;">
  <div style="flex:1 1 50%;min-width:0;">
<h3>Org</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ dig "name" "—" $orgOutputs }}</td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $orgOutputs }}</code></td></tr>
    <tr><td>Status description</td><td>{{ dig "status_description" "—" $orgOutputs }}</td></tr>
    <tr><td>Sandbox Mode</td><td>{{ dig "sandbox_mode" false $orgOutputs }}</td></tr>
    <tr><td>Logo URL</td><td>{{ with dig "logo_url" "" $orgOutputs }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Tags</td><td>{{ with dig "tags" (list) $orgOutputs }}{{ range . }}<nuon-badge theme="info" size="sm">{{ . }}</nuon-badge> {{ end }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $orgOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $orgOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>
  </div>
  <div style="flex:1 1 50%;min-width:0;">
<h3>Features</h3>
{{ $features := dig "features" (dict) $orgOutputs }}
{{ if gt (len $features) 0 }}
<table>
  <thead><tr><th>Feature</th><th>Enabled</th></tr></thead>
  <tbody>
  {{ range $k, $v := $features }}
    <tr><td><code>{{ $k }}</code></td><td>{{ $v }}</td></tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No features.</nuon-banner>{{ end }}
  </div>
</div>

<h3>Apps</h3>

{{ $apps := dig "apps" (list) $orgOutputs }}
{{ if gt (len $apps) 0 }}
<table>
  <thead><tr><th>Name</th><th>Status</th><th>Created At</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $apps }}
    <tr>
      <td>{{ dig "name" "—" . }}</td>
      <td>{{ with dig "status" "" . }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ with dig "created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No apps.</nuon-banner>{{ end }}

<h3>Installs</h3>

{{ $installs := dig "installs" (list) $orgOutputs }}
{{ if gt (len $installs) 0 }}
<table>
  <thead><tr><th>Name</th><th>App ID</th><th>Created At</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $installs }}
    <tr>
      <td>{{ dig "name" "—" . }}</td>
      <td><code>{{ dig "app_id" "—" . }}</code></td>
      <td>{{ with dig "created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No installs.</nuon-banner>{{ end }}

<h3>VCS connections</h3>

{{ $vcs := dig "vcs_connections" (list) $orgOutputs }}
{{ if gt (len $vcs) 0 }}
<table>
  <thead><tr><th>Account</th><th>Github Install ID</th><th>Created At</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $vcs }}
    <tr>
      <td>{{ dig "github_account_name" "—" . }}</td>
      <td><code>{{ dig "github_install_id" "—" . }}</code></td>
      <td>{{ with dig "created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No VCS connections.</nuon-banner>{{ end }}

<h3>Roles</h3>

{{ $roles := dig "roles" (list) $orgOutputs }}
{{ if gt (len $roles) 0 }}
<table>
  <thead><tr><th>Type</th><th>Policies</th><th>Created At</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $roles }}
    <tr>
      <td>{{ dig "role_type" "—" . }}</td>
      <td>{{ dig "policy_count" 0 . }}</td>
      <td>{{ with dig "created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No roles.</nuon-banner>{{ end }}

{{ else }}

<nuon-banner theme="info">Run the <code>inspect_org</code> action with an <code>ORG_ID</code> to populate this tab.</nuon-banner>

{{ end }}

  </nuon-tab>
</nuon-tabs>
