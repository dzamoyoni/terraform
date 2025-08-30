# 🏗️ Unified Foundation Layer Module

## Overview

This **unified foundation layer module** provides foundational networking and security infrastructure for multi-tenant architecture with **two operational modes**:

- **🔄 IMPORT MODE**: References existing infrastructure (us-east-1)
- **🆕 CREATE MODE**: Creates new infrastructure (future regions)

**Both modes provide identical SSM parameter outputs for full consistency.**

## ✅ **Your Current Setup (Import Mode)**

### **What It Does:**
- ✅ **Zero modifications** to your existing VPC, subnets, NAT, IGW, VPN
- ✅ **References existing** infrastructure via data sources
- ✅ **Creates SSM parameters** pointing to your existing resources
- ✅ **Enables other layers** to use foundation layer pattern
- ✅ **Full lifecycle protection** (prevent_destroy = true)

### **Your Existing Infrastructure:**
```
VPC:              vpc-0ec63df5e5566ea0c
Private Subnets:  subnet-0a6936df3ff9a4f77, subnet-0ec8a91aa274caea1
Public Subnets:   subnet-0b97065c0b7e66d5e, subnet-067cb01bb4e3bb0e7
VPN Gateway:      vgw-00ea48420a1cf8d13
EKS Cluster SG:   sg-014caac5c31fbc765
Database SG:      sg-067bc5c25980da2cc
ALB SG:           sg-0fc956334f67b2f64
```

## 🚀 **Future Regions (Create Mode)**

### **Example: us-west-2 Region**
```hcl
module "foundation" {
  source = "../../../../../modules/foundation-layer"

  # Mode Configuration - CREATE MODE for new regions
  import_mode = false  # Creates new infrastructure

  # General Configuration
  environment        = "production"
  vpc_name          = "usw2-production-vpc"
  cluster_name      = "us-west-2-cluster-01"
  aws_region        = "us-west-2"
  availability_zones = ["us-west-2a", "us-west-2b"]

  # NEW Infrastructure Configuration
  vpc_cidr         = "172.21.0.0/16"        # Different CIDR per region
  private_subnets  = ["172.21.1.0/24", "172.21.2.0/24"]
  public_subnets   = ["172.21.101.0/24", "172.21.102.0/24"]
  
  # Gateway Configuration
  enable_nat_gateway = true
  single_nat_gateway = true
  
  # DNS Configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Security Groups - Create new ones for new region
  create_security_groups = true

  # VPN Configuration (optional for new regions)
  enable_vpn = false  # Or configure as needed

  common_tags = {
    Environment = "production"
    Region      = "us-west-2"
    Layer       = "foundation"
    ManagedBy   = "terraform"
  }
}
```

### **Example: eu-west-1 Region**
```hcl
module "foundation" {
  source = "../../../../../modules/foundation-layer"

  # Mode Configuration - CREATE MODE
  import_mode = false

  # General Configuration  
  environment        = "production"
  vpc_name          = "euw1-production-vpc"
  cluster_name      = "eu-west-1-cluster-01"
  aws_region        = "eu-west-1"
  availability_zones = ["eu-west-1a", "eu-west-1b"]

  # NEW Infrastructure Configuration
  vpc_cidr         = "172.22.0.0/16"        # Different CIDR per region
  private_subnets  = ["172.22.1.0/24", "172.22.2.0/24"]
  public_subnets   = ["172.22.101.0/24", "172.22.102.0/24"]
  
  # Create new security groups for this region
  create_security_groups = true
  
  # VPN Configuration (configure per region needs)
  enable_vpn = true
  vpn_config = {
    customer_gateway_ip = "YOUR_REGION_VPN_IP"
    client_cidr        = "YOUR_CLIENT_CIDR"
    bgp_asn           = 6500
  }
}
```

## 📊 **Consistent SSM Parameter Structure**

**All regions (import or create mode) provide identical SSM parameters:**

```
/terraform/production/foundation/vpc_id
/terraform/production/foundation/vpc_cidr
/terraform/production/foundation/private_subnets
/terraform/production/foundation/public_subnets
/terraform/production/foundation/private_subnet_cidrs
/terraform/production/foundation/public_subnet_cidrs
/terraform/production/foundation/eks_cluster_security_group_id
/terraform/production/foundation/database_security_group_id
/terraform/production/foundation/alb_security_group_id
/terraform/production/foundation/vpn_enabled
/terraform/production/foundation/vpn_gateway_id
/terraform/production/foundation/deployed
/terraform/production/foundation/version
/terraform/production/foundation/mode
/terraform/production/foundation/region
/terraform/production/foundation/availability_zones
```

## 🗺️ **Regional CIDR Allocation Strategy**

```
us-east-1:      172.20.0.0/16  (existing - import mode)
us-west-2:      172.21.0.0/16  (future - create mode)
eu-west-1:      172.22.0.0/16  (future - create mode)
ap-southeast-1: 172.23.0.0/16  (future - create mode)
ca-central-1:   172.24.0.0/16  (future - create mode)
```

## 🔧 **Usage Examples**

### **Current Region (us-east-1) - Import Mode**
```bash
cd /terraform/regions/us-east-1/layers/01-foundation/production

# Initialize
terraform init -backend-config=../../../../../shared/backend-configs/foundation-production.hcl

# Plan (should show only SSM parameter creation, no infrastructure changes)
terraform plan

# Apply (creates only SSM parameters)
terraform apply
```

### **New Region (us-west-2) - Create Mode**
```bash
cd /terraform/regions/us-west-2/layers/01-foundation/production

# Initialize
terraform init -backend-config=../../../../../shared/backend-configs/foundation-production-usw2.hcl

# Plan (will show new VPC, subnets, security groups creation)
terraform plan

# Apply (creates new infrastructure)
terraform apply
```

## 🔒 **Security and Lifecycle Protection**

### **Import Mode (us-east-1):**
- ✅ **Zero modifications** to existing resources
- ✅ **Data sources only** for reading existing resources
- ✅ **SSM parameters protected** with prevent_destroy
- ✅ **No new resources** created in your VPC

### **Create Mode (future regions):**
- ✅ **New resources protected** with prevent_destroy  
- ✅ **Consistent security patterns** across regions
- ✅ **Same SSM parameter structure** as import mode
- ✅ **Same layer interface** for other layers

## 📈 **Benefits of Unified Approach**

### **Consistency Benefits:**
- 🎯 **Same module** for all regions
- 🎯 **Same SSM parameters** everywhere
- 🎯 **Same deployment process** everywhere
- 🎯 **Same layer dependencies** everywhere

### **Scalability Benefits:**
- 🚀 **Easy region expansion** using create mode
- 🚀 **Protected existing infrastructure** in import mode
- 🚀 **Unified operational procedures** across regions
- 🚀 **Consistent multi-region architecture**

### **Operational Benefits:**
- 💼 **Teams use same patterns** everywhere
- 💼 **Documentation applies** to all regions
- 💼 **Troubleshooting procedures** are consistent
- 💼 **CI/CD pipelines** work the same way

## 🎯 **Next Steps**

### **Immediate (us-east-1):**
1. Deploy foundation layer in import mode
2. Validate SSM parameters are created
3. Update other layers to use foundation SSM parameters
4. Test end-to-end functionality

### **Future Regions:**
1. Copy foundation layer structure to new region
2. Update tfvars for create mode with region-specific CIDR
3. Deploy foundation layer in create mode
4. Deploy other layers using same SSM parameter patterns

**Result: Full consistency across all regions with zero risk to existing infrastructure!**
