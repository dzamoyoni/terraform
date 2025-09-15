# ============================================================================
# Database Layer - AF-South-1 Production
# ============================================================================
# This layer deploys PostgreSQL databases for clients using the postgres-ec2 module
# Manages high-availability PostgreSQL with master-replica setup
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration loaded from backend.hcl file
  # Use: terraform init -backend-config=backend.hcl
}

# Configure AWS Provider with default tags
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project       = "CPTWN-Multi-Client-EKS"
      Environment   = "Production"
      ManagedBy     = "Terraform"
      Region        = var.aws_region
      Layer         = "Database"
      SecurityLevel = "High"
    }
  }
}

# Data sources to fetch foundation layer information
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "cptwn-terraform-state-ezra"
    key    = "providers/aws/regions/af-south-1/layers/01-foundation/production/terraform.tfstate"
    region = "af-south-1"
  }
}

# Local variables for consistent resource naming
locals {
  # Common tags for all resources in this layer
  common_tags = {
    Project       = "CPTWN-Multi-Client-EKS"
    Environment   = "Production"
    ManagedBy     = "Terraform"
    Region        = var.aws_region
    Layer         = "Database"
    SecurityLevel = "High"
  }

  # VPC information from foundation layer
  vpc_id             = data.terraform_remote_state.foundation.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids

  # Database subnets (use first two private subnets for HA)
  master_subnet_id  = local.private_subnet_ids[0]
  replica_subnet_id = local.private_subnet_ids[1]
}

# ============================================================================
# POSTGRESQL DATABASES FOR CLIENTS
# ============================================================================

# MTN Ghana PostgreSQL Database
module "mtn_ghana_postgres" {
  source = "../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "mtn-ghana"
  environment = "production"

  # Network configuration from foundation layer
  vpc_id                 = local.vpc_id
  master_subnet_id       = local.master_subnet_id
  replica_subnet_id      = local.replica_subnet_id
  allowed_cidr_blocks    = [data.terraform_remote_state.foundation.outputs.vpc_cidr_block]
  management_cidr_blocks = var.management_cidr_blocks
  monitoring_cidr_blocks = [data.terraform_remote_state.foundation.outputs.vpc_cidr_block]

  # Instance configuration
  ami_id                = var.postgres_ami_id
  key_name              = var.key_name
  master_instance_type  = var.master_instance_type
  replica_instance_type = var.replica_instance_type

  # Database configuration
  database_name        = "mtn_ghana_db"
  database_user        = "mtn_ghana_user"
  database_password    = var.mtn_ghana_db_password
  replication_password = var.mtn_ghana_replication_password

  # Storage configuration
  data_volume_size   = var.data_volume_size
  wal_volume_size    = var.wal_volume_size
  backup_volume_size = var.backup_volume_size

  # Features
  enable_replica             = true
  enable_monitoring          = true
  enable_encryption          = true
  enable_deletion_protection = true
  backup_retention_days      = var.backup_retention_days

  # Tags
  tags = merge(local.common_tags, {
    Client  = "mtn-ghana"
    Purpose = "client-database"
  })
}

# Ezra PostgreSQL Database  
module "ezra_postgres" {
  source = "../../../../../modules/postgres-ec2"

  # Client identification
  client_name = "ezra"
  environment = "production"

  # Network configuration from foundation layer
  vpc_id                 = local.vpc_id
  master_subnet_id       = local.master_subnet_id
  replica_subnet_id      = local.replica_subnet_id
  allowed_cidr_blocks    = [data.terraform_remote_state.foundation.outputs.vpc_cidr_block]
  management_cidr_blocks = var.management_cidr_blocks
  monitoring_cidr_blocks = [data.terraform_remote_state.foundation.outputs.vpc_cidr_block]

  # Instance configuration
  ami_id                = var.postgres_ami_id
  key_name              = var.key_name
  master_instance_type  = var.master_instance_type
  replica_instance_type = var.replica_instance_type

  # Database configuration
  database_name        = "ezra_db"
  database_user        = "ezra_user"
  database_password    = var.ezra_db_password
  replication_password = var.ezra_replication_password

  # Storage configuration
  data_volume_size   = var.data_volume_size
  wal_volume_size    = var.wal_volume_size
  backup_volume_size = var.backup_volume_size

  # Features
  enable_replica             = true
  enable_monitoring          = true
  enable_encryption          = true
  enable_deletion_protection = true
  backup_retention_days      = var.backup_retention_days

  # Tags
  tags = merge(local.common_tags, {
    Client  = "ezra"
    Purpose = "client-database"
  })
}
