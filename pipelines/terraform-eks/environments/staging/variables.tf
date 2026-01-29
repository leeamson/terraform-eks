#──────────────────────────────────────────────────────────────────────────────
# GENERAL
#──────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

#──────────────────────────────────────────────────────────────────────────────
# VPC
#──────────────────────────────────────────────────────────────────────────────

variable "use_existing_vpc" {
  description = "Use existing VPC"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = ""
}

variable "existing_subnet_ids" {
  description = "Existing subnet IDs"
  type        = list(string)
  default     = []
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "Subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

#──────────────────────────────────────────────────────────────────────────────
# EKS
#──────────────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups"
  type        = any
}

variable "create_kms_key" {
  description = "Create KMS key"
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Create CloudWatch log group"
  type        = bool
  default     = false
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING
#──────────────────────────────────────────────────────────────────────────────

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = false
}

variable "monitoring_namespace" {
  description = "Monitoring namespace"
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Monitoring release name"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Monitoring chart version"
  type        = string
  default     = "58.2.1"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Grafana service type"
  type        = string
  default     = "ClusterIP"
}
