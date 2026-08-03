---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ctl-api-psql
  namespace: ctl-api
  labels:
    app: ctl-api-psql
spec:
  # Template-only: this CronJob never fires on its own (suspended; the schedule
  # is a required placeholder). Actions stamp out per-run Jobs from it with
  #   kubectl create job -n ctl-api <unique-name> --from=cronjob/ctl-api-psql
  # then exec psql into the job's pod. Per-run parameters (DB host, users,
  # short-lived IAM tokens) are passed via `kubectl exec` env, never through
  # the template — Jobs created with --from copy this spec immutably.
  suspend: true
  schedule: "0 0 1 1 *"
  concurrencyPolicy: Allow
  jobTemplate:
    spec:
      backoffLimit: 0
      # Backstops for runs whose action died before cleaning up: the container
      # exits on its own (sleep), activeDeadlineSeconds kills a wedged pod, and
      # the TTL controller garbage-collects the finished Job and its pod.
      activeDeadlineSeconds: 900
      ttlSecondsAfterFinished: 600
      template:
        metadata:
          labels:
            # Deliberately NOT app=ctl-api-init: actions that still use the
            # deployment select pods on that label and must never grab these.
            nuon.co/oneshot: "true"
        spec:
          restartPolicy: Never
          containers:
            - name: psql
              image: "postgres:15-alpine3.20"
              command: [ "sleep", "900" ]
              securityContext:
                runAsNonRoot: true
                runAsUser: 70
                allowPrivilegeEscalation: false
              volumeMounts:
              - name: init-config
                mountPath: "/var/init-config"
          volumes:
            - name: init-config
              configMap:
                # Mount every key (no items:) so the template is insensitive
                # to conditional keys like grant_user_iam.sql.
                name: ctl-api-init
          {{- with .Values.nodeSelector }}
          nodeSelector:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.tolerations }}
          tolerations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
