variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "release_name" {
  type    = string
  default = "kube-prometheus-stack"
}

variable "chart_version" {
  type    = string
  default = "58.2.1"
}

variable "helm_timeout" {
  type    = number
  default = 600
}

variable "storage_class_name" {
  type    = string
  default = "gp2"
}

variable "prometheus_enabled" {
  type    = bool
  default = true
}

variable "prometheus_retention" {
  type    = string
  default = "15d"
}

variable "prometheus_storage_enabled" {
  type    = bool
  default = true
}

variable "prometheus_storage_size" {
  type    = string
  default = "50Gi"
}

variable "prometheus_resources" {
  type = map(any)
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

variable "grafana_enabled" {
  type    = bool
  default = true
}

variable "grafana_admin_user" {
  type    = string
  default = "admin"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "grafana_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "grafana_persistence_enabled" {
  type    = bool
  default = true
}

variable "grafana_storage_size" {
  type    = string
  default = "10Gi"
}

variable "alertmanager_enabled" {
  type    = bool
  default = true
}

variable "node_exporter_enabled" {
  type    = bool
  default = true
}

variable "kube_state_metrics_enabled" {
  type    = bool
  default = true
}
