# Recent workflows

<div style="padding-top:1rem;"></div>

<nuon-banner theme="info">To drill into a single workflow's step groups and steps, copy its <strong>ID</strong> from the
table below and run the <code>debug_workflow</code> runbook with it.</nuon-banner>

<div style="padding-top:1rem;"></div>

{{ $wfOutputs := dict }}{{ $wfActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}{{ with .outputs }}{{ $wfOutputs = . }}{{ end }}{{ $wfActionID = dig "id" "" . }}{{ end }}

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $wfOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $wfActionID }}">ctl_api_query_workflows_by_type</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

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
