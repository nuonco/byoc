{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}

{{/* Feature & setup runbooks. The README template can't read runbook labels at render time, so
     mirror them here: each type=feature runbook goes in $featureRunbooks (Features tab) and each
     type=setup runbook in $setupRunbooks (Setup tab), with its completion check. Keep in sync as
     these runbooks are added/removed. */}} {{ $slackDone := false }}{{ with index (default dict .nuon.actions.workflows) "sync_slack_secrets" }}{{ if eq .status "finished" }}{{ $slackDone = true }}{{ end }}{{ end }}
{{ $loopsDone := false }}{{ with index (default dict .nuon.actions.workflows) "sync_loops_secret" }}{{ if eq .status "finished" }}{{ $loopsDone = true }}{{ end }}{{ end }}
{{ $s3Done := false }}{{ with index (default dict .nuon.actions.workflows) "s3_bucket" }}{{ if eq .status "finished" }}{{ $s3Done = true }}{{ end }}{{ end }}
{{ $dnsDone := false }}{{ if dig "dns_zone" "" (default dict (default dict .nuon.components.management).outputs) }}{{ $dnsDone = true }}{{ end }}
{{ $featureRunbooks := list (dict "name" "slack_setup" "label" "Slack" "complete" $slackDone "desc" "Set up the Slack integration: create the Slack app, provision and populate the central secret, set the install inputs, then sync the secrets into the ctl-api namespace and verify.") }}
{{ $setupRunbooks := list (dict "name" "dns_setup" "label" "DNS" "complete" $dnsDone "desc" "Show the DNS delegation records (nameservers) to share with the customer so they can delegate their domain to this install.") (dict "name" "s3_bucket" "label" "S3 Bucket" "complete" $s3Done "desc" "Enable and inspect the AWS S3 install-templates bucket integration used for install templates.") (dict "name" "loops_setup" "label" "Loops" "complete" $loopsDone "desc" "Set up the Loops integration: provision and populate the central secret, set the loops_secret_arn input, then sync the API key into the ctl-api namespace.") }}
{{ $incomplete := list }}{{ range $setupRunbooks }}{{ if not .complete }}{{ $incomplete = append $incomplete . }}{{ end }}{{ end }}
{{ if gt (len $incomplete) 0 }}<nuon-banner theme="warn"> <strong>Setup is incomplete.</strong> Complete the runbooks in
the Setup tab. </nuon-banner>

<div style="padding-bottom:1.5rem;"></div>{{ end }}

<div style="float:right;">
  <nuon-run-runbook name="refresh_readme"></nuon-run-runbook>
</div>

<img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg" style="margin:0;padding:0;"/>
<img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg" style="margin:0;padding:0;"/>

<nuon-tabs>
<nuon-tab name="Application">

<div style="padding-top:1rem;"></div>

{{ $wfOutputs := dict }}{{ $wfActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}{{ with .outputs }}{{ $wfOutputs = . }}{{ end }}{{ $wfActionID = dig "id" "" . }}{{ end }}

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Recent workflows</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_workflows" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $wfOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

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
{{ $runnersOutputs  := default dict (dig "outputs" dict $runnersAction) }}
{{ $installsOutputs := default dict (dig "outputs" dict $installsAction) }}
{{ $runnersSteps  := dig "steps" dict $runnersOutputs }} {{ $installsSteps := dig "steps" dict $installsOutputs }}
{{ $orgsSteps     := dig "steps" dict (default dict (dig "outputs" dict $orgsAction)) }}
{{ $appsSteps     := dig "steps" dict (default dict (dig "outputs" dict $appsAction)) }}

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Installs</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_installs" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $installsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

{{ $installs := dig "installs" (dict) $installsSteps }} {{ $appsByID := dict }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $appsByID = set $appsByID (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $installOrgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $installOrgsByID = set $installOrgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ $installList := values $installs }} {{ if gt (len $installList) 0 }}

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

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Runners</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_runners" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $runnersOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

{{ $runners := dig "runners" (dict) $runnersSteps }} {{ $ownerNames := dict }}
{{ range $_, $i := (dig "installs" (dict) $installsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $i) (dig "name" "" $i) }}{{ end }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $runnerList := values $runners }} {{ if gt (len $runnerList) 0 }}

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

</nuon-tab>
<nuon-tab name="System">

{{ $api  := dict }}{{ $apiActionID  := "" }}{{ with index .nuon.actions.workflows "api_status"       }}{{ with .outputs }}{{ $api  = . }}{{ end }}{{ $apiActionID  = dig "id" "" . }}{{ end }}
{{ $dash := dict }}{{ $dashActionID := "" }}{{ with index .nuon.actions.workflows "dashboard_status" }}{{ with .outputs }}{{ $dash = . }}{{ end }}{{ $dashActionID = dig "id" "" . }}{{ end }}
{{ $apiSteps  := dig "steps" (dict) $api  }} {{ $dashSteps := dig "steps" (dict) $dash }}

<div style="display:flex;gap:1.5rem;align-items:flex-start;margin-top:1.5rem;">
  <div style="flex:1;min-width:0;">

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">API</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_api" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $api }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

<nuon-card>

<nuon-group gap="2" align="center" justify="start">{{ range $step := list "route-healthcheck-ctl-api-public" "route-healthcheck-ctl-api-admin" "route-healthcheck-ctl-api-runner" }}{{ $indicator := dig $step "indicator" "" $apiSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}<nuon-label-badge
label="version:{{ dig "ctl_api_version" "unknown" $api }}"></nuon-label-badge><nuon-label-badge
label="git:{{ dig "ctl_api_git_ref" "unknown" $api }}"></nuon-label-badge><a href="https://api.{{ $public_domain }}/docs/index.html">Open
↗</a></nuon-group>

{{ if not (dig "updated_at" "" $api) }}<nuon-banner theme="warn">Waiting on api_status. Run it to populate this
section.</nuon-banner>{{ end }}

</nuon-card>

  </div>
  <div style="flex:1;min-width:0;">

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Dashboard</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_dashboard" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $dash }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

<nuon-card>

<nuon-group gap="2" align="center" justify="start">{{ $indicator := dig "route-healthcheck-dashboard-ui" "indicator" "" $dashSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="version:{{ dig "dashboard_ui_version" "unknown" $dash }}"></nuon-label-badge><nuon-label-badge
label="git:{{ dig "dashboard_ui_git_ref" "unknown" $dash }}"></nuon-label-badge><a href="https://app.{{ $public_domain }}">Open
↗</a></nuon-group>

{{ if not (dig "updated_at" "" $dash) }}<nuon-banner theme="warn">Waiting on dashboard_status. Run it to populate this
section.</nuon-banner>{{ end }}

</nuon-card>

  </div>
</div>

{{ $migAction := default dict (index (default dict .nuon.actions.workflows) "inspect_migrations") }}
{{ $migOutputs := default dict (dig "outputs" dict $migAction) }}
{{ $migSteps := dig "steps" dict $migOutputs }}
{{ $migrations := dig "migrations" (dict) $migSteps }}

<div style="display:flex;align-items:baseline;gap:0.75rem;margin-top:1.5rem;"><h3 style="margin:0;">Migrations</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_migrations" style="font-size:0.85em;">See more →</a>{{ with dig "updated_at" "" $migOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

{{ if gt (len $migrations) 0 }}
{{ $themeMap := dict "applied" "success" "in_progress" "info" "error" "error" "unknown" "neutral" }}

<table>
  <thead><tr><th>Name</th><th>Status</th><th>Created</th></tr></thead>
  <tbody>
  {{ range $_, $m := $migrations }}
    {{ $status := dig "status" "" $m }}
    <tr>
      <td>{{ dig "name" "—" $m }}<br><small style="opacity:0.6;"><code>{{ dig "id" "—" $m }}</code></small></td>
      <td>{{ if $status }}<nuon-label-badge theme="{{ dig (lower $status) "neutral" $themeMap }}" label="{{ $status }}"></nuon-label-badge>{{ else }}—{{ end }}</td>
      <td>{{ with dig "created_at" "" $m }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else if not (dig "updated_at" "" $migOutputs) }}<nuon-banner theme="warn">Waiting on inspect_migrations. Run it to populate this section.</nuon-banner>{{ else }}<nuon-banner theme="info">No migrations reported.</nuon-banner>{{ end }}

</nuon-tab>
<nuon-tab name="Infrastructure">

<div style="padding-top:1rem;"></div>

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Stack</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_stack" style="font-size:0.85em;">See more →</a></div>

{{ $stackStatus := dig "status" "" .nuon.install_stack }}
{{ $stackOutputs := default dict .nuon.install_stack.outputs }}

<table>
  <tbody>
    <tr><td>Status</td><td>{{ if $stackStatus }}<nuon-status status="{{ $stackStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Cloud</td><td>GCP</td></tr>
    <tr><td>Project</td><td><code>{{ dig "project_id" "—" $stackOutputs }}</code></td></tr>
    <tr><td>Region</td><td><code>{{ dig "region" "—" $stackOutputs }}</code></td></tr>
    <tr><td>Network</td><td><code>{{ dig "network_name" "—" $stackOutputs }}</code></td></tr>
  </tbody>
</table>

  </div>
  <div style="flex:1;min-width:0;">

<div style="display:flex;align-items:baseline;gap:0.75rem;"><h3 style="margin:0;">Cluster</h3><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/inspect_cluster" style="font-size:0.85em;">See more →</a></div>

{{ $sandboxStatus := dig "status" "" .nuon.sandbox }} {{ $cluster := dig "outputs" "cluster" (dict) .nuon.sandbox }}

<table>
  <tbody>
    <tr><td>Status</td><td>{{ if $sandboxStatus }}<nuon-status status="{{ lower $sandboxStatus }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Name</td><td><code>{{ dig "name" "—" $cluster }}</code></td></tr>
    <tr><td>Location</td><td><code>{{ dig "location" "—" $cluster }}</code></td></tr>
    <tr><td>Endpoint</td><td>{{ with dig "endpoint" "" $cluster }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Self Link</td><td>{{ with dig "self_link" "" $cluster }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

  </div>
</div>

</nuon-tab>

<nuon-tab name="Features">

<div style="padding-top:1rem;"></div>

### Features

Optional features that can be enabled for this install.

<table>
  <thead><tr><th>Status</th><th>Runbook</th><th>Description</th></tr></thead>
  <tbody>
  {{ range $featureRunbooks }}
    <tr>
      <td>{{ if .complete }}<nuon-status status="finished" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}</td>
      <td><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/{{ .name }}">{{ .label }}</a></td>
      <td>{{ .desc }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

</nuon-tab>

<nuon-tab name="Setup">

<div style="padding-top:1rem;"></div>

### Setup

Tasks required to make this install of Nuon BYOC on GCP fully operational.

<table>
  <thead><tr><th>Status</th><th>Runbook</th><th>Description</th></tr></thead>
  <tbody>
  {{ range $setupRunbooks }}
    <tr>
      <td>{{ if .complete }}<nuon-status status="finished" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}</td>
      <td><a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/runbooks/{{ .name }}">{{ .label }}</a></td>
      <td>{{ .desc }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

</nuon-tab>

</nuon-tabs>
