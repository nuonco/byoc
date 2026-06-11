Resets the Temporal database without a full hard-reset of runner/workflow state:

- refreshes the Temporal RDS secret in the cluster (re-copies the rotated master password from Secrets Manager) and restarts the Temporal deployments so they pick it up
- scales the Temporal server deployments to 0
- pauses the ctl-api worker HPAs and scales the worker deployments to 0 (so autoscaling can't resurrect them mid-reset)
- clears org queue signals: cancels all in-flight `queue_signals` in the ctl_api DB via `ctl_api_clear_org_queues`
- drops and recreates the Temporal DB
- scales the Temporal server back up
- restores Temporal namespaces (needs the server up — done after the scale-up)
- unpauses the ctl-api worker HPAs, letting the workers scale up automatically
- reprovisions every org

Use when the Temporal DB itself is the problem (corruption, bloat, schema drift) and the workers need to be quiesced while it is rebuilt. This terminates all in-flight Temporal state.

Worker HPAs are paused by backing them up to the `ctl-api-worker-hpa-backup` configmap and deleting them; the unpause step re-applies them from that backup and removes the configmap. If the runbook is aborted between the pause and unpause steps, re-run `ctl_api_unpause_worker_hpas` manually to restore autoscaling.
