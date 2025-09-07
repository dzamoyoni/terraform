# 🔗 Multiple VPN Connection Examples for cptwn-eks-01
# Choose the scenario that fits your needs

# =================================================================
# SCENARIO 1: Multiple Office Locations
# =================================================================

# Primary Office VPN
module "vpn_primary_office" {
  source = "../modules/site-to-site-vpn"
  
  enabled               = true
  project_name         = "cptwn-eks-01-primary"
  region               = "af-south-1"
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = "178.162.141.130"  # Your current office
  
  bgp_asn              = 65001
  amazon_side_asn      = 64512
  static_routes_only   = true
  onprem_cidr_blocks   = [
    "178.162.141.130/32",  # Office public IP
    "10.1.0.0/16"         # Office internal network
  ]
  
  # Tunnel configuration
  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel2_inside_cidr   = "169.254.11.0/30"
  
  common_tags = {
    VPNSite = "Primary-Office"
    Location = "Main-HQ"
  }
}

# Secondary Office VPN (if you have another office)
module "vpn_secondary_office" {
  source = "../modules/site-to-site-vpn"
  
  enabled               = false  # Enable when you have second office
  project_name         = "cptwn-eks-01-secondary"
  region               = "af-south-1"
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = "203.0.113.45"     # Different office IP
  
  bgp_asn              = 65002  # Different ASN
  amazon_side_asn      = 64513  # Different Amazon ASN
  static_routes_only   = true
  onprem_cidr_blocks   = [
    "203.0.113.45/32",    # Second office public IP
    "10.2.0.0/16"        # Second office internal network
  ]
  
  # Non-overlapping tunnel networks
  tunnel1_inside_cidr   = "169.254.12.0/30"
  tunnel2_inside_cidr   = "169.254.13.0/30"
  
  common_tags = {
    VPNSite = "Secondary-Office"
    Location = "Branch-Office"
  }
}

# =================================================================
# SCENARIO 2: Redundant VPN (Same Office, Different ISPs)
# =================================================================

# Primary ISP Connection
module "vpn_isp_primary" {
  source = "../modules/site-to-site-vpn"
  
  enabled               = true
  project_name         = "cptwn-eks-01-isp1"
  region               = "af-south-1"
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = "178.162.141.130"  # ISP 1 connection
  
  bgp_asn              = 65001
  amazon_side_asn      = 64512
  static_routes_only   = true
  onprem_cidr_blocks   = [
    "178.162.141.130/32",
    "10.0.0.0/16"        # Your internal networks
  ]
  
  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel2_inside_cidr   = "169.254.11.0/30"
  
  common_tags = {
    VPNType = "Primary-ISP"
    ISP = "Primary-Provider"
  }
}

# Backup ISP Connection
module "vpn_isp_backup" {
  source = "../modules/site-to-site-vpn"
  
  enabled               = false  # Enable when you have backup ISP
  project_name         = "cptwn-eks-01-isp2"
  region               = "af-south-1"
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = "198.51.100.50"    # Backup ISP IP
  
  bgp_asn              = 65001  # Same ASN (same location)
  amazon_side_asn      = 64513  # Different Amazon ASN
  static_routes_only   = true
  onprem_cidr_blocks   = [
    "198.51.100.50/32",   # Backup ISP public IP
    "10.0.0.0/16"        # Same internal networks
  ]
  
  # Non-overlapping tunnel networks
  tunnel1_inside_cidr   = "169.254.14.0/30"
  tunnel2_inside_cidr   = "169.254.15.0/30"
  
  common_tags = {
    VPNType = "Backup-ISP"
    ISP = "Backup-Provider"
  }
}

# =================================================================
# SCENARIO 3: Partner/Client VPN Connections
# =================================================================

# Partner Company VPN
module "vpn_partner_mtn" {
  source = "../modules/site-to-site-vpn"
  
  enabled               = false  # Enable when partner connection needed
  project_name         = "cptwn-eks-01-partner-mtn"
  region               = "af-south-1"
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = "192.0.2.100"      # Partner's public IP
  
  bgp_asn              = 65100  # Partner's ASN
  amazon_side_asn      = 64514  # Unique Amazon ASN
  static_routes_only   = true
  onprem_cidr_blocks   = [
    "192.0.2.100/32",     # Partner public IP
    "172.20.0.0/16"      # Partner internal networks
  ]
  
  tunnel1_inside_cidr   = "169.254.16.0/30"
  tunnel2_inside_cidr   = "169.254.17.0/30"
  
  common_tags = {
    VPNType = "Partner-Connection"
    Partner = "MTN-Ghana"
  }
}

# =================================================================
# ADVANCED: AWS Transit Gateway for Complex Multi-VPN
# =================================================================

# If you need 5+ VPN connections, consider Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0
  
  description                     = "Transit Gateway for ${var.project_name}"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  
  tags = {
    Name = "${var.project_name}-tgw"
    Purpose = "Multi-VPN Hub"
  }
}
```

## 🚀 **How to Implement Multiple VPNs**

### **Step 1: Update Your Foundation Layer**
Add this to your `main.tf`:

```hcl
# Add multiple VPN connections
module "vpn_connections" {
  for_each = var.vpn_connections
  
  source = "../../modules/site-to-site-vpn"
  
  enabled               = each.value.enabled
  project_name         = "${var.project_name}-${each.key}"
  region               = var.region
  vpc_id               = module.vpc_foundation.vpc_id
  customer_gateway_ip  = each.value.customer_gateway_ip
  
  bgp_asn              = each.value.bgp_asn
  amazon_side_asn      = each.value.amazon_side_asn
  static_routes_only   = each.value.static_routes_only
  onprem_cidr_blocks   = each.value.onprem_cidr_blocks
  
  # Unique tunnel networks per connection
  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
}
```

### **Step 2: Add VPN Variable**
```hcl
variable "vpn_connections" {
  description = "Multiple VPN connections configuration"
  type = map(object({
    enabled               = bool
    customer_gateway_ip   = string
    bgp_asn              = number
    amazon_side_asn      = number
    static_routes_only   = bool
    onprem_cidr_blocks   = list(string)
    tunnel1_inside_cidr  = string
    tunnel2_inside_cidr  = string
  }))
  
  default = {
    primary = {
      enabled               = true
      customer_gateway_ip   = "178.162.141.130"
      bgp_asn              = 65001
      amazon_side_asn      = 64512
      static_routes_only   = true
      onprem_cidr_blocks   = ["178.162.141.130/32"]
      tunnel1_inside_cidr  = "169.254.10.0/30"
      tunnel2_inside_cidr  = "169.254.11.0/30"
    }
    backup = {
      enabled               = false  # Enable when needed
      customer_gateway_ip   = "198.51.100.50"
      bgp_asn              = 65001  # Same ASN if same site
      amazon_side_asn      = 64513  # Different Amazon ASN
      static_routes_only   = true
      onprem_cidr_blocks   = ["198.51.100.50/32"]
      tunnel1_inside_cidr  = "169.254.12.0/30"
      tunnel2_inside_cidr  = "169.254.13.0/30"
    }
  }
}
```

## 🎯 **Recommended Next Steps**

1. **Start with Single VPN**: Your current config is perfect for starting
2. **Validate Connectivity**: Get first VPN working completely
3. **Add Additional VPNs**: Use the multi-VPN pattern when needed
4. **Scale to cptwn-eks-02**: When you need another cluster, use new CIDR ranges

Your configuration is **consistent and well-planned**! The `cptwn-eks-01` naming convention is excellent for future scaling.

**Should we proceed with deploying the foundation layer now?** I can deploy it with your current single VPN configuration, and we can add additional VPNs later when needed.

<function_calls>
<invoke name="mark_todo_as_done">
<parameter name="todo_ids">["e518593c-426f-4ee7-9d8a-3314f48b4030", "db754779-89fb-4827-a127-652a860ce164", "fabc3d13-1917-4b21-bc6c-532c768d441b"]
