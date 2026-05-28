Hard-resets Temporal:

- drops and recreates the Temporal DB
- restores namespaces
- clears stale runner/workflow state.
- checks status of temporal and runners (this will update the install README as well)

Use only when Temporal is wedged badly enough that targeted fixes have failed — this terminates in-flight work.

Once we split out the runbook state, we could also add the temporal status action at the end to see what workflows are
active in temporal.
