output "tenant_subnet_ids" {
  description = "Map of tenant names to their subnet IDs"
  value = {
    for tenant_name, config in var.tenant_configs : tenant_name => [
      for subnet in local.tenant_subnets : 
      aws_subnet.tenant_subnets["${subnet.tenant_name}-${subnet.subnet_index}"].id
      if subnet.tenant_name == tenant_name
    ]
  }
}

output "tenant_subnet_cidrs" {
  description = "Map of tenant names to their subnet CIDR blocks"
  value = {
    for tenant_name, config in var.tenant_configs : tenant_name => [
      for subnet in local.tenant_subnets : 
      aws_subnet.tenant_subnets["${subnet.tenant_name}-${subnet.subnet_index}"].cidr_block
      if subnet.tenant_name == tenant_name
    ]
  }
}

output "tenant_route_table_ids" {
  description = "Map of tenant names to their route table IDs"
  value = {
    for tenant_name, route_table in aws_route_table.tenant_route_tables : 
    tenant_name => route_table.id
  }
}

output "tenant_network_acl_ids" {
  description = "Map of tenant names to their Network ACL IDs (if enabled)"
  value = var.enable_network_acls ? {
    for tenant_name, nacl in aws_network_acl.tenant_nacls :
    tenant_name => nacl.id
  } : {}
}
