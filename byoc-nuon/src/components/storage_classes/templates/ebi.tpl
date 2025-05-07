apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebi
parameters:
  fsType: ext4
  type: gp2
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - {{ .Values.region }}a
    - {{ .Values.region }}b
    - {{ .Values.region }}c
provisioner: kubernetes.io/aws-ebs
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
