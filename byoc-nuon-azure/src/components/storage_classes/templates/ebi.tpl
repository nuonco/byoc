apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  # Keep the existing class name to avoid changing workload manifests.
  name: ebi
provisioner: disk.csi.azure.com
parameters:
  kind: Managed
  fsType: ext4
  skuName: Premium_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
