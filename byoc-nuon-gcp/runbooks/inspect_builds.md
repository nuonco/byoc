<nuon-tabs>
  <nuon-tab name="Recent Builds">

<div style="padding-top:1rem;"></div>

{{ $buildsOutputs := dict }}{{ $buildsActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_builds") }}{{ with .outputs }}{{ $buildsOutputs = . }}{{ end }}{{ $buildsActionID = dig "id" "" . }}{{ end }}

<nuon-group gap="2" align="center" justify="start">{{ with dig "updated_at" "" $buildsOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last
updated by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $buildsActionID }}">ctl_api_query_builds</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_builds") }}
{{ $buildsData := dict }}{{ with .outputs }}{{ $buildsData = . }}{{ end }}
{{ $buildRows := dig "builds" (list) $buildsData }}
{{ if and .populated (eq .status "finished") (gt (len $buildRows) 0) }}

<table>
  <thead>
    <tr>
      <th>Build ID</th>
      <th>Status</th>
      <th>Created By</th>
      <th>Component</th>
      <th>Org</th>
      <th>Created At</th>
      <th>Updated At</th>
      <th>Details</th>
    </tr>
  </thead>
  <tbody>
  {{ range $buildRows }}
    {{ $status := dig "build_status" "" . }}
    {{ $email := dig "created_by_email" "" . }}
    {{ $createdByID := dig "created_by_id" "" . }}
    {{ $createdByLabel := $email }}{{ if not $createdByLabel }}{{ $createdByLabel = default "—" $createdByID }}{{ end }}
    {{ $buildID := dig "build_id" "" . }}
    {{ $componentName := dig "component_name" "" . }}{{ $componentID := dig "component_id" "" . }}
    {{ $srcRef := dig "source_ref" "" . }}{{ $gitRef := dig "git_ref" "" . }}{{ $resolvedTag := dig "resolved_tag" "" . }}
    {{ $orgName := dig "org_name" "" . }}{{ $orgID := dig "org_id" "" . }}
    <tr>
      <td style="white-space:nowrap;">{{ if $buildID }}<code>{{ $buildID }}</code>{{ else }}—{{ end }}</td>
      <td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}{{ if dig "build_no_op" false . }}<br><small style="opacity:0.6;">no-op</small>{{ end }}</td>
      <td style="white-space:nowrap;">{{ $createdByLabel }}</td>
      <td style="white-space:nowrap;">{{ if $componentName }}{{ $componentName }}{{ else }}—{{ end }}{{ with $componentID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}</td>
      <td style="white-space:nowrap;">{{ if $orgName }}{{ $orgName }}{{ with $orgID }}<br><small style="opacity:0.6;"><code>{{ . }}</code></small>{{ end }}{{ else if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td>
      <td>{{ with dig "build_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>{{ with dig "build_updated_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td>
      <td>

<nuon-panel heading="Build: {{ default $buildID $componentName }}" trigger="View" size="3/4">

<table>
  <thead><tr><th>Field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Status</td><td>{{ if $status }}<nuon-status status="{{ $status }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</td></tr>
    <tr><td>Status description</td><td>{{ default "—" (dig "build_status_description" "" .) }}</td></tr>
    <tr><td>Build ID</td><td><code>{{ default "—" $buildID }}</code></td></tr>
    <tr><td>No-op</td><td>{{ dig "build_no_op" false . }}</td></tr>
    <tr><td>Component</td><td>{{ default "—" $componentName }}</td></tr>
    <tr><td>Component ID</td><td>{{ if $componentID }}<code>{{ $componentID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td colspan="2"><strong>Source</strong></td></tr>
    <tr><td>Git ref</td><td>{{ if $gitRef }}<code>{{ $gitRef }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Source ref</td><td>{{ if $srcRef }}<code>{{ $srcRef }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Source image</td><td>{{ with dig "source_image" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Resolved tag</td><td>{{ with $resolvedTag }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Source digest</td><td>{{ with dig "source_digest" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Source media type</td><td>{{ default "—" (dig "source_media_type" "" .) }}</td></tr>
    <tr><td>Resolved at</td><td>{{ with dig "build_resolved_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Checksum</td><td>{{ with dig "checksum" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td colspan="2"><strong>Ownership</strong></td></tr>
    <tr><td>Created By</td><td>{{ if $email }}{{ $email }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By ID</td><td>{{ if $createdByID }}<code>{{ $createdByID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Created By Subject</td><td>{{ default "—" (dig "created_by_subject" "" .) }}</td></tr>
    <tr><td>Created By Account Type</td><td>{{ default "—" (dig "created_by_account_type" "" .) }}</td></tr>
    <tr><td>Org</td><td>{{ if $orgName }}{{ $orgName }}{{ else }}—{{ end }}</td></tr>
    <tr><td>Org ID</td><td>{{ if $orgID }}<code>{{ $orgID }}</code>{{ else }}—{{ end }}</td></tr>
    <tr><td>Created At</td><td>{{ with dig "build_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
    <tr><td>Updated At</td><td>{{ with dig "build_updated_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</td></tr>
  </tbody>
</table>

</nuon-panel>

      </td>
    </tr>

{{ end }}

  </tbody>
</table>

{{ else if and .populated (eq .status "finished") }}

<nuon-banner theme="info">No builds returned by the last run of ctl_api_query_builds.</nuon-banner>

{{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_builds action. Run it to populate this section.</nuon-banner>

{{ end }} {{ else }}

<nuon-banner theme="warn">Waiting on ctl_api_query_builds action. Run it to populate this section.</nuon-banner>

{{ end }}

  </nuon-tab>
{{ $buildOutputs := dict }}{{ $buildActionID := "" }}{{ with (index (default dict .nuon.actions.workflows) "ctl_api_query_build") }}{{ with .outputs }}{{ $buildOutputs = . }}{{ end }}{{ $buildActionID = dig "id" "" . }}{{ end }}
{{ $rows := list }}{{ with index .nuon.actions.workflows "ctl_api_query_build" }}{{ with .outputs }}{{ $rows = (dig "rows" (list) .) }}{{ end }}{{ end }}
{{ $titleName := "" }}{{ $titleBuildID := "" }}{{ if $rows }}{{ $titleBuildID = dig "build_id" "" (index $rows 0) }}{{ $cn := dig "component_name" "" (index $rows 0) }}{{ if $cn }}{{ $titleName = printf "%s build" $cn }}{{ else }}{{ $titleName = $titleBuildID }}{{ end }}{{ end }}

  <nuon-tab name="Build">

<div style="padding-top:1rem;"></div>

<div style="display:flex;align-items:baseline;gap:0.75rem;">{{ with $titleName }}<h3 style="margin:0;">{{ . }}</h3>{{ end }}{{ with $titleBuildID }}<code>{{ . }}</code>{{ end }}{{ with dig "updated_at" "" $buildOutputs }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $buildActionID }}">ctl_api_query_build</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</div>

<div style="padding-bottom:1rem;"></div>

{{ if not $rows }}

<nuon-banner theme="info">Run the ctl_api_query_build action below to inspect a build. Leave BUILD_ID empty for the most
recent build, or set it to drill into a specific one.</nuon-banner>

<div style="padding-top:1rem;"></div>

<nuon-action-card name="ctl_api_query_build"></nuon-action-card>

{{ else }} {{ range $rows }}

<nuon-card>

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Status:</strong> <span style="display:inline-block;vertical-align:middle;">{{ with dig "build_status" "" . }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ end }}</span>{{ with dig "build_status_description" "" . }} <small style="opacity:0.7;">{{ . }}</small>{{ end }}</li>
    <li><strong>Component:</strong> {{ default "—" (dig "component_name" "" .) }} <small><code>{{ default "—" (dig "component_id" "" .) }}</code></small></li>
    <li><strong>Component type:</strong> {{ default "—" (dig "component_type" "" .) }}</li>
    <li><strong>Org:</strong> {{ default "—" (dig "org_name" "" .) }} <small><code>{{ default "—" (dig "org_id" "" .) }}</code></small></li>
    <li><strong>Created by:</strong> {{ default "—" (dig "created_by_email" "" .) }}</li>
    <li><strong>No-op:</strong> {{ dig "build_no_op" false . }}</li>
    <li><strong>Created:</strong> {{ with dig "build_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Updated:</strong> {{ with dig "build_updated_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
</ul>

  </div>
  <div style="flex:1;min-width:0;">

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Git ref:</strong> {{ with dig "git_ref" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</li>
    <li><strong>Source ref:</strong> {{ with dig "source_ref" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}{{ with dig "resolved_tag" "" . }} → <code>{{ . }}</code>{{ end }}</li>
    <li><strong>Source digest:</strong> {{ with dig "source_digest" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</li>
</ul>

  </div>
</div>

</nuon-card>

{{ end }} {{ end }}

  </nuon-tab>
  <nuon-tab name="Queue signal">

<div style="padding-top:1rem;"></div>

{{ if not $rows }}

<nuon-banner theme="info">Run the ctl_api_query_build action on the Build tab to inspect a build.</nuon-banner>

{{ else }} {{ range $rows }}

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<nuon-card>

<h4 style="margin-top:0;">Queue signal</h4>

{{ $signals := dig "build_signals" (list) . }} {{ if $signals }} {{ range $i, $s := $signals }}
{{ if $i }}<hr style="border:none;border-top:1px solid;opacity:0.15;margin:1rem 0;">{{ end }}

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Status:</strong> <span style="display:inline-block;vertical-align:middle;">{{ with dig "signal_status" "" $s }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</span>{{ with dig "signal_status_description" "" $s }} <small style="opacity:0.7;">{{ . }}</small>{{ end }}</li>
    <li><strong>Type:</strong> {{ dig "signal_type" "—" $s }}</li>
    <li><strong>Enqueued:</strong> {{ dig "enqueued" false $s }}</li>
    <li><strong>Executions:</strong> {{ dig "execution_count" "—" $s }}</li>
    <li><strong>Created:</strong> {{ with dig "created_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Expires:</strong> {{ with dig "expires_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
</ul>

<h5 style="margin:1rem 0 0.5rem;">Timeline</h5>

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Enqueued:</strong> {{ with dig "enqueue_started_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Enqueue finished:</strong> {{ with dig "enqueue_finished_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Dequeued:</strong> {{ with dig "dequeued_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Execute started:</strong> {{ with dig "execute_started_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
    <li><strong>Execute finished:</strong> {{ with dig "execute_finished_at" "" $s }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
</ul>
{{ end }}
{{ else }}
<nuon-banner theme="info">No queue signal for this build. A build only enqueues a signal onto its component's build queue once it passes its initial checks — builds that error before then never create one.</nuon-banner>
{{ end }}

</nuon-card>

  </div>
  <div style="flex:1;min-width:0;">

<nuon-card>

<h4 style="margin-top:0;">Queue</h4>

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Queue name:</strong> {{ default "—" (dig "queue_name" "" .) }}</li>
    <li><strong>Queue ID:</strong> {{ with dig "queue_id" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</li>
    <li><strong>Queue status:</strong> <span style="display:inline-block;vertical-align:middle;">{{ with dig "queue_status" "" . }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</span></li>
    <li><strong>In-flight depth:</strong> {{ dig "queue_depth" "—" . }}</li>
    <li><strong>Max depth:</strong> {{ dig "queue_max_depth" "—" . }}</li>
    <li><strong>Max in-flight:</strong> {{ dig "queue_max_in_flight" "—" . }}</li>
    <li><strong>Idle timeout:</strong> {{ dig "queue_idle_timeout" "—" . }}</li>
</ul>

</nuon-card>

  </div>
</div>

{{ end }} {{ end }}

  </nuon-tab>
  <nuon-tab name="Runner job">

<div style="padding-top:1rem;"></div>

{{ if not $rows }}

<nuon-banner theme="info">Run the ctl_api_query_build action on the Build tab to inspect a build.</nuon-banner>

{{ else }} {{ range $rows }}

<nuon-card>

<h4 style="margin-top:0;">Runner job</h4>

{{ if dig "runner_job_id" "" . }}

<div style="display:flex;gap:1.5rem;align-items:flex-start;">
  <div style="flex:1;min-width:0;">

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Job ID:</strong> <code>{{ dig "runner_job_id" "" . }}</code></li>
    <li><strong>Status:</strong> <span style="display:inline-block;vertical-align:middle;">{{ with dig "runner_job_status" "" . }}<nuon-status status="{{ . }}" variant="badge"></nuon-status>{{ else }}—{{ end }}</span></li>
    <li><strong>Runner ID:</strong> {{ with dig "runner_id" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</li>
    <li><strong>Log stream ID:</strong> {{ with dig "log_stream_id" "" . }}<code>{{ . }}</code>{{ else }}—{{ end }}</li>
    <li><strong>Job created:</strong> {{ with dig "runner_job_created_at" "" . }}<nuon-time time="{{ printf "%sZ" (substr 0 19 .) }}" format="relative"></nuon-time>{{ else }}—{{ end }}</li>
</ul>

  </div>
  <div style="flex:1;min-width:0;">

<ul style="list-style:none;padding-left:0;margin:0;">
    <li><strong>Plan:</strong> {{ with dig "runner_job_plan" dict . }}<nuon-panel heading="Runner job plan" trigger="View" size="3/4"><pre style="white-space:pre-wrap;">{{ . | toPrettyJson }}</pre></nuon-panel>{{ else }}—{{ end }}</li>
</ul>

  </div>
</div>
{{ else }}
<nuon-banner theme="info">No runner job for this build. A build only dispatches a runner job once it passes its pre-checks (e.g. the component being active) — builds that error before then never create one.</nuon-banner>
{{ end }}

</nuon-card>

{{ end }} {{ end }}

  </nuon-tab>
</nuon-tabs>
