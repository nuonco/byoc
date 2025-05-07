# notes

## Secrets

Right now we're using a sandbox configuration that copies the secrets from the secrets manager into
the k8s cluster. This works fine to emulate the way the runner will copy secrets. But this is not
great, long term since secret values may end up in logs or in tf state.

three secrets are created in actions that run pre sandbox. these are secrets for the clickhouse
operator and the username/password for two users for the clickhouse cluster (a writer and a readonly
user). these are copied into the cluster using a `secrets` module in the karpenter sandbox.

## TODO

1. make a reader for each of the postgers dbs
2. make the default user an admin user and create writer credentials for ctl_api and temporal.
3. fork the rds temporal db and update w/ the service `infra/*` RDS backup configuration.
