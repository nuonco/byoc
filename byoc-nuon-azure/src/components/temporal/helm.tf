locals {
  temporal = {
    version      = "0.33.0"
    image_tag    = local.vars.image_tag
    value_file   = "values/temporal.yaml"
    namespace    = "temporal"
    frontend_url = "temporal-frontend.${local.zone}"
    web_url      = "temporal-ui.${local.zone}"
  }
  db = {
    default = {
      username = "temporal"
      password = try(
        data.kubernetes_secret_v1.db_default_password.data["value"],
        data.kubernetes_secret_v1.db_default_password.data["password"],
      )
    }
    visibility = {
      username = "temporal_visibility"
      password = try(
        data.kubernetes_secret_v1.db_visibility_password.data["value"],
        data.kubernetes_secret_v1.db_visibility_password.data["password"],
      )
    }
  }
}

data "kubernetes_secret_v1" "db_default_password" {
  metadata {
    name      = "temporal-temporal-db-pw"
    namespace = local.temporal.namespace
  }
}

data "kubernetes_secret_v1" "db_visibility_password" {
  metadata {
    name      = "temporal-visibility-db-pw"
    namespace = local.temporal.namespace
  }
}

resource "helm_release" "temporal" {
  namespace        = local.temporal.namespace
  create_namespace = true

  name    = "temporal"
  version = local.temporal.version
  chart   = "https://github.com/temporalio/helm-charts/releases/download/temporal-${local.temporal.version}/temporal-${local.temporal.version}.tgz"

  values = [
    file(local.temporal.value_file),
    yamlencode(
      {
        server = {
          image = {
            repository = var.temporal_server_image_repository
            tag        = var.temporal_server_image_tag
          }

          config = {
            persistence = {
              default = {
                sql = {
                  host     = var.db_instance_address
                  port     = var.db_instance_port
                  user     = local.db.default.username
                  password = local.db.default.password
                  # TODO: replace password w/ existingSecret existingSecret
                }
              }
              visibility = {
                sql = {
                  host     = var.db_instance_address
                  port     = var.db_instance_port
                  user     = local.db.visibility.username
                  password = local.db.visibility.password
                }
              }
            }
          }

          frontend = {
            service = {
              annotations = {
                "external-dns.alpha.kubernetes.io/internal-hostname" = local.temporal.frontend_url
                "external-dns.alpha.kubernetes.io/ttl"               = "60"
              }
            }
            topologySpreadConstraints = [
              {
                maxSkew           = 1
                topologyKey       = "topology.kubernetes.io/zone"
                whenUnsatisfiable = "ScheduleAnyway"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "frontend"
                  },
                }
              },
              {
                maxSkew           = 2
                topologyKey       = "kubernetes.io/hostname"
                whenUnsatisfiable = "DoNotSchedule"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "frontend"
                  },
                }
              }
            ]
            nodeSelector = {
              "pool.nuon.co" = "temporal"
            }
            tolerations = [
              {
                key      = "pool.nuon.co"
                operator = "Equal"
                value    = "temporal"
                effect   = "NoSchedule"
              }
            ]
          }

          worker = {
            topologySpreadConstraints = [
              {
                maxSkew           = 1
                topologyKey       = "topology.kubernetes.io/zone"
                whenUnsatisfiable = "ScheduleAnyway"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "worker"
                  },
                }
              },
              {
                maxSkew           = 2
                topologyKey       = "kubernetes.io/hostname"
                whenUnsatisfiable = "DoNotSchedule"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "worker"
                  },
                }
              }
            ]
            nodeSelector = {
              "pool.nuon.co" = "temporal"
            }
            tolerations = [
              {
                key      = "pool.nuon.co"
                operator = "Equal"
                value    = "temporal"
                effect   = "NoSchedule"
              }
            ]
          }

          matching = {
            topologySpreadConstraints = [
              {
                maxSkew           = 1
                topologyKey       = "topology.kubernetes.io/zone"
                whenUnsatisfiable = "ScheduleAnyway"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "matching"
                  },
                }
              },
              {
                maxSkew           = 2
                topologyKey       = "kubernetes.io/hostname"
                whenUnsatisfiable = "DoNotSchedule"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "matching"
                  },
                }
              }
            ]
            nodeSelector = {
              "pool.nuon.co" = "temporal"
            }
            tolerations = [
              {
                key      = "pool.nuon.co"
                operator = "Equal"
                value    = "temporal"
                effect   = "NoSchedule"
              }
            ]
          }

          history = {
            topologySpreadConstraints = [
              {
                maxSkew           = 1
                topologyKey       = "topology.kubernetes.io/zone"
                whenUnsatisfiable = "ScheduleAnyway"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "history"
                  }
                }
              },
              {
                maxSkew           = 2
                topologyKey       = "kubernetes.io/hostname"
                whenUnsatisfiable = "DoNotSchedule"
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"      = "temporal"
                    "app.kubernetes.io/component" = "history"
                  }
                }
              }
            ]
            nodeSelector = {
              "pool.nuon.co" = "temporal"
            }
            tolerations = [
              {
                key      = "pool.nuon.co"
                operator = "Equal"
                value    = "temporal"
                effect   = "NoSchedule"
              }
            ]
          }
        }

        admintools = {
          image = {
            repository = var.temporal_admin_tools_image_repository
            tag        = var.temporal_admin_tools_image_tag
          }
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "ScheduleAnyway"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name"      = "temporal"
                  "app.kubernetes.io/component" = "admintools"
                },
              }
            },
            {
              maxSkew           = 2
              topologyKey       = "kubernetes.io/hostname"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name"      = "temporal"
                  "app.kubernetes.io/component" = "admintools"
                },
              }
            }
          ]
          nodeSelector = {
            "pool.nuon.co" = "temporal"
          }
          tolerations = [
            {
              key      = "pool.nuon.co"
              operator = "Equal"
              value    = "temporal"
              effect   = "NoSchedule"
            }
          ]
        }

        web = {
          service = {
            annotations = {
              "external-dns.alpha.kubernetes.io/internal-hostname" = local.temporal.web_url
              "external-dns.alpha.kubernetes.io/ttl"               = "60"
            }
          }
          image = {
            repository = var.temporal_web_image_repository
            tag        = var.temporal_web_image_tag
          }
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "ScheduleAnyway"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name"      = "temporal"
                  "app.kubernetes.io/component" = "web"
                },
              }
            },
            {
              maxSkew           = 2
              topologyKey       = "kubernetes.io/hostname"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name"      = "temporal"
                  "app.kubernetes.io/component" = "web"
                },
              }
            }
          ]
          nodeSelector = {
            "pool.nuon.co" = "temporal"
          }
          tolerations = [
            {
              key      = "pool.nuon.co"
              operator = "Equal"
              value    = "temporal"
              effect   = "NoSchedule"
            }
          ]
          additionalEnv = [
            {
              name  = "TEMPORAL_CODEC_ENDPOINT"
              value = var.codec_endpoint
            },
            {
              name  = "TEMPORAL_CSRF_COOKIE_INSECURE"
              value = "true"
            },
            {
              name  = "TEMPORAL_UI_PUBLIC_PATH"
              value = "/admin/temporal"
            },
          ]
        }
      }
    )
  ]
}
