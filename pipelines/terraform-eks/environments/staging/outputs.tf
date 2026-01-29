#──────────────────────────────────────────────────────────────────────────────
# VPC OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = local.subnet_ids
}

#──────────────────────────────────────────────────────────────────────────────
# EKS OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "monitoring_enabled" {
  description = "Monitoring enabled"
  value       = var.enable_monitoring
}

output "grafana_port_forward" {
  description = "Grafana port forward command"
  value       = var.enable_monitoring ? module.monitoring[0].grafana_port_forward_command : "Monitoring not enabled"
}
