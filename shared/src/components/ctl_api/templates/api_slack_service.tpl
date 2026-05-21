{{- if .Values.api.slack.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-slack
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-slack
spec:
  selector:
    {{- include "common.apiSelectorLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-slack
  ports:
    - name: http
      port: 80
      targetPort: http-internal
{{- end }}
