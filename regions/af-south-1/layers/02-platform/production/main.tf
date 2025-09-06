# 🏗️ Platform Layer - AF-South-1 Production
# EKS CLUSTER AND PLATFORM SERVICES
# Consumes foundation layer outputs to deploy EKS cluster

terraform {
  required_version = ">= 1.5"
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
    # Backend configuration loaded from file
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project            = "CPTWN-Multi-Client-EKS"
      Environment        = var.environment
      ManagedBy         = "Terraform"
      CriticalInfra     = "true"
      BackupRequired    = "true"
      SecurityLevel     = "High"
      Region            = var.region
      Layer             = "Platform"
      DeploymentPhase   = "Phase-2"
    }
  }
}

# 📊 DATA SOURCES - Foundation Layer Outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

# 🔍 LOCALS - Foundation Layer Data
locals {
  # Foundation layer outputs
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  platform_subnet_ids = data.terraform_remote_state.foundation.outputs.platform_subnet_ids
  vpc_cidr_block      = data.terraform_remote_state.foundation.outputs.vpc_cidr_block
  availability_zones  = data.terraform_remote_state.foundation.outputs.availability_zones
  
  # Platform configuration - shortened to avoid IAM role name length limits
  cluster_name = "${var.project_name}"
}

# ☸️ EKS PLATFORM - Using Multi-Region Wrapper Module
module "eks_platform" {
  source = "../../../../../modules/eks-platform"
  
  # Core CPTWN configuration
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  # Cluster configuration
  cluster_version = var.cluster_version
  
  # Network configuration from foundation layer
  vpc_id              = local.vpc_id
  platform_subnet_ids = local.platform_subnet_ids
  
  # Security configuration
  enable_public_access    = true
  management_cidr_blocks  = var.management_cidr_blocks
  log_retention_days      = 30
  
  # Multi-client node groups
  node_groups = {
    # MTN Ghana Client Node Group
    mtn_ghana_prod = {
      name_suffix    = "mtn-gh"
      instance_types = ["m5.large", "m5a.large", "t3.xlarge", "c5.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      disk_size      = 30
      
      # Client-specific configuration
      client  = "mtn-ghana-prod"
      purpose = "MTN Ghana Client Node Group"
      
      # Additional labels for this client
      labels = {
        NodeGroup = "client"
      }
    }
    
    # Orange Madagascar Client Node Group (Disabled - will be enabled later)
    # orange_madagascar_prod = {
    #   name_suffix    = "omm"
    #   instance_types = ["m5.large", "m5a.large", "t3.xlarge", "c5.large"]
    #   min_size       = 1
    #   max_size       = 3
    #   desired_size   = 2
    #   disk_size      = 30
    #   
    #   # Client-specific configuration
    #   client  = "orange-madagascar-prod"
    #   purpose = "Orange Madagascar Client Node Group"
    #   
    #   # Additional labels for this client
    #   labels = {
    #     NodeGroup = "client"
    #   }
    # }
  }
  
  # Access configuration
  access_entries = {
    admin = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  
  # Additional project-specific tags
  additional_tags = {
    Project = "CPTWN-Multi-Client-EKS"
  }
}

# 📊 DATA SOURCE - Current AWS account
data "aws_caller_identity" "current" {}
