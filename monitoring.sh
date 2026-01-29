#!/bin/bash

# =============================================================================
# Script: add-monitoring-module.sh
# Description: Adds the monitoring module to an existing Terraform project
# Usage: ./add-monitoring-module.sh [project-path]
# =============================================================================

set -e

# Project path (default to current directory)
PROJECT_PATH="${1:-.}"

echo "🚀 Adding Monitoring Module to: $PROJECT_PATH"
echo "================================================"

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Project directory not found: $PROJECT_PATH"
    exit 1
fi

# Check if modules directory exists
if [ ! -d "$PROJECT_PATH/modules" ]; then
    echo "❌ Error: modules directory not found. Is this a Terraform project?"
    exit 1
fi

# Create monitoring module directory
echo "📁 Creating monitoring module directory..."
mkdir -p "$PROJECT_PATH/modules/monitoring/dashboards"

# -----------------------------------------------------------------------------
# Create modules/monitoring/main.tf
# -----------------------------------------------------------------------------
echo "📄 Creating modules/monitoring/main.tf..."

cat > "$PROJECT_PATH/modules/monitoring/main.tf" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# MONITORING MODULE
# Deploys Prometheus, Grafana, and Alertmanager using kube-prometheus-stack
#──────────────────────────────────────────────────────────────────────────────

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

#──────────────────────────────────────────────────────────────────────────────
# NAMESPACE
#──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      managed-by  = "terraform"
      environment = var.environment
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# KUBE-PROMETHEUS-STACK HELM RELEASE
#──────────────────────────────────────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  depends_on = [kubernetes_namespace.monitoring]

  timeout = var.helm_timeout

  values = [
    yamlencode({
      #────────────────────────────────────────────────────────────────────────
      # GLOBAL SETTINGS
      #────────────────────────────────────────────────────────────────────────
      fullnameOverride = var.release_name

      #────────────────────────────────────────────────────────────────────────
      # PROMETHEUS CONFIGURATION
      #────────────────────────────────────────────────────────────────────────
      prometheus = {
        enabled = var.prometheus_enabled

        prometheusSpec = {
          resources     = var.prometheus_resources
          retention     = var.prometheus_retention
          retentionSize = var.prometheus_retention_size

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

          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          additionalScrapeConfigs                 = var.additional_scrape_configs
        }

        service = {
          type = var.prometheus_service_type
          port = 9090
        }
      }

      #────────────────────────────────────────────────────────────────────────
      # GRAFANA CONFIGURATION
      #────────────────────────────────────────────────────────────────────────
      grafana = {
        enabled       = var.grafana_enabled
        adminUser     = var.grafana_admin_user
        adminPassword = var.grafana_admin_password
        resources     = var.grafana_resources

        service = {
          type = var.grafana_service_type
          port = 80
        }

        ingress = {
          enabled     = var.grafana_ingress_enabled
          hosts       = var.grafana_ingress_hosts
          path        = "/"
          annotations = var.grafana_ingress_annotations
        }

        persistence = {
          enabled          = var.grafana_persistence_enabled
          storageClassName = var.storage_class_name
          size             = var.grafana_storage_size
          accessModes      = ["ReadWriteOnce"]
        }

        defaultDashboardsEnabled  = true
        defaultDashboardsTimezone = var.grafana_default_timezone
        additionalDataSources     = var.grafana_additional_datasources

        sidecar = {
          dashboards = {
            enabled          = true
            searchNamespace  = "ALL"
            label            = "grafana_dashboard"
            folderAnnotation = "grafana_folder"
          }
          datasources = {
            enabled         = true
            searchNamespace = "ALL"
            label           = "grafana_datasource"
          }
        }

        "grafana.ini" = {
          server = {
            root_url = var.grafana_root_url
          }
          auth = {
            disable_login_form = false
          }
          "auth.anonymous" = {
            enabled  = var.grafana_anonymous_enabled
            org_role = "Viewer"
          }
          security = {
            allow_embedding = true
          }
        }

        plugins = var.grafana_plugins
      }

      #────────────────────────────────────────────────────────────────────────
      # ALERTMANAGER CONFIGURATION
      #────────────────────────────────────────────────────────────────────────
      alertmanager = {
        enabled = var.alertmanager_enabled

        alertmanagerSpec = {
          resources = var.alertmanager_resources

          storage = var.alertmanager_storage_enabled ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          } : null
        }

        config = var.alertmanager_config

        service = {
          type = var.alertmanager_service_type
          port = 9093
        }
      }

      #────────────────────────────────────────────────────────────────────────
      # NODE EXPORTER CONFIGURATION
      #────────────────────────────────────────────────────────────────────────
      nodeExporter = {
        enabled = var.node_exporter_enabled
      }

      prometheus-node-exporter = {
        resources = var.node_exporter_resources
      }

      #────────────────────────────────────────────────────────────────────────
      # KUBE STATE METRICS CONFIGURATION
      #────────────────────────────────────────────────────────────────────────
      kubeStateMetrics = {
        enabled = var.kube_state_metrics_enabled
      }

      kube-state-metrics = {
        resources = var.kube_state_metrics_resources
      }

      #────────────────────────────────────────────────────────────────────────
      # ADDITIONAL COMPONENTS (EKS-specific settings)
      #────────────────────────────────────────────────────────────────────────
      kubeApiServer = {
        enabled = true
      }

      kubelet = {
        enabled = true
      }

      kubeControllerManager = {
        enabled = false  # Not accessible in EKS
      }

      kubeScheduler = {
        enabled = false  # Not accessible in EKS
      }

      kubeProxy = {
        enabled = true
      }

      kubeEtcd = {
        enabled = false  # Not accessible in EKS
      }

      #────────────────────────────────────────────────────────────────────────
      # DEFAULT RULES
      #────────────────────────────────────────────────────────────────────────
      defaultRules = {
        create = var.default_rules_enabled
        rules = {
          alertmanager                = true
          etcd                        = false
          configReloaders             = true
          general                     = true
          k8s                         = true
          kubeApiserverAvailability   = true
          kubeApiserverBurnrate       = true
          kubeApiserverHistogram      = true
          kubeApiserverSlos           = true
          kubeControllerManager       = false
          kubelet                     = true
          kubeProxy                   = true
          kubePrometheusGeneral       = true
          kubePrometheusNodeRecording = true
          kubernetesApps              = true
          kubernetesResources         = true
          kubernetesStorage           = true
          kubernetesSystem            = true
          kubeScheduler               = false
          kubeStateMetrics            = true
          network                     = true
          node                        = true
          nodeExporterAlerting        = true
          nodeExporterRecording       = true
          prometheus                  = true
          prometheusOperator          = true
        }
      }
    })
  ]

  dynamic "set" {
    for_each = var.additional_set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# CUSTOM CONFIGMAP FOR ADDITIONAL DASHBOARDS
#──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_config_map" "grafana_dashboards" {
  count = var.custom_dashboards_enabled ? 1 : 0

  metadata {
    name      = "custom-grafana-dashboards"
    namespace = var.namespace

    labels = {
      grafana_dashboard = "1"
    }

    annotations = {
      grafana_folder = "Custom"
    }
  }

  data = var.custom_dashboards

  depends_on = [helm_release.kube_prometheus_stack]
}

#──────────────────────────────────────────────────────────────────────────────
# SERVICE MONITOR FOR CUSTOM APPLICATIONS
#──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_manifest" "custom_service_monitors" {
  for_each = var.custom_service_monitors

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = each.key
      namespace = var.namespace
      labels = {
        release = var.release_name
      }
    }

    spec = each.value
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
EOF

# -----------------------------------------------------------------------------
# Create modules/monitoring/variables.tf
# -----------------------------------------------------------------------------
echo "📄 Creating modules/monitoring/variables.tf..."

cat > "$PROJECT_PATH/modules/monitoring/variables.tf" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# GENERAL VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "Kube-prometheus-stack Helm chart version"
  type        = string
  default     = "58.2.1"
}

variable "helm_timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 600
}

variable "storage_class_name" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp2"
}

#──────────────────────────────────────────────────────────────────────────────
# PROMETHEUS VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "prometheus_enabled" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_retention_size" {
  description = "Maximum size of Prometheus data"
  type        = string
  default     = "10GB"
}

variable "prometheus_storage_enabled" {
  description = "Enable persistent storage for Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_storage_size" {
  description = "Size of Prometheus persistent volume"
  type        = string
  default     = "50Gi"
}

variable "prometheus_service_type" {
  description = "Kubernetes service type for Prometheus"
  type        = string
  default     = "ClusterIP"
}

variable "prometheus_resources" {
  description = "Resource limits for Prometheus"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "additional_scrape_configs" {
  description = "Additional Prometheus scrape configurations"
  type        = list(any)
  default     = []
}

#──────────────────────────────────────────────────────────────────────────────
# GRAFANA VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Kubernetes service type for Grafana"
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_ingress_enabled" {
  description = "Enable ingress for Grafana"
  type        = bool
  default     = false
}

variable "grafana_ingress_hosts" {
  description = "Ingress hosts for Grafana"
  type        = list(string)
  default     = ["grafana.local"]
}

variable "grafana_ingress_annotations" {
  description = "Ingress annotations for Grafana"
  type        = map(string)
  default     = {}
}

variable "grafana_persistence_enabled" {
  description = "Enable persistent storage for Grafana"
  type        = bool
  default     = true
}

variable "grafana_storage_size" {
  description = "Size of Grafana persistent volume"
  type        = string
  default     = "10Gi"
}

variable "grafana_resources" {
  description = "Resource limits for Grafana"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "grafana_root_url" {
  description = "Grafana root URL"
  type        = string
  default     = "http://localhost:3000"
}

variable "grafana_anonymous_enabled" {
  description = "Enable anonymous access to Grafana"
  type        = bool
  default     = false
}

variable "grafana_default_timezone" {
  description = "Default timezone for Grafana dashboards"
  type        = string
  default     = "browser"
}

variable "grafana_plugins" {
  description = "List of Grafana plugins to install"
  type        = list(string)
  default = [
    "grafana-clock-panel",
    "grafana-piechart-panel",
    "grafana-worldmap-panel"
  ]
}

variable "grafana_additional_datasources" {
  description = "Additional data sources for Grafana"
  type        = list(any)
  default     = []
}

#──────────────────────────────────────────────────────────────────────────────
# ALERTMANAGER VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "alertmanager_enabled" {
  description = "Enable Alertmanager"
  type        = bool
  default     = true
}

variable "alertmanager_service_type" {
  description = "Kubernetes service type for Alertmanager"
  type        = string
  default     = "ClusterIP"
}

variable "alertmanager_storage_enabled" {
  description = "Enable persistent storage for Alertmanager"
  type        = bool
  default     = false
}

variable "alertmanager_storage_size" {
  description = "Size of Alertmanager persistent volume"
  type        = string
  default     = "5Gi"
}

variable "alertmanager_resources" {
  description = "Resource limits for Alertmanager"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

variable "alertmanager_config" {
  description = "Alertmanager configuration"
  type        = any
  default = {
    global = {
      resolve_timeout = "5m"
    }
    route = {
      group_by        = ["alertname", "namespace"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      receiver        = "null"
      routes = [
        {
          match = {
            alertname = "Watchdog"
          }
          receiver = "null"
        }
      ]
    }
    receivers = [
      {
        name = "null"
      }
    ]
  }
}

#──────────────────────────────────────────────────────────────────────────────
# NODE EXPORTER VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "node_exporter_enabled" {
  description = "Enable Node Exporter"
  type        = bool
  default     = true
}

variable "node_exporter_resources" {
  description = "Resource limits for Node Exporter"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "64Mi"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# KUBE STATE METRICS VARIABLES
#──────────────────────────────────────────────────────────────────────────────

variable "kube_state_metrics_enabled" {
  description = "Enable Kube State Metrics"
  type        = bool
  default     = true
}

variable "kube_state_metrics_resources" {
  description = "Resource limits for Kube State Metrics"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# RULES AND ALERTS
#──────────────────────────────────────────────────────────────────────────────

variable "default_rules_enabled" {
  description = "Enable default Prometheus rules"
  type        = bool
  default     = true
}

#──────────────────────────────────────────────────────────────────────────────
# CUSTOM DASHBOARDS
#──────────────────────────────────────────────────────────────────────────────

variable "custom_dashboards_enabled" {
  description = "Enable custom Grafana dashboards"
  type        = bool
  default     = false
}

variable "custom_dashboards" {
  description = "Map of custom dashboard JSON files"
  type        = map(string)
  default     = {}
}

#──────────────────────────────────────────────────────────────────────────────
# CUSTOM SERVICE MONITORS
#──────────────────────────────────────────────────────────────────────────────

variable "custom_service_monitors" {
  description = "Map of custom ServiceMonitor specs"
  type        = map(any)
  default     = {}
}

#──────────────────────────────────────────────────────────────────────────────
# ADDITIONAL HELM VALUES
#──────────────────────────────────────────────────────────────────────────────

variable "additional_set_values" {
  description = "Additional Helm set values"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
EOF

# -----------------------------------------------------------------------------
# Create modules/monitoring/outputs.tf
# -----------------------------------------------------------------------------
echo "📄 Creating modules/monitoring/outputs.tf..."

cat > "$PROJECT_PATH/modules/monitoring/outputs.tf" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# GENERAL OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "namespace" {
  description = "Namespace where monitoring stack is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}

output "chart_version" {
  description = "Deployed Helm chart version"
  value       = helm_release.kube_prometheus_stack.version
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.kube_prometheus_stack.status
}

#──────────────────────────────────────────────────────────────────────────────
# PROMETHEUS OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "prometheus_service_name" {
  description = "Prometheus service name"
  value       = "${var.release_name}-prometheus"
}

output "prometheus_service_port" {
  description = "Prometheus service port"
  value       = 9090
}

output "prometheus_internal_url" {
  description = "Internal URL for Prometheus"
  value       = "http://${var.release_name}-prometheus.${var.namespace}.svc.cluster.local:9090"
}

#──────────────────────────────────────────────────────────────────────────────
# GRAFANA OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "grafana_service_name" {
  description = "Grafana service name"
  value       = "${var.release_name}-grafana"
}

output "grafana_service_port" {
  description = "Grafana service port"
  value       = 80
}

output "grafana_internal_url" {
  description = "Internal URL for Grafana"
  value       = "http://${var.release_name}-grafana.${var.namespace}.svc.cluster.local:80"
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = var.grafana_admin_user
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

#──────────────────────────────────────────────────────────────────────────────
# ALERTMANAGER OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "alertmanager_service_name" {
  description = "Alertmanager service name"
  value       = "${var.release_name}-alertmanager"
}

output "alertmanager_service_port" {
  description = "Alertmanager service port"
  value       = 9093
}

output "alertmanager_internal_url" {
  description = "Internal URL for Alertmanager"
  value       = "http://${var.release_name}-alertmanager.${var.namespace}.svc.cluster.local:9093"
}

#──────────────────────────────────────────────────────────────────────────────
# ACCESS COMMANDS
#──────────────────────────────────────────────────────────────────────────────

output "grafana_port_forward_command" {
  description = "Command to port-forward Grafana"
  value       = "kubectl port-forward svc/${var.release_name}-grafana -n ${var.namespace} 3000:80"
}

output "prometheus_port_forward_command" {
  description = "Command to port-forward Prometheus"
  value       = "kubectl port-forward svc/${var.release_name}-prometheus -n ${var.namespace} 9090:9090"
}

output "alertmanager_port_forward_command" {
  description = "Command to port-forward Alertmanager"
  value       = "kubectl port-forward svc/${var.release_name}-alertmanager -n ${var.namespace} 9093:9093"
}

#──────────────────────────────────────────────────────────────────────────────
# USEFUL KUBECTL COMMANDS
#──────────────────────────────────────────────────────────────────────────────

output "get_grafana_password_command" {
  description = "Command to get Grafana admin password from secret"
  value       = "kubectl get secret ${var.release_name}-grafana -n ${var.namespace} -o jsonpath='{.data.admin-password}' | base64 -d"
}

output "get_all_pods_command" {
  description = "Command to get all monitoring pods"
  value       = "kubectl get pods -n ${var.namespace}"
}

output "get_all_services_command" {
  description = "Command to get all monitoring services"
  value       = "kubectl get svc -n ${var.namespace}"
}
EOF

# -----------------------------------------------------------------------------
# Create sample custom dashboard
# -----------------------------------------------------------------------------
echo "📄 Creating sample dashboard..."

cat > "$PROJECT_PATH/modules/monitoring/dashboards/sample-dashboard.json" << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "refId": "A"
        }
      ],
      "title": "Memory Usage",
      "type": "gauge"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["custom", "overview"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Custom Overview Dashboard",
  "uid": "custom-overview",
  "version": 1,
  "weekStart": ""
}
EOF

# -----------------------------------------------------------------------------
# Update root main.tf to include monitoring module
# -----------------------------------------------------------------------------
echo "📄 Creating root main.tf update snippet..."

cat > "$PROJECT_PATH/main.tf.monitoring-snippet" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# ADD THESE PROVIDER CONFIGURATIONS TO YOUR main.tf
#──────────────────────────────────────────────────────────────────────────────

# Add to your required_providers block:
#    helm = {
#      source  = "hashicorp/helm"
#      version = "~> 2.12"
#    }
#    kubernetes = {
#      source  = "hashicorp/kubernetes"
#      version = "~> 2.25"
#    }

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING MODULE
#──────────────────────────────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  depends_on = [module.eks]

  # General settings
  namespace     = var.monitoring_namespace
  environment   = var.environment
  release_name  = var.monitoring_release_name
  chart_version = var.monitoring_chart_version

  # Prometheus settings
  prometheus_enabled      = var.prometheus_enabled
  prometheus_retention    = var.prometheus_retention
  prometheus_storage_size = var.prometheus_storage_size
  prometheus_resources    = var.prometheus_resources

  # Grafana settings
  grafana_enabled        = var.grafana_enabled
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password
  grafana_service_type   = var.grafana_service_type
  grafana_storage_size   = var.grafana_storage_size
  grafana_plugins        = var.grafana_plugins

  # Alertmanager settings
  alertmanager_enabled = var.alertmanager_enabled
  alertmanager_config  = var.alertmanager_config

  # Component toggles
  node_exporter_enabled      = var.node_exporter_enabled
  kube_state_metrics_enabled = var.kube_state_metrics_enabled
}
EOF

# -----------------------------------------------------------------------------
# Create variables snippet for root variables.tf
# -----------------------------------------------------------------------------
echo "📄 Creating root variables.tf update snippet..."

cat > "$PROJECT_PATH/variables.tf.monitoring-snippet" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# ADD THESE VARIABLES TO YOUR variables.tf
#──────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Helm release name for monitoring stack"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Kube-prometheus-stack Helm chart version"
  type        = string
  default     = "58.2.1"
}

# Prometheus
variable "prometheus_enabled" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Size of Prometheus persistent volume"
  type        = string
  default     = "50Gi"
}

variable "prometheus_resources" {
  description = "Resource limits for Prometheus"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

# Grafana
variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "[REDACTED:PASSWORD]"
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Kubernetes service type for Grafana"
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_storage_size" {
  description = "Size of Grafana persistent volume"
  type        = string
  default     = "10Gi"
}

variable "grafana_plugins" {
  description = "List of Grafana plugins to install"
  type        = list(string)
  default = [
    "grafana-clock-panel",
    "grafana-piechart-panel",
    "grafana-worldmap-panel"
  ]
}

# Alertmanager
variable "alertmanager_enabled" {
  description = "Enable Alertmanager"
  type        = bool
  default     = true
}

variable "alertmanager_config" {
  description = "Alertmanager configuration"
  type        = any
  default = {
    global = {
      resolve_timeout = "5m"
    }
    route = {
      group_by        = ["alertname", "namespace"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      receiver        = "null"
    }
    receivers = [
      {
        name = "null"
      }
    ]
  }
}

# Component toggles
variable "node_exporter_enabled" {
  description = "Enable Node Exporter"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable Kube State Metrics"
  type        = bool
  default     = true
}
EOF

# -----------------------------------------------------------------------------
# Create outputs snippet for root outputs.tf
# -----------------------------------------------------------------------------
echo "📄 Creating root outputs.tf update snippet..."

cat > "$PROJECT_PATH/outputs.tf.monitoring-snippet" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# ADD THESE OUTPUTS TO YOUR outputs.tf
#──────────────────────────────────────────────────────────────────────────────

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = module.monitoring.namespace
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

output "grafana_port_forward_command" {
  description = "Command to access Grafana locally"
  value       = module.monitoring.grafana_port_forward_command
}

output "prometheus_port_forward_command" {
  description = "Command to access Prometheus locally"
  value       = module.monitoring.prometheus_port_forward_command
}

output "alertmanager_port_forward_command" {
  description = "Command to access Alertmanager locally"
  value       = module.monitoring.alertmanager_port_forward_command
}

output "grafana_internal_url" {
  description = "Internal Grafana URL"
  value       = module.monitoring.grafana_internal_url
}

output "prometheus_internal_url" {
  description = "Internal Prometheus URL"
  value       = module.monitoring.prometheus_internal_url
}
EOF

# -----------------------------------------------------------------------------
# Create terraform.tfvars snippet
# -----------------------------------------------------------------------------
echo "📄 Creating terraform.tfvars update snippet..."

cat > "$PROJECT_PATH/terraform.tfvars.monitoring-snippet" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# ADD THESE VALUES TO YOUR terraform.tfvars
#──────────────────────────────────────────────────────────────────────────────

# Environment
environment = "dev"

# Monitoring Configuration
monitoring_namespace     = "monitoring"
monitoring_release_name  = "kube-prometheus-stack"
monitoring_chart_version = "58.2.1"

# Prometheus
prometheus_enabled      = true
prometheus_retention    = "15d"
prometheus_storage_size = "50Gi"

prometheus_resources = {
  requests = {
    cpu    = "250m"
    memory = "512Mi"
  }
  limits = {
    cpu    = "1000m"
    memory = "2Gi"
  }
}

# Grafana
grafana_enabled        = true
grafana_admin_user     = "admin"
grafana_admin_password = [REDACTED:PASSWORD]!"  # CHANGE THIS!
grafana_service_type   = "LoadBalancer"            # Use "ClusterIP" for private
grafana_storage_size   = "10Gi"

grafana_plugins = [
  "grafana-clock-panel",
  "grafana-piechart-panel",
  "grafana-worldmap-panel",
  "grafana-kubernetes-app"
]

# Alertmanager
alertmanager_enabled = true

alertmanager_config = {
  global = {
    resolve_timeout = "5m"
  }
  route = {
    group_by        = ["alertname", "namespace"]
    group_wait      = "30s"
    group_interval  = "5m"
    repeat_interval = "4h"
    receiver        = "default-receiver"
  }
  receivers = [
    {
      name = "default-receiver"
    }
  ]
}

# Component toggles
node_exporter_enabled      = true
kube_state_metrics_enabled = true
EOF

# -----------------------------------------------------------------------------
# Create README for monitoring module
# -----------------------------------------------------------------------------
echo "📄 Creating monitoring module README..."

cat > "$PROJECT_PATH/modules/monitoring/README.md" << 'EOF'
# Monitoring Module

This module deploys a complete monitoring stack on Kubernetes using the kube-prometheus-stack Helm chart.

## Components

| Component | Description | Port |
|-----------|-------------|------|
| Prometheus | Metrics collection and storage | 9090 |
| Grafana | Visualization and dashboards | 80 |
| Alertmanager | Alert handling and routing | 9093 |
| Node Exporter | Hardware and OS metrics | 9100 |
| Kube State Metrics | Kubernetes object metrics | 8080 |

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  namespace              = "monitoring"
  environment            = "dev"
  grafana_admin_password = "your-secure-password"
  grafana_service_type   = "LoadBalancer"
}
