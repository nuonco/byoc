---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-runner
spec:
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-runner
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        app.nuon.co/name: {{ include "common.fullname" . }}-runner
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"api","service_deployment":"runner"}'
        rollme: {{ randAlphaNum 6 | quote }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      automountServiceAccountToken: true

      # start: NodePool Selection
      nodeSelector:
        pool.nuon.co: "public"
      tolerations:
        - key: "pool.nuon.co"
          operator: "Equal"
          value: "public"
          effect: "NoSchedule"
      # end: NodePool Selection

      # start: Topology Spread Constraints
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: "topology.kubernetes.io/zone"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              {{- /* plucked from common.apiSelectorLabels */}}
              app.nuon.co/name: {{ include "common.fullname" . }}-runner
        - maxSkew: 1
          minDomains: {{ .Values.api.minDomains }}
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              {{- /* plucked from common.apiSelectorLabels */}}
              app.nuon.co/name: {{ include "common.fullname" . }}-runner
      # end: Topology Spread Constraints
      containers:
        - name: {{ include "common.fullname" . }}-runner
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/service
            - api
          ports:
            - name: http-runner
              containerPort: {{ .Values.api.runner.port }}
              protocol: TCP
            - name: pprof
              containerPort: 6060
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.api.readiness_probe}}
              port: http-runner
          livenessProbe:
            httpGet:
              path: {{ .Values.api.liveness_probe}}
              port: http-runner
          resources:
            limits:
              cpu: {{ .Values.api.resources.limits.cpu }}
              memory: {{ .Values.api.resources.limits.memory }}
            requests:
              cpu: {{ .Values.api.resources.requests.cpu }}
              memory: {{ .Values.api.resources.requests.memory }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" . }}
          env:
          {{- range $envSecret := .Values.envSecrets }}
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
              value: ctl-api
            - name: SERVICE_TYPE
              value: api
            - name: SERVICE_DEPLOYMENT
              value: runner
          lifecycle:
            preStop:
              exec:
                # sleep: during this time, the api can finish processing requests.
                command: [
                  "/bin/sh", "-c", "sleep 20"
                ]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
spec:
  minAvailable: 50%
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-runner
