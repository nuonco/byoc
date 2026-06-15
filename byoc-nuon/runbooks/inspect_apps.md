<nuon-tabs>
  <nuon-tab name="Apps">

{{ $appsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $appsOutputs := default dict (dig "outputs" dict $appsAction) }}
{{ $appsActionID := dig "id" "" $appsAction }}
{{ $appsSteps := dig "steps" dict $appsOutputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $appsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $appsActionID }}">inspect_apps</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $appsAction (dig "populated" false $appsAction) (eq (dig "status" "" $appsAction) "finished") }}

{{ $apps := dig "apps" (dict) $appsSteps }}
{{ if gt (len $apps) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Org ID</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
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
              <td>

<nuon-panel heading="App: {{ $appName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $appName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $appID }}</code></td></tr>
    <tr><td>Org ID</td><td>{{ with $orgID }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
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

  </nuon-tab>
  <nuon-tab name="Inspect App">

{{ $appAction := default dict (index (default dict .nuon.actions.workflows) "inspect_app") }}
{{ $appOutputs := default dict (dig "outputs" dict $appAction) }}
{{ $appActionID := dig "id" "" $appAction }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $appOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $appActionID }}">inspect_app</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

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
    <tr><td>Config repo</td><td><code>{{ dig "config_repo" "—" $appOutputs }}</code></td></tr>
    <tr><td>Config directory</td><td><code>{{ dig "config_directory" "—" $appOutputs }}</code></td></tr>
    <tr><td>Status</td><td>{{ dig "status" "—" $appOutputs }}</td></tr>
    <tr><td>Status description</td><td>{{ dig "status_description" "—" $appOutputs }}</td></tr>
    <tr><td>Created At</td><td>{{ dig "created_at" "—" $appOutputs }}</td></tr>
    <tr><td>Updated At</td><td>{{ dig "updated_at" "—" $appOutputs }}</td></tr>
  </tbody>
</table>

{{ $runnerConfig := dig "runner_config" dict $appOutputs }}
{{ if $runnerConfig }}
<h3>Runner config</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Type</td><td>{{ dig "type" "—" $runnerConfig }}</td></tr>
    <tr><td>Helm driver</td><td>{{ dig "helm_driver" "—" $runnerConfig }}</td></tr>
    <tr><td>Instance type</td><td>{{ dig "instance_type" "—" $runnerConfig }}</td></tr>
    <tr><td>Init script</td><td><code>{{ dig "init_script_url" "—" $runnerConfig }}</code></td></tr>
    <tr><td>Auth method</td><td>{{ dig "RUNNER_AUTH_METHOD" "—" (dig "env_vars" dict $runnerConfig) }}</td></tr>
    <tr><td>App config ID</td><td><code>{{ dig "app_config_id" "—" $runnerConfig }}</code></td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $runnerConfig }}</code></td></tr>
  </tbody>
</table>
{{ end }}

{{ $stackConfig := dig "stack_config" dict $appOutputs }}
{{ if $stackConfig }}
<h3>Stack config</h3>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Type</td><td>{{ dig "type" "—" $stackConfig }}</td></tr>
    <tr><td>Name</td><td>{{ dig "name" "—" $stackConfig }}</td></tr>
    <tr><td>Description</td><td>{{ dig "description" "—" $stackConfig }}</td></tr>
    <tr><td>Runner template URL</td><td><code>{{ dig "runner_nested_template_url" "—" $stackConfig }}</code></td></tr>
    <tr><td>VPC template URL</td><td><code>{{ dig "vpc_nested_template_url" "—" $stackConfig }}</code></td></tr>
    <tr><td>Custom nested stacks</td><td>{{ len (dig "custom_nested_stacks" (list) $stackConfig) }}</td></tr>
    <tr><td>App config ID</td><td><code>{{ dig "app_config_id" "—" $stackConfig }}</code></td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $stackConfig }}</code></td></tr>
  </tbody>
</table>
{{ end }}

{{ $sandboxConfig := dig "sandbox_config" dict $appOutputs }}
{{ if $sandboxConfig }}
<h3>Sandbox config</h3>
{{ $sandboxVCS := dig "vcs_config" dict $sandboxConfig }}
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Repository</td><td><code>{{ dig "repo" "—" $sandboxVCS }}</code></td></tr>
    <tr><td>Branch</td><td><code>{{ dig "branch" "—" $sandboxVCS }}</code></td></tr>
    <tr><td>Directory</td><td><code>{{ dig "directory" "—" $sandboxVCS }}</code></td></tr>
    <tr><td>VCS type</td><td>{{ dig "vcs_type" "—" $sandboxVCS }}</td></tr>
    <tr><td>Type</td><td>{{ dig "type" "—" $sandboxConfig }}</td></tr>
    <tr><td>Terraform version</td><td>{{ dig "terraform_version" "—" $sandboxConfig }}</td></tr>
    <tr><td>Runtime</td><td>{{ dig "runtime" "—" $sandboxConfig }}</td></tr>
    <tr><td>Pulumi version</td><td>{{ dig "pulumi_version" "—" $sandboxConfig }}</td></tr>
    <tr><td>Drift schedule</td><td><code>{{ dig "drift_schedule" "—" $sandboxConfig }}</code></td></tr>
    <tr><td>Max auto retries</td><td>{{ dig "max_auto_retries" "—" $sandboxConfig }}</td></tr>
    <tr><td>Skip no-ops</td><td>{{ dig "skip_noops" "—" $sandboxConfig }}</td></tr>
    <tr><td>Auto-approve on policies passing</td><td>{{ dig "auto_approve_on_policies_passing" "—" $sandboxConfig }}</td></tr>
    <tr><td>AWS region type</td><td>{{ dig "aws_region_type" "—" $sandboxConfig }}</td></tr>
    <tr><td>App config ID</td><td><code>{{ dig "app_config_id" "—" $sandboxConfig }}</code></td></tr>
    <tr><td>ID</td><td><code>{{ dig "id" "—" $sandboxConfig }}</code></td></tr>
  </tbody>
</table>
{{ end }}

<h3>Components</h3>

{{ $components := dig "components" (list) $appOutputs }}
{{ if gt (len $components) 0 }}

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

{{ else }}<nuon-banner theme="info">No components.</nuon-banner>{{ end }}

<h3>Action workflows</h3>

{{ $actionWorkflows := dig "action_workflows" (list) $appOutputs }}
{{ if gt (len $actionWorkflows) 0 }}
<table>
  <thead><tr><th>Name</th><th>Status</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $actionWorkflows }}
    <tr>
      <td>{{ dig "name" "—" . }}</td>
      <td>{{ dig "status" "—" . }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No action workflows.</nuon-banner>{{ end }}

<h3>Runbooks</h3>

{{ $runbooks := dig "runbooks" (list) $appOutputs }}
{{ if gt (len $runbooks) 0 }}
<table>
  <thead><tr><th>Name</th><th>Status</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $runbooks }}
    <tr>
      <td>{{ dig "name" "—" . }}<br><small style="opacity:0.6;">{{ dig "description" "" . }}</small></td>
      <td>{{ dig "status" "—" . }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No runbooks.</nuon-banner>{{ end }}

<h3>App branches</h3>

{{ $branches := dig "app_branches" (list) $appOutputs }}
{{ if gt (len $branches) 0 }}
<table>
  <thead><tr><th>Name</th><th>Created At</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $branches }}
    <tr>
      <td>{{ dig "name" "—" . }}</td>
      <td>{{ with dig "created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No branches.</nuon-banner>{{ end }}

<h3>Permissions: roles & policies</h3>

{{ $permsConfig := dig "permissions_config" dict $appOutputs }}
{{ $roles := dig "roles" (list) $permsConfig }}
{{ if gt (len $roles) 0 }}
<table>
  <thead><tr><th>Role</th><th>Type</th><th>Cloud</th><th>Policies</th><th>ID</th></tr></thead>
  <tbody>
  {{ range $roles }}
    {{ $policies := dig "policies" (list) . }}
    <tr>
      <td>{{ dig "display_name" (dig "name" "—" .) . }}<br><small style="opacity:0.6;">{{ dig "name" "" . }}</small></td>
      <td>{{ dig "type" "—" . }}</td>
      <td>{{ dig "cloud_platform" "—" . }}</td>
      <td>
        {{ if gt (len $policies) 0 }}
          <ul style="margin:0;padding-left:1rem;">
          {{ range $policies }}
            <li>{{ dig "name" (dig "managed_policy_name" "—" .) . }}</li>
          {{ end }}
          </ul>
        {{ else }}—{{ end }}
      </td>
      <td><code>{{ dig "id" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>
{{ else }}<nuon-banner theme="info">No roles configured.</nuon-banner>{{ end }}

{{ else }}

<nuon-banner theme="info">Run the inspect_app action with an APP_ID to inspect a single app.</nuon-banner>

{{ end }}

  </nuon-tab>
</nuon-tabs>
