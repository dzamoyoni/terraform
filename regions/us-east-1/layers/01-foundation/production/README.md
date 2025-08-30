# Foundation Layer Deployment Guide

## Overview

This is the **01-foundation** layer of the multi-tenant Terraform architecture. It provides the foundational networking and security infrastructure that all other layers depend on.

## What This Layer Provides

### 🌐 **Networking Infrastructure**
- VPC with CIDR: `172.20.0.0/16`
- Private subnets: `172.20.1.0/24`, `172.20.2.0/24`
- Public subnets: `172.20.101.0/24`, `172.20.102.0/24`
- NAT Gateway for outbound internet access
- Internet Gateway for public subnet access
- Route tables and associations

### 🔒 **Security Groups**
- **EKS Cluster Security Group**: Controls access to EKS control plane
- **Database Security Group**: Controls database access from private subnets  
- **ALB Security Group**: Controls HTTP/HTTPS traffic to load balancers
- **VPN Security Group**: Controls VPN client access

### 🔗 **VPN Infrastructure**
- Primary VPN connection: `178.162.141.150` → `178.162.141.130/32`
- Secondary VPN connection: `165.90.14.138` → `165.90.14.138/32`
- Customer gateways, VPN gateways, and routing

### 📊 **SSM Parameters for Cross-Layer Communication**
All foundation outputs are stored in SSM Parameter Store for other layers:
- `/terraform/production/foundation/vpc_id`
- `/terraform/production/foundation/private_subnets`
- `/terraform/production/foundation/public_subnets`
- `/terraform/production/foundation/vpc_cidr`
- And more security group and network information

## Dependencies

### ✅ **Prerequisites**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- S3 backend bucket: `usest1-terraform-state-ezra`
- DynamoDB table: `terraform-locks`

### 📋 **Required Permissions**
- VPC management (create/modify VPC, subnets, gateways)
- Security group management
- VPN management
- SSM Parameter Store write access
- S3 and DynamoDB for state management

## Deployment Instructions

### 1. **Initialize Terraform**
```bash
cd /home/dennis.juma/terraform/regions/us-east-1/layers/01-foundation/production

# Initialize with backend configuration
terraform init -backend-config=../../../../../shared/backend-configs/foundation-production.hcl
```

### 2. **Validate Configuration**
```bash
# Check configuration syntax
terraform validate

# Review planned changes
terraform plan -var-file=terraform.tfvars
```

### 3. **Deploy Foundation Layer**
```bash
# Apply foundation layer (this will create new VPC infrastructure)
terraform apply -var-file=terraform.tfvars
```

### 4. **Verify Deployment**
```bash
# Check that SSM parameters were created
aws ssm get-parameters-by-path --path "/terraform/production/foundation/" --region us-east-1

# Verify VPC was created
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=main-production-vpc" --region us-east-1
```

## Integration with Other Layers

### 🔗 **Layer Dependencies**
```
01-foundation (THIS LAYER)
    ↓
02-platform (uses foundation VPC & security groups)
    ↓  
03-databases (uses foundation networking)
    ↓
04-client (uses foundation + platform resources)
```

### 📝 **Migration from Hardcoded Values**
The platform layer has been updated to use foundation layer outputs:

**Before (hardcoded):**
```hcl
locals {
  vpc_id          = "vpc-0ec63df5e5566ea0c"
  private_subnets = ["subnet-0a6936df3ff9a4f77", "subnet-0ec8a91aa274caea1"]
}
```

**After (foundation layer):**
```hcl
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/production/foundation/vpc_id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

## Configuration Details

### 🏗️ **Network Architecture**
- **VPC CIDR**: `172.20.0.0/16`
- **Availability Zones**: `us-east-1a`, `us-east-1b`
- **Private Subnets**: `172.20.1.0/24` (1a), `172.20.2.0/24` (1b)
- **Public Subnets**: `172.20.101.0/24` (1a), `172.20.102.0/24` (1b)

### 🔐 **Security Groups**
1. **EKS Cluster SG**: Allows HTTPS (443) from private subnets
2. **Database SG**: Allows PostgreSQL (5432) and MySQL (3306) from private subnets  
3. **ALB SG**: Allows HTTP (80) and HTTPS (443) from internet
4. **VPN SG**: Allows traffic from VPN client CIDRs

### 🌐 **VPN Configuration**
- **Primary**: `178.162.141.150` with BGP ASN `6500`
- **Secondary**: `165.90.14.138` with BGP ASN `6500`
- Static routing for client access

## Troubleshooting

### ❗ **Common Issues**

1. **Backend Access Error**
   ```bash
   Error: Failed to get existing workspaces: S3 bucket does not exist
   ```
   **Solution**: Ensure S3 bucket `usest1-terraform-state-ezra` exists and you have access.

2. **VPC Conflict**
   ```bash
   Error: VPC CIDR block conflicts with existing VPC
   ```
   **Solution**: Check for existing VPCs with overlapping CIDR ranges.

3. **SSM Parameter Permission Denied**
   ```bash
   Error: AccessDenied: User is not authorized to perform: ssm:PutParameter
   ```
   **Solution**: Ensure your AWS credentials have SSM write permissions.

### 🔍 **Validation Commands**
```bash
# Check foundation layer resources
terraform show | grep -E "(vpc|subnet|security_group)"

# Verify SSM parameters
aws ssm describe-parameters --region us-east-1 | grep foundation

# Check VPN status
aws ec2 describe-vpn-connections --region us-east-1
```

## Next Steps

After successful foundation layer deployment:

1. ✅ **Update platform layer**: The platform layer will now use foundation layer SSM parameters
2. ✅ **Update database layer**: Database layer will reference foundation networking
3. ✅ **Update client layer**: Client layer will use foundation + platform resources
4. ✅ **Test end-to-end**: Validate that all layers work together properly

## Resource Summary

### 📊 **Resources Created**
- 1 VPC with DNS support
- 2 Public subnets + 2 Private subnets  
- 1 Internet Gateway + 1 NAT Gateway
- 4 Security groups (EKS, Database, ALB, VPN)
- 2 VPN connections (primary + secondary)
- 15+ SSM parameters for cross-layer communication

### 💰 **Estimated Monthly Cost**
- VPC: Free
- NAT Gateway: ~$32/month
- VPN Connections: ~$72/month (2 connections)
- **Total**: ~$104/month

This foundation layer provides a robust, secure, and scalable networking foundation for your multi-tenant architecture.
