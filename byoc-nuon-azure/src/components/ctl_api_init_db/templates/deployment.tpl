---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ctl-api-init
  namespace: ctl-api
  labels:
    app: ctl-api-init
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ctl-api-init
  template:
    metadata:
      labels:
        app: ctl-api-init
    spec:
      containers:
        - name: ctl-api-init
          image: "postgres:15-alpine3.20"
          command: [ "tail", "-f", "/dev/null" ]
          volumeMounts:
          - name: init-config
            mountPath: "/var/init-config"
      volumes:
        - name: init-config
          configMap:
            name: ctl-api-init
            items:
            - key: create_hstore.sql
              path: create_hstore.sql
            - key: create_user.sql
              path: create_user.sql
            - key: grant_user_iam.sql
              path: grant_user_iam.sql
            - key: alter_user_createdb.sql
              path: alter_user_createdb.sql
            - key: create_db.sql
              path: create_db.sql
            - key: grant_db.sql
              path: grant_db.sql
            - key: grant_public.sql
              path: grant_public.sql
