# ============================================================================
# Client Layer (04-client/production)
# ============================================================================
# This layer manages client-specific infrastructure including:
# - EKS NodeGroups (ezra-nodegroup, mtn-ghana-nodegroup)
# - Cluster Autoscaler
# - Client-specific IAM roles and policies
#
# Dependencies:
# - 02-platform layer (EKS cluster, OIDC provider)
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via -backend-config
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Layer      = "client"
      ManagedBy  = "terraform"
      Repository = "infrastructure"
    }
  }
}

# Get platform layer outputs from SSM
data "aws_ssm_parameter" "cluster_id" {
  name = "/terraform/${var.environment}/platform/cluster_id"
}

data "aws_ssm_parameter" "cluster_endpoint" {
  name = "/terraform/${var.environment}/platform/cluster_endpoint"
}

data "aws_ssm_parameter" "cluster_ca_certificate" {
  name = "/terraform/${var.environment}/platform/cluster_ca_certificate"
}

data "aws_ssm_parameter" "oidc_provider_arn" {
  name = "/terraform/${var.environment}/platform/oidc_provider_arn"
}

# Get foundation layer outputs from SSM parameters
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.environment}/${var.aws_region}/foundation/vpc_id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/${var.environment}/${var.aws_region}/foundation/private_subnets"
}

# Get secondary subnets for IP expansion (high-density workloads)
data "aws_ssm_parameter" "secondary_private_subnets" {
  name = "/${var.environment}/${var.aws_region}/foundation/secondary_private_subnets"
}

# Get VPC and subnet information from foundation layer
locals {
  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  private_subnets     = split(",", data.aws_ssm_parameter.private_subnets.value)
  secondary_subnets   = split(",", data.aws_ssm_parameter.secondary_private_subnets.value)
  cluster_name        = data.aws_ssm_parameter.cluster_id.value
}

# Configure Kubernetes and Helm providers
provider "kubernetes" {
  host                   = data.aws_ssm_parameter.cluster_endpoint.value
  cluster_ca_certificate = base64decode(data.aws_ssm_parameter.cluster_ca_certificate.value)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_ssm_parameter.cluster_endpoint.value
    cluster_ca_certificate = base64decode(data.aws_ssm_parameter.cluster_ca_certificate.value)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }
}

# ============================================================================
# Multi-Client NodeGroups
# ============================================================================

module "client_nodegroups" {
  source = "../../../../../modules/multi-client-nodegroups"
  
  cluster_name    = local.cluster_name
  vpc_id          = local.vpc_id
  private_subnets = local.private_subnets
  environment     = var.environment
  ec2_key_name    = "terraform-key"
  
  client_nodegroups = {
    ezra = {
      # Instance configuration - RESTORED to working state
      capacity_type  = "ON_DEMAND"
      instance_types = ["m5.large", "m5a.large", "t3.xlarge", "c5.large"]
      
      # Auto-scaling configuration
      desired_size = 2
      max_size     = 4
      min_size     = 1
      
      # Update configuration
      max_unavailable_percentage = 25
      
      # Workload classification
      tier        = "general"
      workload    = "application"
      performance = "standard"
      
      # Isolation settings
      enable_client_isolation = true
      
      # No custom taints - allow normal pod scheduling
      custom_taints = []
      
      # 🔙 ROLLBACK: Disable IP optimization to restore working state
      enable_prefix_delegation = false
      max_pods_per_node = 17       # Default for m5.large
      use_launch_template = false  # Disable launch template
      disk_size = 20
      bootstrap_extra_args = ""
      dedicated_subnet_ids = []    # Use existing primary subnets
      
      # Additional labels
      extra_labels = {
        client_namespace = "ezra-client-a"
        cost_allocation  = "ezra-prod"
      }
      
      # Additional tags
      extra_tags = {
        Owner       = "ezra-team"
        CostCenter  = "ezra-production"
        BusinessUnit = "fintech"
      }
    }
    
    mtn-ghana = {
      # Instance configuration - RESTORED to working state
      capacity_type  = "ON_DEMAND"
      instance_types = ["m5.large", "m5a.large", "m5.xlarge", "c5.large"]
      
      # Auto-scaling configuration
      desired_size = 2
      max_size     = 5
      min_size     = 2
      
      # Update configuration
      max_unavailable_percentage = 25
      
      # Workload classification
      tier        = "general"
      workload    = "application"
      performance = "standard"
      
      # Isolation settings
      enable_client_isolation = true
      
      # No custom taints - allow normal pod scheduling
      custom_taints = []
      
      # 🔙 ROLLBACK: Disable IP optimization to restore working state
      enable_prefix_delegation = false  # Disable IP optimization
      max_pods_per_node = 17           # Default for current instance types
      use_launch_template = false      # Disable launch template
      disk_size = 20
      bootstrap_extra_args = ""
      dedicated_subnet_ids = []        # Use existing primary subnets
      
      # Additional labels
      extra_labels = {
        client_namespace = "us-east-1-test"
        cost_allocation  = "mtn-ghana-prod"
      }
      
      # Additional tags
      extra_tags = {
        Owner        = "mtn-ghana-database-team"
        CostCenter   = "mtn-ghana-production"
        BusinessUnit = "telecommunications"
      }
    }
    
  }
}

# ============================================================================
# Cluster Autoscaler
# ============================================================================

module "cluster_autoscaler" {
  source = "../../../../../modules/cluster-autoscaler"
  
  cluster_name      = local.cluster_name
  cluster_oidc_issuer_url = data.aws_ssm_parameter.oidc_provider_arn.value
  
  depends_on = [module.client_nodegroups]
}

# ============================================================================
# Store client layer outputs in SSM
# ============================================================================

resource "aws_ssm_parameter" "nodegroups" {
  name  = "/terraform/${var.environment}/client/nodegroups"
  type  = "String"
  value = jsonencode({
    ezra      = module.client_nodegroups.client_nodegroups["ezra"].arn
    mtn-ghana = module.client_nodegroups.client_nodegroups["mtn-ghana"].arn
  })

  tags = {
    Environment = var.environment
    Layer      = "client"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "cluster_autoscaler_enabled" {
  name  = "/terraform/${var.environment}/client/cluster_autoscaler_enabled"
  type  = "String"
  value = "true"

  tags = {
    Environment = var.environment
    Layer      = "client"
    ManagedBy  = "terraform"
  }
}
