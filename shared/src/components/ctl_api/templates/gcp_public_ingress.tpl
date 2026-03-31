{{- if .Values.gcp }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-public
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-public
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      sectionName: https
  hostnames:
    - {{ .Values.api.public.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-public
          port: {{ .Values.api.public.port }}
{{- end }}
