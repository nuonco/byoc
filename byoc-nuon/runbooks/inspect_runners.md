{{ $runnersAction := default dict (index (default dict .nuon.actions.workflows) "inspect_runners") }}
{{ $installsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_installs") }}
{{ $orgsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $appsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_apps") }}
{{ $runnersOutputs := default dict (dig "outputs" dict $runnersAction) }}
{{ $runnersActionID := dig "id" "" $runnersAction }}
{{ $runnersSteps := dig "steps" dict $runnersOutputs }}
{{ $installsSteps := dig "steps" dict (default dict (dig "outputs" dict $installsAction)) }}
{{ $orgsSteps := dig "steps" dict (default dict (dig "outputs" dict $orgsAction)) }}
{{ $appsSteps := dig "steps" dict (default dict (dig "outputs" dict $appsAction)) }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $runnersOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $runnersActionID }}">inspect_runners</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $runnersAction (dig "populated" false $runnersAction) (eq (dig "status" "" $runnersAction) "finished") }}

{{ $runners := dig "runners" (dict) $runnersSteps }} {{ $ownerNames := dict }}
{{ range $_, $i := (dig "installs" (dict) $installsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $i) (dig "name" "" $i) }}{{ end }}
{{ range $_, $o := (dig "orgs" (dict) $orgsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $o) (dig "name" "" $o) }}{{ end }}
{{ range $_, $a := (dig "apps" (dict) $appsSteps) }}{{ $ownerNames = set $ownerNames (dig "id" "" $a) (dig "name" "" $a) }}{{ end }}
{{ if gt (len $runners) 0 }}

  <table>
      <thead>
          <tr>
              <th>ID</th>
              <th>Status</th>
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
              <td><code>{{ $runnerID }}</code></td>
              <td><nuon-status status="{{ $status }}"></nuon-status></td>
              <td style="white-space:nowrap;">{{ $ownerLabel }}</td>
              <td>{{ dig "type" "—" $runner }}</td>
              <td>{{ with dig "latest_heart_beat_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td>
              <td style="white-space:nowrap;">{{ with dig "uptime" 0 $ownerProc }}{{ (div (int64 .) 1000000000) | int64 | duration }}{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Runner: {{ $ownerLabel }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td><nuon-status status="{{ $status }}" variant="badge"></nuon-status></td></tr>
    <tr><td>Owner</td><td>{{ $ownerLabel }}</td></tr>
    <tr><td>Owner ID</td><td><code>{{ $ownerID }}</code></td></tr>
    <tr><td>Type</td><td>{{ dig "type" "—" $runner }}</td></tr>
    <tr><td>Platform</td><td>{{ dig "platform" "—" $runner }}</td></tr>
    <tr><td>Image</td><td><code>{{ dig "image" "—" $runner }}:{{ dig "tag" "—" $runner }}</code></td></tr>
    <tr><td>Runner ID</td><td><code>{{ $runnerID }}</code></td></tr>
    <tr><td>Latest Heartbeat</td><td>{{ with dig "latest_heart_beat_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Heartbeat Version</td><td>{{ with dig "latest_heart_beat_version" "" $runner }}<nuon-badge theme="info" size="sm" variant="code">{{ . }}</nuon-badge>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Healthcheck</td><td>{{ with dig "latest_health_check_created_at" "" $runner }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Latest Healthcheck Status</td><td>{{ with dig "latest_health_check_status" "" $runner }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

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
      <td>{{ with dig "started_at" "" $p }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
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

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_runners action. Run it to populate this runbook.</nuon-banner>

{{ end }}
