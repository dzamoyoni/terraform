# Infrastructure Modules

## Overview
This directory contains reusable Terraform modules for building scalable, multi-tenant infrastructure.

## Available Modules

### **Core Infrastructure**
- **`aws-load-balancer-controller`** - AWS Load Balancer Controller Helm deployment
- **`aws-load-balancer-controller-irsa`** - IRSA role and policies for ALB Controller
- **`ebs-csi-irsa`** - IRSA role for EBS CSI Driver
- **`external-dns`** - External DNS for Route53 automation
- **`external-dns-irsa`** - IRSA role and policies for External DNS
- **`ingress-class`** - Kubernetes ingress class configuration
- **`istio`** - **Istio Service Mesh** - Complete ambient mesh deployment with gateways
- **`route53-zones`** - Route53 hosted zones management

### **Cluster & Compute**
- **`eks-platform`** - EKS cluster wrapper with company standards
- **`vpc-foundation`** - VPC with public/private subnets and advanced networking
- **`client-subnets`** - Multi-tenant client subnet isolation
- **`ec2`** - EC2 instance management with enhanced configurations

## Module Design Principles

### **Multi-Tenancy**
- Client isolation through taints and tolerations
- Dedicated node groups per client
- Resource tagging for cost allocation
- Flexible scaling per client workload

### **Security**
- IRSA (IAM Roles for Service Accounts) for all AWS integrations
- Least privilege access policies
- VPC isolation and security groups
- No hardcoded credentials

### **Scalability**
- Support for on-demand and spot instances
- Auto-scaling based on workload demands
- Cost optimization through instance type diversity
- Regional deployment support

## Usage Examples

### **EKS Platform Deployment**
```hcl
module "eks_platform" {
  source = "../../modules/eks-platform"
  
  project_name = "your-project"
  environment  = "production"
  region       = "us-east-1"
  
  cluster_version = "1.30"
  vpc_id          = "vpc-0ec63df5e5566ea0c"
  platform_subnet_ids = ["subnet-xxx", "subnet-yyy"]
  
  node_groups = {
    client_prod = {
      name_suffix    = "client"
      instance_types = ["m5.large", "t3.xlarge"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      client         = "client-name"
    }
  }
}
```

### **Platform Services**
```hcl
module "aws_load_balancer_controller" {
  source = "../../modules/aws-load-balancer-controller"
  
  cluster_name = "us-test-cluster-01"
  vpc_id = "vpc-0ec63df5e5566ea0c"
  region = "us-east-1"
}
```

### **Istio Service Mesh**
```hcl
module "istio" {
  source = "../../modules/istio"
  
  cluster_name = "us-test-cluster-01"
  
  # Enable ambient mesh mode
  enable_ambient_mode = true
  
  # Configure gateways
  enable_ingress_gateway = true
  ingress_gateway_type = "LoadBalancer"
  
  # Enable monitoring
  enable_monitoring = true
  
  # Automatically enable ambient mode for specific namespaces
  ambient_namespaces = ["default", "production"]
}
```

## Recent Changes

### **Cleanup Completed (August 26, 2025)**
- **Removed:** Redundant modules: `nodegroups`, `alb`, `ec2`, `environment-base`, `vpn`
- **Kept:** Only essential modules for current and future infrastructure needs
- **Result:** Streamlined to 12 focused, production-ready modules
- **Reasoning:** 
  - `alb` functionality covered by `aws-load-balancer-controller`
  - `ec2` not needed for containerized workloads
  - `environment-base` replaced by layered architecture
  - `vpn` not currently used (can be re-added if needed)

## Module Status
|| Module | Status | Use Case |
|--------|---------|----------|
| `eks-platform` | ✅ Production | EKS cluster wrapper with company standards |
| `vpc-foundation` | ✅ Production | Network foundation with advanced features |
| `client-subnets` | ✅ Production | Multi-tenant client subnet isolation |
| `aws-load-balancer-controller*` | ✅ Production | ALB/NLB integration |
| `external-dns*` | ✅ Production | DNS automation |
| `observability-layer` | ✅ Production | Comprehensive monitoring stack |
| `postgres-ec2` | ✅ Production | PostgreSQL on EC2 with HA |
| `route53-zones` | ✅ Production | DNS zone management |
| `ec2` | ✅ Production | Enhanced EC2 instance management |
| `vpc` | ✅ Production | Network foundation |

**Note:** Modules marked with `*` include both the service and IRSA components.

---

**Last Updated:** January 21, 2025  
**Total Modules:** 13 production-ready modules (+ Istio service mesh)  
**Architecture:** Layered, multi-tenant, secure
