{{ $migAction := default dict (index (default dict .nuon.actions.workflows) "inspect_migrations") }}
{{ $migOutputs := default dict (dig "outputs" dict $migAction) }}
{{ $migActionID := dig "id" "" $migAction }}
{{ $migSteps := dig "steps" dict $migOutputs }}
{{ $themeMap := dict "applied" "success" "in_progress" "info" "error" "error" "unknown" "neutral" }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $migOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $migActionID }}">inspect_migrations</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $migAction (dig "populated" false $migAction) (eq (dig "status" "" $migAction) "finished") }}

{{ $migrations := dig "migrations" (dict) $migSteps }}
{{ if gt (len $migrations) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Status</th>
              <th>Created At</th>
          </tr>
      </thead>
      <tbody>
      {{ range $_, $m := $migrations }}
          {{ $status := dig "status" "" $m }}
          <tr>
              <td>{{ dig "name" "—" $m }}<br><small style="opacity:0.6;"><code>{{ dig "id" "—" $m }}</code></small></td>
              <td>{{ if $status }}<nuon-label-badge theme="{{ dig (lower $status) "neutral" $themeMap }}" label="{{ $status }}"></nuon-label-badge>{{ else }}—{{ end }}</td>
              <td>{{ with dig "created_at" "" $m }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
          </tr>
      {{ end }}
      </tbody>
  </table>

{{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No migrations reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_migrations action. Run it to populate this runbook.</nuon-banner>

{{ end }}
