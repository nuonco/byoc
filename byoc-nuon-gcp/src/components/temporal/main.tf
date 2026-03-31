data "kubernetes_secret" "temporal_pw" {
  metadata {
    name      = "temporal-temporal-db-pw"
    namespace = "temporal"
  }
}

data "kubernetes_secret" "visibility_pw" {
  metadata {
    name      = "temporal-visibility-db-pw"
    namespace = "temporal"
  }
}

locals {
  temporal = {
    version      = "0.33.0"
    namespace    = "temporal"
    frontend_url = "temporal-frontend.${var.zone}"
    web_url      = "temporal-ui.${var.zone}"
  }
}

resource "helm_release" "temporal" {
  namespace        = local.temporal.namespace
  create_namespace = true

  name    = "temporal"
  version = local.temporal.version
  chart   = "https://github.com/temporalio/helm-charts/releases/download/temporal-${local.temporal.version}/temporal-${local.temporal.version}.tgz"

  values = [
    file("${path.module}/values/temporal.yaml"),
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
                  user     = var.db_default_username
                  password = data.kubernetes_secret.temporal_pw.data["value"]
                }
              }
              visibility = {
                sql = {
                  host     = var.db_instance_address
                  port     = var.db_instance_port
                  user     = var.db_visibility_username
                  password = data.kubernetes_secret.visibility_pw.data["value"]
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
          }
        }

        admintools = {
          image = {
            repository = var.temporal_admin_tools_image_repository
            tag        = var.temporal_admin_tools_image_tag
          }
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
