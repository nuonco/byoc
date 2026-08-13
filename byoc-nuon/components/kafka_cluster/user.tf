#
# ctl-api's identity. The User Operator issues a cert signed by the clients CA and
# writes it to a secret of the same name in this namespace.
#
# The secret is operator-managed, so the Reflector annotations have to be set
# through spec.template — annotating the secret directly would be reconciled away
# on the next pass.
#
resource "kubectl_manifest" "user_ctl_api" {
  yaml_body = yamlencode({
    apiVersion = "kafka.strimzi.io/v1"
    kind       = "KafkaUser"
    metadata = {
      name      = local.kafka_user
      namespace = local.namespace
      labels = {
        "strimzi.io/cluster" = local.cluster
      }
    }
    spec = {
      authentication = {
        type = "tls"
        # per-user override of the clients CA schedule; drop these to inherit it
        validityDays = var.ca_validity_days
        renewalDays  = var.ca_renewal_days
      }

      authorization = {
        type = "simple"
        acls = concat(
          # produce + consume on each topic
          flatten([
            for topic in local.topics : [
              {
                resource = {
                  type        = "topic"
                  name        = topic
                  patternType = "literal"
                }
                operations = ["Read", "Write", "Describe"]
              }
            ]
          ]),
          [
            # Prefix rather than literal: ctl-api runs one group per consumer,
            # named <consumer_group_prefix>-<consumer name> — today
            # ctl-api-consumer-heartbeats, -otel-logs, -otel-traces and -dlq. A
            # group each, rather than one shared, so one consumer restarting
            # doesn't rebalance the others. Granting the prefix means adding one
            # needs no change here. The tradeoff is that the group name must stay
            # under this prefix, or the consumer fails authorization at join, which
            # presents as a hang rather than an error because the client retries.
            {
              resource = {
                type        = "group"
                name        = local.consumer_group_prefix
                patternType = "prefix"
              }
              operations = ["Read", "Describe"]
            },
          ]
        )
      }

      template = {
        secret = {
          metadata = {
            annotations = local.reflector_annotations
          }
        }
      }
    }
  })

  depends_on = [
    kubectl_manifest.kafka,
  ]
}

# The cluster CA cert secret — which ctl-api needs to verify brokers — is also
# operator-managed, and gets its Reflector annotations from
# spec.kafka.template.clusterCaCert in kafka.tf.
