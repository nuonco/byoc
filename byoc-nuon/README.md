{{ $region := .nuon.cloud_account.aws.region }}
{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" $root_domain .nuon.sandbox) }}

<center>
  <img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
  <img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>

{{ if .nuon.inputs.inputs.datadog_api_key }}<small>[DataDog](https://us5.datadoghq.com/logs?query=env%3Abyoc%20install.id%3A{{
.nuon.install.id}})</small>{{ end }}

</center>

{{ $api := dict }}{{ with index .nuon.actions.workflows "api_status" }}{{ with .outputs }}{{ $api = . }}{{ end }}{{ end }}
{{ $dash := dict }}{{ with index .nuon.actions.workflows "dashboard_status" }}{{ with .outputs }}{{ $dash = . }}{{ end }}{{ end }}
{{ $apiSteps := dig "steps" (dict) $api }} {{ $dashSteps := dig "steps" (dict) $dash }}

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>API</strong>{{ range $step := list "alb-healthcheck-ctl-api-public" "alb-healthcheck-ctl-api-admin" "alb-healthcheck-ctl-api-runner" }}{{ $indicator := dig $step "indicator" "" $apiSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}<nuon-label-badge label="version:{{ dig "ctl_api_version" "unknown" $api }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "ctl_api_git_ref" "unknown" $api }}"></nuon-label-badge><a href="https://api.{{ $public_domain }}/docs/index.html">Open ↗</a></nuon-group></summary>

**Links**

| Service    | URL                                                                |
| ---------- | ------------------------------------------------------------------ |
| CTL API    | [api.{{ $public_domain }}](https://api.{{ $public_domain }})       |
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

| Service   | URL                                                          |
| --------- | ------------------------------------------------------------ |
| Dashboard | [app.{{ $public_domain }}](https://app.{{ $public_domain }}) |

<nuon-action-card name="dashboard_status"></nuon-action-card>

</details>

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Stack</strong>{{ $stackStatus := dig "status" "" .nuon.install_stack }}{{ if or (eq $stackStatus "active") (eq $stackStatus "healthy") (eq $stackStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $stackStatus "failed") (eq $stackStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="cloud:AWS"></nuon-label-badge><nuon-label-badge label="account:{{ dig "account_id" "000000000000" .nuon.install_stack.outputs }}"></nuon-label-badge><nuon-label-badge label="region:{{ $region }}"></nuon-label-badge><nuon-label-badge label="vpc:{{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}"></nuon-label-badge></nuon-group></summary>

**Outputs**

| Output | Value |
| ------ | ----- |
{{ range $key, $value := .nuon.install_stack.outputs }}| {{ $key }} | {{ $value }} |
{{ end }}

</details>

<details>
<summary><nuon-group gap="2" align="center" justify="start"><strong>Cluster</strong>{{ $sandboxStatus := dig "status" "" .nuon.sandbox | lower }}{{ if or (eq $sandboxStatus "active") (eq $sandboxStatus "healthy") (eq $sandboxStatus "finished") }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if or (eq $sandboxStatus "failed") (eq $sandboxStatus "error") }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge label="name:{{ dig "outputs" "cluster" "name" "unknown" .nuon.sandbox }}"></nuon-label-badge><nuon-label-badge label="version:{{ coalesce (dig "outputs" "cluster" "version" nil .nuon.sandbox) (dig "outputs" "cluster" "platform_version" nil .nuon.sandbox) "unknown" }}"></nuon-label-badge></nuon-group></summary>

**Outputs**

| Output | Value |
| ------ | ----- |
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
{{ $data := dict }}{{ with .outputs }}{{ $data = . }}{{ end }} {{ if false }}

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

| Workflow ID                                                                                                      | Workflow Type      | Started              |
| ---------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------- | --------------------------------------------------------------------------------------------- |
| {{ range $i, $_ := until $count }}{{ $chunk := index $data (printf "ns_%s_chunk_%d" $ns $i) }}{{ range $chunk }} | {{ .workflow_id }} | {{ .workflow_type }} | {{ date "Jan 2, 2006 15:04 UTC" (toDate "2006-01-02T15:04:05.999999999Z07:00" .start_time) }} |

{{ end }}{{ end }}

</nuon-tab>
{{ end }}
</nuon-tabs>

</details>
{{ end }}
{{ end }}

<details>
<summary><strong>Status</strong></summary>

{{ with (index (default dict .nuon.actions.workflows) "status_report") }}
{{ $steps := dict }}{{ with .outputs }}{{ with .steps }}{{ $steps = . }}{{ end }}{{ end }}
{{ if and .populated (eq .status "finished") }}

<nuon-tabs>
  <nuon-tab name="runners">

{{ $runners := dig "runners" (dict) $steps }} {{ $ownerNames := dict }}
{{ range $_, $i := (dig "installs" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $i) (dig "name" "" $i) }}{{ end }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ range $_, $a := (dig "apps" (dict) $steps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ if gt (len $runners) 0 }}

  <table>
      <thead>
          <tr>
              <th></th>
              <th>Owner</th>
              <th>Type</th>
              <th>Latest Heartbeat</th>
              <th>Latest Healthcheck</th>
              <th>Process Uptime</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $runner := $runners}}
          {{ $status := dig "status" "" $runner }}
          {{ $ownerID := dig "owner_id" "" $runner }}
          {{ $ownerName := dig $ownerID "" $ownerNames }}
          {{ $ownerLabel := $ownerName }}{{ if not $ownerLabel }}{{ $ownerLabel = default "—" $ownerID }}{{ end }}
          {{ $runnerID := dig "id" "—" $runner }}
          {{ $processes := default (list) (dig "process_uptimes" nil $runner) }}
          {{ $ownerProc := dict }}{{ range $p := $processes }}{{ $t := dig "type" "" $p }}{{ if or (eq $t "install") (eq $t "build") }}{{ $ownerProc = $p }}{{ end }}{{ end }}
          <tr>
              <td><nuon-status status="{{ $status }}"></nuon-status></td>
              <td style="white-space:nowrap;">{{ $ownerLabel }}</td>
              <td>{{ dig "type" "—" $runner }}</td>
              <td>{{ with dig "latest_heart_beat_created_at" "" $runner }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
              <td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
              <td style="white-space:nowrap;">{{ with dig "uptime" 0 $ownerProc }}{{ (div (int64 .) 1000000000) | int64 | duration }}{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Runner: {{ $ownerLabel }}" trigger="View" size="3/4">

{{ $heartbeatAt := "—" }}{{ with dig "latest_heart_beat_created_at" "" $runner }}{{ $heartbeatAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}
{{ $healthcheckAt := "—" }}{{ with dig "latest_health_check_created_at" "" $runner }}{{ $healthcheckAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}

| Field                     | Value                                                                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Status                    | <nuon-status status="{{ $status }}" variant="badge"></nuon-status>                                                                              |
| Owner                     | {{ $ownerLabel }}                                                                                                                               |
| Owner ID                  | `{{ $ownerID }}`                                                                                                                                |
| Type                      | {{ dig "type" "—" $runner }}                                                                                                                    |
| Platform                  | {{ dig "platform" "—" $runner }}                                                                                                                |
| Image                     | `{{ dig "image" "—" $runner }}:{{ dig "tag" "—" $runner }}`                                                                                     |
| Runner ID                 | `{{ $runnerID }}`                                                                                                                               |
| Latest Heartbeat          | {{ $heartbeatAt }}                                                                                                                              |
| Latest Heartbeat Version  | {{ with dig "latest_heart_beat_version" "" $runner }}<nuon-badge theme="info" size="sm" variant="code">{{ . }}</nuon-badge>{{ else }}—{{ end }} |
| Latest Healthcheck        | {{ $healthcheckAt }}                                                                                                                            |
| Latest Healthcheck Status | {{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}          |

{{ if gt (len $processes) 0 }}

**Processes**

<table>
  <thead>
    <tr>
      <th>Type</th>
      <th>Status</th>
      <th>Started At</th>
      <th>Uptime</th>
      <th>ID</th>
    </tr>
  </thead>
  <tbody>
  {{ range $p := $processes }}
    <tr>
      <td>{{ dig "type" "—" $p }}</td>
      <td>{{ with dig "status" "" $p }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ with dig "started_at" "" $p }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
      <td>{{ with dig "uptime" 0 $p }}{{ (div (int64 .) 1000000000) | int64 | duration }}{{ else }}—{{ end }}</td>
      <td><code>{{ dig "id" "—" $p }}</code></td>
    </tr>
  {{ end }}
  </tbody>
</table>

{{ end }}

</nuon-panel>

              </td>
          </tr>
      {{end}}
      </tbody>

  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No runners reported.</nuon-banner></div>

{{ end }}

  </nuon-tab>
  <nuon-tab name="orgs">

{{ $orgs := dig "orgs" (dict) $steps }} {{ if gt (len $orgs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>ID</th>
              <th>Created At</th>
              <th>Updated At</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $org := $orgs}}
          <tr>
              <td>{{ dig "name" "—" $org }}</td>
              <td><code>{{ dig "id" "—" $org }}</code></td>
              <td>{{ with dig "created_at" "" $org }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $org }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No orgs reported.</nuon-banner></div>

{{ end }}

  </nuon-tab>
  <nuon-tab name="apps">

{{ $apps := dig "apps" (dict) $steps }} {{ $orgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $orgsByID = set $orgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ if gt (len $apps) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Org</th>
              <th>ID</th>
              <th>Created At</th>
              <th>Updated At</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $app := $apps}}
          {{ $orgID := dig "org_id" "" $app }}
          {{ $orgName := dig $orgID "" $orgsByID }}
          <tr>
              <td>{{ dig "name" "—" $app }}</td>
              <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else }}<code>{{ default "—" $orgID }}</code>{{ end }}</td>
              <td><code>{{ dig "id" "—" $app }}</code></td>
              <td>{{ with dig "created_at" "" $app }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $app }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No apps reported.</nuon-banner></div>

{{ end }}

  </nuon-tab>
  <nuon-tab name="installs">

{{ $installs := dig "installs" (dict) $steps }} {{ $appsByID := dict }}
{{ range $_, $a := (dig "apps" (dict) $steps) }}{{ $appsByID = set $appsByID (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ $installOrgsByID := dict }}
{{ range $_, $o := (dig "orgs" (dict) $steps) }}{{ $installOrgsByID = set $installOrgsByID (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ if gt (len $installs) 0 }}

  <table>
      <thead>
          <tr>
              <th></th>
              <th>Name</th>
              <th>App</th>
              <th>Org</th>
              <th>ID</th>
              <th>Created At</th>
              <th>Updated At</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $install := $installs}}
          {{ $status := dig "status" "" $install }}
          {{ $appID := dig "app_id" "" $install }}
          {{ $appName := dig $appID "" $appsByID }}
          {{ $orgID := dig "org_id" "" $install }}
          {{ $orgName := dig $orgID "" $installOrgsByID }}
          <tr>
              <td><nuon-status status="{{ $status }}"></nuon-status></td>
              <td>{{ dig "name" "—" $install }}</td>
              <td style="white-space:nowrap;">{{ if $appName }}{{ $appName }}{{ else }}<code>{{ default "—" $appID }}</code>{{ end }}</td>
              <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else }}<code>{{ default "—" $orgID }}</code>{{ end }}</td>
              <td><code>{{ dig "id" "—" $install }}</code></td>
              <td>{{ with dig "created_at" "" $install }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $install }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No installs reported.</nuon-banner></div>

{{ end }}

  </nuon-tab>
</nuon-tabs>

{{ else }}

<nuon-banner theme="warn">Waiting on status_report action. Run the "status_report" action to populate this
section.</nuon-banner>

{{ end }} {{ end }}

</details>

<details>
<summary><strong>Workflows</strong></summary>

{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_workflows_by_type") }}
{{ $wfData := dict }}{{ with .outputs }}{{ $wfData = . }}{{ end }} {{ $wfRows := dig "workflows" (list) $wfData }}
{{ if and .populated (eq .status "finished") (gt (len $wfRows) 0) }}

<div style="padding-top: 1rem;"><nuon-group gap="8" align="center" justify="start">
<nuon-label-badge label="count:{{ len $wfRows }}"></nuon-label-badge>
</nuon-group></div>

<table>
  <thead>
    <tr>
      <th>Status</th>
      <th>Name</th>
      <th>Type</th>
      <th>Created By</th>
      <th>Org</th>
      <th>Owner</th>
      <th>Created At</th>
      <th>Finished At</th>
      <th>Details</th>
    </tr>
  </thead>
  <tbody>
  {{ range $wfRows }}
    {{ $status := dig "workflow_status" "" . }}
    {{ $email := dig "created_by_email" "" . }}
    {{ $createdByID := dig "created_by_id" "" . }}
    {{ $createdByLabel := $email }}{{ if not $createdByLabel }}{{ $createdByLabel = default "—" $createdByID }}{{ end }}
    {{ $ownerID := dig "owner_id" "" . }}
    {{ $ownerType := dig "owner_type" "" . }}
    {{ $ownerName := dig "owner_name" "" . }}
    <tr>
      <td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
      <td>{{ dig "workflow_name" "—" . }}</td>
      <td>{{ dig "workflow_type" "—" . }}</td>
      <td style="white-space:nowrap;">{{ $createdByLabel }}</td>
      {{ $orgName := dig "org_name" "" . }}{{ $orgID := dig "org_id" "" . }}
      <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ else if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td>
      <td style="white-space:nowrap;">{{ if $ownerName }}{{ $ownerName }}{{ else if $ownerID }}<code>{{ $ownerID }}</code>{{ else }}—{{ end }}</td>
      <td>{{ with dig "workflow_created_at" "" . }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
      <td>{{ with dig "workflow_finished_at" "" . }}{{ (printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC" }}{{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Workflow: {{ dig "workflow_name" (dig "workflow_id" "—" .) . }}" trigger="View" size="3/4">

{{ $wfCreatedAt := "—" }}{{ with dig "workflow_created_at" "" . }}{{ $wfCreatedAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}
{{ $wfUpdatedAt := "—" }}{{ with dig "workflow_updated_at" "" . }}{{ $wfUpdatedAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}
{{ $wfStartedAt := "—" }}{{ with dig "workflow_started_at" "" . }}{{ $wfStartedAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}
{{ $wfFinishedAt := "—" }}{{ with dig "workflow_finished_at" "" . }}{{ $wfFinishedAt = ((printf "%sZ" (substr 0 19 .)) | toDate "2006-01-02T15:04:05Z" | date "Jan 2 15:04 UTC") }}{{ end }}

| Field                   | Value                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| Status                  | {{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }} |
| Name                    | {{ dig "workflow_name" "—" . }}                                                                        |
| Type                    | {{ dig "workflow_type" "—" . }}                                                                        |
| Workflow ID             | `{{ dig "workflow_id" "—" . }}`                                                                        |
| Created By              | {{ if $email }}{{ $email }}{{ else }}—{{ end }}                                                        |
| Created By ID           | {{ if $createdByID }}`{{ $createdByID }}`{{ else }}—{{ end }}                                          |
| Created By Subject      | {{ default "—" (dig "created_by_subject" "" .) }}                                                      |
| Created By Account Type | {{ default "—" (dig "created_by_account_type" "" .) }}                                                 |
| Org                     | {{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}                                                    |
| Org ID                  | {{ if $orgID }}`{{ $orgID }}`{{ else }}—{{ end }}                                                      |
| Owner                   | {{ if $ownerName }}{{ $ownerName }}{{ else }}—{{ end }}                                                |
| Owner ID                | {{ if $ownerID }}`{{ $ownerID }}`{{ else }}—{{ end }}                                                  |
| Owner Type              | {{ default "—" $ownerType }}                                                                           |
| Created At              | {{ $wfCreatedAt }}                                                                                     |
| Updated At              | {{ $wfUpdatedAt }}                                                                                     |
| Started At              | {{ $wfStartedAt }}                                                                                     |
| Finished At             | {{ $wfFinishedAt }}                                                                                    |

</nuon-panel>

      </td>
    </tr>

{{ end }}

  </tbody>
</table>

{{ else if and .populated (eq .status "finished") }}

<nuon-banner theme="info">No workflows returned by the last run of ctl_api_query_workflows_by_type.</nuon-banner>

{{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type action. Run it to populate this
section.</nuon-banner>

{{ end }} {{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_workflows_by_type action. Run it to populate this
section.</nuon-banner>

{{ end }}

</details>
