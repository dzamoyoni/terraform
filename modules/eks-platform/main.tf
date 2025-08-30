# 🏗️ EKS Platform Wrapper Module
# Wraps terraform-aws-modules/eks/aws with company standards and conventions
# This ensures consistency across all EKS deployments in all regions/environments

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# 🔍 LOCALS - CPTWN Standards
locals {
  # CPTWN standard tags applied to all resources
  cptwn_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    BackupRequired    = "true"
    SecurityLevel     = "High"
    Region            = var.region
    Layer             = "Platform"
    DeploymentPhase   = "Phase-2"
    Company           = "CPTWN"
    Architecture      = "Multi-Client"
  }
  
  # CPTWN standard cluster naming (without environment suffix to avoid IAM role name length issues)
  cluster_name = var.project_name
  
  # CPTWN standard node group configuration
  standard_node_group_defaults = {
    capacity_type                = "ON_DEMAND"
    max_unavailable_percentage   = 25
    disk_type                    = "gp3"
    
    # CPTWN security standards
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "enabled"
    }
    
    # CPTWN monitoring standards
    monitoring = {
      enabled = true
    }
    
    # CPTWN standard labels for all nodes
    labels = {
      Environment  = var.environment
      Project      = var.project_name
      ManagedBy    = "Terraform"
      Company      = "CPTWN"
      Architecture = "Multi-Client"
    }
  }
}

# ☸️ EKS CLUSTER - Official Module with CPTWN Standards
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"  # Pinned version for consistency
  
  # CPTWN standard cluster configuration
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  
  # VPC Configuration from foundation layer
  vpc_id     = var.vpc_id
  subnet_ids = var.platform_subnet_ids
  
  # CPTWN security standards
  cluster_endpoint_public_access       = var.enable_public_access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.management_cidr_blocks
  
  # CPTWN encryption standards
  enable_irsa = true
  
  # CPTWN logging standards
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days
  
  # CPTWN standard addons
  cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy            = { most_recent = true }
    vpc-cni               = { most_recent = true }
    aws-ebs-csi-driver    = { most_recent = true }
  }
  
  # Node Groups with CPTWN standards
  eks_managed_node_groups = {
    for name, config in var.node_groups : name => merge(
      local.standard_node_group_defaults,
      config,
      {
        # Apply CPTWN naming standards
        name = "${local.cluster_name}-${config.name_suffix}"
        
        # Custom IAM role name without trailing hyphen
        iam_role_name = "${local.cluster_name}-${config.name_suffix}-nodes"
        
        # Merge CPTWN standard labels with custom labels
        labels = merge(
          local.standard_node_group_defaults.labels,
          lookup(config, "labels", {}),
          {
            NodeGroup = name
            Client    = lookup(config, "client", "platform")
          }
        )
        
        # Apply CPTWN standard tags
        tags = merge(
          local.cptwn_tags,
          lookup(config, "tags", {}),
          {
            Name        = "${local.cluster_name}-${config.name_suffix}-nodes"
            Purpose     = lookup(config, "purpose", "Multi-Client Node Group")
            Client      = lookup(config, "client", "platform")
            NodeGroup   = name
          }
        )
      }
    )
  }
  
  # CPTWN access configuration
  access_entries = var.access_entries
  
  # CPTWN standard cluster tags
  tags = merge(local.cptwn_tags, var.additional_tags)
}

# 📊 DATA SOURCE - Current AWS account for access patterns
data "aws_caller_identity" "current" {}
