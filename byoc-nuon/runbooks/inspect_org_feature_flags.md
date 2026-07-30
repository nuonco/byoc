# Organization feature flags

This report reads feature state from the ctl-api ADMIN API for every non-deleted organization.

{{ $action := default dict (index (default dict .nuon.actions.workflows) "inspect_org_feature_flags") }}
{{ $output := default dict (dig "outputs" dict $action) }}
{{ $orgs := dig "steps" "orgs" (dict) $output }}
{{ $actionID := dig "id" "" $action }}

{{ if and $action (dig "populated" false $action) (eq (dig "status" "" $action) "finished") }}

<nuon-group gap="2" align="center" justify="start"><nuon-label-badge theme="info" label="{{ dig "total_orgs" 0 $output }} orgs"></nuon-label-badge>{{ with dig "updated_at" "" $output }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $actionID }}">inspect_org_feature_flags</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

## Feature summary

<table>
  <thead><tr><th>Feature</th><th>Description</th><th>Enabled</th><th>Disabled</th></tr></thead>
  <tbody>
  {{ range dig "features" (list) $output }}
    <tr><td><code>{{ dig "name" "—" . }}</code></td><td>{{ dig "description" "—" . }}</td><td>{{ dig "enabled" 0 . }}</td><td>{{ dig "disabled" 0 . }}</td></tr>
  {{ end }}
  </tbody>
</table>

## Organization details

<table>
  <thead><tr><th>Organization</th><th>ID</th><th>Features</th></tr></thead>
  <tbody>
  {{ range $id, $org := $orgs }}
    <tr>
      <td>{{ dig "name" "—" $org }}</td>
      <td><code>{{ dig "id" "—" $org }}</code></td>
      <td><nuon-panel heading="Features: {{ dig "name" "—" $org }}" trigger="View full map" size="1/2">
        <table><thead><tr><th>Feature</th><th>Enabled</th></tr></thead><tbody>
        {{ range $key, $enabled := dig "features" (dict) $org }}<tr><td><code>{{ $key }}</code></td><td>{{ $enabled }}</td></tr>{{ end }}
        </tbody></table>
      </nuon-panel></td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ else }}
<nuon-banner theme="warn">Run <code>inspect_org_feature_flags</code> to populate this report.</nuon-banner>
{{ end }}
