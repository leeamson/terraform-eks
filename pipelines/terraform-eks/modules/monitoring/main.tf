terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      name       = var.namespace
      managed-by = "terraform"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  depends_on = [kubernetes_namespace.monitoring]
  timeout    = var.helm_timeout

  values = [
    yamlencode({
      fullnameOverride = var.release_name

      prometheus = {
        enabled = var.prometheus_enabled
        prometheusSpec = {
          retention     = var.prometheus_retention
          resources     = var.prometheus_resources
          storageSpec = var.prometheus_storage_enabled ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          } : null
        }
      }

      grafana = {
        enabled       = var.grafana_enabled
        adminUser     = var.grafana_admin_user
        adminPassword = var.grafana_admin_password
        service = {
          type = var.grafana_service_type
        }
        persistence = {
          enabled = var.grafana_persistence_enabled
          size    = var.grafana_storage_size
        }
      }

      alertmanager = {
        enabled = var.alertmanager_enabled
      }

      nodeExporter = {
        enabled = var.node_exporter_enabled
      }

      kubeStateMetrics = {
        enabled = var.kube_state_metrics_enabled
      }

      kubeControllerManager = { enabled = false }
      kubeScheduler         = { enabled = false }
      kubeEtcd              = { enabled = false }
    })
  ]
}
