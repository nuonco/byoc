# infra-temporal

## Notable Differences

1. stage vars renamed to dev
2. name is now same as service (both local vars)
3. removed the concept of a pool (not to be confused w/ pool.nuon.co)
4. removed the rds primary and replica. these are intended to be managed independently in another
   component. this new component is current the simple rds cluster. we need to udpate it to add
   backus and dns.
5. rds username AND password are loaded from the secret. plan is to move to `existingSecret`
   eventually.

## TODO

Copy these RDS configs into a more refined rds-cluster component
