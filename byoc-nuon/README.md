{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}

<div style="float:right;">
  <nuon-run-runbook name="refresh_readme"></nuon-run-runbook>
</div>

<img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
<img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>

{{ $wfOutputs := dict }}{{ $wfActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}{{ with .outputs }}{{ $wfOutputs = . }}{{ end }}{{ $wfActionID = dig "id" "" . }}{{ end }}

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Recent workflows</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_workflows" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $wfOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $wfActionID }}">ctl_api_query_workflows_by_type</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}
{{ $wfData := dict }}{{ with .outputs }}{{ $wfData = . }}{{ end }} {{ $wfRows := dig "workflows" (list) $wfData }}
{{ if and .populated (eq .status "finished") (gt (len $wfRows) 0) }}

<table>
  <thead>
    <tr>
      <th>Status</th>
      <th>Name</th>
      <th>Latest Step</th>
      <th>Created By</th>
      <th>Started</th>
      <th>Finished</th>
      <th>Details</th>
    </tr>
  </thead>
  <tbody>
  {{ $topWf := $wfRows }}{{ if gt (len $wfRows) 5 }}{{ $topWf = slice $wfRows 0 5 }}{{ end }}
  {{ range $wf := $topWf }}
    {{ $status := dig "workflow_status" "" $wf }}
    {{ $email := dig "created_by_email" "" $wf }}
    {{ $createdByID := dig "created_by_id" "" $wf }}
    {{ $createdByLabel := $email }}{{ if not $createdByLabel }}{{ $createdByLabel = default "—" $createdByID }}{{ end }}
    {{ $wfID := dig "workflow_id" "" $wf }}
    {{ $curStep := dig "latest_step_name" "" $wf }}{{ $curStatus := dig "latest_step_status" "" $wf }}{{ $curGroup := dig "latest_step_group_name" "" $wf }}
    <tr>
      <td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td style="white-space:nowrap;">{{ dig "workflow_name" "—" $wf }}{{ with $wfID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}</td>
      <td style="white-space:nowrap;">{{ if $curStep }}{{ $curStep }}{{ with $curStatus }} <nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ end }}{{ with $curGroup }}<br><small style="opacity:0.6;">{{ . }}</small>{{ end }}{{ else }}—{{ end }}</td>
      <td style="white-space:nowrap;">{{ $createdByLabel }}</td>
      <td>{{ with dig "workflow_started_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ with dig "workflow_finished_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Workflow: {{ dig "workflow_name" (dig "workflow_id" "—" $wf) $wf }}" trigger="View" size="3/4">

{{ $ownerID := dig "owner_id" "" $wf }}{{ $ownerName := dig "owner_name" "" $wf }}{{ $ownerType := dig "owner_type" "" $wf }}
{{ $orgID := dig "org_id" "" $wf }}{{ $orgName := dig "org_name" "" $wf }}

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Name</td><td>{{ dig "workflow_name" "—" $wf }}</td></tr>
    <tr><td>Type</td><td>{{ dig "workflow_type" "—" $wf }}</td></tr>
    <tr><td>Workflow ID</td><td><code>{{ dig "workflow_id" "—" $wf }}</code></td></tr>
    <tr><td>Created By</td><td>{{ if $email }}{{ $email }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By ID</td><td>{{ if $createdByID }}<code>{{ $createdByID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By Subject</td><td>{{ default "—" (dig "created_by_subject" "" $wf) }}</td></tr>
    <tr><td>Created By Account Type</td><td>{{ default "—" (dig "created_by_account_type" "" $wf) }}</td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td>{{ if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner</td><td>{{ if $ownerName }}{{ $ownerName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner ID</td><td>{{ if $ownerID }}<code>{{ $ownerID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Owner Type</td><td>{{ default "—" $ownerType }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "workflow_created_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "workflow_updated_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Started At</td><td>{{ with dig "workflow_started_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Finished At</td><td>{{ with dig "workflow_finished_at" "" $wf }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

<h4 style="margin-top:1rem;">Latest step</h4>
<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ default "—" (dig "latest_step_name" "" $wf) }}</td></tr>
    <tr><td>Status</td><td>{{ with dig "latest_step_status" "" $wf }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Step ID</td><td>{{ with dig "latest_step_id" "" $wf }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Step idx</td><td>{{ default "—" (dig "latest_step_idx" "" $wf) }}</td></tr>
    <tr><td>Group</td><td>{{ default "—" (dig "latest_step_group_name" "" $wf) }}</td></tr>
    <tr><td>Group idx</td><td>{{ default "—" (dig "latest_step_group_idx" "" $wf) }}</td></tr>
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

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type. Run it to populate this section.</nuon-banner>

{{ end }} {{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type. Run it to populate this section.</nuon-banner>

{{ end }}

{{ $runnersAction  := default dict (index (default dict .nuon.actions.workflows) "inspect_runners") }}
{{ $installsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_installs") }}
{{ $orgsAction     := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $appsAction     := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $runnersSteps  := dig "steps" dict (default dict (dig "outputs" dict $runnersAction)) }}
{{ $installsSteps := dig "steps" dict (default dict (dig "outputs" dict $installsAction)) }}
{{ $orgsSteps     := dig "steps" dict (default dict (dig "outputs" dict $orgsAction)) }}
{{ $appsSteps     := dig "steps" dict (default dict (dig "outputs" dict $appsAction)) }}

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<h3 style="display:inline;margin-right:0.75rem;">Installs</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_installs" style="font-size:0.85em;">See more →</a>

{{ $installs := dig "installs" (dict) $installsSteps }} {{ $appsByID := dict }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $appsByID = set $appsByID (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $installOrgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $installOrgsByID = set $installOrgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ $installList := values $installs }}
{{ if gt (len $installList) 0 }}

<table>
  <thead><tr><th>Name</th><th>Status</th><th>Updated</th><th>Details</th></tr></thead>
  <tbody>
  {{ $topInstalls := $installList }}{{ if gt (len $installList) 5 }}{{ $topInstalls = slice $installList 0 5 }}{{ end }}
  {{ range $install := $topInstalls }}
    {{ $installID := dig "id" "—" $install }}
    {{ $installName := dig "name" "—" $install }}
    {{ $runnerStatus := dig "runner_status" "" $install }}
    {{ $sandboxStatus := dig "sandbox_status" "" $install }}
    {{ $componentStatus := dig "component_status" "" $install }}
    {{ $themeMap := dict "active" "success" "healthy" "success" "finished" "success" "ready" "success" "failed" "error" "error" "error" "unhealthy" "error" "pending" "warn" "queued" "warn" "in_progress" "info" "deprovisioned" "neutral" "unknown" "neutral" }}
    <tr>
      <td>{{ $installName }}<br><small style="opacity:0.6;"><code>{{ $installID }}</code></small></td>
      <td><div style="display:flex;flex-direction:column;gap:0.25rem;align-items:flex-start;">{{ if $runnerStatus }}<nuon-label-badge theme="{{ dig (lower $runnerStatus) "neutral" $themeMap }}" label="runner:{{ $runnerStatus }}"></nuon-label-badge>{{ end }}{{ if $sandboxStatus }}<nuon-label-badge theme="{{ dig (lower $sandboxStatus) "neutral" $themeMap }}" label="sandbox:{{ $sandboxStatus }}"></nuon-label-badge>{{ end }}{{ if $componentStatus }}<nuon-label-badge theme="{{ dig (lower $componentStatus) "neutral" $themeMap }}" label="components:{{ $componentStatus }}"></nuon-label-badge>{{ end }}</div></td>
      <td>{{ with dig "updated_at" "" $install }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Install: {{ $installName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    {{ $appID := dig "app_id" "" $install }}{{ $appName := dig $appID "" $appsByID }}
    {{ $orgID := dig "org_id" "" $install }}{{ $orgName := dig $orgID "" $installOrgsByID }}
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
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="info">No installs reported.</nuon-banner>

{{ end }}

  </div>
  <div style="flex:1;min-width:0;">

<h3 style="display:inline;margin-right:0.75rem;">Runners</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_runners" style="font-size:0.85em;">See more →</a>

{{ $runners := dig "runners" (dict) $runnersSteps }} {{ $ownerNames := dict }}
{{ range $_, $i := (dig "installs" (dict) $installsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $i) (dig "name" "" $i) }}{{ end }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $runnerList := values $runners }}
{{ if gt (len $runnerList) 0 }}

<table>
  <thead><tr><th>Owner</th><th>Healthcheck</th><th>Heartbeat</th><th>Details</th></tr></thead>
  <tbody>
  {{ $topRunners := $runnerList }}{{ if gt (len $runnerList) 5 }}{{ $topRunners = slice $runnerList 0 5 }}{{ end }}
  {{ range $runner := $topRunners }}
    {{ $status := dig "status" "" $runner }}
    {{ $ownerID := dig "owner_id" "" $runner }}
    {{ $ownerName := dig $ownerID "" $ownerNames }}
    {{ $ownerLabel := $ownerName }}{{ if not $ownerLabel }}{{ $ownerLabel = default "—" $ownerID }}{{ end }}
    {{ $runnerID := dig "id" "—" $runner }}
    <tr>
      <td>{{ $ownerLabel }}<br><small style="opacity:0.6;"><code>{{ $runnerID }}</code></small></td>
      <td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ with dig "latest_heart_beat_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>

{{ $processes := default (list) (dig "process_uptimes" nil $runner) }}

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

<h4 style="margin-top:1rem;">Processes</h4>
<table>
  <thead><tr><th>Type</th><th>Status</th><th>Started At</th><th>Uptime</th><th>ID</th></tr></thead>
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
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="info">No runners reported.</nuon-banner>

{{ end }}

  </div>
</div>

