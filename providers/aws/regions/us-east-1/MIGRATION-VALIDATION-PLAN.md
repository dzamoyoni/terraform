# 🧪 US-East-1 Wrapper Migration Validation Plan

## Overview

This document outlines the comprehensive testing and validation plan for migrating US-East-1 from legacy patterns to modern AF-South-1 wrapper architecture **without any resource changes**.

## 🎯 Migration Objectives

### ✅ **What We're Doing**
- **Code Modernization**: Update Terraform code to use modern wrapper modules
- **Architecture Alignment**: Adopt AF-South-1 patterns for consistency
- **State Communication**: Migrate from SSM parameters to remote state
- **Tagging Standardization**: Apply CPTWN standard tags
- **Client Isolation Framework**: Prepare for future client separation

### ❌ **What We're NOT Doing**
- **No Resource Creation**: Zero new AWS resources
- **No Resource Deletion**: All existing resources remain
- **No Configuration Changes**: All resource configurations preserved
- **No Workload Impact**: All applications continue running
- **No Network Changes**: All network configurations unchanged

## 📋 Pre-Migration Checklist

### 1. **Current State Documentation** ✅
```bash
# Document current resources
terraform -chdir=regions/us-east-1/layers/01-foundation/production show
terraform -chdir=regions/us-east-1/layers/02-platform/production show
terraform -chdir=regions/us-east-1/layers/03-databases/production show

# Export current state for comparison
terraform -chdir=regions/us-east-1/layers/01-foundation/production show -json > pre-migration-foundation.json
terraform -chdir=regions/us-east-1/layers/02-platform/production show -json > pre-migration-platform.json
terraform -chdir=regions/us-east-1/layers/03-databases/production show -json > pre-migration-databases.json
```

### 2. **Backup Current Configurations** ✅
```bash
# Backup current files
cp regions/us-east-1/layers/01-foundation/production/main.tf regions/us-east-1/layers/01-foundation/production/main.tf.backup
cp regions/us-east-1/layers/02-platform/production/main.tf regions/us-east-1/layers/02-platform/production/main.tf.backup
cp regions/us-east-1/layers/03-databases/production/main.tf regions/us-east-1/layers/03-databases/production/main.tf.backup
```

### 3. **Application Status Check** 
```bash
# Verify all applications are running
kubectl get pods --all-namespaces
kubectl get nodes
kubectl get services --all-namespaces

# Test database connectivity
nc -zv 172.20.1.153 5433  # Ezra DB
nc -zv 172.20.2.33 5432   # MTN Ghana DB
```

## 🔄 Migration Process

### Phase 1: Foundation Layer Migration

#### **Step 1.1: Replace Main Configuration**
```bash
cd regions/us-east-1/layers/01-foundation/production/
mv main.tf main.tf.old
mv main-modern.tf main.tf
mv variables.tf variables.tf.old  
mv variables-modern.tf variables.tf
```

#### **Step 1.2: Validate Configuration**
```bash
terraform -chdir=regions/us-east-1/layers/01-foundation/production validate
terraform -chdir=regions/us-east-1/layers/01-foundation/production plan
```

#### **Step 1.3: Expected Plan Results**
- **Additions**: Multiple SSM parameters (client-specific subnet mappings)
- **Changes**: Tag updates on existing SSM parameters
- **Deletions**: None
- **Resource Count**: No change in managed resource count

#### **Step 1.4: Apply Changes**
```bash
terraform -chdir=regions/us-east-1/layers/01-foundation/production apply
```

#### **Step 1.5: Validation Tests**
```bash
# Verify SSM parameters were created
aws ssm get-parameter --name "/terraform/production/foundation/mtn_ghana_subnet_ids"
aws ssm get-parameter --name "/terraform/production/foundation/ezra_subnet_ids"

# Verify existing parameters still work
aws ssm get-parameter --name "/terraform/production/foundation/vpc_id"
aws ssm get-parameter --name "/terraform/production/foundation/private_subnets"
```

### Phase 2: Platform Layer Migration

#### **Step 2.1: Replace Platform Configuration**
```bash
cd regions/us-east-1/layers/02-platform/production/
mv main.tf main.tf.old
mv main-modern.tf main.tf
mv variables.tf variables.tf.old
mv variables-modern.tf variables.tf
```

#### **Step 2.2: Update Backend Configuration**
```bash
# Create new backend config for remote state communication
cat > backend-remote-state.hcl << EOF
bucket         = "usest1-terraform-state-ezra"
key            = "regions/us-east-1/layers/02-platform/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true
EOF
```

#### **Step 2.3: Initialize with New Backend**
```bash
terraform -chdir=regions/us-east-1/layers/02-platform/production init -backend-config=backend-remote-state.hcl
```

#### **Step 2.4: Validate and Plan**
```bash
terraform -chdir=regions/us-east-1/layers/02-platform/production validate
terraform -chdir=regions/us-east-1/layers/02-platform/production plan
```

#### **Step 2.5: Expected Plan Results**
- **Additions**: New shared services resources (if not existing)
- **Changes**: Updated tags on existing resources
- **Deletions**: None
- **EKS Cluster**: No changes
- **Node Groups**: No changes

#### **Step 2.6: Apply Changes**
```bash
terraform -chdir=regions/us-east-1/layers/02-platform/production apply
```

#### **Step 2.7: Validation Tests**
```bash
# Verify cluster is still operational
kubectl get nodes
kubectl get pods -n kube-system

# Verify platform services
kubectl get deployments -n kube-system | grep -E "(aws-load-balancer|external-dns|ebs-csi)"

# Test DNS functionality
kubectl get ingress --all-namespaces
nslookup stacai.ai
nslookup ezra.world
```

### Phase 3: Database Layer Migration

#### **Step 3.1: Replace Database Configuration**
```bash
cd regions/us-east-1/layers/03-databases/production/
mv main.tf main.tf.old
mv main-modern.tf main.tf
mv variables.tf variables.tf.old
mv variables-modern.tf variables.tf
```

#### **Step 3.2: Initialize with Remote State**
```bash
terraform -chdir=regions/us-east-1/layers/03-databases/production init -backend-config=backend-remote-state.hcl
```

#### **Step 3.3: Validate and Plan**
```bash
terraform -chdir=regions/us-east-1/layers/03-databases/production validate
terraform -chdir=regions/us-east-1/layers/03-databases/production plan
```

#### **Step 3.4: Expected Plan Results**
- **Additions**: None (all database resources already exist)
- **Changes**: Updated tags on existing database instances and volumes
- **Deletions**: None
- **Database Instances**: No configuration changes
- **EBS Volumes**: No configuration changes

#### **Step 3.5: Apply Changes**
```bash
terraform -chdir=regions/us-east-1/layers/03-databases/production apply
```

#### **Step 3.6: Database Validation Tests**
```bash
# Test database connectivity
nc -zv 172.20.1.153 5433  # Ezra DB
nc -zv 172.20.2.33 5432   # MTN Ghana DB

# Verify database instances are running
aws ec2 describe-instances --filters "Name=tag:Name,Values=mtn-ghana-prod-database"
aws ec2 describe-instances --filters "Name=tag:Name,Values=ezra-prod-app-01"

# Test SSM access to database instances
aws ssm describe-instance-information
```

## ✅ Post-Migration Validation

### 1. **Resource Inventory Comparison**
```bash
# Compare pre and post migration state
terraform -chdir=regions/us-east-1/layers/01-foundation/production show -json > post-migration-foundation.json
terraform -chdir=regions/us-east-1/layers/02-platform/production show -json > post-migration-platform.json
terraform -chdir=regions/us-east-1/layers/03-databases/production show -json > post-migration-databases.json

# Resource count should be same or higher (due to additional SSM parameters)
diff pre-migration-foundation.json post-migration-foundation.json
diff pre-migration-platform.json post-migration-platform.json  
diff pre-migration-databases.json post-migration-databases.json
```

### 2. **Application Health Checks**
```bash
# Verify all pods are still running
kubectl get pods --all-namespaces | grep -v Running

# Check for any failed deployments
kubectl get deployments --all-namespaces | grep -v "READY"

# Verify services are accessible
curl -I https://stacai.ai/health
curl -I https://ezra.world/health
```

### 3. **Infrastructure Connectivity Tests**
```bash
# Test database connectivity from EKS
kubectl run -i --tty --rm debug --image=postgres:13 --restart=Never -- bash
# Inside pod:
# psql -h 172.20.1.153 -p 5433 -U postgres  # Ezra
# psql -h 172.20.2.33 -p 5432 -U postgres   # MTN Ghana

# Test DNS resolution
nslookup stacai.ai
nslookup ezra.world

# Test load balancer functionality
kubectl get ingress --all-namespaces
```

### 4. **Security and Access Validation**
```bash
# Verify SSM access to database instances
aws ssm start-session --target i-xxxxx  # Database instance IDs

# Test IRSA functionality
kubectl get serviceaccounts -n kube-system
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system

# Verify security groups are functioning
aws ec2 describe-security-groups --group-ids sg-067bc5c25980da2cc  # Database SG
aws ec2 describe-security-groups --group-ids sg-014caac5c31fbc765  # EKS Cluster SG
```

### 5. **Remote State Communication Tests**
```bash
# Test cross-layer communication
cd regions/us-east-1/layers/02-platform/production/
terraform console
> data.terraform_remote_state.foundation.outputs.vpc_id
> data.terraform_remote_state.foundation.outputs.mtn_ghana_subnet_ids

cd regions/us-east-1/layers/03-databases/production/
terraform console
> data.terraform_remote_state.foundation.outputs.vpc_id
> data.terraform_remote_state.platform.outputs.cluster_name
```

## 🚨 Rollback Plan

### **Emergency Rollback Procedure**
If any issues occur during migration:

```bash
# Immediate rollback to previous configuration
cd regions/us-east-1/layers/XX-layer/production/
mv main.tf main.tf.modern
mv main.tf.old main.tf
mv variables.tf variables.tf.modern
mv variables.tf.old variables.tf

# Reinitialize with previous backend
terraform init
terraform plan  # Should show no changes
```

### **Rollback Validation**
```bash
# Verify applications are still running
kubectl get pods --all-namespaces
kubectl get nodes

# Test database connectivity
nc -zv 172.20.1.153 5433
nc -zv 172.20.2.33 5432
```

## 📊 Success Criteria

### ✅ **Migration Successful If**
1. **Zero Resource Changes**: No AWS resources created, modified, or deleted
2. **All Applications Running**: 29 pods operational
3. **Database Connectivity**: Both databases accessible
4. **DNS Functionality**: Both zones resolving correctly
5. **Load Balancer Working**: Ingress controllers functional
6. **Remote State Working**: Cross-layer communication functional
7. **Modern Patterns Applied**: CPTWN tags and wrapper modules active

### ❌ **Migration Failed If**
1. Any AWS resources are deleted or recreated
2. Any applications stop running
3. Database connectivity is lost
4. DNS resolution fails
5. Load balancers stop working
6. Cross-layer communication breaks

## 📝 Documentation Updates

### **Post-Migration Documentation**
1. Update layer READMEs to reflect new patterns
2. Document new SSM parameter structure
3. Update operational runbooks
4. Create troubleshooting guides for new architecture

## 🔄 Maintenance Tasks

### **Regular Validation**
```bash
# Weekly validation script
#!/bin/bash
echo "Validating US-East-1 Infrastructure..."

# Check all layers can plan with no changes
for layer in 01-foundation 02-platform 03-databases; do
  echo "Validating $layer..."
  terraform -chdir=regions/us-east-1/layers/$layer/production plan -detailed-exitcode
  if [ $? -eq 2 ]; then
    echo "WARNING: $layer has pending changes!"
  fi
done

# Test application health
kubectl get pods --all-namespaces | grep -v Running
if [ $? -eq 0 ]; then
  echo "WARNING: Some pods are not running!"
fi

echo "Validation complete."
```

## 🎯 Next Steps After Migration

1. **Monitor for 48 hours**: Ensure stability
2. **Performance Validation**: Compare metrics pre/post migration  
3. **Client Isolation Planning**: Prepare for true client subnet separation
4. **Documentation Review**: Update all documentation with new patterns
5. **Team Training**: Train team on new architecture patterns

---

**This migration plan ensures zero downtime, zero resource changes, and maintains all existing functionality while modernizing the codebase to match AF-South-1 patterns.**
