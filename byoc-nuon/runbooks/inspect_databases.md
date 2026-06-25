{{ $dbAction := default dict (index (default dict .nuon.actions.workflows) "inspect_databases") }}
{{ $dbOutputs := default dict (dig "outputs" dict $dbAction) }}
{{ $dbActionID := dig "id" "" $dbAction }}
{{ $dbSteps := dig "steps" dict $dbOutputs }}
{{ $databases := dig "databases" (dict) $dbSteps }}

{{ $chAction := default dict (index (default dict .nuon.actions.workflows) "ch_inspect") }}
{{ $chOutputs := default dict (dig "outputs" dict $chAction) }}
{{ $chActionID := dig "id" "" $chAction }}
{{ $chSteps := dig "steps" dict $chOutputs }}
{{ $clickhouse := dig "clickhouse" (dict) $chSteps }}

<div style="padding-top:1rem;"></div>

<h3 style="margin:0;">Postgres (RDS)</h3>

<nuon-group gap="2" align="center" justify="start"><nuon-label-badge label="window: last 1h (avg)"></nuon-label-badge>{{ with dig "updated_at" "" $dbOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $dbActionID }}">inspect_databases</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $dbAction (dig "populated" false $dbAction) (eq (dig "status" "" $dbAction) "finished") }}

{{ if gt (len $databases) 0 }}

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
      <th>DB load (AAS)</th>
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

<nuon-banner theme="info">Averages over the last hour from Performance Insights. Memory "used" excludes cache and buffers. A cell shows — when the metric returned no data (e.g. Performance Insights disabled).</nuon-banner>

{{ else }}

<div style="padding-top:1rem;"><nuon-banner theme="info">No database metrics reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_databases action. Run it to populate this runbook.</nuon-banner>

{{ end }}

<div style="padding-top:2rem;"></div>

<h3 style="margin:0;">ClickHouse</h3>

<nuon-group gap="2" align="center" justify="start"><nuon-label-badge label="snapshot (per pod)"></nuon-label-badge>{{ with dig "updated_at" "" $chOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $chActionID }}">ch_inspect</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $chAction (dig "populated" false $chAction) (eq (dig "status" "" $chAction) "finished") }}

{{ if gt (len $clickhouse) 0 }}

<table>
  <thead>
    <tr>
      <th>Pod</th>
      <th>CPU (of node)</th>
      <th>Memory (used / total)</th>
      <th>Disk (used / total)</th>
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

<nuon-banner theme="info">Point-in-time snapshot from the kubelet Summary API (no ClickHouse query). CPU is relative to the node; memory and disk are relative to the pod limit / data volume. IOPS and DB load are not available without querying ClickHouse.</nuon-banner>

{{ else }}

<div style="padding-top:1rem;"><nuon-banner theme="info">No ClickHouse pod metrics reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on ch_inspect action. Run it to populate this section.</nuon-banner>

{{ end }}
