apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd
parameters:
  type: pd-ssd
provisioner: pd.csi.storage.gke.io
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
