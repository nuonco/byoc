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
    budgets:
    - nodes: "1"
      reasons:
      - Empty
      - Drifted
    - duration: 20h
      nodes: "1"
      reasons:
      - Underutilized
      schedule: 0 8 * * 1,2,3,4,5
    consolidateAfter: 1m
    consolidationPolicy: WhenEmptyOrUnderutilized
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
        values: {{ .instance_types }}
      - key: topology.kubernetes.io/zone
        operator: In
        values:
        - {{ $.Values.region }}a
        - {{ $.Values.region }}b
        - {{ $.Values.region }}c
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
