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
    GRANT USAGE ON SCHEMA public TO ctl_api;
