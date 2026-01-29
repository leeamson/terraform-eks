variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access"
  type        = bool
  default     = true
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

variable "cluster_addons" {
  description = "Cluster addons"
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Control plane subnet IDs"
  type        = list(string)
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups"
  type        = any
  default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
