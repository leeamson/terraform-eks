terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# PROVIDERS
#──────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

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
# DATA SOURCES - EXISTING VPC
#──────────────────────────────────────────────────────────────────────────────

data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

locals {
  vpc_id     = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  subnet_ids = var.use_existing_vpc ? var.existing_subnet_ids : module.vpc[0].subnet_ids
}

#──────────────────────────────────────────────────────────────────────────────
# VPC MODULE
#──────────────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"
  count  = var.use_existing_vpc ? 0 : 1

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
}

#──────────────────────────────────────────────────────────────────────────────
# EKS MODULE
#──────────────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = local.vpc_id
  subnet_ids               = local.subnet_ids
  control_plane_subnet_ids = local.subnet_ids
  eks_managed_node_groups  = var.eks_managed_node_groups

  create_kms_key              = var.create_kms_key
  create_cloudwatch_log_group = var.create_cloudwatch_log_group
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING MODULE
#──────────────────────────────────────────────────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  depends_on = [module.eks]

  namespace              = var.monitoring_namespace
  environment            = var.environment
  release_name           = var.monitoring_release_name
  chart_version          = var.monitoring_chart_version
  grafana_admin_password = var.grafana_admin_password
  grafana_service_type   = var.grafana_service_type
}
