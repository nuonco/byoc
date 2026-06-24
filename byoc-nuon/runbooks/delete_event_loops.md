{{ $checkAction := default dict (index (default dict .nuon.actions.workflows) "temporal_check_event_loops") }}
{{ $checkOutputs := default dict (dig "outputs" dict $checkAction) }}
{{ $checkActionID := dig "id" "" $checkAction }}

{{ $deleteAction := default dict (index (default dict .nuon.actions.workflows) "temporal_delete_event_loops") }}
{{ $deleteOutputs := default dict (dig "outputs" dict $deleteAction) }}
{{ $deleteActionID := dig "id" "" $deleteAction }}

## Delete EventLoop Workflows

Stale EventLoop workflows can accumulate in Temporal and cause high workflow
counts across the `installs`, `actions`, `runners`, and `apps` namespaces.

**Step 1:** Run the check to see how many are running. If any are found,
**Step 2:** run the delete.

**Affected workflow types:** `EventLoop`, `ActionEventLoop`,
`ComponentEventLoop`, `SandboxEventLoop`, `StackEventLoop`

---

## Step 1: Check

<nuon-action-card name="temporal_check_event_loops"></nuon-action-card>

<div style="padding-top:1rem;"></div>

{{ if and (dig "populated" false $checkAction) (eq (dig "status" "" $checkAction) "finished") }}

<nuon-group gap="2" align="center" justify="start">
{{ with dig "checked_at" "" $checkOutputs }}<span style="font-size:0.85em;">Checked <nuon-time time="{{ . }}" format="relative"></nuon-time> by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $checkActionID }}">temporal_check_event_loops</a></span>{{ end }}
</nuon-group>

<div style="padding-top:0.5rem;"></div>

{{ if dig "any_found" false $checkOutputs }}
<nuon-banner theme="warn">Found {{ dig "total_found" 0 $checkOutputs }} EventLoop workflow(s) running — proceed to Step 2.</nuon-banner>
{{ else }}
<nuon-banner theme="success">No EventLoop workflows found. Nothing to delete.</nuon-banner>
{{ end }}

<table>
  <thead>
    <tr>
      <th>Namespace</th>
      <th>Running</th>
    </tr>
  </thead>
  <tbody>
  {{ range dig "namespaces" (list) $checkOutputs }}
    <tr>
      <td><code>{{ dig "name" "—" . }}</code></td>
      <td>{{ dig "found" 0 . }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="warn">Run <code>temporal_check_event_loops</code> above to see current
counts.</nuon-banner>

{{ end }}

<div style="padding-top:2rem;"></div>

---

## Step 2: Delete

If the check found running EventLoop workflows, run the delete below. It waits
for each batch operation to complete before submitting the next.

<nuon-action-card name="temporal_delete_event_loops"></nuon-action-card>

<div style="padding-top:1rem;"></div>

{{ if and (dig "populated" false $deleteAction) (eq (dig "status" "" $deleteAction) "finished") }}

<nuon-group gap="2" align="center" justify="start">
{{ with dig "checked_at" "" $deleteOutputs }}<span style="font-size:0.85em;">Ran <nuon-time time="{{ . }}" format="relative"></nuon-time> by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $deleteActionID }}">temporal_delete_event_loops</a></span>{{ end }}
</nuon-group>

<div style="padding-top:0.5rem;"></div>

{{ if dig "any_found" false $deleteOutputs }}
<nuon-banner theme="info">Found {{ dig "total_found" 0 $deleteOutputs }} EventLoop workflow(s) — deletes were submitted.</nuon-banner>
{{ else }}
<nuon-banner theme="success">No EventLoop workflows found at delete time.</nuon-banner>
{{ end }}

<table>
  <thead>
    <tr>
      <th>Namespace</th>
      <th>Found</th>
      <th>Delete submitted</th>
    </tr>
  </thead>
  <tbody>
  {{ range dig "namespaces" (list) $deleteOutputs }}
    <tr>
      <td><code>{{ dig "name" "—" . }}</code></td>
      <td>{{ dig "found" 0 . }}</td>
      <td>{{ if dig "deleted" false . }}yes{{ else }}—{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}

<nuon-banner theme="info">Run <code>temporal_delete_event_loops</code> above if the check found
workflows to clean up.</nuon-banner>

{{ end }}
