{{ $region := .nuon.cloud_account.aws.region }}
{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" $root_domain .nuon.sandbox) }}

<div style="float:right;">
  <nuon-run-runbook name="refresh_readme"></nuon-run-runbook>
</div>

<img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
<img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>

{{ $api := dict }}{{ $apiActionID := "" }}{{ with index .nuon.actions.workflows "api_status" }}{{ with .outputs }}{{ $api = . }}{{ end }}{{ $apiActionID = dig "id" "" . }}{{ end }}
{{ $dash := dict }}{{ $dashActionID := "" }}{{ with index .nuon.actions.workflows "dashboard_status" }}{{ with .outputs }}{{ $dash = . }}{{ end }}{{ $dashActionID = dig "id" "" . }}{{ end }}
{{ $apiSteps := dig "steps" (dict) $api }} {{ $dashSteps := dig "steps" (dict) $dash }}
{{ $statusOutputs := dict }}{{ $statusActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "status_report") }}{{ with .outputs }}{{ $statusOutputs = . }}{{ end }}{{ $statusActionID = dig "id" "" . }}{{ end }}
<nuon-tabs>
{{ $wfOutputs := dict }}{{ $wfActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}{{ with .outputs }}{{ $wfOutputs = . }}{{ end }}{{ $wfActionID = dig "id" "" . }}{{ end }}
  <nuon-tab name="workflows">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $wfOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $wfActionID }}">ctl_api_query_workflows_by_type</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}
{{ $wfData := dict }}{{ with .outputs }}{{ $wfData = . }}{{ end }} {{ $wfRows := dig "workflows" (list) $wfData }}
{{ if and .populated (eq .status "finished") (gt (len $wfRows) 0) }}

<table>
  <thead>
    <tr>
      <th>Status</th>
      <th>Name</th>
      <th>Created By</th>
      <th>Org</th>
      <th>Owner</th>
      <th>Created At</th>
      <th>Finished At</th>
      <th>Details</th>
    </tr>
  </thead>
  <tbody>
  {{ range $wfRows }}
    {{ $status := dig "workflow_status" "" . }}
    {{ $email := dig "created_by_email" "" . }}
    {{ $createdByID := dig "created_by_id" "" . }}
    {{ $createdByLabel := $email }}{{ if not $createdByLabel }}{{ $createdByLabel = default "—" $createdByID }}{{ end }}
    {{ $ownerID := dig "owner_id" "" . }}
    {{ $ownerType := dig "owner_type" "" . }}
    {{ $ownerName := dig "owner_name" "" . }}
    <tr>
      <td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ dig "workflow_name" "—" . }}</td>
      <td style="white-space:nowrap;">{{ $createdByLabel }}</td>
      {{ $orgName := dig "org_name" "" . }}{{ $orgID := dig "org_id" "" . }}
      <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ with $orgID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}{{ else if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td>
      <td style="white-space:nowrap;">{{ if $ownerName }}{{ $ownerName }}{{ with $ownerID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}{{ else if $ownerID }}<code>{{ $ownerID }}</code>{{ else }}—{{ end }}</td>
      <td>{{ with dig "workflow_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ with dig "workflow_finished_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Workflow: {{ dig "workflow_name" (dig "workflow_id" "—" .) . }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Name</td><td>{{ dig "workflow_name" "—" . }}</td></tr>
    <tr><td>Type</td><td>{{ dig "workflow_type" "—" . }}</td></tr>
    <tr><td>Workflow ID</td><td><code>{{ dig "workflow_id" "—" . }}</code></td></tr>
    <tr><td>Created By</td><td>{{ if $email }}{{ $email }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By ID</td><td>{{ if $createdByID }}<code>{{ $createdByID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By Subject</td><td>{{ default "—" (dig "created_by_subject" "" .) }}</td></tr>
    <tr><td>Created By Account Type</td><td>{{ default "—" (dig "created_by_account_type" "" .) }}</td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td>{{ if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner</td><td>{{ if $ownerName }}{{ $ownerName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner ID</td><td>{{ if $ownerID }}<code>{{ $ownerID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner Type</td><td>{{ default "—" $ownerType }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "workflow_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "workflow_updated_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Started At</td><td>{{ with dig "workflow_started_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Finished At</td><td>{{ with dig "workflow_finished_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

      </td>
    </tr>

{{ end }}

  </tbody>
</table>

{{ else if and .populated (eq .status "finished") }}

<nuon-banner theme="info">No workflows returned by the last run of ctl_api_query_workflows_by_type.</nuon-banner>

{{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type action. Run it to populate this
section.</nuon-banner>

{{ end }} {{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type action. Run it to populate this
section.</nuon-banner>

{{ end }}

</nuon-tab>
{{ with (index (default dict .nuon.actions.workflows) "status_report") }}
{{ $steps := dict }}{{ with .outputs }}{{ with .steps }}{{ $steps = . }}{{ end }}{{ end }}
{{ if and .populated (eq .status "finished") }}
  <nuon-tab name="runners">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $statusOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $statusActionID }}">status_report</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ $runners := dig "runners" (dict) $steps }} {{ $ownerNames := dict }}
{{ range $_, $i := (dig "installs" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $i) (dig "name" "" $i) }}{{ end }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ range $_, $a := (dig "apps" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ if gt (len $runners) 0 }}

  <table>
      <thead>
          <tr>
              <th>ID</th>
              <th>Status</th>
              <th>Owner</th>
              <th>Type</th>
              <th>Latest Heartbeat</th>
              <th>Latest Healthcheck</th>
              <th>Process Uptime</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $runner := $runners}}
          {{ $status := dig "status" "" $runner }}
          {{ $ownerID := dig "owner_id" "" $runner }}
          {{ $ownerName := dig $ownerID "" $ownerNames }}
          {{ $ownerLabel := $ownerName }}{{ if not $ownerLabel }}{{ $ownerLabel = default "—" $ownerID }}{{ end }}
          {{ $runnerID := dig "id" "—" $runner }}
          {{ $processes := default (list) (dig "process_uptimes" nil $runner) }}
          {{ $ownerProc := dict }}{{ range $p := $processes }}{{ $t := dig "type" "" $p }}{{ if or (eq $t "install") (eq $t "build") }}{{ $ownerProc = $p }}{{ end }}{{ end }}
          <tr>
              <td><code>{{ $runnerID }}</code></td>
              <td><nuon-status status="{{ $status }}"></nuon-status></td>
              <td style="white-space:nowrap;">{{ $ownerLabel }}</td>
              <td>{{ dig "type" "—" $runner }}</td>
              <td>{{ with dig "latest_heart_beat_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
              <td style="white-space:nowrap;">{{ with dig "uptime" 0 $ownerProc }}{{ (div (int64 .) 1000000000) | int64 | duration }}{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Runner: {{ $ownerLabel }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td><nuon-status status="{{ $status }}" variant="badge"></nuon-status></td></tr>
    <tr><td>Owner</td><td>{{ $ownerLabel }}</td></tr>
    <tr><td>Owner ID</td><td><code>{{ $ownerID }}</code></td></tr>
    <tr><td>Type</td><td>{{ dig "type" "—" $runner }}</td></tr>
    <tr><td>Platform</td><td>{{ dig "platform" "—" $runner }}</td></tr>
    <tr><td>Image</td><td><code>{{ dig "image" "—" $runner }}:{{ dig "tag" "—" $runner }}</code></td></tr>
    <tr><td>Runner ID</td><td><code>{{ $runnerID }}</code></td></tr>
    <tr><td>Latest Heartbeat</td><td>{{ with dig "latest_heart_beat_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Heartbeat Version</td><td>{{ with dig "latest_heart_beat_version" "" $runner }}<nuon-badge theme="info" size="sm" variant="code">{{ . }}</nuon-badge>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Healthcheck</td><td>{{ with dig "latest_health_check_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Healthcheck Status</td><td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

{{ if gt (len $processes) 0 }}

**Processes**

<table>
  <thead>
    <tr>
      <th>Type</th>
      <th>Status</th>
      <th>Started At</th>
      <th>Uptime</th>
      <th>ID</th>
    </tr>
  </thead>
  <tbody>
  {{ range $p := $processes }}
    <tr>
      <td>{{ dig "type" "—" $p }}</td>
      <td>{{ with dig "status" "" $p }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ with dig "started_at" "" $p }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ with dig "uptime" 0 $p }}{{ (div (int64 .) 1000000000) | int64 | duration }}{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" $p }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ end }}

</nuon-panel>

              </td>
          </tr>
      {{end}}
      </tbody>

  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No runners reported.</nuon-banner></div>

{{ end }}

  </nuon-tab>
  <nuon-tab name="installs">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $statusOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $statusActionID }}">status_report</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ $installs := dig "installs" (dict) $steps }} {{ $appsByID := dict }}
{{ range $_, $a := (dig "apps" (dict) $steps) }}{{ $appsByID = set $appsByID (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $installOrgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $installOrgsByID = set $installOrgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
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
          <tr>
              <td>{{ $installName }}<br><small style="opacity:0.6;"><code>{{ $installID }}</code></small></td>
              <td style="white-space:nowrap;"><nuon-group gap="1" align="center" justify="start">{{ if $runnerStatus }}<nuon-status status="{{ $runnerStatus }}" variant="badge" label="runner"></nuon-status>{{ end }}{{ if $sandboxStatus }}<nuon-status status="{{ $sandboxStatus }}" variant="badge" label="sandbox"></nuon-status>{{ end }}{{ if $componentStatus }}<nuon-status status="{{ $componentStatus }}" variant="badge" label="components"></nuon-status>{{ end }}</nuon-group></td>
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
    <tr><td>Runner Status</td><td>{{ if $runnerStatus }}<nuon-status status="{{ $runnerStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}{{ with dig "runner_status_description" "" $install }} <small style="opacity:0.7;">{{ . }}</small>{{ end }}</td></tr>
    <tr><td>Sandbox Status</td><td>{{ if $sandboxStatus }}<nuon-status status="{{ $sandboxStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}{{ with dig "sandbox_status_description" "" $install }} <small style="opacity:0.7;">{{ . }}</small>{{ end }}</td></tr>
    <tr><td>Components Status</td><td>{{ if $componentStatus }}<nuon-status status="{{ $componentStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}{{ with dig "component_status_description" "" $install }} <small style="opacity:0.7;">{{ . }}</small>{{ end }}</td></tr>
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

  </nuon-tab>
  <nuon-tab name="apps">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $statusOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $statusActionID }}">status_report</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ $apps := dig "apps" (dict) $steps }} {{ $orgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $orgsByID = set $orgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
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

  </nuon-tab>
  <nuon-tab name="orgs">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $statusOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $statusActionID }}">status_report</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ $orgs := dig "orgs" (dict) $steps }} {{ if gt (len $orgs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $org := $orgs}}
          {{ $orgID := dig "id" "—" $org }}
          {{ $orgName := dig "name" "—" $org }}
          <tr>
              <td>{{ $orgName }}<br><small style="opacity:0.6;"><code>{{ $orgID }}</code></small></td>
              <td>{{ with dig "created_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Org: {{ $orgName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $orgName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $orgID }}</code></td></tr>
    <tr><td>Slug</td><td>{{ with dig "slug" "" $org }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
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

  </nuon-tab>
{{ end }} {{ end }}


  <nuon-tab name="api">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ range $step := list "alb-healthcheck-ctl-api-public" "alb-healthcheck-ctl-api-admin" "alb-healthcheck-ctl-api-runner" }}{{ $indicator := dig $step "indicator" "" $apiSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}<nuon-label-badge label="version:{{ dig "ctl_api_version" "unknown" $api }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "ctl_api_git_ref" "unknown" $api }}"></nuon-label-badge><a href="https://api.{{ $public_domain }}/docs/index.html">Open ↗</a>{{ with dig "updated_at" "" $api }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $apiActionID }}">api_status</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

**Links**

| Service    | URL                                                                |
| ---------- | ------------------------------------------------------------------ |
| CTL API    | [api.{{ $public_domain }}](https://api.{{ $public_domain }})       |
| Runner API | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }}) |

**CLI**

Install the latest version of the nuon cli ([docs](https://docs.nuon.co/cli#cli)).

```bash
brew install nuonco/tap/nuon
```

Update your `~/.nuon` config or create one specifically for this byoc install (e.g. `~/.nuon.byoc`).

Configure as follows:

```yaml
api_url: https://api.{{ $public_domain }}
```

Log in:

```yaml
nuon -f ~/.nuon.byoc login
```

<nuon-action-card name="api_status"></nuon-action-card>

</nuon-tab>

  <nuon-tab name="dashboard">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $indicator := dig "alb-healthcheck-dashboard-ui" "indicator" "" $dashSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="version:{{ dig "dashboard_ui_version" "unknown" $dash }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "dashboard_ui_git_ref" "unknown" $dash }}"></nuon-label-badge><a href="https://app.{{ $public_domain }}">Open ↗</a>{{ with dig "updated_at" "" $dash }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $dashActionID }}">dashboard_status</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

**Links**

| Service   | URL                                                          |
| --------- | ------------------------------------------------------------ |
| Dashboard | [app.{{ $public_domain }}](https://app.{{ $public_domain }}) |

<nuon-action-card name="dashboard_status"></nuon-action-card>

</nuon-tab>

  <nuon-tab name="stack">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $stackStatus := dig "status" "" .nuon.install_stack }}{{ if or (eq $stackStatus "active") (eq $stackStatus "healthy") (eq $stackStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $stackStatus "failed") (eq $stackStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="cloud:AWS"></nuon-label-badge><nuon-label-badge label="account:{{ dig "account_id" "000000000000" .nuon.install_stack.outputs }}"></nuon-label-badge><nuon-label-badge label="region:{{ $region }}"></nuon-label-badge><nuon-label-badge label="vpc:{{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}"></nuon-label-badge><span style="margin-left:auto;font-size:0.85em;">(from install state)</span></nuon-group>

**Outputs**

<table>
  <thead><tr><th>Output</th><th>Value</th></tr></thead>
  <tbody>
  {{ range $key, $value := .nuon.install_stack.outputs }}
    <tr><td>{{ $key }}</td><td>{{ $value }}</td></tr>
  {{ end }}
  </tbody>
</table>

</nuon-tab>

  <nuon-tab name="cluster">

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $sandboxStatus := dig "status" "" .nuon.sandbox | lower }}{{ if or (eq $sandboxStatus "active") (eq $sandboxStatus "healthy") (eq $sandboxStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $sandboxStatus "failed") (eq $sandboxStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="name:{{ dig "outputs" "cluster" "name" "unknown" .nuon.sandbox }}"></nuon-label-badge><nuon-label-badge label="version:{{ coalesce (dig "outputs" "cluster" "version" nil .nuon.sandbox) (dig "outputs" "cluster" "platform_version" nil .nuon.sandbox) "unknown" }}"></nuon-label-badge><span style="margin-left:auto;font-size:0.85em;">(from install state)</span></nuon-group>

**Outputs**

<table>
  <thead><tr><th>Output</th><th>Value</th></tr></thead>
  <tbody>
  {{ range $key, $value := dig "outputs" "cluster" (dict) .nuon.sandbox }}
    <tr><td>{{ $key }}</td><td>{{ $value }}</td></tr>
  {{ end }}
  </tbody>
</table>

**Accessing the EKS Cluster**

1. Add an access entry for the relevant role.
2. Grant the following perms: AWSEKSAdmin, AWSClusterAdmin.gtg
3. Add the cluster kubeconfig w/ the following command.

<pre>
aws --region {{ .nuon.install_stack.outputs.region }} \
    --profile your.Profile eks update-kubeconfig      \
    --name {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --alias {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }}
</pre>

  </nuon-tab>
</nuon-tabs>


