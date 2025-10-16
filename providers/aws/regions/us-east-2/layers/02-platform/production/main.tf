#  Platform Layer - Production
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

# TAGGING STRATEGY: Provider-level default tags for consistency
# All AWS resources will automatically inherit tags from provider configuration

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      # Core identification
      Project         = var.project_name
      Environment     = var.environment
      Region          = var.region
      
      # Operational
      ManagedBy       = "Terraform"
      Layer           = "Platform"
      DeploymentPhase = "Phase-2"
      
      # Governance
      CriticalInfra   = "true"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      
      # Cost Management
      CostCenter      = "IT-Infrastructure"
      BillingGroup    = "Platform-Engineering"
      
      # Platform specific
      ClusterRole     = "Primary"
      PlatformType    = "EKS"
    }
  }
}

# DATA SOURCES - Foundation Layer Outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

#  LOCALS - Foundation Layer Data with Validation
locals {
  # Foundation layer outputs
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  platform_subnet_ids = data.terraform_remote_state.foundation.outputs.platform_subnet_ids
  vpc_cidr_block      = data.terraform_remote_state.foundation.outputs.vpc_cidr_block
  availability_zones  = data.terraform_remote_state.foundation.outputs.availability_zones
  
  # Foundation layer metadata for validation
  foundation_project_name = try(data.terraform_remote_state.foundation.outputs.project_name, "")
  foundation_environment  = try(data.terraform_remote_state.foundation.outputs.environment, "")
  foundation_region      = try(data.terraform_remote_state.foundation.outputs.region, "")

  # Platform configuration - shortened to avoid IAM role name length limits
  cluster_name = var.project_name
  
  # Cross-layer validation
  foundation_compatibility_check = {
    project_name_match = local.foundation_project_name == "" || local.foundation_project_name == var.project_name
    environment_match  = local.foundation_environment == "" || local.foundation_environment == var.environment
    region_match       = local.foundation_region == "" || local.foundation_region == var.region
    vpc_exists         = local.vpc_id != null && local.vpc_id != ""
    subnets_exist      = length(local.platform_subnet_ids) > 0
  }
}

# VALIDATION CHECKS
resource "null_resource" "cross_layer_validation" {
  # Ensure foundation layer is compatible
  lifecycle {
    precondition {
      condition     = local.foundation_compatibility_check.vpc_exists
      error_message = "VPC from foundation layer is missing. Ensure foundation layer is applied successfully."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.subnets_exist
      error_message = "Platform subnets from foundation layer are missing. Check foundation layer outputs."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.project_name_match
      error_message = "Project name mismatch between foundation (${local.foundation_project_name}) and platform (${var.project_name}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.environment_match
      error_message = "Environment mismatch between foundation (${local.foundation_environment}) and platform (${var.environment}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.region_match
      error_message = "Region mismatch between foundation (${local.foundation_region}) and platform (${var.region}) layers."
    }
  }
  
  triggers = {
    foundation_state_version = try(data.terraform_remote_state.foundation.outputs.state_version, timestamp())
    platform_config_version  = md5(jsonencode({
      project_name = var.project_name
      environment  = var.environment
      region       = var.region
    }))
  }
}

# ☸️ EKS PLATFORM - Using Multi-Region Wrapper Module
module "eks_platform" {
  source = "../../../../../../../modules/eks-platform"

  # Core configuration
  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  # Cluster configuration
  cluster_version = var.cluster_version

  # Network configuration from foundation layer
  vpc_id              = local.vpc_id
  platform_subnet_ids = local.platform_subnet_ids

  # Security configuration
  enable_public_access   = true
  management_cidr_blocks = var.management_cidr_blocks
  log_retention_days     = 30

  # Multi-client node groups
  node_groups = {
    # ETA Client Node Group
    est_test_a = {
      name_suffix    = "ETA"
      instance_types = ["m5.large", "m5a.large", "t3.xlarge", "c5.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size      = 20

      # Client-specific configuration
      client  = "est-test-a"
      purpose = "ETA Client Node Group"

      # Additional labels for this client
      labels = {
        NodeGroup = "client"
      }
    }

    # System Node Group for shared services and observability workloads
    system = {
      name_suffix    = "system-ng"
      instance_types = ["m5.large", "m5a.large", "t3.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 3
      disk_size      = 30
      capacity_type  = "ON_DEMAND"

      # System workload configuration
      client  = "system"
      purpose = "System workloads - shared services and observability"

      # System workload taints to prevent client workloads from scheduling
      taints = {
        system_workload = {
          key    = "workload-type"
          value  = "system"
          effect = "NO_SCHEDULE"
        }
        dedicated_shared_services = {
          key    = "dedicated"
          value  = "shared-services"
          effect = "NO_SCHEDULE"
          
        }
      }

      # System workload labels for node selection
      labels = {
        NodeGroup                  = "system"
        "workload-type"           = "system"
        "node-purpose"            = "shared-services"
        "dedicated"               = "shared-services"
        "workload/shared-services" = "true"
        "workload/observability"   = "true"
        "workload/istio-system"    = "true"
        "client-workload"         = "false"
        "system-workload"         = "true"
      }

      # System-specific tags
      tags = {
        NodeGroupPurpose = "system-workloads"
        WorkloadType     = "shared-services-observability"
        SystemWorkload   = "true"
        ClientWorkload   = "false"
        Dedicated        = "shared-services"
      }
    }

    # ETB Client Node Group (Disabled - will be enabled later)
    # est_test_b = {
    #   name_suffix    = "ETB"
    #   instance_types = ["m5.large", "m5a.large", "t3.xlarge", "c5.large"]
    #   min_size       = 1
    #   max_size       = 3
    #   desired_size   = 2
    #   disk_size      = 20
    #   
    #   # Client-specific configuration
    #   client  = "est-test-b"
    #   purpose = "ETB Client Node Group"
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
    terraform_user = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/djuma"

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

  # Tags are handled via provider default_tags for consistency
  additional_tags = {}
}

# Security Group Rules for Inter-Node Communication
# Required for metrics server and other system workloads to access kubelet on all nodes
resource "aws_security_group_rule" "node_to_node_kubelet" {
  description              = "Allow node-to-node kubelet communication for metrics server"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = module.eks_platform.node_security_group_id
  source_security_group_id = module.eks_platform.node_security_group_id
}

# DNS rules already exist in the EKS module

#  DATA SOURCE - Current AWS account
data "aws_caller_identity" "current" {}
