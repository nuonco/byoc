{{ $orgsAction := default dict (index (default dict .nuon.actions.workflows) "inspect_orgs") }}
{{ $orgsOutputs := default dict (dig "outputs" dict $orgsAction) }}
{{ $orgsActionID := dig "id" "" $orgsAction }}
{{ $orgsSteps := dig "steps" dict $orgsOutputs }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $orgsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $orgsActionID }}">inspect_orgs</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

{{ if and $orgsAction (dig "populated" false $orgsAction) (eq (dig "status" "" $orgsAction) "finished") }}

{{ $orgs := dig "orgs" (dict) $orgsSteps }} {{ if gt (len $orgs) 0 }}

  <table>
      <thead>
          <tr>
              <th>Name</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Details</th>
          </tr>
      </thead>
      <tbody>
      {{range $id, $org := $orgs}}
          {{ $orgID := dig "id" "—" $org }}
          {{ $orgName := dig "name" "—" $org }}
          <tr>
              <td>{{ $orgName }}<br><small style="opacity:0.6;"><code>{{ $orgID }}</code></small></td>
              <td>{{ with dig "created_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td>
              <td>{{ with dig "updated_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
              <td>

<nuon-panel heading="Org: {{ $orgName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Name</td><td>{{ $orgName }}</td></tr>
    <tr><td>ID</td><td><code>{{ $orgID }}</code></td></tr>
    <tr><td>Slug</td><td>{{ with dig "slug" "" $org }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "created_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="short-datetime"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "updated_at" "" $org }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

              </td>
          </tr>
      {{end}}
      </tbody>
  </table>
  {{ else }}

<div style="padding-top: 1rem;"><nuon-banner theme="info">No orgs reported.</nuon-banner></div>

{{ end }}

{{ else }}

<nuon-banner theme="warn">Waiting on inspect_orgs action. Run it to populate this runbook.</nuon-banner>

{{ end }}
