# 🏗️ Foundation Meta Wrapper Module
# Orchestrates VPC, client subnets, and VPN infrastructure with company standards
# This meta-module simplifies foundation layer deployment across all regions/environments

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# 📊 DATA SOURCES
data "aws_availability_zones" "available" {
  state = "available"
}

# 🔍 LOCALS - CPTWN Standards and Computed Values
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
    Layer             = "Foundation"
    DeploymentPhase   = "Phase-1"
    Company           = "CPTWN"
    Architecture      = "Multi-Client"
  }
  
  # Use first 2 AZs for high availability (CPTWN standard)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # CPTWN standard cluster naming
  cluster_name = "${var.project_name}-${var.environment}"
}

# 🌐 VPC FOUNDATION - CPTWN Multi-Client Architecture
module "vpc_foundation" {
  source = "../vpc-foundation"
  
  # CPTWN standard configuration
  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.availability_zones
  
  # CPTWN security standards
  enable_vpc_flow_logs     = var.enable_vpc_flow_logs
  flow_log_retention_days  = var.log_retention_days
  enable_vpc_endpoints     = var.enable_vpc_endpoints
  
  # CPTWN standard tags
  common_tags = merge(local.cptwn_tags, var.additional_tags, {
    Component = "VPC-Foundation"
  })
}

# 🏢 CLIENT SUBNETS - Dynamic Multi-Client Architecture
module "client_subnets" {
  for_each = var.clients
  source = "../client-subnets"
  
  # Basic configuration
  enabled            = each.value.enabled
  project_name       = var.project_name
  client_name        = each.key
  vpc_id            = module.vpc_foundation.vpc_id
  client_cidr_block = each.value.cidr_block
  availability_zones = local.availability_zones
  nat_gateway_ids   = module.vpc_foundation.nat_gateway_ids
  cluster_name      = local.cluster_name
  
  # CPTWN security standards
  management_cidr_blocks = var.management_cidr_blocks
  custom_ports          = each.value.custom_ports
  database_ports        = each.value.database_ports
  
  # VPN integration (will be set after VPN creation)
  vpn_gateway_id = var.enable_vpn && length(var.vpn_connections) > 0 ? 
    values(module.vpn_connections)[0].vpn_gateway_id : null
  
  # CPTWN standard tags with client-specific information
  common_tags = merge(local.cptwn_tags, var.additional_tags, {
    Component = "Client-Subnets"
    Client    = each.key
    Purpose   = each.value.purpose
  })
  
  depends_on = [module.vpc_foundation]
}

# 🔗 VPN CONNECTIONS - Secure Site-to-Site Connectivity
module "vpn_connections" {
  for_each = var.enable_vpn ? var.vpn_connections : {}
  source = "../site-to-site-vpn"
  
  # VPN Configuration
  enabled               = each.value.enabled
  project_name         = "${var.project_name}-${each.key}"
  region               = var.region
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = each.value.customer_gateway_ip
  
  # BGP Configuration
  bgp_asn              = each.value.bgp_asn
  amazon_side_asn      = each.value.amazon_side_asn
  static_routes_only   = each.value.static_routes_only
  onprem_cidr_blocks   = [each.value.local_network_cidr]
  
  # Tunnel Configuration
  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel1_preshared_key = null  # AWS auto-generates
  tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
  tunnel2_preshared_key = null  # AWS auto-generates
  
  # Route Propagation - Dynamically includes all client route tables
  platform_route_table_ids = module.vpc_foundation.platform_route_table_ids
  client_route_table_ids = flatten([
    for client_key, client_module in module.client_subnets : 
    client_module.route_table_ids
  ])
  
  # CPTWN monitoring standards
  enable_vpn_logging      = var.enable_vpn_logging
  vpn_log_retention_days = var.log_retention_days
  sns_topic_arn          = var.sns_topic_arn
  
  # CPTWN standard tags with VPN-specific information
  common_tags = merge(local.cptwn_tags, var.additional_tags, {
    Component      = "VPN-Connection"
    VPNConnection  = each.key
    VPNDescription = each.value.description
    VPNType        = each.value.static_routes_only ? "Static" : "BGP"
  })
  
  depends_on = [module.vpc_foundation, module.client_subnets]
}
