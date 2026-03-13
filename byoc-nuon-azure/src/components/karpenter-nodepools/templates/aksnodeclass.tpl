{{- range .Values.nodepools }}
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: "{{ .name }}"
spec:
  imageFamily: {{ .imageFamily | default "Ubuntu2204" }}
  osDiskSizeGB: {{ .osDiskSizeGB | default 128 }}
  {{- if $.Values.tags }}
  tags:
    {{- range $key, $value := $.Values.tags }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
{{- end }}
