#!/bin/bash

# =============================================================================
# Script: create-terraform-structure.sh
# Description: Creates a modular Terraform project structure for AWS EKS
# Usage: ./create-terraform-structure.sh [project-name]
# =============================================================================

set -e  # Exit on error

# Project name (default or from argument)
PROJECT_NAME="${1:-terraform-eks-project}"

echo "🚀 Creating Terraform project: $PROJECT_NAME"
echo "================================================"

# -----------------------------------------------------------------------------
# Create Directory Structure
# -----------------------------------------------------------------------------
echo "📁 Creating directory structure..."

mkdir -p "$PROJECT_NAME/modules/vpc"
mkdir -p "$PROJECT_NAME/modules/eks"

# -----------------------------------------------------------------------------
# Root Module Files
# -----------------------------------------------------------------------------
echo "📄 Creating root module files..."

# main.tf
cat > "$PROJECT_NAME/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.subnet_ids
  control_plane_subnet_ids = module.vpc.subnet_ids
  eks_managed_node_groups  = var.eks_managed_node_groups
}
EOF

# variables.tf
cat > "$PROJECT_NAME/variables.tf" << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups configuration"
  type        = any
  default = {
    green = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }
}
EOF

# outputs.tf
cat > "$PROJECT_NAME/outputs.tf" << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = module.vpc.subnet_ids
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}
EOF

# terraform.tfvars
cat > "$PROJECT_NAME/terraform.tfvars" << 'EOF'
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
EOF

# -----------------------------------------------------------------------------
# VPC Module Files
# -----------------------------------------------------------------------------
echo "📄 Creating VPC module files..."

# modules/vpc/main.tf
cat > "$PROJECT_NAME/modules/vpc/main.tf" << 'EOF'
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.map_public_ip

  tags = {
    Name = "${var.vpc_name}-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.vpc_name}-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main.id
}
EOF

# modules/vpc/variables.tf
cat > "$PROJECT_NAME/modules/vpc/variables.tf" << 'EOF'
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "map_public_ip" {
  description = "Map public IP on launch"
  type        = bool
  default     = true
}
EOF

# modules/vpc/outputs.tf
cat > "$PROJECT_NAME/modules/vpc/outputs.tf" << 'EOF'
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
EOF

# -----------------------------------------------------------------------------
# EKS Module Files
# -----------------------------------------------------------------------------
echo "📄 Creating EKS module files..."

# modules/eks/main.tf
cat > "$PROJECT_NAME/modules/eks/main.tf" << 'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  cluster_addons = var.cluster_addons

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  eks_managed_node_groups = var.eks_managed_node_groups
}
EOF

# modules/eks/variables.tf
cat > "$PROJECT_NAME/modules/eks/variables.tf" << 'EOF'
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_addons" {
  description = "Map of cluster addons"
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for worker nodes"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for control plane"
  type        = list(string)
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
  default = {
    green = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }
}
EOF

# modules/eks/outputs.tf
cat > "$PROJECT_NAME/modules/eks/outputs.tf" << 'EOF'
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the cluster"
  value       = module.eks.cluster_security_group_id
}
EOF

# -----------------------------------------------------------------------------
# Create .gitignore
# -----------------------------------------------------------------------------
echo "📄 Creating .gitignore..."

cat > "$PROJECT_NAME/.gitignore" << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
*.tfvars.json

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

# -----------------------------------------------------------------------------
# Create README.md
# -----------------------------------------------------------------------------
echo "📄 Creating README.md..."

cat > "$PROJECT_NAME/README.md" << 'EOF'
# Terraform EKS Project

This project creates an AWS EKS cluster with a custom VPC using modular Terraform configuration.

## Structure

