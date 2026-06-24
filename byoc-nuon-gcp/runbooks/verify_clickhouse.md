Verifies the ClickHouse cluster's durability and resilience: persistent volumes are bound and actually
retain data across pod/StatefulSet recreation, the server and keeper pods are spread across distinct
nodes, and scheduled GCS backups are running. Use this after deploying ClickHouse changes, or when
diagnosing data-loss / availability concerns.

Each check below runs as an action against the install — no direct cluster or GCP access is required.
Run a step to refresh its result; the latest output is rendered inline.

> **Background:** ClickHouse on GCP previously ran with no `volumeClaimTemplates`, so its data lived on
> ephemeral pod storage and was lost on any reschedule — surfacing as a "no healthy upstream" error on
> the auth service (which depends on ClickHouse). Persistent volumes and pod anti-affinity were added to
> fix this. This runbook confirms both are in effect.

{{ $storage := dict }}{{ $storageID := "" }}{{ with index .nuon.actions.workflows "ch_verify_storage" }}{{ with .outputs }}{{ $storage = . }}{{ end }}{{ $storageID = dig "id" "" . }}{{ end }}
{{ $spread := dict }}{{ $spreadID := "" }}{{ with index .nuon.actions.workflows "ch_verify_pod_spread" }}{{ with .outputs }}{{ $spread = . }}{{ end }}{{ $spreadID = dig "id" "" . }}{{ end }}
{{ $backups := dict }}{{ $backupsID := "" }}{{ with index .nuon.actions.workflows "ch_verify_backups" }}{{ with .outputs }}{{ $backups = . }}{{ end }}{{ $backupsID = dig "id" "" . }}{{ end }}

---

**1. Persistent storage**

Lists the PVCs (expect one per server replica, `Bound`, `20Gi`, storageclass `ssd`) and confirms the
data dir is backed by a real disk rather than an ephemeral overlay. To also prove data survives a
StatefulSet recreation, re-run the action with `RUN_RESTART_TEST=true` — note this restarts the
`chi-clickhouse-installation-simple-0-0` StatefulSet and is disruptive.

<nuon-group gap="2" align="center" justify="start">{{ $ind := dig "indicator" "" $storage }}{{ if eq $ind "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $ind "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="pvcs:{{ dig "pvcs_bound" "?" $storage }}/{{ dig "pvcs_total" "?" $storage }} bound"></nuon-label-badge><nuon-label-badge
label="restart-test:{{ dig "restart_test" "not run" $storage }}"></nuon-label-badge>{{ with dig "updated_at" "" $storage }}<span style="margin-left:auto;font-size:0.85em;">Last run by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $storageID }}">ch_verify_storage</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

| Check | Result |
| ----- | ------ |
| PVCs bound | {{ dig "pvcs_bound" "?" $storage }} / {{ dig "pvcs_total" "?" $storage }} |
| Data dir device | {{ dig "data_mount" "unknown" $storage }} |
| Unbound PVCs | {{ $ub := dig "unbound_pvcs" (list) $storage }}{{ if $ub }}{{ range $ub }}`{{ . }}` {{ end }}{{ else }}none{{ end }} |
| Durability restart test | {{ dig "restart_test" "not run" $storage }} |

> **Note — first cutover is destructive:** the very first deploy that adds `volumeClaimTemplates` to an
> install still running on ephemeral storage forces the operator to recreate the StatefulSet, and the
> old ephemeral data is lost in that one transition. Treat the initial volumes rollout on any existing
> install as a reset of ClickHouse data. After that, data persists.

<nuon-action-card name="ch_verify_storage"></nuon-action-card>

---

**2. Pod spread (anti-affinity)**

Confirms the 2 server replicas are on distinct nodes and the 3 keeper replicas are on distinct nodes
(and reports how many distinct zones the keeper quorum spans — ideally 3, so a single zonal outage
cannot break raft quorum).

<nuon-group gap="2" align="center" justify="start">{{ $ind := dig "indicator" "" $spread }}{{ if eq $ind "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $ind "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="server:{{ dig "server_nodes" "?" $spread }} nodes"></nuon-label-badge><nuon-label-badge
label="keeper:{{ dig "keeper_nodes" "?" $spread }} nodes / {{ dig "keeper_distinct_zones" "?" $spread }} zones"></nuon-label-badge>{{ with dig "updated_at" "" $spread }}<span style="margin-left:auto;font-size:0.85em;">Last run by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $spreadID }}">ch_verify_pod_spread</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

| Check | Result |
| ----- | ------ |
| Server replicas on distinct nodes | {{ dig "server_nodes" "?" $spread }} {{ if dig "server_distinct_nodes_ok" false $spread }}✅{{ else }}❌{{ end }} |
| Keeper replicas on distinct nodes | {{ dig "keeper_nodes" "?" $spread }} {{ if dig "keeper_distinct_nodes_ok" false $spread }}✅{{ else }}❌{{ end }} |
| Keeper distinct zones | {{ dig "keeper_distinct_zones" "?" $spread }} |

<nuon-action-card name="ch_verify_pod_spread"></nuon-action-card>

---

**3. GCS backups**

Confirms the HMAC credential secret and backup CronJob(s) exist, triggers a backup run and waits for it
to complete (logs should show `BACKUP_CREATED`), and lists the resulting objects in the backup bucket.

<nuon-group gap="2" align="center" justify="start">{{ $ind := dig "indicator" "" $backups }}{{ if eq $ind "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $ind "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}<nuon-label-badge
label="job:{{ dig "backup_job" "not run" $backups }}"></nuon-label-badge><nuon-label-badge
label="objects:{{ dig "objects_found" "?" $backups }}"></nuon-label-badge>{{ with dig "updated_at" "" $backups }}<span style="margin-left:auto;font-size:0.85em;">Last run by
<a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $backupsID }}">ch_verify_backups</a>
<nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

| Check | Result |
| ----- | ------ |
| Backup job | {{ dig "backup_job" "not run" $backups }} |
| Table | {{ dig "table" "-" $backups }} |
| CronJob | {{ dig "cronjob" "-" $backups }} |
| Objects in bucket | {{ dig "objects_found" "?" $backups }} |

<nuon-action-card name="ch_verify_backups"></nuon-action-card>

---

**4. Replica status**

An at-a-glance view of ClickHouse replica health (flags any read-only replicas).

<nuon-action-card name="ch_cluster_replicas"></nuon-action-card>
