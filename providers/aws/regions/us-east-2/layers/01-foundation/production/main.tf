# Foundation Layer - us-east-2 Production
# CRITICAL INFRASTRUCTURE: VPC, Subnets, NAT Gateways, VPN
# DO NOT DELETE OR MODIFY WITHOUT PROPER AUTHORIZATION

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration loaded from backend.hcl file
  # Use: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

# ============================================================================
# Centralized Tagging Configuration
# ============================================================================

module "tags" {
  source = "../../../../../../../modules/tagging"
  
  # Core configuration
  project_name     = var.project_name
  environment      = var.environment
  layer_name       = "foundation"
  region           = var.region
  
  # Layer-specific configuration
  layer_purpose    = "VPC and Network Infrastructure"
  deployment_phase = "Phase-1"
  
  # Infrastructure classification
  critical_infrastructure = "true"
  backup_required        = "true"
  security_level         = "High"
  
  # Cost management
  cost_center      = "IT-Infrastructure"
  billing_group    = "Platform-Engineering"
  chargeback_code  = "EST1-FOUNDATION-001"
  
  # Operational settings
  sla_tier           = "Gold"
  monitoring_level   = "Enhanced"
  maintenance_window = "Sunday-02:00-04:00-UTC"
  
  # Governance
  compliance_framework = "SOC2-ISO27001"
  data_classification  = "Internal"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = module.tags.standard_tags
  }
}

#  DATA SOURCES
data "aws_availability_zones" "available" {
  state = "available"
}

#  VPC FOUNDATION - Dual NAT Gateway Setup
module "vpc_foundation" {
  source = "../../../../../../../modules/vpc-foundation"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_vpc_flow_logs    = true
  flow_log_retention_days = 30
  enable_vpc_endpoints    = true

  common_tags = local.critical_tags
}

# ETA CLIENT SUBNETS - Perfect Isolation
module "client_subnets_est_test_a" {
  source = "../../../../../../../modules/client-subnets"

  enabled            = true
  project_name       = var.project_name
  client_name        = "est-test-a"
  vpc_id             = module.vpc_foundation.vpc_id
  client_cidr_block  = "172.16.12.0/22" # 4,094 IPs f - Non-conflicting range
  availability_zones = local.availability_zones
  nat_gateway_ids    = module.vpc_foundation.nat_gateway_ids
  cluster_name       = "${var.project_name}-cluster"

  management_cidr_blocks = var.management_cidr_blocks
  custom_ports           = [8080, 9000, 3000, 5000]
  database_ports         = [5432, 5433, 5434, 5435] # PostgreSQL custom ports

  # VPN gateway will be available after VPN module creates it
  vpn_gateway_id = null # Will be updated after VPN deployment

  common_tags = local.client_tags["est_test_a"]

  depends_on = [module.vpc_foundation]
}

#  ETB CLIENT SUBNETS - Perfect Isolation
module "client_subnets_est_test_b" {
  source = "../../../../../../../modules/client-subnets"

  enabled            = true
  project_name       = var.project_name
  client_name        = "est-test-b"
  vpc_id             = module.vpc_foundation.vpc_id
  client_cidr_block  = "172.16.16.0/22" # 4,094 IPs  - Non-conflicting range
  availability_zones = local.availability_zones
  nat_gateway_ids    = module.vpc_foundation.nat_gateway_ids
  cluster_name       = "${var.project_name}-cluster"

  management_cidr_blocks = var.management_cidr_blocks
  custom_ports           = [8080, 9000, 3000, 5000]
  database_ports         = [5432, 5433, 5434, 5435] # PostgreSQL custom ports

  # VPN gateway will be available after VPN module creates it
  vpn_gateway_id = null # Will be updated after VPN deployment

  common_tags = local.client_tags["est_test_b"]

  depends_on = [module.vpc_foundation]
}

# 🔗 DUAL SITE-TO-SITE VPN - Multiple Secure On-Premises Connections
module "vpn_connections" {
  for_each = var.enable_vpn ? var.vpn_connections : {}
  source   = "../../../../../../../modules/site-to-site-vpn"

  enabled             = each.value.enabled
  project_name        = "${var.project_name}-${each.key}"
  region              = var.region
  vpc_id              = module.vpc_foundation.vpc_id
  customer_gateway_ip = each.value.customer_gateway_ip

  bgp_asn            = each.value.bgp_asn
  amazon_side_asn    = each.value.amazon_side_asn
  static_routes_only = each.value.static_routes_only
  onprem_cidr_blocks = [each.value.local_network_cidr]

  # Tunnel configuration
  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel1_preshared_key = null # AWS auto-generates
  # tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
  # tunnel2_preshared_key = null # AWS auto-generates

  # Route propagation
  platform_route_table_ids = module.vpc_foundation.platform_route_table_ids
  client_route_table_ids = concat(
    module.client_subnets_est_test_a.route_table_ids,
    module.client_subnets_est_test_b.route_table_ids
  )

  enable_vpn_logging     = true
  vpn_log_retention_days = 30
  sns_topic_arn          = var.sns_topic_arn

  common_tags = merge(
    local.critical_tags,
    {
      VPNConnection  = each.key
      VPNDescription = each.value.description
      ConnectionType = "Site-to-Site"
      TunnelCount    = "2"
    }
  )

  depends_on = [module.vpc_foundation]
}

# ============================================================================
# Locals for computed values and standardized configurations
# ============================================================================

locals {
  # Use first 2 AZs for high availability
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Standard tags for all resources in this layer
  common_tags = module.tags.standard_tags
  
  # Comprehensive tags for critical infrastructure
  critical_tags = module.tags.comprehensive_tags
  
  # Client-specific tag generator function
  client_tags = {
    "est_test_a" = merge(
      module.tags.standard_tags,
      {
        Client     = "est-test-a"
        ClientCode = "ETA"
        ClientTier = "Premium"
        TenantType = "Production"
      }
    )
    "est_test_b" = merge(
      module.tags.standard_tags,
      {
        Client     = "est-test-b"
        ClientCode = "ETB"
        ClientTier = "Premium"
        TenantType = "Production"
      }
    )
  }
}
