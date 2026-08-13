#
# Topics are created by a Job running create-topics.sh, mounted from a ConfigMap,
# rather than by KafkaTopic CRs. Same script mono's infra/kafka and docker-compose
# use — one mechanism everywhere; the tradeoff is that config converges when the
# Job runs rather than continuously.
#
# Vendored rather than shared: byoc components cannot read files from outside their
# own directory, so this is a copy of mono/images/kafka/create-topics.sh. Keep them
# in sync.
#
locals {
  create_topics_script = file("${path.module}/create-topics.sh")

  topic_settings = {
    KAFKA_BOOTSTRAP_SERVER          = local.bootstrap_servers
    KAFKA_TOPICS                    = join(" ", local.topics)
    KAFKA_TOPIC_PARTITIONS          = tostring(var.num_partitions)
    KAFKA_TOPIC_REPLICATION_FACTOR  = tostring(var.replication_factor)
    KAFKA_TOPIC_MIN_INSYNC_REPLICAS = tostring(var.min_insync_replicas)
    KAFKA_TOPIC_RETENTION_MS        = tostring(var.log_retention_hours * 3600 * 1000)
    KAFKA_TOPIC_CLEANUP_POLICY      = "delete"
    KAFKA_TOPIC_MAX_MESSAGE_BYTES   = tostring(var.max_message_bytes)

    KAFKA_SECURITY_PROTOCOL       = "SSL"
    KAFKA_TLS_TRUSTSTORE_LOCATION = "/etc/kafka/certs/ca/ca.p12"
    KAFKA_TLS_KEYSTORE_LOCATION   = "/etc/kafka/certs/user/user.p12"
  }

  # Jobs are largely immutable, so key the name off the inputs: changing a topic or
  # its config creates a new Job instead of silently doing nothing.
  create_topics_job = "kafka-create-topics-${substr(sha256(join("", [local.create_topics_script, jsonencode(local.topic_settings)])), 0, 8)}"
}

resource "kubectl_manifest" "create_topics_script" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "kafka-create-topics"
      namespace = local.namespace
    }
    data = {
      "create-topics.sh" = local.create_topics_script
    }
  })

  depends_on = [kubectl_manifest.namespace]
}

# Separate identity from ctl-api: creating and configuring topics needs privileges
# the application itself has no business holding.
resource "kubectl_manifest" "user_topic_admin" {
  yaml_body = yamlencode({
    apiVersion = "kafka.strimzi.io/v1"
    kind       = "KafkaUser"
    metadata = {
      name      = local.topic_admin_user
      namespace = local.namespace
      labels = {
        "strimzi.io/cluster" = local.cluster
      }
    }
    spec = {
      authentication = {
        type         = "tls"
        validityDays = var.ca_validity_days
        renewalDays  = var.ca_renewal_days
      }
      authorization = {
        type = "simple"
        acls = concat(
          flatten([
            for topic in local.topics : [
              {
                resource = {
                  type        = "topic"
                  name        = topic
                  patternType = "literal"
                }
                operations = ["Create", "Describe", "DescribeConfigs", "Alter", "AlterConfigs"]
              }
            ]
          ]),
          [
            {
              resource   = { type = "cluster" }
              operations = ["Describe"]
            },
          ]
        )
      }
    }
  })

  depends_on = [kubectl_manifest.kafka]
}

resource "kubectl_manifest" "create_topics" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = local.create_topics_job
      namespace = local.namespace
    }
    spec = {
      backoffLimit = 6
      # the script bounds its own wait, but cap the Job too so a wedged pod shows
      # up as Failed rather than sitting in Running indefinitely
      activeDeadlineSeconds   = 900
      ttlSecondsAfterFinished = 86400
      template = {
        spec = {
          restartPolicy = "OnFailure"
          containers = [
            {
              name    = "create-topics"
              image   = local.strimzi_kafka_image
              command = ["/bin/sh", "/scripts/create-topics.sh"]
              env = concat(
                [
                  for k, v in local.topic_settings : {
                    name  = k
                    value = v
                  }
                ],
                [
                  {
                    name = "KAFKA_TLS_TRUSTSTORE_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = local.cluster_ca_secret
                        key  = "ca.password"
                      }
                    }
                  },
                  {
                    name = "KAFKA_TLS_KEYSTORE_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = local.topic_admin_user
                        key  = "user.password"
                      }
                    }
                  },
                ]
              )
              volumeMounts = [
                { name = "scripts", mountPath = "/scripts" },
                { name = "kafka-ca", mountPath = "/etc/kafka/certs/ca", readOnly = true },
                { name = "kafka-user", mountPath = "/etc/kafka/certs/user", readOnly = true },
              ]
            }
          ]
          volumes = [
            {
              name = "scripts"
              configMap = {
                name        = "kafka-create-topics"
                defaultMode = 493 # 0755
              }
            },
            {
              name = "kafka-ca"
              secret = {
                secretName = local.cluster_ca_secret
              }
            },
            {
              name = "kafka-user"
              secret = {
                secretName = local.topic_admin_user
              }
            },
          ]
        }
      }
    }
  })

  depends_on = [
    kubectl_manifest.create_topics_script,
    kubectl_manifest.user_topic_admin,
  ]
}
