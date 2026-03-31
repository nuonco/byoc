{{- if and .Values.auth.enabled .Values.gcp }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-auth
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-auth
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      sectionName: https
  hostnames:
    - {{ .Values.api.auth.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-auth
          port: 80
{{- end }}
