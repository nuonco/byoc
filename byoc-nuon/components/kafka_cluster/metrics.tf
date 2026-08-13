#
# JMX Prometheus exporter rules for the brokers, scraped by the node-local
# Datadog agent via the pod annotations in kafka.tf.
#
# Deliberately a curated allowlist rather than a wildcard: Kafka's JMX surface is
# enormous and every series is a billed custom metric.
#
resource "kubectl_manifest" "metrics_config" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = local.metrics_configmap
      "namespace" = local.namespace
    }
    "data" = {
      "kafka-metrics-config.yml" = yamlencode({
        lowercaseOutputName = true
        rules = [
          # throughput + request rates per topic
          {
            pattern = "kafka.server<type=(BrokerTopicMetrics), name=(MessagesInPerSec|BytesInPerSec|BytesOutPerSec|BytesRejectedPerSec), topic=(.+)><>Count"
            name    = "kafka_server_$1_$2_total"
            type    = "COUNTER"
            labels  = { topic = "$3" }
          },
          {
            pattern = "kafka.server<type=(BrokerTopicMetrics), name=(MessagesInPerSec|BytesInPerSec|BytesOutPerSec|BytesRejectedPerSec)><>Count"
            name    = "kafka_server_$1_$2_total"
            type    = "COUNTER"
          },
          # replication health — under-replicated/offline is the page-worthy one
          {
            pattern = "kafka.server<type=ReplicaManager, name=(UnderReplicatedPartitions|PartitionCount|LeaderCount|IsrShrinksPerSec|IsrExpandsPerSec)><>Value"
            name    = "kafka_server_replicamanager_$1"
            type    = "GAUGE"
          },
          {
            pattern = "kafka.controller<type=KafkaController, name=(OfflinePartitionsCount|ActiveControllerCount|GlobalPartitionCount|GlobalTopicCount)><>Value"
            name    = "kafka_controller_$1"
            type    = "GAUGE"
          },
          # on-disk size per topic/partition — retention + disk headroom
          {
            pattern = "kafka.log<type=Log, name=Size, topic=(.+), partition=(.+)><>Value"
            name    = "kafka_log_size"
            type    = "GAUGE"
            labels  = { topic = "$1", partition = "$2" }
          },
          # request latency, to see broker-side backpressure
          {
            pattern = "kafka.network<type=RequestMetrics, name=(TotalTimeMs|RequestQueueTimeMs), request=(Produce|Fetch|FetchConsumer)><>(\\d+)thPercentile"
            name    = "kafka_network_requestmetrics_$1"
            type    = "GAUGE"
            labels  = { request = "$2", quantile = "0.$3" }
          },
          {
            pattern = "kafka.server<type=DelayedOperationPurgatory, name=PurgatorySize, delayedOperation=(.+)><>Value"
            name    = "kafka_server_purgatory_size"
            type    = "GAUGE"
            labels  = { operation = "$1" }
          },
        ]
      })
    }
  })

  depends_on = [
    kubectl_manifest.namespace,
  ]
}
