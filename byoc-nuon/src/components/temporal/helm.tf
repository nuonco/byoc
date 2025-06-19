locals {
  temporal = {
    version       = "0.33.0"
    image_tag     = local.vars.image_tag
    value_file    = "values/temporal.yaml"
    override_file = "values/${local.name}.yaml"
    namespace     = "temporal"
    frontend_url  = "temporal-frontend.${local.zone}"
    web_url       = "temporal-ui.${local.zone}"
  }
  db = {
    default = {
      username = "temporal"
      password = data.aws_secretsmanager_secret_version.db_default_password.secret_string
    }
    visibility = {
      username = "temporal_visibility"
      password = data.aws_secretsmanager_secret_version.db_visibility_password.secret_string
    }
  }
  # environment = local.tags.environment
}

data "aws_secretsmanager_secret_version" "db_default_password" {
  secret_id = var.temporal_pw_secret_arn
}

data "aws_secretsmanager_secret_version" "db_visibility_password" {
  secret_id = var.temporal_visibility_pw_secret_arn
}

resource "helm_release" "temporal" {
  namespace        = local.temporal.namespace
  create_namespace = true

  name    = "temporal"
  version = local.temporal.version
  chart   = "https://github.com/temporalio/helm-charts/releases/download/temporal-${local.temporal.version}/temporal-${local.temporal.version}.tgz"

  values = [
    file(local.temporal.value_file),
    fileexists(local.temporal.override_file) ? file(local.temporal.override_file) : "",
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
            # repository = "431927561584.dkr.ecr.us-west-2.amazonaws.com/mirror/temporalio/admin-tools"
            # tag        = local.temporal.image_tag
          }
          topologySpreadConstraints = [
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
            # repository = "431927561584.dkr.ecr.us-west-2.amazonaws.com/mirror/temporalio/ui"
            # tag        = "2.34.0"
          }
          topologySpreadConstraints = [
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
        }
      }
    )
  ]
}
