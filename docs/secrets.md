# Secrets

## AWS Secrets Manager

This application makes use of several components that create and require the use of secrets.

1. RDS Cluster: These components create a secret in Secret Manager. This secret is the admin username/password.
2. gen secret actions: these actions generate random secrets for use by the clickhouse reader and writer credentials.
   These secrets are later used by the ch operator and the ch cluster definition.

As a result, `Deny` `*` on `secretsmanager:*` is a no go. To work around this, we: i

1. allow full access to secrets w/ the `rds!*` prefix. The maintenance role can read these secrets.
2. allow write and udpate access to secrets w/ the `nuon-gen/*` secrets. The maintenance role has write and update
   access, but no read access.
3. allow `secretsmanager:ListSecrets` on all secrets. this is required becaue `ListSecrets` applies to all resources and
   cannot be scoped to a prefix or what have you. we use this permission to determine wether we should create or update
   a `nuon-gen` secret.
