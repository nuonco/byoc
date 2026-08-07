# Enable an organization feature flag globally

<nuon-banner theme="warn"><strong>Warning:</strong> This enables the selected feature for every non-deleted organization. Type the feature key again in the confirmation field. The flags are bidirectionally coupled: enabling <code>control-plane-builds</code> disables <code>org-runner</code>, and enabling <code>org-runner</code> disables <code>control-plane-builds</code>.</nuon-banner>

The action validates the key against the live ctl-api feature catalog, records before/after counts, applies one bulk ADMIN API PATCH when needed, and verifies every organization afterward.

{{ $action := default dict (index (default dict .nuon.actions.workflows) "enable_org_feature_flag") }}
{{ $output := default dict (dig "outputs" dict $action) }}
{{ if and $action (dig "populated" false $action) (eq (dig "status" "" $action) "finished") }}

## Result

<table><tbody>
  <tr><td>Feature</td><td><code>{{ dig "feature" "—" $output }}</code></td></tr>
  <tr><td>Description</td><td>{{ dig "description" "—" $output }}</td></tr>
  <tr><td>Status</td><td><nuon-label-badge theme="{{ if eq (dig "status" "" $output) "noop" }}info{{ else }}success{{ end }}" label="{{ dig "status" "—" $output }}"></nuon-label-badge></td></tr>
  <tr><td>Changed organizations</td><td>{{ dig "changed" 0 $output }}</td></tr>
  <tr><td>Mutual-exclusion invariant count</td><td>{{ dig "invariant_count" 0 $output }}</td></tr>
</tbody></table>

<table>
  <thead><tr><th>State</th><th>Total orgs</th><th>Enabled</th><th>Disabled</th></tr></thead>
  <tbody>
    {{ $before := dig "before" (dict) $output }}{{ $after := dig "after" (dict) $output }}
    <tr><td>Before</td><td>{{ dig "total_orgs" 0 $before }}</td><td>{{ dig "enabled" 0 $before }}</td><td>{{ dig "disabled" 0 $before }}</td></tr>
    <tr><td>After</td><td>{{ dig "total_orgs" 0 $after }}</td><td>{{ dig "enabled" 0 $after }}</td><td>{{ dig "disabled" 0 $after }}</td></tr>
  </tbody>
</table>

{{ $coupled := dig "coupled_flags" (dict) $output }}{{ $coupledBefore := dig "before" (dict) $coupled }}{{ $coupledAfter := dig "after" (dict) $coupled }}
<h3>Coupled flag side effects</h3>
<table><thead><tr><th>Feature</th><th>Before enabled</th><th>After enabled</th></tr></thead><tbody>
  <tr><td><code>control-plane-builds</code></td><td>{{ dig "control-plane-builds" 0 $coupledBefore }}</td><td>{{ dig "control-plane-builds" 0 $coupledAfter }}</td></tr>
  <tr><td><code>org-runner</code></td><td>{{ dig "org-runner" 0 $coupledBefore }}</td><td>{{ dig "org-runner" 0 $coupledAfter }}</td></tr>
</tbody></table>

{{ else }}
<nuon-banner theme="info">Provide the feature key and type the feature key again to run this SOP.</nuon-banner>
{{ end }}
