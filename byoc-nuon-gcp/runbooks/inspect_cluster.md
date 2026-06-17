<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ $sandboxStatus := dig "status" "" .nuon.sandbox | lower }}{{ if or (eq $sandboxStatus "active") (eq $sandboxStatus "healthy") (eq $sandboxStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $sandboxStatus "failed") (eq $sandboxStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="name:{{ dig "outputs" "cluster" "name" "unknown" .nuon.sandbox }}"></nuon-label-badge><nuon-label-badge
label="location:{{ dig "outputs" "cluster" "location" "unknown" .nuon.sandbox }}"></nuon-label-badge><span style="margin-left:auto;font-size:0.85em;">(from
install state)</span></nuon-group>

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

**Accessing the GKE Cluster**

1. Grant the relevant principal IAM access to the cluster (e.g. `roles/container.admin` on the project).
2. Install the GKE auth plugin: `gcloud components install gke-gcloud-auth-plugin`.
3. Add the cluster kubeconfig w/ the following command.

<pre>
gcloud container clusters get-credentials \
    {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --location {{ dig "outputs" "cluster" "location" "$location" .nuon.sandbox }} \
    --project {{ .nuon.install_stack.outputs.project_id }}
</pre>
