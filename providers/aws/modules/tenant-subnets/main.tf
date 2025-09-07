# Tenant Subnet Management Module
# Creates dedicated subnets per tenant for enhanced isolation
# Compatible with existing VPC and EKS setup

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Calculate subnet CIDRs for each tenant
locals {
  # Base CIDR for tenant subnets (use unused space in your VPC)
  tenant_base_cidr = var.tenant_base_cidr # e.g., "172.20.10.0/22" for tenant subnets
  
  # Calculate individual tenant subnet CIDRs
  tenant_subnet_calculations = {
    for tenant_name, config in var.tenant_configs : tenant_name => {
      subnet_cidrs = [
        for az_index, az in slice(data.aws_availability_zones.available.names, 0, config.subnet_count) :
        cidrsubnet(local.tenant_base_cidr, 
          config.subnet_size_bits, 
          (config.tenant_index * config.subnet_count) + az_index
        )
      ]
      availability_zones = slice(data.aws_availability_zones.available.names, 0, config.subnet_count)
    }
  }
  
  # Flatten subnets for creation
  tenant_subnets = flatten([
    for tenant_name, tenant in local.tenant_subnet_calculations : [
      for index, cidr in tenant.subnet_cidrs : {
        tenant_name       = tenant_name
        subnet_index     = index
        cidr_block       = cidr
        availability_zone = tenant.availability_zones[index]
        subnet_key       = "${tenant_name}-${index}"
      }
    ]
  ])
}

# Create dedicated subnets for each tenant
resource "aws_subnet" "tenant_subnets" {
  for_each = {
    for subnet in local.tenant_subnets : subnet.subnet_key => subnet
  }

  vpc_id                  = var.vpc_id
  cidr_block             = each.value.cidr_block
  availability_zone      = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(
    {
      Name                                            = "${var.cluster_name}-${each.value.tenant_name}-private-${each.value.subnet_index + 1}"
      Environment                                     = var.environment
      Tenant                                          = each.value.tenant_name
      SubnetType                                      = "tenant-private"
      ManagedBy                                      = "terraform"
      # EKS tags for proper integration
      "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
      "kubernetes.io/role/internal-elb"              = "1"
      # Tenant-specific isolation tags
      "tenant.kubernetes.io/name"                     = each.value.tenant_name
      "tenant.kubernetes.io/isolation-level"         = "subnet"
    },
    var.common_tags
  )
}

# Route table for tenant subnets (associate with existing NAT gateway)
resource "aws_route_table" "tenant_route_tables" {
  for_each = var.tenant_configs

  vpc_id = var.vpc_id

  # Route to NAT Gateway for internet access
  dynamic "route" {
    for_each = var.nat_gateway_id != "" ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.nat_gateway_id
    }
  }

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-${each.key}-private-rt"
      Environment                                 = var.environment
      Tenant                                      = each.key
      ManagedBy                                  = "terraform"
      "tenant.kubernetes.io/name"                 = each.key
      "tenant.kubernetes.io/isolation-level"     = "subnet"
    },
    var.common_tags
  )
}

# Associate tenant subnets with their route tables
resource "aws_route_table_association" "tenant_subnet_associations" {
  for_each = {
    for subnet in local.tenant_subnets : subnet.subnet_key => subnet
  }

  subnet_id      = aws_subnet.tenant_subnets[each.key].id
  route_table_id = aws_route_table.tenant_route_tables[each.value.tenant_name].id
}

# Network ACLs for additional tenant isolation (optional)
resource "aws_network_acl" "tenant_nacls" {
  for_each = var.enable_network_acls ? var.tenant_configs : {}

  vpc_id     = var.vpc_id
  subnet_ids = [
    for subnet in local.tenant_subnets : 
    aws_subnet.tenant_subnets["${subnet.tenant_name}-${subnet.subnet_index}"].id
    if subnet.tenant_name == each.key
  ]

  # Allow internal tenant communication
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.tenant_configs[each.key].allowed_cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Allow communication with cluster service CIDR
  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.cluster_service_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow HTTPS/HTTP from VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = data.aws_vpc.main.cidr_block
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 310
    action     = "allow"
    cidr_block = data.aws_vpc.main.cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Default deny rule
  ingress {
    protocol   = "-1"
    rule_no    = 32766
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all egress (can be restricted based on requirements)
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      Name                                    = "${var.cluster_name}-${each.key}-nacl"
      Environment                             = var.environment
      Tenant                                  = each.key
      ManagedBy                              = "terraform"
      "tenant.kubernetes.io/name"             = each.key
      "tenant.kubernetes.io/isolation-level" = "network-acl"
    },
    var.common_tags
  )
}
