{{ $action := default dict (index (default dict .nuon.actions.workflows) "temporal_delete_event_loops") }}
{{ $outputs := default dict (dig "outputs" dict $action) }}
{{ $actionID := dig "id" "" $action }}

## Delete EventLoop Workflows

Stale EventLoop workflows can accumulate in Temporal and cause high workflow
counts across the `installs`, `actions`, `runners`, and `apps` namespaces.
This runbook checks for running EventLoop workflows and deletes them.

**Affected workflow types:** `EventLoop`, `ActionEventLoop`,
`ComponentEventLoop`, `SandboxEventLoop`, `StackEventLoop`

Run the action below to check counts and delete any found. It waits for each
batch operation to complete before submitting the next, so it is safe to run
without hitting the concurrent batch limit.

<nuon-action-card name="temporal_delete_event_loops"></nuon-action-card>

<div style="padding-top:2rem;"></div>

## Last Run Results

{{ if and (dig "populated" false $action) (eq (dig "status" "" $action) "finished") }}

<nuon-group gap="2" align="center" justify="start">
{{ with dig "checked_at" "" $outputs }}<span style="font-size:0.85em;">Checked <nuon-time time="{{ . }}" format="relative"></nuon-time> by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $actionID }}">temporal_delete_event_loops</a></span>{{ end }}
</nuon-group>

<div style="padding-top:1rem;"></div>

{{ if dig "any_found" false $outputs }}
<nuon-banner theme="warn">Found {{ dig "total_found" 0 $outputs }} EventLoop workflow(s) — deletes were submitted.</nuon-banner>
{{ else }}
<nuon-banner theme="success">No EventLoop workflows found. Nothing to delete.</nuon-banner>
{{ end }}

<div style="padding-top:1rem;"></div>

<table>
  <thead>
    <tr>
      <th>Namespace</th>
      <th>Found</th>
      <th>Delete submitted</th>
    </tr>
  </thead>
  <tbody>
  {{ range dig "namespaces" (list) $outputs }}
    <tr>
      <td><code>{{ dig "name" "—" . }}</code></td>
      <td>{{ dig "found" 0 . }}</td>
      <td>{{ if dig "deleted" false . }}yes{{ else }}—{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="warn">Run <code>temporal_delete_event_loops</code> above to populate this
section.</nuon-banner>

{{ end }}
