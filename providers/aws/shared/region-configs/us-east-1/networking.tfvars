# US-East-1 Region Network Configuration
# Extracted from existing infrastructure

# VPC Configuration
vpc_cidr = "172.20.0.0/16"
private_subnets = ["172.20.1.0/24", "172.20.2.0/24"]  
public_subnets = ["172.20.101.0/24", "172.20.102.0/24"]

# Availability Zones
availability_zones = ["us-east-1a", "us-east-1b"]

# VPN Configuration (extracted from current setup)
vpn_config = {
  # Primary VPN Connection
  customer_gateway_ip = "178.162.141.150"
  client_cidr = "178.162.141.130/32"
  bgp_asn = 6500
  
  # Secondary VPN Connection  
  secondary_gateway_ip = "165.90.14.138"
  secondary_client_cidr = "165.90.14.138/32"
  secondary_bgp_asn = 6500
}

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = true  # Current setup uses single NAT
enable_dns_hostnames = true
enable_dns_support = true

# Network ACLs
enable_network_acls = true

# Flow Logs (optional for enhanced networking)
enable_flow_log = false
flow_log_destination_type = "cloud-watch-logs"
