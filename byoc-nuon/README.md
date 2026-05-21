{{ $region := .nuon.cloud_account.aws.region }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}

<center>
  <img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
  <img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>

{{ if .nuon.inputs.inputs.datadog_api_key }}<small>[DataDog](https://us5.datadoghq.com/logs?query=env%3Abyoc%20install.id%3A{{
.nuon.install.id}})</small>{{ end }}

</center>

{{ $api := dict }}{{ with index .nuon.actions.workflows "api_status" }}{{ with .outputs }}{{ $api = . }}{{ end }}{{ end }}
{{ $dash := dict }}{{ with index .nuon.actions.workflows "dashboard_status" }}{{ with .outputs }}{{ $dash = . }}{{ end }}{{ end }}
{{ $apiSteps := dig "steps" (dict) $api }}
{{ $dashSteps := dig "steps" (dict) $dash }}

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>API</strong>{{ range $step := list "alb-healthcheck-ctl-api-public" "alb-healthcheck-ctl-api-admin" "alb-healthcheck-ctl-api-runner" }}{{ $indicator := dig $step "indicator" "" $apiSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}<nuon-label-badge label="version:{{ dig "ctl_api_version" "unknown" $api }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "ctl_api_git_ref" "unknown" $api }}"></nuon-label-badge><a href="https://api.{{ $public_domain }}/docs/index.html">Open ↗</a></nuon-group></summary>

**Links**

| Service | URL |
|---|---|
| CTL API | [api.{{ $public_domain }}](https://api.{{ $public_domain }}) |
| Runner API | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }}) |

**CLI**

Install the latest version of the nuon cli ([docs](https://docs.nuon.co/cli#cli)).

```bash
brew install nuonco/tap/nuon
```

Update your `~/.nuon` config or create one specifically for this byoc install (e.g. `~/.nuon.byoc`).

Configure as follows:

```yaml
api_url: https://api.{{ $public_domain }}
```

Log in:

```yaml
nuon -f ~/.nuon.byoc login
```

<nuon-action-card name="api_status"></nuon-action-card>

</details>

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Dashboard</strong>{{ $indicator := dig "alb-healthcheck-dashboard-ui" "indicator" "" $dashSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="version:{{ dig "dashboard_ui_version" "unknown" $dash }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "dashboard_ui_git_ref" "unknown" $dash }}"></nuon-label-badge><a href="https://app.{{ $public_domain }}">Open ↗</a></nuon-group></summary>

**Links**

| Service | URL |
|---|---|
| Dashboard | [app.{{ $public_domain }}](https://app.{{ $public_domain }}) |

<nuon-action-card name="dashboard_status"></nuon-action-card>

</details>

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Stack</strong>{{ $stackStatus := dig "status" "" .nuon.install_stack }}{{ if or (eq $stackStatus "active") (eq $stackStatus "healthy") (eq $stackStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $stackStatus "failed") (eq $stackStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="cloud:AWS"></nuon-label-badge><nuon-label-badge label="account:{{ dig "account_id" "000000000000" .nuon.install_stack.outputs }}"></nuon-label-badge><nuon-label-badge label="region:{{ $region }}"></nuon-label-badge><nuon-label-badge label="vpc:{{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}"></nuon-label-badge></nuon-group></summary>

**Outputs**

| Output | Value |
|---|---|
{{ range $key, $value := .nuon.install_stack.outputs }}| {{ $key }} | {{ $value }} |
{{ end }}

</details>

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Cluster</strong>{{ $sandboxStatus := dig "status" "" .nuon.sandbox | lower }}{{ if or (eq $sandboxStatus "active") (eq $sandboxStatus "healthy") (eq $sandboxStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $sandboxStatus "failed") (eq $sandboxStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="name:{{ dig "outputs" "cluster" "name" "unknown" .nuon.sandbox }}"></nuon-label-badge><nuon-label-badge label="version:{{ coalesce (dig "outputs" "cluster" "version" nil .nuon.sandbox) (dig "outputs" "cluster" "platform_version" nil .nuon.sandbox) "unknown" }}"></nuon-label-badge></nuon-group></summary>

**Outputs**

| Output | Value |
|---|---|
{{ range $key, $value := dig "outputs" "cluster" (dict) .nuon.sandbox }}| {{ $key }} | {{ $value }} |
{{ end }}

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

</details>

{{ with index .nuon.actions.workflows "temporal_status" }}
{{ $data := dict }}{{ with .outputs }}{{ $data = . }}{{ end }}
{{ if false }}
<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Temporal Status</strong>{{ with index $.nuon.actions.workflows "healthcheck_temporal" }}{{ if eq .status "error" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else if eq .status "finished" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}</nuon-group></summary>

**Active workflows**

<nuon-tabs>
{{ range (dig "namespace_names" (list) $data) }}
{{ $ns := . }}
{{ $count := index $data (printf "ns_%s_count" $ns) | default 0 | int }}
{{ $total := 0 }}
{{ range $i, $_ := until $count }}{{ $chunk := index $data (printf "ns_%s_chunk_%d" $ns $i) }}{{ range $chunk }}{{ $total = add $total 1 }}{{ end }}{{ end }}
<nuon-tab name="{{ $ns }}">

<div style="padding-top: 1rem;"><nuon-group gap="8" align="center" justify="start">
<nuon-label-badge label="total:{{ $total }}"></nuon-label-badge>
</nuon-group></div>

| Workflow ID | Workflow Type | Started |
|---|---|---|
{{ range $i, $_ := until $count }}{{ $chunk := index $data (printf "ns_%s_chunk_%d" $ns $i) }}{{ range $chunk }}| {{ .workflow_id }} | {{ .workflow_type }} | {{ date "Jan 2, 2006 15:04 UTC" (toDate "2006-01-02T15:04:05.999999999Z07:00" .start_time) }} |
{{ end }}{{ end }}

</nuon-tab>
{{ end }}
</nuon-tabs>

</details>
{{ end }}
{{ end }}





<details>
<summary><strong>Runners</strong></summary>

{{ with .nuon.actions.workflows.runners }}
{{ if and .populated (eq .status "finished") }}
{{ $runnerSettings := .outputs.steps.settings }}

<nuon-tabs>                                                                                                                                
  <nuon-tab name="install runners">
                                                                                                                                             
  {{ with .outputs.steps.install }}                                            
  <table>                                                                                                                                    
      <thead>                                                                  
          <tr>
              <th></th>
              <th>ID</th>                                                                                                                    
              <th>Org ID</th>
              <th>Tag</th>                                                                                                                   
              <th>Created At</th>                                              
              <th>Updated At</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $runner := .}}                                                                                                            
          {{ $settings := dig $id "settings" nil $runnerSettings }}
          <tr>                                                                                                                               
              {{ $status := dig "status_v2" "status" "" $runner }}
              <td>{{if eq $status "active"}}🟢{{else if eq $status "error"}}🔴{{else}}🟡{{end}}</td>
              <td><code>{{$runner.id}}</code></td>                                                                                           
              <td><code>{{$runner.org_id}}</code></td>
              <td><code>{{if $settings}}{{dig "container_image_tag" "" $settings}}{{end}}</code></td>                                        
              <td>{{(printf "%sZ" (substr 0 19 $runner.created_at)) | toDate "2006-01-02T15:04:05Z" | date "2006-01-02 15:04"}}</td>         
              <td>{{(printf "%sZ" (substr 0 19 $runner.updated_at)) | toDate "2006-01-02T15:04:05Z" | date "2006-01-02 15:04"}}</td>         
          </tr>                                                                                                                              
      {{end}}                                                                                                                                
      </tbody>                                                                                                                               
  </table>                                                                     
  {{ end }}

  </nuon-tab>
  <nuon-tab name="org runners">
                                                                                                                                             
  {{ with .outputs.steps.org }}
  <table>                                                                                                                                    
      <thead>                                                                  
          <tr>
              <th></th>
              <th>ID</th>
              <th>Org ID</th>
              <th>Tag</th>
              <th>Created At</th>
              <th>Updated At</th>                                                                                                            
          </tr>
      </thead>                                                                                                                               
      <tbody>                                                                  
      {{range $id, $runner := .}}
          {{ $settings := dig $id "settings" nil $runnerSettings }}
          <tr>                                                                                                                               
              {{ $status := dig "status_v2" "status" "" $runner }}
              <td>{{if eq $status "active"}}🟢{{else if eq $status "error"}}🔴{{else}}🟡{{end}}</td>
              <td><code>{{$runner.id}}</code></td>                                                                                           
              <td><code>{{$runner.org_id}}</code></td>                                                                                       
              <td><code>{{if $settings}}{{dig "container_image_tag" "" $settings}}{{end}}</code></td>
              <td>{{(printf "%sZ" (substr 0 19 $runner.created_at)) | toDate "2006-01-02T15:04:05Z" | date "2006-01-02 15:04"}}</td>         
              <td>{{(printf "%sZ" (substr 0 19 $runner.updated_at)) | toDate "2006-01-02T15:04:05Z" | date "2006-01-02 15:04"}}</td>         
          </tr>                                                                                                                              
      {{end}}                                                                                                                                
      </tbody>                                                                                                                               
  </table>                                                                                                                                   
  {{ end }}
                                                                                                                                             
  </nuon-tab>                                                                  
  <nuon-tab name="more info">

  {{ with .outputs.steps.settings }}
  {{range $id, $runner := .}}
  <details>
  <summary><code>{{$id}}</code> — {{$runner.type}} ({{dig "metadata" "org.name" "unknown" $runner.settings}})</summary>
                                                                                                                                             
  <ul>
  <li><strong>Type:</strong> {{$runner.type}}</li>                                                                                           
  <li><strong>Org ID:</strong> <code>{{$runner.org_id}}</code></li>                                                                          
  <li><strong>Platform:</strong> {{dig "metadata" "runner.platform" "unknown" $runner.settings}}</li>
  <li><strong>Image:</strong> <code>{{dig "container_image_url" "" $runner.settings}}:{{dig "container_image_tag" ""                         
  $runner.settings}}</code></li>                                                                                                             
  <li><strong>Instance Type:</strong> {{dig "aws_instance_type" "" $runner.settings}}</li>
  <li><strong>Max Instance Lifetime:</strong> {{dig "aws_max_instance_lifetime" "" $runner.settings}}</li>                                   
  <li><strong>Logging:</strong> {{dig "enable_logging" "" $runner.settings}} ({{dig "logging_level" "" $runner.settings}})</li>
  <li><strong>Sentry:</strong> {{dig "enable_sentry" "" $runner.settings}}</li>                                                              
  <li><strong>Metrics:</strong> {{dig "enable_metrics" "" $runner.settings}}</li>
  <li><strong>Heartbeat Timeout:</strong> {{dig "heart_beat_timeout" "" $runner.settings}}</li>                                              
  <li><strong>Runner API URL:</strong> {{dig "runner_api_url" "" $runner.settings}}</li>                                                     
  <li><strong>Runner Group ID:</strong> <code>{{dig "runner_group_id" "" $runner.settings}}</code></li>
  <li><strong>Created:</strong> {{dig "created_at" "" $runner.settings}}</li>                                                                
  <li><strong>Updated:</strong> {{dig "updated_at" "" $runner.settings}}</li>  
  </ul>                                                                                                                                      
                                                                               
  </details>                                                                                                                                 
  {{end}}
  {{ end }}                                                                                                                                  
                                                                               
  </nuon-tab>
  </nuon-tabs>


{{ else }}

> [!WARNING] Waiting on runners action. Run the "runners" action to populate this section.

{{ end }}
{{ end }}

</details>


