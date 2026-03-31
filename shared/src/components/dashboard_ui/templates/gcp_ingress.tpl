{{- if .Values.gcp }}
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-hc
  namespace: {{ .Release.Namespace }}
spec:
  default:
    checkIntervalSec: 5
    timeoutSec: 2
    healthyThreshold: 2
    unhealthyThreshold: 2
    config:
      type: HTTP
      httpHealthCheck:
        requestPath: {{ .Values.ui.readiness_probe | default "/" }}
        port: {{ .Values.ui.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      namespace: ctl-api
      sectionName: https
  hostnames:
    - {{ .Values.ui.alb.public_domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}
          port: 4000
{{- end }}
