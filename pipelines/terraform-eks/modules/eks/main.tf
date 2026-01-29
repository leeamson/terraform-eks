module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Disable KMS and CloudWatch to avoid conflicts
  create_kms_key              = var.create_kms_key
  cluster_encryption_config   = var.create_kms_key ? {} : {}
  create_cloudwatch_log_group = var.create_cloudwatch_log_group
  cluster_enabled_log_types   = var.create_cloudwatch_log_group ? ["api", "audit", "authenticator"] : []

  cluster_addons = var.cluster_addons

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  eks_managed_node_groups = var.eks_managed_node_groups

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  tags = var.tags
}
