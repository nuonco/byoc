---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        tags.datadoghq.com/service: dashboard-ui
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"ui"}'
    spec:
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
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: DoNotSchedule
          minDomains: 2
          labelSelector:
            matchLabels:
              {{- include "common.selectorLabels" . | nindent 14 }}
        - maxSkew: 2
          topologyKey: "topology.kubernetes.io/zone"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              {{- include "common.selectorLabels" . | nindent 14 }}
      # end: Topology Spread Constraints
      serviceAccountName: {{ .Values.serviceAccount.name }}
      automountServiceAccountToken: true
      containers:
        - name: {{ include "common.fullname" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - npm
            - run
            - start
          ports:
            - name: http
              containerPort: {{ .Values.ui.port }}
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.ui.readiness_probe}}
              port: http
          livenessProbe:
            httpGet:
              path: {{ .Values.ui.liveness_probe}}
              port: http
          resources:
            limits:
              cpu: {{ .Values.ui.resources.limits.cpu }}
              memory: {{ .Values.ui.resources.limits.memory }}
            requests:
              cpu: {{ .Values.ui.resources.requests.cpu }}
              memory: {{ .Values.ui.resources.requests.memory }}
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
              value: dashboard-ui
            - name: SERVICE_TYPE
              value: ui
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
