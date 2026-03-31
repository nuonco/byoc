{{- range $.Values.worker.instances }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.workerLabels" $ | nindent 4 }}
    app.nuon.co/worker-namespace: {{ .namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
  minReplicas: {{ .minReplicas | default 1 }}
  maxReplicas: {{ .maxReplicas | default 5 }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $.Values.worker.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $.Values.worker.autoscaling.targetMemoryUtilizationPercentage }}
{{- end }}
