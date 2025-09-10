{{- range $.Values.worker.instances }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.workerLabels" $ | nindent 4 }}
    app.nuon.co/worker-namespace: {{ .namespace }}
    tags.datadoghq.com/service:  {{ include "common.fullname" $ }}-worker-{{ .namespace }}
spec:
  selector:
    matchLabels:
      {{- include "common.workerSelectorLabels" $ | nindent 6 }}
      app.nuon.co/worker-namespace: {{ .namespace }}
  template:
    metadata:
      labels:
        {{- include "common.workerSelectorLabels" $ | nindent 8 }}
        app.nuon.co/worker-namespace: {{ .namespace }}
        tags.datadoghq.com/service:  {{ include "common.fullname" $ }}-worker-{{ .namespace }}

    spec:
      serviceAccountName: {{ $.Values.serviceAccount.name }}
      automountServiceAccountToken: true
      nodeSelector:
        pool.nuon.co: ctl-api-worker
      tolerations:
        - key: "pool.nuon.co"
          operator: "Equal"
          value: ctl-api-worker
          effect: "NoSchedule"
      # start: Topology Spread Constraints
      topologySpreadConstraints:
        - maxSkew: 2
          topologyKey: "topology.kubernetes.io/zone"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              {{- /* plucked from common.apiSelectorLabels */}}
              app.kubernetes.io/name: {{ include "common.name" $ }}-worker
        - maxSkew: 2
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              {{- /* plucked from common.workerSelectorLabels */}}
              app.kubernetes.io/name: {{ include "common.name" $ }}-worker
      # end: Topology Spread Constraints
      containers:
        - name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
          ports:
          - containerPort: 6060
            name: pprof
            protocol: TCP
          image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
          command: {{- .command  | toYaml | nindent 14}}
          resources: {{ merge (default (dict) .resources) $.Values.worker.resources | toYaml | nindent 14 }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" $ }}
          env:
          {{- range $envSecret := $.Values.envSecrets }}
            - name: {{ $envSecret.name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $envSecret.valueFrom.name }}
                  key: {{ $envSecret.valueFrom.key }}
          {{- end}}
            - name: HOST_IP
              valueFrom:
                  fieldRef:
                      fieldPath: status.hostIP
            - name: HOST_NAME
              valueFrom:
                  fieldRef:
                      fieldPath: spec.nodeName
            - name: DD_SERVICE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/service']
{{- end }}
