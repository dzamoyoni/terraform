# Multi-Region Independent EKS Clusters Strategy
## Same Codebase, Regional Independence, IP Optimization

### Architecture Overview
```
Global Structure:
terraform/
├── modules/ (shared across all regions)
├── shared/ (global configurations)
└── regions/
    ├── us-east-1/
    │   ├── clusters/
    │   │   ├── cluster-01/ (production)
    │   │   └── cluster-02/ (future scale-out)
    │   └── shared/ (region-specific configs)
    ├── us-west-2/
    │   ├── clusters/
    │   │   └── cluster-01/
    │   └── shared/
    └── eu-west-1/
        ├── clusters/
        │   └── cluster-01/
        └── shared/
```

### Regional Independence Principles

#### 1. Isolated State Management
```hcl
# Each region has separate state files
backend "s3" {
  bucket = "your-terraform-state"
  key    = "regions/${var.aws_region}/clusters/${var.cluster_name}/terraform.tfstate"
  region = "us-east-1"
}
```

#### 2. Regional Resource Naming
```hcl
# Consistent naming across regions
locals {
  cluster_name = "${var.region_code}-${var.environment}-cluster-${var.cluster_index}"
  # Examples:
  # use1-prod-cluster-01 (us-east-1)
  # usw2-prod-cluster-01 (us-west-2)  
  # euw1-prod-cluster-01 (eu-west-1)
}
```

#### 3. Independent VPC Per Region/Cluster
```hcl
# No cross-region dependencies
vpc_configs = {
  "us-east-1" = {
    vpc_cidr = "172.20.0.0/16"
    cluster_01 = "172.20.0.0/18"   # First cluster gets /18
    cluster_02 = "172.20.64.0/18"  # Second cluster gets /18
  }
  "us-west-2" = {
    vpc_cidr = "172.21.0.0/16" 
    cluster_01 = "172.21.0.0/18"
  }
  "eu-west-1" = {
    vpc_cidr = "172.22.0.0/16"
    cluster_01 = "172.22.0.0/18"
  }
}
```

### IP Allocation Strategy

#### Per-Region CIDR Planning
```
Region: us-east-1 (172.20.0.0/16)
├── cluster-01: 172.20.0.0/18   (16,384 IPs)
│   ├── Public: 172.20.0.0/22   (1,024 IPs)
│   ├── Private: 172.20.4.0/22  (1,024 IPs) 
│   └── Tenants: 172.20.8.0/21  (2,048 IPs)
└── cluster-02: 172.20.64.0/18  (16,384 IPs)
    ├── Public: 172.20.64.0/22
    ├── Private: 172.20.68.0/22
    └── Tenants: 172.20.72.0/21

Region: us-west-2 (172.21.0.0/16)
└── cluster-01: 172.21.0.0/18
    ├── Public: 172.21.0.0/22
    ├── Private: 172.21.4.0/22
    └── Tenants: 172.21.8.0/21
```

#### Tenant Subnet Allocation
```hcl
# Scalable tenant subnets per cluster
tenant_subnet_allocation = {
  base_cidr = "172.${region_octet}.${cluster_offset + 8}.0/21"  # 2048 IPs
  
  # Each tenant gets /24 subnets (254 IPs each)
  ezra = {
    subnets = ["172.${region_octet}.${cluster_offset + 8}.0/24", 
               "172.${region_octet}.${cluster_offset + 9}.0/24"]
  }
  mtn_ghana = {
    subnets = ["172.${region_octet}.${cluster_offset + 10}.0/24", 
               "172.${region_octet}.${cluster_offset + 11}.0/24"]
  }
  # Room for 4 more tenants...
}
```

### Codebase Structure for Regional Independence

#### 1. Shared Modules (Reusable)
```
modules/
├── foundation-layer/      # VPC, subnets, security groups
├── multi-client-nodegroups/  # Enhanced with IP optimization
├── tenant-subnets/       # Dedicated tenant networking
├── cluster-autoscaler/   # Compatible with multiple regions
└── monitoring/           # Regional monitoring stack
```

#### 2. Regional Configuration Structure
```
regions/us-east-1/
├── shared/
│   ├── networking.tfvars      # Region networking config
│   ├── backend.tfvars         # State backend config
│   └── common.tfvars          # Common region settings
└── clusters/
    └── production/
        ├── main.tf            # Cluster-specific config
        ├── terraform.tfvars   # Cluster variables
        └── backend.tf         # Remote state
```

#### 3. Environment-Specific Overlays
```
regions/us-west-2/
├── shared/
│   └── networking.tfvars      # Different CIDR, same structure
└── clusters/
    └── production/
        ├── main.tf            # Identical to us-east-1
        └── terraform.tfvars   # Region-specific values
```

### Regional Configuration Examples

#### US-East-1 Configuration
```hcl
# regions/us-east-1/shared/networking.tfvars
region_code = "use1"
aws_region = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# VPC Configuration
vpc_cidr = "172.20.0.0/16"
cluster_base_offset = 0  # First cluster starts at 172.20.0.0

# Tenant subnet planning
tenant_base_cidr = "172.20.8.0/21"
enable_dedicated_tenant_subnets = true
```

#### US-West-2 Configuration  
```hcl
# regions/us-west-2/shared/networking.tfvars
region_code = "usw2"
aws_region = "us-west-2" 
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# VPC Configuration (different CIDR, same structure)
vpc_cidr = "172.21.0.0/16"
cluster_base_offset = 0

# Tenant subnet planning
tenant_base_cidr = "172.21.8.0/21"
enable_dedicated_tenant_subnets = true
```

### Cluster-Level Configuration Template

#### Main Cluster Configuration (Same across regions)
```hcl
# regions/${region}/clusters/production/main.tf
module "foundation" {
  source = "../../../../modules/foundation-layer"
  
  # Region-agnostic variables
  environment = var.environment
  cluster_name = local.cluster_name
  
  # Region-specific from shared config
  aws_region = var.aws_region
  vpc_cidr = var.vpc_cidr
  availability_zones = var.availability_zones
  
  # Import mode for existing, create mode for new regions
  import_mode = var.region_has_existing_infrastructure
}

module "tenant_subnets" {
  source = "../../../../modules/tenant-subnets"
  count  = var.enable_dedicated_tenant_subnets ? 1 : 0
  
  vpc_id = module.foundation.vpc_id
  cluster_name = local.cluster_name
  tenant_base_cidr = var.tenant_base_cidr
  
  tenant_configs = var.tenant_configs
}

module "multi_client_nodegroups" {
  source = "../../../../modules/multi-client-nodegroups"
  
  cluster_name = local.cluster_name
  vpc_id = module.foundation.vpc_id
  private_subnets = module.foundation.private_subnet_ids
  
  client_nodegroups = var.client_nodegroups
}
```

### IP Optimization Configuration

#### Enhanced Nodegroup Configuration (All Regions)
```hcl
# Same configuration works across all regions
client_nodegroups = {
  ezra = {
    # IP Optimization
    enable_prefix_delegation = true
    max_pods_per_node = 110
    use_launch_template = true
    
    # Use dedicated subnets if available
    dedicated_subnet_ids = var.enable_dedicated_tenant_subnets ? 
      module.tenant_subnets[0].tenant_subnet_ids["ezra"] : []
    
    # Standard configuration
    capacity_type = "ON_DEMAND"
    instance_types = ["m5.large", "c5.large"]
    desired_size = 2
    max_size = 10
    min_size = 1
    
    custom_taints = [{
      key    = "tenant"
      value  = "ezra" 
      effect = "NO_SCHEDULE"
    }]
  }
  
  mtn_ghana = {
    enable_prefix_delegation = true
    max_pods_per_node = 110
    use_launch_template = true
    
    dedicated_subnet_ids = var.enable_dedicated_tenant_subnets ? 
      module.tenant_subnets[0].tenant_subnet_ids["mtn_ghana"] : []
      
    capacity_type = "ON_DEMAND"
    instance_types = ["m5.large", "c5.large"]  
    desired_size = 2
    max_size = 10
    min_size = 1
    
    custom_taints = [{
      key    = "tenant"
      value  = "mtn_ghana"
      effect = "NO_SCHEDULE"
    }]
  }
}
```

### Deployment Process

#### 1. New Region Deployment
```bash
# Set up new region (us-west-2)
cd regions/us-west-2/clusters/production

# Initialize with region-specific backend
terraform init -backend-config=../../shared/backend.tfvars

# Plan with regional configuration
terraform plan -var-file="../../shared/networking.tfvars" -var-file="terraform.tfvars"

# Deploy independent cluster
terraform apply
```

#### 2. Scale-Out Within Region
```bash
# Add second cluster in existing region
cd regions/us-east-1/clusters/cluster-02

# Different state file, same region
terraform init -backend-config=backend.tfvars

# Deploy with different cluster offset
terraform apply -var="cluster_index=02" -var="cluster_base_offset=64"
```

### Benefits of This Approach

✅ **Regional Independence**: No cross-region dependencies
✅ **Code Reusability**: Same modules work everywhere  
✅ **Scalability**: Easy to add regions and clusters
✅ **IP Optimization**: Prefix delegation + dedicated subnets
✅ **Fault Isolation**: Regional failures don't affect others
✅ **Compliance**: Meet data residency requirements
✅ **Cost Control**: Per-region resource management
