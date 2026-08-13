#
# kafbat Kafka UI.
#
# Lives in this component because everything it needs is here: the cluster CA that
# verifies brokers and its own mTLS cert are operator-managed secrets in this
# namespace, so running alongside them means mounting them directly instead of
# reflecting a third secret elsewhere.
#
# It is not exposed. The Service is ClusterIP with no external-dns annotation and no
# ALB; the only route in is the dashboard-ui proxy, which serves
# kafka_ui_context_path behind a valid session. That check is the authn/authz
# boundary, which is why kafbat's own AUTH_TYPE stays disabled.
#

locals {
  kafka_ui_cert_dir = "/etc/kafka/certs"

  # Client mTLS goes through the raw client-properties passthrough rather than
  # kafbat's own ssl block: KAFKA_CLUSTERS_0_SSL is a truststore-only config
  # (ClustersProperties$TruststoreConfig), and its KeystoreConfig is wired to
  # schema-registry and ksqldb, not to the Kafka client. Same property set
  # create-topics.sh writes, pointed at the same Strimzi PKCS12 stores. Hostname
  # verification is left on — the broker certs carry SANs for the bootstrap
  # service, which is what ctl-api already relies on.
  kafka_ui_client_properties = {
    KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL       = "SSL"
    KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_LOCATION = "${local.kafka_ui_cert_dir}/ca/ca.p12"
    KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_TYPE     = "PKCS12"
    KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_LOCATION   = "${local.kafka_ui_cert_dir}/user/user.p12"
    KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_TYPE       = "PKCS12"
  }

  kafka_ui_env = merge(
    {
      KAFKA_CLUSTERS_0_NAME             = "${local.cluster}-${var.install_id}"
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS = local.bootstrap_servers
      KAFKA_CLUSTERS_0_READONLY         = tostring(var.kafka_ui_readonly)

      # Served under the proxy's path so every asset and API URL kafbat emits is
      # already prefixed, and the proxy can pass requests through untouched.
      SERVER_SERVLET_CONTEXT_PATH = local.kafka_ui_context_path

      # The dashboard-ui proxy is the auth boundary; a second login here would just
      # be a second secret to rotate.
      AUTH_TYPE = "DISABLED"

      # This is about editing kafbat's own cluster list at runtime, not about Kafka
      # writes. Off, so what's deployed is what's in this file.
      DYNAMIC_CONFIG_ENABLED = "false"

      # Spring Boot enables the liveness/readiness health groups automatically when
      # it detects Kubernetes; set it explicitly so the probes below can't start
      # 404ing on a detection change.
      MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED = "true"

      JAVA_OPTS = var.kafka_ui_java_opts
    },
    local.kafka_ui_client_properties,
  )
}

#
# Third identity alongside ctl-api and kafka-topic-admin, for the same reason those
# are separate: an admin UI reachable by every operator shouldn't borrow the
# application's credentials, and revoking it shouldn't mean touching ctl-api.
#
# Wildcards rather than the local.topics list, so a topic added later is visible
# without an ACL change — this identity is deliberately an admin one. See the
# kafka_ui_readonly note in variables.tf for the tradeoff.
#
resource "kubectl_manifest" "user_kafka_ui" {
  yaml_body = yamlencode({
    apiVersion = "kafka.strimzi.io/v1"
    kind       = "KafkaUser"
    metadata = {
      name      = local.kafka_ui_user
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
        acls = [
          {
            resource = {
              type        = "topic"
              name        = "*"
              patternType = "literal"
            }
            operations = ["Read", "Write", "Create", "Delete", "Describe", "DescribeConfigs", "Alter", "AlterConfigs"]
          },
          {
            # Read and Delete are what an offset reset and a group deletion
            # actually need; Describe alone only lists them.
            resource = {
              type        = "group"
              name        = "*"
              patternType = "literal"
            }
            operations = ["Read", "Describe", "Delete"]
          },
          {
            # IdempotentWrite matters more than it looks: Kafka clients default
            # enable.idempotence=true, so without it producing from the UI fails
            # with CLUSTER_AUTHORIZATION_FAILED, which names nothing useful.
            #
            # Cluster-level Alter and AlterConfigs are deliberately absent even
            # though this is otherwise a write-mode identity. Alter on the cluster
            # resource is Kafka's *ACL management* permission — with it, anyone who
            # reached the UI could grant this user more access — and AlterConfigs is
            # live broker config editing. Neither is needed to produce, reset
            # offsets or manage topics, so the UI's ACL and broker-config pages
            # error instead. That's the intended tradeoff.
            resource   = { type = "cluster" }
            operations = ["Describe", "DescribeConfigs", "IdempotentWrite"]
          },
        ]
      }
    }
  })

  depends_on = [
    kubectl_manifest.kafka,
  ]
}

resource "kubectl_manifest" "kafka_ui" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = local.kafka_ui
      namespace = local.namespace
      labels    = local.kafka_ui_labels
    }
    spec = {
      # One replica: it holds no state worth replicating, and a second would just
      # double the polling load on the brokers. A restart costs a page reload.
      replicas = 1
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = local.kafka_ui
        }
      }
      template = {
        metadata = {
          labels = local.kafka_ui_labels
        }
        spec = {
          # No nodeSelector or toleration: this belongs on the default nodepool, not
          # the tainted kafka one. Same reasoning as the operator — the kafka nodes
          # are sized for brokers and configured never to be disrupted.
          securityContext = {
            # The image's own user. runAsNonRoot alone isn't enough — the image
            # declares USER by name (kafkaui), which kubelet can't verify, so the
            # numeric ids have to be spelled out here.
            runAsNonRoot = true
            runAsUser    = 100
            runAsGroup   = 101
            fsGroup      = 101
          }
          containers = [
            {
              name  = local.kafka_ui
              image = local.kafka_ui_image
              ports = [
                {
                  name          = "http"
                  containerPort = local.kafka_ui_port
                }
              ]
              env = concat(
                [
                  for k, v in local.kafka_ui_env : {
                    name  = k
                    value = v
                  }
                ],
                [
                  {
                    name = "KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = local.cluster_ca_secret
                        key  = "ca.password"
                      }
                    }
                  },
                  {
                    name = "KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = local.kafka_ui_user
                        key  = "user.password"
                      }
                    }
                  },
                  {
                    # Strimzi's p12 uses the store password for the key too, and the
                    # JDK can't read a PKCS12 key with a null password.
                    name = "KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEY_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = local.kafka_ui_user
                        key  = "user.password"
                      }
                    }
                  },
                ]
              )
              volumeMounts = [
                { name = "kafka-ca", mountPath = "${local.kafka_ui_cert_dir}/ca", readOnly = true },
                { name = "kafka-user", mountPath = "${local.kafka_ui_cert_dir}/user", readOnly = true },
              ]
              # Spring Boot's startup dominates here, so the slack lives in the
              # startup probe rather than in a long initialDelay on the other two.
              #
              # Startup is the one probe that uses the composite /actuator/health:
              # before we've ever reached the brokers, "can't reach Kafka" really is
              # not-ready. After that it must not be — see the liveness note.
              startupProbe = {
                httpGet = {
                  path = "${local.kafka_ui_context_path}/actuator/health"
                  port = local.kafka_ui_port
                }
                periodSeconds    = 5
                failureThreshold = 24
              }
              # Deliberately the readiness *group*, not composite health. kafbat
              # folds per-cluster health into the composite endpoint, so a broker
              # outage or an expired cert would drop this pod out of the Service and
              # the proxy would 502 — hiding the UI exactly when it's the thing you
              # want, to look at the broken cluster.
              readinessProbe = {
                httpGet = {
                  path = "${local.kafka_ui_context_path}/actuator/health/readiness"
                  port = local.kafka_ui_port
                }
                periodSeconds = 10
              }
              # Same reasoning, worse failure: on composite health a Kafka outage
              # would restart this pod every 90s for the duration of the incident.
              # The liveness group only reflects whether the process itself is
              # wedged, which is the only thing a restart can fix.
              livenessProbe = {
                httpGet = {
                  path = "${local.kafka_ui_context_path}/actuator/health/liveness"
                  port = local.kafka_ui_port
                }
                periodSeconds    = 30
                failureThreshold = 3
              }
              resources = var.kafka_ui_resources
              securityContext = {
                allowPrivilegeEscalation = false
                capabilities = {
                  drop = ["ALL"]
                }
              }
            }
          ]
          volumes = [
            {
              name = "kafka-ca"
              secret = {
                secretName = local.cluster_ca_secret
              }
            },
            {
              name = "kafka-user"
              secret = {
                secretName = local.kafka_ui_user
              }
            },
          ]
        }
      }
    }
  })

  # Only orders the KafkaUser CR, not the secret the User Operator writes from it —
  # so a first apply can leave this pod in CreateContainerConfigError for a few
  # seconds until that lands. Self-heals, and the create-topics Job has the same
  # shape.
  depends_on = [
    kubectl_manifest.user_kafka_ui,
  ]
}

# ClusterIP, and deliberately nothing else: no external-dns annotation, no ingress.
# Reachable from the dashboard-ui pods and nowhere else.
resource "kubectl_manifest" "kafka_ui_service" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = local.kafka_ui
      namespace = local.namespace
      labels    = local.kafka_ui_labels
    }
    spec = {
      type = "ClusterIP"
      selector = {
        "app.kubernetes.io/name" = local.kafka_ui
      }
      ports = [
        {
          name       = "http"
          port       = local.kafka_ui_port
          targetPort = "http"
          protocol   = "TCP"
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.kafka_ui,
  ]
}
