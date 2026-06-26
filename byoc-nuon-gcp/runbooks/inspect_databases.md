{{ $dbAction := default dict (index (default dict .nuon.actions.workflows) "inspect_postgres") }}
{{ $dbOutputs := default dict (dig "outputs" dict $dbAction) }}
{{ $dbActionID := dig "id" "" $dbAction }}
{{ $dbSteps := dig "steps" dict $dbOutputs }}
{{ $databases := dig "databases" (dict) $dbSteps }}

{{ $chAction := default dict (index (default dict .nuon.actions.workflows) "inspect_clickhouse") }}
{{ $chOutputs := default dict (dig "outputs" dict $chAction) }}
{{ $chActionID := dig "id" "" $chAction }}
{{ $chSteps := dig "steps" dict $chOutputs }}
{{ $clickhouse := dig "clickhouse" (dict) $chSteps }}

<div style="padding-top:1rem;"></div>

<h3 style="margin:0;">Postgres (Cloud SQL)</h3>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $dbOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $dbActionID }}">inspect_postgres</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $dbAction (dig "populated" false $dbAction) (eq (dig "status" "" $dbAction) "finished") }}

{{ if gt (len $databases) 0 }}

{{ $ca := dig "ctl-api" (dict) $databases }}{{ $cac := dig "config" (dict) $ca }}
{{ $tp := dig "temporal" (dict) $databases }}{{ $tpc := dig "config" (dict) $tp }}

<div style="display:grid;grid-template-columns:1fr 1fr;gap:1.5rem;margin-bottom:2rem;">
  <div>
    <strong>ctl-api</strong>
    <table style="margin-top:0.75rem;">
      <tbody>
        <tr><td>Instance</td><td><code>{{ dig "instance_id" "—" $cac }}</code></td></tr>
        <tr><td>Class</td><td>{{ dig "class" "—" $cac }}</td></tr>
        <tr><td>Status</td><td>{{ dig "status" "—" $cac }}</td></tr>
        <tr><td>Storage</td><td>{{ dig "storage_type" "—" $cac }}{{ $ag := dig "allocated_gb" nil $cac }}{{ if not (kindIs "invalid" $ag) }} / {{ $ag }}GB{{ end }}</td></tr>
        <tr><td>Multi-AZ</td><td>{{ $v := dig "multi_az" nil $cac }}{{ if kindIs "invalid" $v }}—{{ else if $v }}Yes{{ else }}No{{ end }}</td></tr>
        <tr><td>AZ</td><td>{{ dig "az" "—" $cac }}</td></tr>
      </tbody>
    </table>
  </div>
  <div>
    <strong>temporal</strong>
    <table style="margin-top:0.75rem;">
      <tbody>
        <tr><td>Instance</td><td><code>{{ dig "instance_id" "—" $tpc }}</code></td></tr>
        <tr><td>Class</td><td>{{ dig "class" "—" $tpc }}</td></tr>
        <tr><td>Status</td><td>{{ dig "status" "—" $tpc }}</td></tr>
        <tr><td>Storage</td><td>{{ dig "storage_type" "—" $tpc }}{{ $ag := dig "allocated_gb" nil $tpc }}{{ if not (kindIs "invalid" $ag) }} / {{ $ag }}GB{{ end }}</td></tr>
        <tr><td>Multi-AZ</td><td>{{ $v := dig "multi_az" nil $tpc }}{{ if kindIs "invalid" $v }}—{{ else if $v }}Yes{{ else }}No{{ end }}</td></tr>
        <tr><td>AZ</td><td>{{ dig "az" "—" $tpc }}</td></tr>
      </tbody>
    </table>
  </div>
</div>

<table>
  <thead>
    <tr>
      <th>Database</th>
      <th>CPU</th>
      <th>Memory (used / total)</th>
      <th>Disk (used / total)</th>
      <th>Read IOPS</th>
      <th>Write IOPS</th>
      <th>Total IOPS</th>
      <th>DB load</th>
    </tr>
  </thead>
  <tbody>
  {{ range $label, $r := $databases }}
    <tr>
      <td>{{ $label }}</td>
      <td>{{ $v := dig "cpu_pct" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}%{{ end }}</td>
      <td>{{ $u := dig "mem_used_gib" nil $r }}{{ $t := dig "mem_total_gib" nil $r }}{{ $p := dig "mem_used_pct" nil $r }}{{ if or (kindIs "invalid" $u) (kindIs "invalid" $t) }}—{{ else }}{{ $u }} / {{ $t }} Gi{{ if not (kindIs "invalid" $p) }} ({{ $p }}%){{ end }}{{ end }}</td>
      <td>{{ $u := dig "disk_used_gib" nil $r }}{{ $t := dig "disk_total_gib" nil $r }}{{ $p := dig "disk_used_pct" nil $r }}{{ if or (kindIs "invalid" $u) (kindIs "invalid" $t) }}—{{ else }}{{ $u }} / {{ $t }} Gi{{ if not (kindIs "invalid" $p) }} ({{ $p }}%){{ end }}{{ end }}</td>
      <td>{{ $v := dig "read_iops" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}{{ end }}</td>
      <td>{{ $v := dig "write_iops" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}{{ end }}</td>
      <td>{{ $v := dig "total_iops" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}{{ end }}</td>
      <td>{{ $v := dig "db_load" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

<div style="padding-top:1rem;"></div>

<nuon-banner theme="info">Averages over the last hour from Cloud Monitoring. DB load has no Cloud SQL equivalent (no average-active-sessions metric), so it shows —.</nuon-banner>

{{ else }}

<div style="padding-top:1rem;"><nuon-banner theme="info">No database metrics reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_postgres action. Run it to populate this runbook.</nuon-banner>

{{ end }}

<div style="padding-top:2rem;"></div>

<h3 style="margin:0;">ClickHouse</h3>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $chOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $chActionID }}">inspect_clickhouse</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $chAction (dig "populated" false $chAction) (eq (dig "status" "" $chAction) "finished") }}

{{ if gt (len $clickhouse) 0 }}

<table>
  <thead>
    <tr>
      <th>Pod</th>
      <th>CPU (of node)</th>
      <th>Memory</th>
      <th>Disk</th>
    </tr>
  </thead>
  <tbody>
  {{ range $label, $r := $clickhouse }}
    <tr>
      <td>{{ $label }}</td>
      <td>{{ $v := dig "cpu_pct" nil $r }}{{ if kindIs "invalid" $v }}—{{ else }}{{ $v }}%{{ end }}</td>
      <td>{{ $u := dig "mem_used_gib" nil $r }}{{ $t := dig "mem_total_gib" nil $r }}{{ $p := dig "mem_used_pct" nil $r }}{{ if or (kindIs "invalid" $u) (kindIs "invalid" $t) }}—{{ else }}{{ $u }} / {{ $t }} Gi{{ if not (kindIs "invalid" $p) }} ({{ $p }}%){{ end }}{{ end }}</td>
      <td>{{ $u := dig "disk_used_gib" nil $r }}{{ $t := dig "disk_total_gib" nil $r }}{{ $p := dig "disk_used_pct" nil $r }}{{ if or (kindIs "invalid" $u) (kindIs "invalid" $t) }}—{{ else }}{{ $u }} / {{ $t }} Gi{{ if not (kindIs "invalid" $p) }} ({{ $p }}%){{ end }}{{ end }}</td>
    </tr>
  {{ end }}
  </tbody>
</table>

<div style="padding-top:1rem;"></div>

<nuon-banner theme="info">Point-in-time snapshot from the kubelet Summary API.</nuon-banner>

{{ else }}

<div style="padding-top:1rem;"><nuon-banner theme="info">No ClickHouse pod metrics reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_clickhouse action. Run it to populate this section.</nuon-banner>

{{ end }}
