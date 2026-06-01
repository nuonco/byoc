{{ $rows := list }}{{ with index .nuon.actions.workflows "ctl_api_query_workflow_steps" }}{{ with .outputs }}{{ $rows = (dig "rows" (list) .) }}{{ end }}{{ end }}

{{ if not $rows }} _No rows returned. Run the **Query workflow steps** action above (optionally with a `WORKFLOW_ID`)
and re-render this runbook._ {{ else }} {{ $state := dict "lastWf" "" }} {{ range $rows }}
{{- if ne .workflow_id (index $state "lastWf") }} {{- if ne (index $state "lastWf") "" }}

  </tbody>
</table>
{{- end }}

<div style="display:flex;gap:1rem;align-items:stretch;flex-wrap:wrap;margin-bottom:1rem;">
  <div style="flex:2 1 0;min-width:320px;border:1px solid var(--nuon-border-color,#e5e7eb);border-radius:0.5rem;padding:1rem;background:var(--nuon-card-bg,#fff);">
    <h3 style="margin-top:0;">Workflow</h3>
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
  <div style="flex:1 1 0;min-width:240px;border:1px solid var(--nuon-border-color,#e5e7eb);border-radius:0.5rem;padding:1rem;background:var(--nuon-card-bg,#fff);">
    <h3 style="margin-top:0;">About this runbook</h3>
    <p>This runbook reads a workflow and its steps for debugging. Fetches the most recent workflow run by default.</p>
    <p>Set the action's <code>WORKFLOW_ID</code> env var to inspect a specific workflow. (This can currently only be done by running the action itself, until we add inputs to runbooks.)</p>
  </div>
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
