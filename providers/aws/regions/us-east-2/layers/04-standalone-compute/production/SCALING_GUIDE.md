# Standalone Compute Layer - Scaling Guide

## Overview

The standalone compute layer is designed with **enterprise-grade scaling** capabilities that allow you to easily provision analytics instances for new clients with **zero code changes**. The architecture automatically discovers available clients from the foundation layer and provides multiple scaling strategies.

## Current Architecture Strengths

✅ **Client-Isolated Design**: Each client gets completely separate resources  
✅ **Dynamic Configuration**: Uses `for_each` loops with `active_clients`  
✅ **Subnet-Scoped Security**: Security groups restricted to client-specific CIDR blocks  
✅ **Modular Structure**: Easy to add/remove clients by configuration changes  
✅ **Comprehensive Monitoring**: Per-client CloudWatch namespaces and SSM parameters  
✅ **Auto-Discovery**: Automatically finds available client subnets from foundation layer  

---

## Scaling Methods

### Method 1: Configuration-Based Scaling (Recommended)
**Best for**: Adding clients that already have foundation layer subnets

#### Steps:
1. **Enable the client** in `terraform.tfvars`:
   ```hcl
   enabled_clients = ["est-test-a", "est-test-b", "est-test-c"]
   ```

2. **Configure instance specs** (optional):
   ```hcl
   analytics_configs = {
     "est-test-c" = {
       instance_type      = "t3.xlarge"     # 4 vCPU, 16 GB RAM
       root_volume_size   = 40              # GB
       data_volume_size   = 200             # GB
     }
   }
   ```

3. **Apply changes**:
   ```bash
   terraform plan   # Review resources
   terraform apply  # Deploy new client instance
   ```

**Result**: Complete client isolation with dedicated instances, security groups, IAM roles, and monitoring.

---

### Method 2: Foundation-First Scaling
**Best for**: Adding completely new clients

#### Steps:
1. **Add client to foundation layer** first (Layer 01):
   - Update foundation layer configuration to include new client subnets
   - Apply foundation changes

2. **Follow Method 1** to enable in compute layer

---

### Method 3: Multi-Region Scaling
**Best for**: Geographic distribution

#### Steps:
1. **Deploy foundation in new region**
2. **Copy compute layer to new region**:
   ```bash
   cp -r us-east-2/layers/04-standalone-compute us-west-2/layers/04-standalone-compute
   ```
3. **Update region-specific configurations**
4. **Deploy in parallel**

---

## Scaling Examples

### Single Client Addition
```bash
# Before: 1 client (est-test-a) = 9 resources
terraform plan
# Plan: 9 to add, 0 to change, 0 to destroy

# After: 2 clients (est-test-a, est-test-b) = 17 resources
# Edit terraform.tfvars: enabled_clients = ["est-test-a", "est-test-b"]
terraform plan
# Plan: 17 to add, 0 to change, 0 to destroy
```

### Performance Scaling
```hcl
# High-performance analytics client
"est-prod-analytics" = {
  instance_type      = "m5.2xlarge"       # 8 vCPU, 32 GB RAM
  root_volume_size   = 50                 # GB
  data_volume_size   = 500                # GB - Large datasets
}

# Development/testing client
"est-dev-test" = {
  instance_type      = "t3.medium"        # 2 vCPU, 4 GB RAM
  root_volume_size   = 20                 # GB
  data_volume_size   = 50                 # GB - Minimal storage
}
```

---

## Security & Isolation Features

### Network Isolation
- **Per-Client Security Groups**: Each client can only access their own subnet CIDRs
- **No Cross-Client Access**: Analytics instances cannot communicate across clients
- **Subnet-Scoped Access**: Database and application ports restricted to client subnets only

### Resource Isolation
- **Dedicated IAM Roles**: Each client gets separate IAM instance profiles
- **Per-Client SSM Parameters**: Service discovery parameters namespaced by client
- **Isolated CloudWatch Logs**: Separate log groups for each client

---

## Monitoring & Management

### Per-Client Monitoring
```bash
# Check client-specific SSM parameters
aws ssm get-parameter --name "/terraform/production/est-test-a/analytics/endpoint"
aws ssm get-parameter --name "/terraform/production/est-test-a/analytics/instance-id"

# Client-specific CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/analytics/est-test-a"
```

### Scaling Metrics
- **Resource Count**: 9 resources per client (IAM + Instance + Security + SSM)
- **Network**: 2 subnet CIDRs per client (multi-AZ)
- **Storage**: Root + Data volumes (encrypted, customizable)

---

## Best Practices for Production Scaling

### 1. Capacity Planning
```hcl
# Use instance types that match workload requirements
analytics_configs = {
  # Data science workloads
  "client-data-science" = {
    instance_type = "r5.xlarge"    # Memory-optimized
    data_volume_size = 1000        # Large datasets
  }
  
  # Business intelligence
  "client-business-intel" = {
    instance_type = "c5.large"     # Compute-optimized
    data_volume_size = 200         # Moderate datasets
  }
}
```

### 2. Cost Optimization
```hcl
# Enable only active clients
enabled_clients = ["active-client-1", "active-client-2"]

# Use cost-effective instance types for development
"dev-client" = {
  instance_type = "t3.micro"      # Burstable, cost-effective
}
```

### 3. Operational Excellence
```bash
# Validate before applying
terraform plan -out=scale.plan
terraform show scale.plan        # Review detailed changes
terraform apply scale.plan       # Apply with confirmation
```

### 4. Disaster Recovery
- **Multi-AZ Deployment**: Automatically spreads across availability zones
- **EBS Snapshots**: Enable automated backups for data volumes
- **Infrastructure as Code**: Complete configuration in version control

---

## Troubleshooting Scaling Issues

### Issue: Client Not Scaling
```bash
# Check if foundation subnets exist
terraform console
> local.client_subnets

# Verify enabled clients configuration
> var.enabled_clients

# Check validation errors
terraform plan
```

### Issue: Foundation Dependencies
```bash
# Verify foundation layer is applied
cd ../01-foundation/production
terraform output

# Check platform layer integration
cd ../02-platform/production
terraform output cluster_name
```

---

## Scaling Checklist

**Pre-Scaling:**
- [ ] Foundation layer subnets exist for new client
- [ ] Instance type and storage requirements defined
- [ ] Network access requirements documented

**During Scaling:**
- [ ] Update `terraform.tfvars` with new client
- [ ] Run `terraform plan` to review changes
- [ ] Verify resource count matches expectations
- [ ] Apply changes with `terraform apply`

**Post-Scaling:**
- [ ] Verify instance accessibility via SSM
- [ ] Test application endpoints (Jupyter, custom apps)
- [ ] Confirm CloudWatch logging is working
- [ ] Update documentation with new client info

---

## Advanced Scaling Scenarios

### Auto-Scaling Groups (Future Enhancement)
```hcl
# Potential enhancement for dynamic scaling
resource "aws_autoscaling_group" "client_analytics" {
  for_each = local.active_clients
  
  min_size         = 1
  max_size         = 5
  desired_capacity = 2
  
  # Scale based on CPU or custom metrics
  vpc_zone_identifier = each.value.subnet_ids
}
```

### Container-Based Analytics (Alternative)
```hcl
# ECS-based scaling for containerized analytics
resource "aws_ecs_service" "client_analytics" {
  for_each = local.active_clients
  
  desired_count = var.analytics_configs[each.key].desired_count
  # Full container orchestration
}
```

---

## 📞 Support & Resources

- **Terraform Documentation**: Standard resource management
- **AWS Documentation**: EC2, VPC, IAM best practices  
- **Monitoring**: CloudWatch dashboards and alarms
- **Security**: VPC security groups and NACLs

---

**Last Updated**: October 2025  
**Version**: 1.0  
**Maintainer**: Platform Engineering Team