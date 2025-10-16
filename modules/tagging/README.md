# Centralized Tagging Module

## Overview

This module provides consistent, scalable, and enterprise-grade tagging for all AWS resources across your infrastructure. It generates standardized tags based on organizational policies, environment context, and infrastructure layer specifics.

## Features

- ✅ **Consistent Tagging**: Standardized tags across all layers and environments
- ✅ **Scalable Design**: Easy to extend and customize for new requirements
- ✅ **Cost Management**: Built-in tags for cost allocation and chargeback
- ✅ **Compliance Support**: Tags for governance and regulatory compliance
- ✅ **Multi-tenancy**: Support for client-specific and tenant-specific tags
- ✅ **Auto-generated Values**: Dynamic tags like dates, regions, and account IDs
- ✅ **Validation**: Input validation to ensure tag consistency
- ✅ **Multiple Output Types**: Different tag combinations for different use cases

## Tag Categories

### 1. Organizational Tags
- Organization, Project, Portfolio
- Business Unit, Cost Center
- Owner, Contact Email

### 2. Infrastructure Tags  
- Managed By, Terraform Module
- Region, Availability Zones
- Account, Account Alias

### 3. Environment Tags
- Environment, Environment Type
- Layer, Layer Purpose
- Deployment Phase, Version

### 4. Operational Tags
- Critical Infrastructure, Security Level
- Backup Required, SLA Tier
- Monitoring Level, Maintenance Window

### 5. Cost Management Tags
- Billing Group, Chargeback Code
- Budget, Cost Optimization
- Auto Scaling, Instance Schedule

### 6. Client/Tenant Tags
- Client Name, Client Code
- Tenant ID, Service Level
- Client Tier, Client Region

### 7. Governance Tags
- Created By, Creation Date
- Change Ticket, Compliance Framework
- Data Retention, Archive Policy

## Usage Examples

### Basic Usage

```hcl
module "tags" {
  source = "../../../modules/tagging"
  
  # Required variables
  project_name = "CPTWN-Multi-Client-EKS"
  environment  = "production"
  layer_name   = "foundation"
  region       = "us-east-2"
}

# Use standard tags in provider
provider "aws" {
  default_tags {
    tags = module.tags.standard_tags
  }
}

# Use tags in resources
resource "aws_s3_bucket" "example" {
  bucket = "example-bucket"
  tags   = module.tags.standard_tags
}
```

### Advanced Usage with Client-Specific Tags

```hcl
module "client_tags" {
  source = "../../../modules/tagging"
  
  project_name = "CPTWN-Multi-Client-EKS"
  environment  = "production"
  layer_name   = "platform"
  region       = "us-east-2"
  
  # Client-specific configuration
  client_name    = "mtn-ghana-prod"
  client_code    = "MTN-GH"
  client_tier    = "premium"
  tenant_id      = "mtn-ghana-production"
  service_level  = "Gold"
  
  # Custom tags
  additional_tags = {
    Application = "Mobile-Money-Platform"
    Integration = "MTN-Core-Systems"
  }
}

# Use client-specific tags
resource "aws_eks_node_group" "client_nodes" {
  tags = module.client_tags.client_tags
}
```

### Layer-Specific Usage

```hcl
# Foundation Layer
module "foundation_tags" {
  source = "../../../modules/tagging"
  
  project_name     = "CPTWN-Multi-Client-EKS"
  environment      = "production"
  layer_name       = "foundation"
  layer_purpose    = "VPC and Networking Foundation"
  deployment_phase = "Phase-1"
}

# Platform Layer  
module "platform_tags" {
  source = "../../../modules/tagging"
  
  project_name       = "CPTWN-Multi-Client-EKS"
  environment        = "production"
  layer_name         = "platform"
  layer_purpose      = "EKS Cluster and Platform Services"
  deployment_phase   = "Phase-2"
  kubernetes_version = "1.28"
}

# Database Layer
module "database_tags" {
  source = "../../../modules/tagging"
  
  project_name     = "CPTWN-Multi-Client-EKS"
  environment      = "production"
  layer_name       = "database"
  layer_purpose    = "Client Database Infrastructure"
  deployment_phase = "Phase-3"
  database_engine  = "PostgreSQL"
  backup_strategy  = "Daily-Full-Weekly-Archive"
}
```

## Output Types

### `standard_tags`
Standard tags for most AWS resources
```hcl
tags = module.tags.standard_tags
```

### `minimal_tags`
Essential tags for cost-sensitive resources
```hcl
tags = module.tags.minimal_tags
```

### `comprehensive_tags`
Full tag set for critical infrastructure
```hcl
tags = module.tags.comprehensive_tags
```

### `client_tags`
Tags with client-specific information
```hcl
tags = module.tags.client_tags
```

### `kubernetes_labels`
Tags formatted as Kubernetes labels
```hcl
labels = module.tags.kubernetes_labels
```

## Best Practices

### 1. Provider-Level Tagging
Use provider-level default tags for consistency:

```hcl
provider "aws" {
  default_tags {
    tags = module.tags.standard_tags
  }
}
```

### 2. Resource-Specific Tags
Merge standard tags with resource-specific tags:

```hcl
resource "aws_instance" "example" {
  tags = merge(
    module.tags.standard_tags,
    {
      Name        = "example-instance"
      Purpose     = "Application-Server"
      ServerRole  = "Frontend"
    }
  )
}
```

### 3. Client-Specific Resources
Use client tags for multi-tenant resources:

```hcl
module "client_tags" {
  source      = "../../../modules/tagging"
  # ... standard config ...
  client_name = "mtn-ghana-prod"
  # ... client config ...
}

resource "aws_subnet" "client_subnet" {
  tags = module.client_tags.client_tags
}
```

### 4. Cost Allocation
Enable proper cost allocation:

```hcl
module "tags" {
  source = "../../../modules/tagging"
  # ... standard config ...
  
  cost_center         = "IT-Infrastructure"
  billing_group       = "Platform-Engineering"
  chargeback_code     = "CPTWN-INFRA-001"
  budget_name         = "EKS-Platform-Budget"
}
```

## Layer Configuration Examples

### Foundation Layer
```hcl
deployment_phase = "Phase-1"
layer_purpose    = "VPC, Subnets, NAT Gateways, VPN"
critical_infrastructure = "true"
backup_required = "true"
security_level  = "High"
```

### Platform Layer
```hcl
deployment_phase   = "Phase-2"
layer_purpose      = "EKS Cluster and Node Groups"
kubernetes_version = "1.28"
sla_tier          = "Gold"
monitoring_level  = "Premium"
```

### Observability Layer
```hcl
deployment_phase = "Phase-3.5"
layer_purpose    = "Monitoring, Logging, Tracing"
monitoring_level = "Premium"
data_retention   = "90-days"
```

## Validation

The module includes validation for:
- Valid environment names
- Valid layer names  
- Email format validation
- Security level validation
- SLA tier validation
- Data classification validation

## Integration with Existing Layers

To integrate with your existing layers, replace current tag blocks with module calls:

**Before:**
```hcl
common_tags = {
  Project         = "CPTWN-Multi-Client-EKS"
  Environment     = var.environment
  ManagedBy       = "Terraform"
  Layer           = "Foundation"
}
```

**After:**
```hcl
module "tags" {
  source = "../../../../../../../modules/tagging"
  
  project_name     = var.project_name
  environment      = var.environment
  layer_name       = "foundation"
  region           = var.region
  deployment_phase = "Phase-1"
}

# Use in locals
locals {
  common_tags = module.tags.standard_tags
}
```

## Migration Guide

1. **Add the tagging module** to your layer
2. **Replace hardcoded tags** with module outputs
3. **Update provider configuration** to use default tags
4. **Test and validate** tag consistency
5. **Update documentation** and team guidelines

This ensures consistent, scalable, and maintainable tagging across your entire infrastructure.