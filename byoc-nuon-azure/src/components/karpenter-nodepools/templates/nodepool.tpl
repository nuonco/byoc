{{- range .Values.nodepools }}
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    pool.nuon.co: "{{ .name }}"
  name: "{{ .name }}"
spec:
  disruption:
    {{- if .disruption }}
    consolidationPolicy: {{ .disruption.consolidationPolicy | default "WhenEmptyOrUnderutilized" }}
    consolidateAfter: {{ .disruption.consolidateAfter | default "5m" }}
    budgets:
    {{- range .disruption.budgets }}
    - nodes: {{ .nodes | quote }}
      {{- if .schedule }}
      schedule: {{ .schedule | quote }}
      {{- end }}
      {{- if .duration }}
      duration: {{ .duration }}
      {{- end }}
      {{- if .reasons }}
      reasons:
      {{- range .reasons }}
      - {{ . }}
      {{- end }}
      {{- end }}
    {{- end }}
    {{- else }}
    budgets:
    - nodes: "10%"
    - nodes: "1"
      duration: 20h
      reasons:
      - Underutilized
      - Empty
      - Drifted
      schedule: 0 14 * * *
    consolidateAfter: 5m
    consolidationPolicy: WhenEmptyOrUnderutilized
    {{- end }}
  limits:
    cpu: {{ .limits.cpu }}
    memory: {{ .limits.memory }}
  template:
    metadata:
      labels:
        pool.nuon.co: "{{ .name }}"
    spec:
      expireAfter: {{ .expireAfter }}
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: {{ .name }}
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      {{- if .sku_families }}
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        {{- range .sku_families }}
        - {{ . }}
        {{- end }}
      {{- end }}
      {{- if .instance_types }}
      - key: node.kubernetes.io/instance-type
        operator: In
        values: {{ .instance_types }}
      {{- end }}
      {{- if .zones }}
      - key: topology.kubernetes.io/zone
        operator: In
        values:
        {{- range .zones }}
        - {{ . | quote }}
        {{- end }}
      {{- end }}
      - key: pool.nuon.co
        operator: Exists
      - key: pool.nuon.co
        operator: In
        values:
        - "{{ .name }}"
      taints:
      - effect: NoSchedule
        key: pool.nuon.co
        value: {{ .name }}
{{- end }}
