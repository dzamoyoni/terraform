# ============================================================================
# Foundation Layer (01-foundation/production)
# ============================================================================
# This layer provides the foundational infrastructure for the multi-tenant 
# architecture including:
# - VPC and networking (public/private subnets, NAT gateway)
# - Security groups for different service types
# - VPN connections for secure client access
# - SSM parameters for cross-layer communication
#
# This layer must be deployed first before other layers can reference
# its outputs via SSM parameters.
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
      Environment   = var.environment
      Layer        = "foundation"
      ManagedBy    = "terraform"
      Repository   = "infrastructure"
    }
  }
}

# Get current region and availability zones
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# Foundation Layer Implementation
# ============================================================================

module "foundation" {
  source = "../../../../../modules/foundation-layer"

  # Mode Configuration - IMPORT MODE for existing infrastructure
  import_mode = true  # Explicitly use import mode

  # General Configuration
  environment        = var.environment
  vpc_name          = var.vpc_name
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  availability_zones = var.availability_zones

  # EXISTING Infrastructure - Your current setup (NO MODIFICATIONS)
  existing_vpc_id               = var.existing_vpc_id
  existing_private_subnet_ids   = var.existing_private_subnet_ids
  existing_public_subnet_ids    = var.existing_public_subnet_ids
  existing_igw_id              = var.existing_igw_id
  existing_nat_gateway_ids     = var.existing_nat_gateway_ids
  existing_vpn_gateway_id      = var.existing_vpn_gateway_id

  # Security Groups - use existing ones (NO NEW SECURITY GROUPS)
  create_security_groups       = false  # Use existing security groups
  existing_eks_cluster_sg_id   = var.existing_eks_cluster_sg_id
  existing_database_sg_id      = var.existing_database_sg_id
  existing_alb_sg_id           = var.existing_alb_sg_id

  # Common tags for SSM parameters only
  common_tags = {
    Environment   = var.environment
    Region        = var.aws_region
    Layer         = "foundation"
    ManagedBy     = "terraform"
    Repository    = "infrastructure"
    ImportMode    = "true"
    # Add cluster tagging for existing EKS integration
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ============================================================================
# Foundation Layer Outputs to SSM (Additional Parameters)
# ============================================================================
# Store additional metadata for other layers to consume

resource "aws_ssm_parameter" "foundation_deployed" {
  name  = "/terraform/${var.environment}/foundation/deployed"
  type  = "String"
  value = "true"

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    ManagedBy  = "terraform"
  }

  depends_on = [module.foundation]
}

resource "aws_ssm_parameter" "foundation_version" {
  name  = "/terraform/${var.environment}/foundation/version"
  type  = "String"
  value = "1.0.0"

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "region" {
  name  = "/terraform/${var.environment}/foundation/region"
  type  = "String"
  value = var.aws_region

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "availability_zones" {
  name  = "/terraform/${var.environment}/foundation/availability_zones"
  type  = "StringList"
  value = join(",", var.availability_zones)

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    ManagedBy  = "terraform"
  }
}

