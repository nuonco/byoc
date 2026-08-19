locals {
  service = "kafka"

  # Strimzi derives the bootstrap service name as <cluster>-kafka-bootstrap, so
  # keep this short: "nuon" yields nuon-kafka-bootstrap, not nuon-kafka-kafka-*.
  #
  # It is also baked into the cert secret name below and into ctl-api's
  # KAFKA_BROKERS, which is set in values/ctl-api.yaml rather than read from this
  # component's outputs — the address is deterministic, so a cross-component
  # dependency would buy nothing.
  cluster   = "nuon"
  namespace = "kafka"

  # KafkaUsers, and therefore the names of the secrets holding their certs
  kafka_user       = "ctl-api"
  topic_admin_user = "kafka-topic-admin"
  kafka_ui_user    = "kafka-ui"

  # namespace ctl-api runs in; grants it listener + secret access
  client_namespace = "ctl-api"

  storage_class     = "kafka-gp3"
  metrics_configmap = "kafka-metrics"

  bootstrap_servers = "${local.cluster}-kafka-bootstrap.${local.namespace}.svc.cluster.local:9093"

  # Strimzi names the CA secrets off the cluster name. ctl-api needs the cluster
  # CA to verify brokers, and its KafkaUser secret to present its own cert.
  cluster_ca_secret = "${local.cluster}-cluster-ca-cert"

  # Names mirror the destination ClickHouse tables. Underscores, not dots: dots
  # collide with _ in JMX metric names and force quoting in ksql.
  #
  # dlq is the shared dead-letter topic every consumer produces to when it can't
  # decode a record — same provisioning as the others, since the ACLs and the
  # create-topics Job both iterate this list.
  topics = [
    "runner_heart_beats",
    "otel_log_records",
    "otel_traces",
    "dlq",
  ]

  # ctl-api runs one consumer group per consumer, named
  # <prefix>-<consumer name>. Granted as a prefix ACL so adding a consumer needs
  # no change here.
  consumer_group_prefix = "ctl-api"

  # Reflector (the reflector component) mirrors the cert secrets into the
  # namespace ctl-api runs in. Set through spec.template on the operator-managed
  # objects — annotating the secrets directly would be reconciled away.
  reflector_annotations = {
    "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
    "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = local.client_namespace
    "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
    "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = local.client_namespace
  }

  # Strimzi serves the JMX exporter on 9404 and kafka-exporter on 9308. The
  # node-local Datadog agent scrapes each pod directly; a static confd endpoint
  # against the headless service would only hit whichever pod DNS resolved.
  #
  # Inert when the datadog component is toggled off — they are just annotations.
  dd_annotations = {
    "ad.datadoghq.com/kafka.checks" = jsonencode({
      openmetrics = {
        init_config = {}
        instances = [
          {
            openmetrics_endpoint = "http://%%host%%:9404/metrics"
            namespace            = "kafka"
            # safe to take everything: the allowlist is enforced upstream by the
            # JMX exporter rules in metrics.tf
            metrics = [".*"]
          }
        ]
      }
    })
  }

  # consumer group lag is not on the broker's JMX surface, so it comes from
  # Strimzi's kafka-exporter sidecar deployment instead
  dd_exporter_annotations = {
    "ad.datadoghq.com/kafka-exporter.checks" = jsonencode({
      openmetrics = {
        init_config = {}
        instances = [
          {
            openmetrics_endpoint = "http://%%host%%:9308/metrics"
            namespace            = "kafka"
            metrics              = ["kafka_consumergroup_.*", "kafka_topic_partition_.*"]
          }
        ]
      }
    })
  }

  # kafbat Kafka UI. Runs in this namespace so it can mount the Strimzi cert
  # secrets directly, rather than needing a third secret reflected elsewhere.
  kafka_ui      = "kafka-ui"
  kafka_ui_port = 8080

  # Our own label, so the listener's networkPolicyPeers (kafka.tf) can select this
  # pod without depending on a label we don't control.
  kafka_ui_labels = {
    "app.kubernetes.io/name"      = local.kafka_ui
    "app.kubernetes.io/component" = "ui"
    "app.nuon.co/kafka-ui"        = "true"
  }

  # Setting SERVER_SERVLET_CONTEXT_PATH to this makes kafbat generate every asset
  # and API URL under the prefix, and moves actuator to <prefix>/actuator/health.
  # That is what lets the dashboard-ui proxy pass it through untouched instead of
  # rewriting its HTML the way the Temporal UI proxy has to.
  #
  # Don't "correct" this to spring.webflux.base-path. kafbat is WebFlux, not
  # servlet-based, so the generic Spring rule says server.servlet.context-path is
  # ignored here — but kafbat honours it anyway and base-path does nothing.
  # Changing the path means changing it here, in the dashboard-ui BFF's proxy.go,
  # and in docker-compose.
  kafka_ui_context_path = "/admin/kafka"

  # Full image refs. Repository already includes the registry host, per the
  # container_image output contract (`{{.repository}}:{{.tag}}`).
  strimzi_kafka_image    = "${var.strimzi_kafka_image_repository}:${var.strimzi_kafka_image_tag}"
  strimzi_operator_image = "${var.strimzi_operator_image_repository}:${var.strimzi_operator_image_tag}"
  kafka_ui_image         = "${var.kafka_ui_image_repository}:${var.kafka_ui_image_tag}"

  # The Strimzi chart composes the operator image as
  # <registry>/<repository>/<name>:<tag> rather than taking a full ref, so the
  # mirrored repository has to be split. Everything else (brokers, exporter, user
  # operator) takes a full ref on the CR, so this is the only place that needs it.
  #
  # Nuon mirrors every image for an install into ONE repository and distinguishes
  # them by tag (565044017775.dkr.ecr.../<install-id>:img-strimzi-operator-1.1.0),
  # so the ref is only host + install-id. Everything after the host therefore goes
  # in repository, and name stays empty: the chart's helper drops empty segments
  # via compact, and there is no defaultImageName to fall back to, so this renders
  # <host>/<install-id>:<tag>. Do not leave repository empty -- it would fall back
  # to defaultImageRepository ("strimzi") and point at an image we never mirrored.
  operator_ref_parts  = split("/", var.strimzi_operator_image_repository)
  operator_registry   = local.operator_ref_parts[0]
  operator_repository = join("/", slice(local.operator_ref_parts, 1, length(local.operator_ref_parts)))
  operator_name       = ""
}

variable "install_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

#
# images
#

variable "strimzi_operator_image_repository" {
  type        = string
  description = "Mirrored quay.io/strimzi/operator repository, including registry host."
}

variable "strimzi_operator_image_tag" {
  type = string
}

variable "strimzi_kafka_image_repository" {
  type        = string
  description = "Mirrored quay.io/strimzi/kafka repository, including registry host."
}

variable "strimzi_kafka_image_tag" {
  type = string
}

variable "kafka_ui_image_repository" {
  type        = string
  description = "Mirrored ghcr.io/kafbat/kafka-ui repository, including registry host."
}

variable "kafka_ui_image_tag" {
  type = string
}

#
# strimzi / kafka
#

variable "operator_version" {
  type        = string
  description = "Strimzi chart version. Must match the operator image tag, and cannot skip minor versions on upgrade."
  default     = "1.1.0"
}

variable "kafka_version" {
  type    = string
  default = "4.3.0"
}

variable "metadata_version" {
  type        = string
  description = "Kafka's internal format version. Not reversible — only raise it after every broker runs the new kafka_version."
  default     = "4.3-IV0"
}

variable "replicas" {
  type        = number
  description = <<-EOT
    Broker count. These are KRaft dual-role nodes, so this also sets the
    controller quorum: at 1 there is no quorum tolerance and every rolling
    restart (cert rotation, version bump, node replacement) is a full outage.
    Do not lower this below 3 without also lowering min_insync_replicas, and
    understand that dropped heartbeats take runners offline.
  EOT
  default     = 3

  validation {
    condition     = var.replicas >= 3
    error_message = "replicas must be at least 3: fewer loses KRaft quorum tolerance and makes min.insync.replicas=2 unsatisfiable."
  }
}

variable "volume_size" {
  type        = string
  description = "Per-broker log dir size. EBS can only grow, and the storage class allows expansion, so start small."
  default     = "100Gi"
}

variable "num_partitions" {
  type    = number
  default = 8
}

variable "replication_factor" {
  type    = number
  default = 3
}

variable "min_insync_replicas" {
  type    = number
  default = 2
}

variable "log_retention_hours" {
  type        = string
  description = "Kafka is a buffer, not the store of record — ClickHouse is."
  default     = 168
}

variable "max_message_bytes" {
  type        = string
  description = "4MiB, up from Kafka's 1MiB default. A dlq record re-wraps an original record inside a new envelope, so this covers the worst case."
  default     = 4194304
}

variable "ca_validity_days" {
  type    = number
  default = 365
}

variable "ca_renewal_days" {
  # number, not string: the Kafka/KafkaUser CRDs type renewalDays as integer and
  # reject a quoted value outright.
  type        = number
  description = "Certs renew this many days before expiry and the old cert stays valid for the whole window, so a client that fails to reload has runway before it breaks."
  default     = 90
}

variable "broker_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = <<-EOT
    requests == limits so brokers land in the Guaranteed QoS class: last evicted
    under node pressure and never CFS-throttled. A throttled broker stalls every
    partition it leads, which just accrues lag — quieter and easier to miss than a
    crash.
  EOT
  default = {
    requests = { cpu = "1", memory = "5Gi" }
    limits   = { cpu = "1", memory = "5Gi" }
  }
}

variable "broker_jvm" {
  type        = object({ xms = string, xmx = string })
  description = <<-EOT
    Heap is deliberately a fraction of the container memory: Kafka serves reads
    from the OS page cache, so the remainder is doing real work. -Xms == -Xmx
    avoids heap-resize pauses.
  EOT
  default     = { xms = "1536m", xmx = "1536m" }
}

variable "operator_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "exporter_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "128Mi" }
  }
}

#
# kafka ui
#

variable "kafka_ui_readonly" {
  type        = bool
  description = <<-EOT
    Write mode is the default, matching mono: anyone who reaches the dashboard as
    an authorized user can produce records, reset consumer group offsets, and
    create or delete topics. That is deliberate — it is the point of having it
    during an incident. Flipping this only hides the buttons; it also needs the
    KafkaUser ACLs in ui.tf narrowed to mean anything.
  EOT
  default     = false
}

variable "kafka_ui_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "512Mi" }
    limits   = { cpu = "1", memory = "1Gi" }
  }
}

variable "kafka_ui_java_opts" {
  type        = string
  description = "The JVM's default heap is 25% of the container limit. kafbat holds decoded message batches on heap while browsing, so give it the room."
  default     = "-XX:MaxRAMPercentage=75.0"
}
