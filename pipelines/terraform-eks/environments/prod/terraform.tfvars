#──────────────────────────────────────────────────────────────────────────────
# General Configuration
#──────────────────────────────────────────────────────────────────────────────
aws_region   = "eu-west-1"
environment  = "prod"
project_name = "eks-project"

#──────────────────────────────────────────────────────────────────────────────
# VPC Configuration
#──────────────────────────────────────────────────────────────────────────────
use_existing_vpc = true
existing_vpc_id  = "vpc-XXXXXXXXX"  # UPDATE THIS

existing_subnet_ids = [
  "subnet-XXXXXXXXX",  # UPDATE THIS
  "subnet-XXXXXXXXX",
  "subnet-XXXXXXXXX"
]

# If creating new VPC (set use_existing_vpc = false)
vpc_name           = "prod-vpc"
vpc_cidr           = "10.0.0.0/16"
subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

#──────────────────────────────────────────────────────────────────────────────
# EKS Configuration
#──────────────────────────────────────────────────────────────────────────────
cluster_name    = "eks-cluster-prod"
cluster_version = "1.31"

create_kms_key              = false
create_cloudwatch_log_group = false

eks_managed_node_groups = {
  general = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["m5.xlarge"]
    min_size       = 3
    max_size       = 10
    desired_size   = 5
    
    labels = {
      Environment = "prod"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# Monitoring Configuration
#──────────────────────────────────────────────────────────────────────────────
enable_monitoring        = false
monitoring_namespace     = "monitoring"
monitoring_release_name  = "kube-prometheus-stack"
monitoring_chart_version = "58.2.1"
grafana_service_type     = "ClusterIP"

# grafana_admin_password is passed via CI/CD secrets
