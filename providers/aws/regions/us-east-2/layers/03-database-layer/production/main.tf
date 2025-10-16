# ============================================================================
# Layer 3: Database Layer - US-East-2 Production
# ============================================================================
# High-Availability PostgreSQL databases with master-replica setup for multi-client architecture
# Provides dedicated, secured database instances with enterprise-grade features:
# - Master-Replica PostgreSQL with automatic replication
# - Multi-volume storage strategy (data, WAL, backup)
# - Comprehensive monitoring and alerting
# - Network isolation and security hardening
# - Cross-AZ deployment for high availability
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration loaded from backend.hcl file
  backend "s3" {}
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
      Layer           = "03-Database"
      DeploymentPhase = "Layer-3"
      
      # Governance
      CriticalInfra   = "true"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      
      # Cost Management
      CostCenter      = "IT-Infrastructure"
      BillingGroup    = "Platform-Engineering"
      
      # Platform specific
      ClusterRole     = "Primary"
      PlatformType    = "Database"
    }
  }
}

# DATA SOURCES - Foundation and Platform Layer Outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/02-platform/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

# DATA SOURCES - Current AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# DATA SOURCES - EKS subnet CIDR blocks for client-specific database access
data "aws_subnet" "est_test_a_eks" {
  for_each = toset(data.terraform_remote_state.foundation.outputs.est_test_a_eks_subnet_ids)
  id       = each.value
}

data "aws_subnet" "est_test_b_eks" {
  for_each = toset(data.terraform_remote_state.foundation.outputs.est_test_b_eks_subnet_ids)
  id       = each.value
}

# LOCALS - Foundation Layer Data with Validation
locals {
  # Foundation layer outputs
  vpc_id             = data.terraform_remote_state.foundation.outputs.vpc_id
  # Client-specific database subnets from foundation layer
  est_test_a_database_subnet_ids = data.terraform_remote_state.foundation.outputs.est_test_a_database_subnet_ids
  est_test_b_database_subnet_ids = data.terraform_remote_state.foundation.outputs.est_test_b_database_subnet_ids
  
  # Client-specific EKS subnets for database access control
  est_test_a_eks_subnet_ids = data.terraform_remote_state.foundation.outputs.est_test_a_eks_subnet_ids
  est_test_b_eks_subnet_ids = data.terraform_remote_state.foundation.outputs.est_test_b_eks_subnet_ids
  
  vpc_cidr_block     = data.terraform_remote_state.foundation.outputs.vpc_cidr_block
  availability_zones = data.terraform_remote_state.foundation.outputs.availability_zones
  
  # Get subnet CIDR blocks for client-specific database access
  est_test_a_eks_cidr_blocks = [
    for subnet_id in local.est_test_a_eks_subnet_ids :
    data.aws_subnet.est_test_a_eks[subnet_id].cidr_block
  ]
  
  est_test_b_eks_cidr_blocks = [
    for subnet_id in local.est_test_b_eks_subnet_ids :
    data.aws_subnet.est_test_b_eks[subnet_id].cidr_block
  ]
  
  # Platform layer integration
  cluster_name = data.terraform_remote_state.platform.outputs.cluster_name
  
  # Foundation layer metadata for validation
  foundation_project_name = try(data.terraform_remote_state.foundation.outputs.project_name, "")
  foundation_environment  = try(data.terraform_remote_state.foundation.outputs.environment, "")
  foundation_region      = try(data.terraform_remote_state.foundation.outputs.region, "")
  
  # Database subnets for HA deployment (use client-specific dedicated database subnets)
  # Each client gets their own isolated database subnets for security
  est_test_a_master_subnet_id  = local.est_test_a_database_subnet_ids[0]
  est_test_a_replica_subnet_id = local.est_test_a_database_subnet_ids[1]
  
  # Cross-layer validation
  foundation_compatibility_check = {
    project_name_match = local.foundation_project_name == "" || local.foundation_project_name == var.project_name
    environment_match  = local.foundation_environment == "" || local.foundation_environment == var.environment
    region_match       = local.foundation_region == "" || local.foundation_region == var.region
    vpc_exists         = local.vpc_id != null && local.vpc_id != ""
    database_subnets_exist = length(local.est_test_a_database_subnet_ids) >= 2
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
      condition     = local.foundation_compatibility_check.database_subnets_exist
      error_message = "Database subnets from foundation layer are missing. Check foundation layer outputs."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.project_name_match
      error_message = "Project name mismatch between foundation (${local.foundation_project_name}) and database (${var.project_name}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.environment_match
      error_message = "Environment mismatch between foundation (${local.foundation_environment}) and database (${var.environment}) layers."
    }
    
    precondition {
      condition     = local.foundation_compatibility_check.region_match
      error_message = "Region mismatch between foundation (${local.foundation_region}) and database (${var.region}) layers."
    }
  }
  
  triggers = {
    foundation_state_version = try(data.terraform_remote_state.foundation.outputs.state_version, timestamp())
    platform_state_version   = try(data.terraform_remote_state.platform.outputs.cluster_name, timestamp())
    database_config_version  = md5(jsonencode({
      project_name = var.project_name
      environment  = var.environment
      region       = var.region
    }))
  }
}

# ============================================================================
# HIGH-AVAILABILITY POSTGRESQL DATABASES FOR CLIENTS
# ============================================================================

# EST Test A (Primary Client) PostgreSQL Database - Master/Replica HA Setup
module "est_test_a_postgres" {
  source = "../../../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "test-test-a"
  environment = var.environment

  # Network configuration from foundation layer - EST Test A specific subnets
  vpc_id                 = local.vpc_id
  master_subnet_id       = local.est_test_a_master_subnet_id
  replica_subnet_id      = local.est_test_a_replica_subnet_id
  # SECURITY: Only allow access from EST Test A EKS subnets for client isolation
  allowed_cidr_blocks    = local.est_test_a_eks_cidr_blocks
  management_cidr_blocks = var.management_cidr_blocks
  monitoring_cidr_blocks = local.est_test_a_eks_cidr_blocks

  # Instance configuration
  ami_id                = var.postgres_ami_id
  key_name              = var.key_name
  master_instance_type  = var.master_instance_type
  replica_instance_type = var.replica_instance_type

  # Database configuration
  database_name        = "est_test_a_db"
  database_user        = "est_test_a_user"
  database_password    = var.est_test_a_db_password
  replication_password = var.est_test_a_replication_password

  # Storage configuration - Production-grade volumes
  data_volume_size   = var.data_volume_size
  wal_volume_size    = var.wal_volume_size
  backup_volume_size = var.backup_volume_size

  # Enterprise features
  enable_replica             = true
  enable_monitoring          = true
  enable_encryption          = true
  enable_deletion_protection = true
  backup_retention_days      = var.backup_retention_days

  # Tags are handled via provider default_tags for consistency
  tags = {
    Client  = "est-test-a"
    Purpose = "primary-client-database"
    DataClass = "restricted"
    BackupSchedule = "daily"
  }

  depends_on = [null_resource.cross_layer_validation]
}

# EST Test B (Secondary Client) PostgreSQL Database - Master/Replica HA Setup  
# Currently disabled for phased deployment - will be enabled when EST Test B is ready
/*
module "est_test_b_postgres" {
  source = "../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "est-test-b"
  environment = var.environment

  # Network configuration from foundation layer
  vpc_id                 = local.vpc_id
  master_subnet_id       = local.master_subnet_id
  replica_subnet_id      = local.replica_subnet_id
  allowed_cidr_blocks    = [local.vpc_cidr_block]
  management_cidr_blocks = var.management_cidr_blocks
  monitoring_cidr_blocks = [local.vpc_cidr_block]

  # Instance configuration
  ami_id                = var.postgres_ami_id
  key_name              = var.key_name
  master_instance_type  = var.master_instance_type
  replica_instance_type = var.replica_instance_type

  # Database configuration
  database_name        = "est_test_b_db"
  database_user        = "est_test_b_user"
  database_password    = var.est_test_b_db_password
  replication_password = var.est_test_b_replication_password

  # Storage configuration
  data_volume_size   = var.data_volume_size
  wal_volume_size    = var.wal_volume_size
  backup_volume_size = var.backup_volume_size

  # Enterprise features
  enable_replica             = true
  enable_monitoring          = true
  enable_encryption          = true
  enable_deletion_protection = true
  backup_retention_days      = var.backup_retention_days

  # Tags are handled via provider default_tags for consistency
  tags = {
    Client  = "est-test-b"
    Purpose = "secondary-client-database"
    DataClass = "restricted"
    BackupSchedule = "daily"
  }

  depends_on = [null_resource.cross_layer_validation]
}
*/
