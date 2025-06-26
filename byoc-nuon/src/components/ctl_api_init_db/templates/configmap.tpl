---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ctl-api-init
  namespace: ctl-api
data:
  create_hstore.sql: |
    CREATE EXTENSION IF NOT EXISTS hstore;
  create_user.sql: |
    CREATE USER ctl_api WITH LOGIN;
  grant_user_iam.sql: |
    GRANT rds_iam TO ctl_api;
  alter_user_createdb.sql: |
    ALTER USER ctl_api CREATEDB;
  create_db.sql: |
    CREATE DATABASE ctl_api;
  grant_db.sql: |
    GRANT ALL ON DATABASE ctl_api to ctl_api;
  grant_public.sql: |
    GRANT ALL ON SCHEMA public TO ctl_api;
  copy_db.sql: |
    pg_dump -h $SOURCE_HOST -u nuon -P $SOURCE_PASSWORD   -d ctl_api > /tmp/ctl_api
    psql    -h $TARGET_HOST -u nuon -P $TARGET_PGPASSWORD < /tmp/ctl_api
