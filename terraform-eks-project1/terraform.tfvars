aws_region         = "ap-south-1"
vpc_name           = "main-vpc"
vpc_cidr           = "10.0.0.0/16"
subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
cluster_name       = "eks-cluster"
cluster_version    = "1.31"

eks_managed_node_groups = {
  green = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["m5.xlarge"]
    min_size       = 1
    max_size       = 1
    desired_size   = 1
  }
}
