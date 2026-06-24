resource "kubectl_manifest" "clickhouse_keeper_installation" {
  yaml_body = yamlencode({
    "apiVersion" = "clickhouse-keeper.altinity.com/v1"
    "kind"       = "ClickHouseKeeperInstallation"
    "metadata" = {
      "name"      = "clickhouse-keeper"
      "namespace" = "clickhouse"
    }
    "spec" = {
      "defaults" = {
        "templates" = {
          "podTemplate" = "default"
        }
      }
      "configuration" = {
        "clusters" = [
          {
            "layout" = {
              "replicasCount" = 3
            }
            "name" = "chk-simple"
          },
        ]
        "settings" = {
          "keeper_server/coordination_settings/raft_logs_level" = "information"
          "keeper_server/four_letter_word_white_list"           = "*"
          "keeper_server/raft_configuration/server/port"        = "9444"
          "keeper_server/storage_path"                          = "/var/lib/clickhouse-keeper"
          "keeper_server/tcp_port"                              = "2181"
          "listen_host"                                         = "0.0.0.0"
          "logger/console"                                      = "true"
          "logger/level"                                        = "warning"
          "prometheus/asynchronous_metrics"                     = "true"
          "prometheus/endpoint"                                 = "/metrics"
          "prometheus/events"                                   = "true"
          "prometheus/metrics"                                  = "true"
          "prometheus/port"                                     = "7000"
          "prometheus/status_info"                              = "false"
        }
      }
      "templates" = {
        "serviceTemplates" = [{
          "name" = "default"
          "metadata" = {
            "namespace" = "clickhouse"
          }
          "spec" = {
            "ports" = [
              {
                "name"       = "tcp"
                "port"       = 2181
                "targetPort" = 2181
              }
            ]
          }
        }]
        "podTemplates" = [
          {
            "name" = "default"
            "spec" = {
              "securityContext" = {
                "fsGroup"   = 101
                "runAsUser" = 101
              }
              # spread the 3 keeper replicas onto distinct nodes so a single node failure
              # cannot take out the raft quorum. the regional pool has >=1 node per zone
              # (3 zones), so DoNotSchedule/minDomains=3 is satisfiable and naturally
              # spreads the quorum across zones. label is applied automatically by the CRD.
              # NOTE: no nodeSelector/tolerations on GCP (single autoscaling pool, no taints).
              "topologySpreadConstraints" = [
                # hard: the 3 keeper replicas must land on distinct nodes.
                {
                  "maxSkew"           = 1
                  "topologyKey"       = "kubernetes.io/hostname"
                  "whenUnsatisfiable" = "DoNotSchedule"
                  "minDomains"        = 3
                  "labelSelector" = {
                    "matchLabels" = {
                      # verified against live pods; the AWS install's "app=clickhouse-keeper"
                      # label does not exist on this keeper CRD version.
                      "clickhouse-keeper.altinity.com/chk" = "clickhouse-keeper"
                    }
                  }
                },
                # soft: strongly prefer one replica per zone so a single zonal outage
                # cannot take out raft quorum (observed pre-fix: 2 of 3 keepers in one zone).
                # soft (not DoNotSchedule) so a capacity-constrained zone can't strand a replica.
                {
                  "maxSkew"           = 1
                  "topologyKey"       = "topology.kubernetes.io/zone"
                  "whenUnsatisfiable" = "ScheduleAnyway"
                  "labelSelector" = {
                    "matchLabels" = {
                      "clickhouse-keeper.altinity.com/chk" = "clickhouse-keeper"
                    }
                  }
                }
              ]
              "containers" = [
                {
                  "image"           = "${var.keeper_image_repository}:${var.keeper_image_tag}"
                  "imagePullPolicy" = "IfNotPresent"
                  "name"            = "clickhouse-keeper"
                  "resources" = {
                    "limits" = {
                      "cpu"    = "2"
                      "memory" = "4Gi"
                    }
                    "requests" = {
                      "cpu"    = "1"
                      "memory" = "256M"
                    }
                  }
                },
              ]
            }
          }
        ]
        "volumeClaimTemplates" = [
          {
            "name" = "default"
            "metadata" = {
              "name" = "both-paths"
            }
            "spec" = {
              "storageClassName" = "ssd"
              "accessModes" = [
                "ReadWriteOnce",
              ]
              "resources" = {
                "requests" = {
                  "storage" = "10Gi"
                }
              }
            }
          }
        ]
      }
    }
  })
}
