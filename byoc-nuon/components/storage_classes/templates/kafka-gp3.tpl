{{/*
gp3 for the Kafka broker log dirs.

Separate from the `ebi` class above rather than reusing it: `ebi` is gp2 via the
in-tree kubernetes.io/aws-ebs provisioner, which cannot expand a volume in place.
Brokers start small and grow, so they need the CSI driver plus
allowVolumeExpansion — raising volume_size on the Kafka node pool then resizes the
PVCs rather than requiring a migration. EBS volumes can only ever grow.

WaitForFirstConsumer so the volume is created in whichever AZ Karpenter places the
broker in.
*/}}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: kafka-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
# Delete so removing a PVC doesn't orphan a paid-for EBS volume. The PVCs themselves
# are protected by deleteClaim=false on the Kafka node pool, which is what stops a
# deleted Kafka CR from taking the data with it.
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
