#
# Kafka cluster. KRaft only — Strimzi removed ZooKeeper, and node pools are
# mandatory, so broker count and storage live on the KafkaNodePool while
# cluster-wide config lives on the Kafka CR.
#
# Dual-role nodes (controller + broker): at 4 topics / 8 partitions each,
# splitting controllers out would be 3 extra pods for no benefit. Splitting later
# is a node-pool change, not a rebuild.
#
resource "kubectl_manifest" "node_pool" {
  yaml_body = yamlencode({
    apiVersion = "kafka.strimzi.io/v1"
    kind       = "KafkaNodePool"
    metadata = {
      name      = "kafka-broker"
      namespace = local.namespace
      labels = {
        "strimzi.io/cluster" = local.cluster
      }
    }
    spec = {
      replicas = var.replicas
      roles    = ["controller", "broker"]
      storage = {
        type = "jbod"
        volumes = [
          {
            id   = 0
            type = "persistent-claim"
            size = var.volume_size
            # keep the PVCs if the Kafka CR is ever deleted
            deleteClaim   = false
            class         = local.storage_class
            kraftMetadata = "shared"
          }
        ]
      }
      template = {
        pod = {
          metadata = {
            # our own label, so the spread constraints below select on something
            # we control rather than a Strimzi-internal label that could change
            labels = {
              "app.nuon.co/kafka-broker" = "true"
            }
            # Must live here, not on the Kafka CR: KafkaPool.processTemplate
            # replaces the Kafka CR's whole template.pod object when the node pool
            # sets one, so annotations placed there would be silently dropped and
            # the JMX endpoint would never be scraped.
            annotations = local.dd_annotations
          }

          # Strimzi's rack setting only adds node affinity requiring the zone
          # label to exist — it does NOT spread pods. Without these constraints
          # Karpenter is free to bin-pack all three brokers onto one large node,
          # which it prefers because one bigger box is cheaper than three small
          # ones. That would put every replica of every partition on a single node
          # in a single zone, making RF3 and min.insync.replicas=2 meaningless.
          # DoNotSchedule so a capacity shortfall shows up as a Pending pod
          # instead of silent co-location.
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "kubernetes.io/hostname"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.nuon.co/kafka-broker" = "true"
                }
              }
            },
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.nuon.co/kafka-broker" = "true"
                }
              }
            },
          ]

          # Strimzi's pod template has no nodeSelector field, so pinning to the
          # kafka nodepool has to go through nodeAffinity.
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [
                  {
                    matchExpressions = [
                      {
                        key      = "pool.nuon.co"
                        operator = "In"
                        values   = [local.service]
                      }
                    ]
                  }
                ]
              }
            }
          }
          tolerations = [
            {
              key      = "pool.nuon.co"
              operator = "Equal"
              value    = local.service
              effect   = "NoSchedule"
            }
          ]
        }
      }
      resources = var.broker_resources

      jvmOptions = {
        "-Xms" = var.broker_jvm.xms
        "-Xmx" = var.broker_jvm.xmx
      }
    }
  })

  depends_on = [
    helm_release.strimzi,
    kubectl_manifest.namespace,
  ]
}

resource "kubectl_manifest" "kafka" {
  yaml_body = yamlencode({
    apiVersion = "kafka.strimzi.io/v1"
    kind       = "Kafka"
    metadata = {
      name      = local.cluster
      namespace = local.namespace
    }
    spec = {
      kafka = {
        version = var.kafka_version
        # must be bumped deliberately, and only after all brokers run the new
        # version — it is not reversible
        metadataVersion = var.metadata_version
        image           = local.strimzi_kafka_image

        listeners = [
          {
            name = "tls"
            port = 9093
            type = "internal"
            tls  = true
            authentication = {
              # mTLS: clients present a cert signed by the clients CA
              type = "tls"
            }
            # Only takes effect if the CNI enforces NetworkPolicy (the AWS VPC CNI
            # needs enableNetworkPolicy). Defense in depth — mTLS is the control
            # we actually rely on.
            #
            # Every client needs a peer here or it is denied once enforcement is
            # on. The kafka-ui peer has no namespaceSelector on purpose: a bare
            # podSelector means "this namespace", which is where it runs.
            networkPolicyPeers = [
              {
                namespaceSelector = {
                  matchLabels = {
                    "kubernetes.io/metadata.name" = local.client_namespace
                  }
                }
              },
              {
                podSelector = {
                  matchLabels = {
                    "app.nuon.co/kafka-ui" = "true"
                  }
                }
              },
            ]
          }
        ]

        # authentication only proves identity; without this any authenticated
        # client could read or write anything. ACLs live on the KafkaUser.
        authorization = {
          type = "simple"
        }

        config = {
          "num.partitions"                           = var.num_partitions
          "default.replication.factor"               = var.replication_factor
          "min.insync.replicas"                      = var.min_insync_replicas
          "offsets.topic.replication.factor"         = var.replication_factor
          "transaction.state.log.replication.factor" = var.replication_factor
          "transaction.state.log.min.isr"            = var.min_insync_replicas
          "log.retention.hours"                      = var.log_retention_hours
          "log.cleanup.policy"                       = "delete"
          "message.max.bytes"                        = var.max_message_bytes
          # Must be >= message.max.bytes: a broker won't replicate a record larger
          # than its own fetch-from-leader ceiling, which otherwise silently
          # degrades replication for anything over the old 1MiB default rather
          # than failing loudly.
          "replica.fetch.max.bytes" = var.max_message_bytes
          # topics are declared by the create-topics Job; an undeclared name
          # should fail rather than silently get a 1-partition topic
          "auto.create.topics.enable"      = false
          "unclean.leader.election.enable" = false
        }

        # sets broker.rack so the replicas land in different AZs
        rack = {
          topologyKey = "topology.kubernetes.io/zone"
        }

        metricsConfig = {
          type = "jmxPrometheusExporter"
          valueFrom = {
            configMapKeyRef = {
              name = local.metrics_configmap
              key  = "kafka-metrics-config.yml"
            }
          }
        }

        template = {
          # No pod block here on purpose: the node pool sets one, which replaces
          # this wholesale (KafkaPool.processTemplate). Broker pod annotations and
          # labels belong on the KafkaNodePool template.
          #
          # ctl-api needs this CA to verify brokers, and it lives in this
          # namespace — Reflector mirrors it across.
          clusterCaCert = {
            metadata = {
              annotations = local.reflector_annotations
            }
          }
        }
      }

      # Certs renew ahead of expiry and the old one stays valid for that whole
      # window, so a client that fails to reload has runway to be caught by the
      # expiry monitor instead of dropping offline.
      clusterCa = {
        validityDays = var.ca_validity_days
        renewalDays  = var.ca_renewal_days
      }
      clientsCa = {
        validityDays = var.ca_validity_days
        renewalDays  = var.ca_renewal_days
      }

      entityOperator = {
        # Only the user operator: topics are created by the shared script in
        # topics.tf, not by KafkaTopic CRs. It runs the operator image, not the
        # kafka one.
        userOperator = {
          image = local.strimzi_operator_image
        }
      }

      # consumer group lag isn't exposed on the broker JMX surface, and lag is the
      # metric that actually tells us whether the consumer is keeping up. With
      # heartbeats on Kafka, sustained lag here means runners are about to look
      # offline.
      kafkaExporter = {
        topicRegex = ".*"
        groupRegex = ".*"
        image      = local.strimzi_kafka_image
        resources  = var.exporter_resources
        template = {
          pod = {
            metadata = {
              annotations = local.dd_exporter_annotations
            }
          }
        }
      }
    }
  })

  depends_on = [
    kubectl_manifest.node_pool,
    kubectl_manifest.metrics_config,
  ]
}
