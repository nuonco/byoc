<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $sandboxStatus := dig "status" "" .nuon.sandbox | lower }}{{ if or (eq $sandboxStatus "active") (eq $sandboxStatus "healthy") (eq $sandboxStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $sandboxStatus "failed") (eq $sandboxStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="name:{{ dig "outputs" "cluster" "name" "unknown" .nuon.sandbox }}"></nuon-label-badge><nuon-label-badge label="version:{{ coalesce (dig "outputs" "cluster" "version" nil .nuon.sandbox) (dig "outputs" "cluster" "platform_version" nil .nuon.sandbox) "unknown" }}"></nuon-label-badge><span style="margin-left:auto;font-size:0.85em;">(from install state)</span></nuon-group>

<div style="padding-bottom:1rem;"></div>

**Outputs**

<table>
  <thead><tr><th>Output</th><th>Value</th></tr></thead>
  <tbody>
  {{ range $key, $value := dig "outputs" "cluster" (dict) .nuon.sandbox }}
    <tr><td>{{ $key }}</td><td>{{ $value }}</td></tr>
  {{ end }}
  </tbody>
</table>

**Accessing the EKS Cluster**

1. Add an access entry for the relevant role.
2. Grant the following perms: AWSEKSAdmin, AWSClusterAdmin.gtg
3. Add the cluster kubeconfig w/ the following command.

<pre>
aws --region {{ .nuon.install_stack.outputs.region }} \
    --profile your.Profile eks update-kubeconfig      \
    --name {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --alias {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }}
</pre>
