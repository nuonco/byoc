{{ $listAction := default dict (index (default dict .nuon.actions.workflows) "temporal_workflow_list") }}
{{ $listOutputs := default dict (dig "outputs" dict $listAction) }}
{{ $listActionID := dig "id" "" $listAction }}
{{ $namespaces := dig "namespaces" (list) $listOutputs }}
{{ $totalCount := dig "total_count" 0 $listOutputs }}

{{ if and (dig "populated" false $listAction) (eq (dig "status" "" $listAction) "finished") (gt (len $namespaces) 0) }}

## Running workflows

<nuon-tabs>
{{ range $namespaces }}
  <nuon-tab name="{{ dig "name" "—" . }} ({{ dig "workflow_count" 0 . }})">

<div style="padding-top:1rem;"></div>

{{ $wfs := dig "workflows" (list) . }}

<nuon-group gap="2" align="center" justify="start"><nuon-label-badge label="total:{{ dig "running_total" 0 . }}"></nuon-label-badge>{{ with dig "updated_at" "" $listOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $listActionID }}">temporal_workflow_list</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ if gt (len $wfs) 0 }}

<table>
  <thead>
    <tr>
      <th>Workflow ID</th>
      <th>Type</th>
      <th>Task Queue</th>
      <th>Started</th>
    </tr>
  </thead>
  <tbody>
  {{ range $wfs }}
    <tr>
      <td><code>{{ dig "workflow_id" "—" . }}</code></td>
      <td>{{ dig "type" "—" . }}</td>
      <td>{{ dig "task_queue" "—" . }}</td>
      <td>{{ with dig "start_time" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="info">No running workflows in this namespace.</nuon-banner>

{{ end }}

  </nuon-tab>
{{ end }}
</nuon-tabs>

{{ else if and (dig "populated" false $listAction) (eq (dig "status" "" $listAction) "finished") }}

<nuon-banner theme="info">No namespaces returned by the last run of temporal_workflow_list.</nuon-banner>

{{ else }}

<nuon-banner theme="warn">Waiting on temporal_workflow_list. Run it to populate this section.</nuon-banner>

{{ end }}

<div style="padding-top:2rem;"></div>

{{ $historyAction := default dict (index (default dict .nuon.actions.workflows) "temporal_workflow_history") }}
{{ $historyOutputs := default dict (dig "outputs" dict $historyAction) }}
{{ $historyActionID := dig "id" "" $historyAction }}

## Workflow details

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $historyOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $historyActionID }}">temporal_workflow_history</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ if and (dig "populated" false $historyAction) (eq (dig "status" "" $historyAction) "finished") (dig "workflow_id" "" $historyOutputs) }}

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td>{{ with dig "status" "" $historyOutputs }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Workflow ID</td><td><code>{{ dig "workflow_id" "—" $historyOutputs }}</code></td></tr>
    <tr><td>Run ID</td><td><code>{{ dig "run_id" "—" $historyOutputs }}</code></td></tr>
    <tr><td>Type</td><td>{{ dig "type" "—" $historyOutputs }}</td></tr>
    <tr><td>Task Queue</td><td>{{ dig "task_queue" "—" $historyOutputs }}</td></tr>
    <tr><td>Start</td><td>{{ with dig "start_time" "" $historyOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>End</td><td>{{ with dig "close_time" "" $historyOutputs }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>History size (bytes)</td><td>{{ dig "history_size_bytes" "—" $historyOutputs }}</td></tr>
    <tr><td>History length</td><td>{{ dig "history_length" "—" $historyOutputs }}</td></tr>
    <tr><td>State transitions</td><td>{{ dig "state_transition_count" "—" $historyOutputs }}</td></tr>
  </tbody>
</table>

<div style="padding-top:1rem;"></div>

### Input

{{ with dig "input" "" $historyOutputs }}

```json
{{ . }}
```

{{ else }}

<nuon-banner theme="info">No input recorded.</nuon-banner>

{{ end }}

### Result

{{ with dig "result" "" $historyOutputs }}

```json
{{ . }}
```

{{ else }}

<nuon-banner theme="info">Results will appear upon completion.</nuon-banner>

{{ end }}

### Event history

<table>
  <thead><tr><th>Event ID</th><th>Timestamp</th><th>Type</th></tr></thead>
  <tbody>
  {{ range (dig "events" (list) $historyOutputs) }}
    <tr>
      <td>{{ dig "event_id" "—" . }}</td>
      <td>{{ with dig "event_time" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
      <td><code>{{ dig "event_type" "—" . }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="warn">Run <code>temporal_workflow_history</code> with a <code>WORKFLOW_ID</code> to populate this section.</nuon-banner>

{{ end }}
