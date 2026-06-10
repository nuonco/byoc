<nuon-tabs>
  <nuon-tab name="Recent Workflows">

<div style="padding-top:1rem;"></div>

{{ $wfOutputs := dict }}{{ $wfActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}{{ with .outputs }}{{ $wfOutputs = . }}{{ end }}{{ $wfActionID = dig "id" "" . }}{{ end }}

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $wfOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $wfActionID }}">ctl_api_query_workflows_by_type</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

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
      {{ $wfID := dig "workflow_id" "" . }}
      <td style="white-space:nowrap;">{{ dig "workflow_name" "—" . }}{{ with $wfID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}</td>
      {{ $curStep := dig "latest_step_name" "" . }}{{ $curStatus := dig "latest_step_status" "" . }}{{ $curGroup := dig "latest_step_group_name" "" . }}
      <td style="white-space:nowrap;">{{ if $curStep }}{{ $curStep }}{{ with $curStatus }} <nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ end }}{{ with $curGroup }}<br><small style="opacity:0.6;">{{ . }}</small>{{ end }}{{ else }}—{{ end }}</td>
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
  <nuon-tab name="Inspect Workflow">

<div style="padding-top:1rem;"></div>

{{ $stepsOutputs := dict }}{{ $stepsActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflow_steps") }}{{ with .outputs }}{{ $stepsOutputs = . }}{{ end }}{{ $stepsActionID = dig "id" "" . }}{{ end }}

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $stepsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $stepsActionID }}">ctl_api_query_workflow_steps</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ $rows := list }}{{ with index .nuon.actions.workflows "ctl_api_query_workflow_steps" }}{{ with .outputs }}{{ $rows = (dig "rows" (list) .) }}{{ end }}{{ end }}

{{ if not $rows }}

<nuon-banner theme="info">Run the <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $stepsActionID }}">ctl_api_query_workflow_steps</a> action to inspect the details of a workflow.</nuon-banner>

{{ else }} {{ $state := dict "lastWf" "" }} {{ range $rows }}
{{- if ne .workflow_id (index $state "lastWf") }} {{- if ne (index $state "lastWf") "" }}

  </tbody>
</table>
{{- end }}

<div style="padding:1rem 0;">
  <h3 style="margin-top:0;">{{ default .workflow_type (dig "workflow_name" "" .) }}</h3>
  <ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>ID:</strong> <code>{{ .workflow_id }}</code></li>
    <li><strong>Type:</strong> {{ .workflow_type }}</li>
    <li><strong>Status:</strong> <span style="display:inline-block;vertical-align:middle;">{{ if .workflow_status }}<nuon-status status="{{ .workflow_status }}" variant="badge"></nuon-status>{{ end }}</span></li>
    <li><strong>Install:</strong> {{ default "—" .install_name }} <small><code>{{ .install_id }}</code></small></li>
    <li><strong>Org:</strong> {{ default "—" .org_name }} <small><code>{{ .org_id }}</code></small></li>
    <li><strong>Created by:</strong> {{ .created_by_email }}</li>
    <li><strong>Approval:</strong> {{ .approval_option }}</li>
    <li><strong>Created:</strong> {{ with .workflow_created_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Started:</strong> {{ with .workflow_started_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Finished:</strong> {{ with .workflow_finished_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
  </ul>
</div>

### Steps

<table>
  <thead>
    <tr>
      <th>Group</th>
      <th>Group status</th>
      <th>Step</th>
      <th>Status</th>
      <th>Retry</th>
      <th>Skip</th>
      <th>Retried</th>
      <th>Started</th>
      <th>Finished</th>
      <th>Target</th>
      <th>Details</th>
    </tr>
  </thead>
  <tbody>
{{- $_ := set $state "lastWf" .workflow_id }}
{{- end }}
    <tr>
      <td>{{ .group_idx }}{{ with .step_group_name }} — {{ . }}{{ end }}</td>
      <td>{{ if .step_group_status }}<nuon-status status="{{ .step_group_status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ default "—" .step_name }}</td>
      <td>{{ if .step_status }}<nuon-status status="{{ .step_status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ .retryable }}</td>
      <td>{{ .skippable }}</td>
      <td>{{ .retried }}</td>
      <td>{{ with .step_started_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ with .step_finished_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ if .step_target_id }}<code>{{ .step_target_id }}</code> ({{ .step_target_type }}){{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Step: {{ default .step_id .step_name }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Step ID</td><td><code>{{ default "—" .step_id }}</code></td></tr>
    <tr><td>Step name</td><td>{{ default "—" .step_name }}</td></tr>
    <tr><td>Step idx</td><td>{{ default "—" .step_idx }}</td></tr>
    <tr><td>Execution type</td><td>{{ default "—" .execution_type }}</td></tr>
    <tr><td>Status</td><td>{{ if .step_status }}<nuon-status status="{{ .step_status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Result directive</td><td>{{ default "—" .step_result_directive }}</td></tr>
    <tr><td>Retryable</td><td>{{ .retryable }}</td></tr>
    <tr><td>Skippable</td><td>{{ .skippable }}</td></tr>
    <tr><td>Retried</td><td>{{ .retried }}</td></tr>
    <tr><td>Started at</td><td>{{ with .step_started_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Finished at</td><td>{{ with .step_finished_at }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Target ID</td><td>{{ if .step_target_id }}<code>{{ .step_target_id }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Target type</td><td>{{ default "—" .step_target_type }}</td></tr>
    <tr><td>Step signals</td><td>{{ default "—" .step_signals }}</td></tr>
    <tr><td colspan="2"><strong>Step group</strong></td></tr>
    <tr><td>Group ID</td><td><code>{{ default "—" .step_group_id }}</code></td></tr>
    <tr><td>Group name</td><td>{{ default "—" .step_group_name }}</td></tr>
    <tr><td>Group idx</td><td>{{ default "—" .group_idx }}</td></tr>
    <tr><td>Group parallel</td><td>{{ .group_parallel }}</td></tr>
    <tr><td>Group status</td><td>{{ if .step_group_status }}<nuon-status status="{{ .step_group_status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Group result directive</td><td>{{ default "—" .sg_result_directive }}</td></tr>
    <tr><td>Group signals</td><td>{{ default "—" .sg_signals }}</td></tr>
  </tbody>
</table>

</nuon-panel>

      </td>
    </tr>

{{- end }}

  </tbody>
</table>
{{ end }}

  </nuon-tab>
</nuon-tabs>
