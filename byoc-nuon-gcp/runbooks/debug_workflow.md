# Debug workflow

Inspect a single install workflow in detail. Run this runbook with a **Workflow ID** — its `Query workflow steps` step
queries ctl-api for that workflow's step groups, steps, and the queue signals attached at both the step-group and step
level, then renders them below. Grab the ID from the Recent Workflows table in the `inspect_workflows` runbook.

<div style="padding-top:1rem;"></div>

{{ $stepsOutputs := dict }}{{ $stepsActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflow_steps") }}{{ with .outputs }}{{ $stepsOutputs = . }}{{ end }}{{ $stepsActionID = dig "id" "" . }}{{ end }}

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $stepsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $stepsActionID }}">ctl_api_query_workflow_steps</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ $rows := list }}{{ with index .nuon.actions.workflows "ctl_api_query_workflow_steps" }}{{ with .outputs }}{{ $rows = (dig "rows" (list) .) }}{{ end }}{{ end }}

{{ if not $rows }}

<nuon-banner theme="info">Run this runbook with a <strong>Workflow ID</strong> to inspect the details of a
workflow. The <code>Query workflow steps</code> step will populate this page.</nuon-banner>

{{ else }} {{ $state := dict "lastWf" "" }} {{ range $rows }} {{- if ne .workflow_id (index $state "lastWf") }}
{{- if ne (index $state "lastWf") "" }}

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
