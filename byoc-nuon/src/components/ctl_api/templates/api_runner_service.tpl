---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-runner
spec:
  selector:
    {{- include "common.apiSelectorLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-runner
  type: ClusterIP
  ports:
    - name: http
      port: {{ .Values.api.runner.port }}
      targetPort: http-runner
