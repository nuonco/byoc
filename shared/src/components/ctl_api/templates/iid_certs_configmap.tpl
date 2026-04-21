---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . }}-iid-certs
  namespace: {{ .Release.Namespace | quote | default "default"}}
  labels:
    {{- include "common.labels" . | nindent 4 }}
data:
{{- range $path, $bytes := .Files.Glob "iid-certs/*.pem" }}
  {{ base $path }}: |
{{ toString $bytes | indent 4 }}
{{- end }}
