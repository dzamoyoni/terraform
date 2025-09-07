# 🏗️ Foundation Layer - AF-South-1 Production
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
      Layer             = "Foundation"
      DeploymentPhase   = "Phase-1"
    }
  }
}

#  DATA SOURCES
data "aws_availability_zones" "available" {
  state = "available"
}

#  VPC FOUNDATION - Dual NAT Gateway Setup
module "vpc_foundation" {
  source = "../../../../../modules/vpc-foundation"
  
  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.availability_zones
  
  enable_vpc_flow_logs     = true
  flow_log_retention_days  = 30
  enable_vpc_endpoints     = true
  
  common_tags = {
    Project            = "CPTWN-Multi-Client-EKS"
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    Layer             = "Foundation"
    DeploymentPhase   = "Phase-1"
  }
}

#  MTN GHANA PROD CLIENT SUBNETS - Perfect Isolation
module "client_subnets_mtn_ghana_prod" {
  source = "../../../../../modules/client-subnets"
  
  enabled            = true
  project_name       = var.project_name
  client_name        = "mtn-ghana-prod"
  vpc_id            = module.vpc_foundation.vpc_id
  client_cidr_block = "172.16.12.0/22"  # 4,094 IPs for MTN Ghana Prod - Non-conflicting range
  availability_zones = local.availability_zones
  nat_gateway_ids   = module.vpc_foundation.nat_gateway_ids
  cluster_name      = "${var.project_name}-cluster"
  
  management_cidr_blocks = var.management_cidr_blocks
  custom_ports          = [8080, 9000, 3000, 5000]
  database_ports        = [5432, 5433, 5434, 5435]  # PostgreSQL custom ports
  
  # VPN gateway will be available after VPN module creates it
  vpn_gateway_id = null  # Will be updated after VPN deployment
  
  common_tags = {
    Project            = "CPTWN-Multi-Client-EKS"
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    Layer             = "Foundation"
    Client            = "mtn-ghana-prod"
    DeploymentPhase   = "Phase-1"
  }
  
  depends_on = [module.vpc_foundation]
}

#  ORANGE MADAGASCAR PROD CLIENT SUBNETS - Perfect Isolation
module "client_subnets_orange_madagascar_prod" {
  source = "../../../../../modules/client-subnets"
  
  enabled            = true
  project_name       = var.project_name
  client_name        = "orange-madagascar-prod"
  vpc_id            = module.vpc_foundation.vpc_id
  client_cidr_block = "172.16.16.0/22"  # 4,094 IPs for Orange Madagascar Prod - Non-conflicting range
  availability_zones = local.availability_zones
  nat_gateway_ids   = module.vpc_foundation.nat_gateway_ids
  cluster_name      = "${var.project_name}-cluster"
  
  management_cidr_blocks = var.management_cidr_blocks
  custom_ports          = [8080, 9000, 3000, 5000]
  database_ports        = [5432, 5433, 5434, 5435]  # PostgreSQL custom ports
  
  # VPN gateway will be available after VPN module creates it
  vpn_gateway_id = null  # Will be updated after VPN deployment
  
  common_tags = {
    Project            = "CPTWN-Multi-Client-EKS"
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    Layer             = "Foundation"
    Client            = "orange-madagascar-prod"
    DeploymentPhase   = "Phase-1"
  }
  
  depends_on = [module.vpc_foundation]
}

# 🔗 DUAL SITE-TO-SITE VPN - Multiple Secure On-Premises Connections
module "vpn_connections" {
  for_each = var.enable_vpn ? var.vpn_connections : {}
  source = "../../../../../modules/site-to-site-vpn"
  
  enabled               = each.value.enabled
  project_name         = "${var.project_name}-${each.key}"
  region               = var.region
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = each.value.customer_gateway_ip
  
  bgp_asn              = each.value.bgp_asn
  amazon_side_asn      = each.value.amazon_side_asn
  static_routes_only   = each.value.static_routes_only
  onprem_cidr_blocks   = [each.value.local_network_cidr]
  
  # Tunnel configuration
  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel1_preshared_key = null  # AWS auto-generates
  tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
  tunnel2_preshared_key = null  # AWS auto-generates
  
  # Route propagation
  platform_route_table_ids = module.vpc_foundation.platform_route_table_ids
  client_route_table_ids = concat(
    module.client_subnets_mtn_ghana_prod.route_table_ids,
    module.client_subnets_orange_madagascar_prod.route_table_ids
  )
  
  enable_vpn_logging      = true
  vpn_log_retention_days = 30
  sns_topic_arn          = var.sns_topic_arn
  
  common_tags = {
    Project            = "CPTWN-Multi-Client-EKS"
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    Layer             = "Foundation"
    DeploymentPhase   = "Phase-1"
    VPNConnection     = each.key
    VPNDescription    = each.value.description
  }
  
  depends_on = [module.vpc_foundation]
}

#  LOCALS for computed values
locals {
  # Use first 2 AZs for high availability
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}
