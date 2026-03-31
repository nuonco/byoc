{{- if .Values.gcp }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-admin
spec:
  parentRefs:
    - kind: Gateway
      name: internal-gateway
  hostnames:
    - {{ .Values.api.admin.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-admin
          port: 80
{{- end }}
