{{- range .Values.nodepools }}
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  annotations:
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
    {{/* default: allows up to 10% of nodes to rotate during the 4 hours between (1000 UTC to 1400 UTC); and only one at a time otherwise. */}}
    budgets:
    - nodes: "10%"
    - nodes: "1"
      duration: 20h
      reasons:
      - Underutilized
      - Empty
      - Drifted
      schedule: 0 14 * * *  # https://crontab.guru/#0_8_*_*_*
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
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: {{ .name }}
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: node.kubernetes.io/instance-type
        operator: In
        values:
        {{- range .instance_types }}
        - {{ . }}
        {{- end }}
      - key: topology.kubernetes.io/zone
        operator: In
        values:
        {{- if .zones }}
        {{- range .zones }}
        - {{ . }}
        {{- end }}
        {{- else }}
        - {{ $.Values.region }}a
        - {{ $.Values.region }}b
        - {{ $.Values.region }}c
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
{{- end}}
