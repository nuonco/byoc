{{ $region := dig "region" "unknown" .nuon.install_stack.outputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $stackStatus := dig "status" "" .nuon.install_stack }}{{ if or (eq $stackStatus "active") (eq $stackStatus "healthy") (eq $stackStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $stackStatus "failed") (eq $stackStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="cloud:GCP"></nuon-label-badge><nuon-label-badge
label="project:{{ dig "project_id" "unknown" .nuon.install_stack.outputs }}"></nuon-label-badge><nuon-label-badge label="region:{{ $region }}"></nuon-label-badge><nuon-label-badge
label="network:{{ dig "network_name" "unknown" .nuon.install_stack.outputs }}"></nuon-label-badge><span style="margin-left:auto;font-size:0.85em;">(from
install state)</span></nuon-group>

<div style="padding-bottom:1rem;"></div>

**Outputs**

<table>
  <thead><tr><th>Output</th><th>Value</th></tr></thead>
  <tbody>
  {{ range $key, $value := .nuon.install_stack.outputs }}
    <tr><td>{{ $key }}</td><td>{{ $value }}</td></tr>
  {{ end }}
  </tbody>
</table>
