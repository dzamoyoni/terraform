# Operational Runbooks for Scalable Terraform Architecture

## Overview

This document provides comprehensive operational procedures for managing the scalable Terraform architecture, including deployment procedures, troubleshooting guides, maintenance tasks, and emergency response protocols.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Deployment Procedures](#deployment-procedures)
3. [Troubleshooting Guide](#troubleshooting-guide)
4. [Maintenance Tasks](#maintenance-tasks)
5. [Emergency Procedures](#emergency-procedures)
6. [Monitoring and Alerting](#monitoring-and-alerting)
7. [Client Onboarding](#client-onboarding)
8. [Team Procedures](#team-procedures)

## Daily Operations

### 1. Health Checks

#### Morning Health Check (Daily at 9:00 AM)
```bash
#!/bin/bash
# Daily health check script

echo "=== Daily Infrastructure Health Check ==="
date

# Check all layer states
ENVIRONMENTS=("production" "staging" "development")
LAYERS=("01-foundation" "02-platform" "03-databases")

for env in "${ENVIRONMENTS[@]}"; do
    echo "Checking $env environment..."
    
    for layer in "${LAYERS[@]}"; do
        cd "regions/us-east-1/layers/$layer/$env"
        
        echo "[$env/$layer] Refreshing state..."
        terraform refresh -input=false > /dev/null
        
        echo "[$env/$layer] Checking for drift..."
        if terraform plan -detailed-exitcode -input=false > /dev/null; then
            echo "✅ [$env/$layer] No drift detected"
        else
            exit_code=$?
            if [ $exit_code -eq 2 ]; then
                echo "⚠️  [$env/$layer] DRIFT DETECTED - Requires attention"
                # Log drift details
                terraform plan -no-color > "/tmp/drift-$env-$layer-$(date +%Y%m%d).txt"
            else
                echo "❌ [$env/$layer] ERROR - Plan failed"
            fi
        fi
    done
done

# Check client states
CLIENTS=("mtn-ghana" "ezra")
for env in "${ENVIRONMENTS[@]}"; do
    for client in "${CLIENTS[@]}"; do
        if [[ -d "regions/us-east-1/clients/$client/$env" ]]; then
            cd "regions/us-east-1/clients/$client/$env"
            
            echo "[$env/$client] Checking client state..."
            if terraform plan -detailed-exitcode -input=false > /dev/null; then
                echo "✅ [$env/$client] No drift detected"
            else
                echo "⚠️  [$env/$client] Drift or issues detected"
            fi
        fi
    done
done

echo "=== Health Check Complete ==="
```

#### Cross-Layer Communication Check
```bash
#!/bin/bash
# Check SSM parameters for cross-layer communication

check_ssm_parameters() {
    local env=$1
    local region="us-east-1"
    
    echo "Checking SSM parameters for $env environment..."
    
    # Foundation layer parameters
    echo "Foundation parameters:"
    aws ssm get-parameters-by-path \
        --path "/$env/$region/foundation" \
        --recursive \
        --query 'Parameters[*].[Name,Value]' \
        --output table || echo "❌ Foundation parameters missing"
    
    # Platform layer parameters
    echo "Platform parameters:"
    aws ssm get-parameters-by-path \
        --path "/$env/$region/platform" \
        --recursive \
        --query 'Parameters[*].[Name,Value]' \
        --output table || echo "❌ Platform parameters missing"
    
    # Test EKS connectivity
    echo "Testing EKS connectivity..."
    CLUSTER_NAME=$(aws ssm get-parameter \
        --name "/$env/$region/platform/cluster_name" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null)
    
    if [[ -n "$CLUSTER_NAME" ]]; then
        aws eks update-kubeconfig --region $region --name $CLUSTER_NAME
        kubectl cluster-info > /dev/null && echo "✅ EKS connectivity OK" || echo "❌ EKS connectivity failed"
    fi
}

check_ssm_parameters "production"
check_ssm_parameters "staging"
```

### 2. State File Management

#### Daily State Backup
```bash
#!/bin/bash
# Automated state backup script

BACKUP_BUCKET="terraform-state-backups-$(date +%Y%m%d)"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup bucket if it doesn't exist
aws s3 mb "s3://$BACKUP_BUCKET" 2>/dev/null || true

backup_state() {
    local layer_path=$1
    local backup_name=$2
    
    cd "$layer_path"
    
    # Pull current state
    terraform state pull > "terraform-state-$DATE.json"
    
    # Upload to backup bucket
    aws s3 cp "terraform-state-$DATE.json" \
        "s3://$BACKUP_BUCKET/$backup_name-$DATE.json"
    
    # Keep only last 30 days of local backups
    find . -name "terraform-state-*.json" -mtime +30 -delete
    
    echo "✅ Backed up state: $backup_name"
}

# Backup all production states
backup_state "regions/us-east-1/layers/01-foundation/production" "foundation-production"
backup_state "regions/us-east-1/layers/02-platform/production" "platform-production"
backup_state "regions/us-east-1/layers/03-databases/production" "databases-production"

# Backup client states
for client in mtn-ghana ezra; do
    if [[ -d "regions/us-east-1/clients/$client/production" ]]; then
        backup_state "regions/us-east-1/clients/$client/production" "client-$client-production"
    fi
done
```

## Deployment Procedures

### 1. Standard Deployment Process

#### Foundation Layer Deployment
```bash
#!/bin/bash
# Foundation layer deployment procedure

deploy_foundation() {
    local environment=$1
    local region="us-east-1"
    
    echo "=== Deploying Foundation Layer to $environment ==="
    
    # Pre-deployment checks
    echo "1. Pre-deployment validation..."
    cd "regions/$region/layers/01-foundation/$environment"
    
    # Check terraform version
    terraform version
    
    # Initialize backend
    echo "2. Initializing backend..."
    terraform init -backend-config="../../../../../shared/backend-configs/$environment.hcl" -upgrade
    
    # Validate configuration
    echo "3. Validating configuration..."
    terraform validate || { echo "❌ Validation failed"; exit 1; }
    
    # Generate plan
    echo "4. Generating plan..."
    terraform plan -out="foundation-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Review plan (manual step)
    echo "5. Please review the plan above."
    read -p "Continue with apply? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    
    # Apply changes
    echo "6. Applying changes..."
    terraform apply "foundation-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Verify SSM parameters
    echo "7. Verifying SSM parameters..."
    sleep 30  # Wait for parameters to be created
    aws ssm get-parameters-by-path --path "/$environment/$region/foundation" --recursive
    
    echo "✅ Foundation deployment completed successfully"
}

# Usage
deploy_foundation "production"
```

#### Platform Layer Deployment
```bash
#!/bin/bash
# Platform layer deployment procedure

deploy_platform() {
    local environment=$1
    local region="us-east-1"
    
    echo "=== Deploying Platform Layer to $environment ==="
    
    # Wait for foundation dependencies
    echo "1. Checking foundation dependencies..."
    aws ssm wait parameter-exists --name "/$environment/$region/foundation/vpc_id" || {
        echo "❌ Foundation dependencies not ready"
        exit 1
    }
    
    cd "regions/$region/layers/02-platform/$environment"
    
    # Initialize and validate
    echo "2. Initializing backend..."
    terraform init -backend-config="../../../../../shared/backend-configs/$environment.hcl" -upgrade
    
    echo "3. Validating configuration..."
    terraform validate || { echo "❌ Validation failed"; exit 1; }
    
    # Generate and apply plan
    echo "4. Generating plan..."
    terraform plan -out="platform-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Manual review
    read -p "Continue with apply? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    
    echo "5. Applying changes..."
    terraform apply "platform-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Verify EKS cluster
    echo "6. Verifying EKS cluster..."
    CLUSTER_NAME=$(aws ssm get-parameter \
        --name "/$environment/$region/platform/cluster_name" \
        --query 'Parameter.Value' \
        --output text)
    
    aws eks update-kubeconfig --region $region --name $CLUSTER_NAME
    kubectl cluster-info
    kubectl get nodes
    
    echo "✅ Platform deployment completed successfully"
}

deploy_platform "production"
```

#### Client Deployment
```bash
#!/bin/bash
# Client infrastructure deployment procedure

deploy_client() {
    local client=$1
    local environment=$2
    local region="us-east-1"
    
    echo "=== Deploying $client Client Infrastructure to $environment ==="
    
    # Check platform dependencies
    echo "1. Checking platform dependencies..."
    aws ssm wait parameter-exists --name "/$environment/$region/platform/cluster_name" || {
        echo "❌ Platform dependencies not ready"
        exit 1
    }
    
    cd "regions/$region/clients/$client/$environment"
    
    # Initialize and validate
    echo "2. Initializing backend..."
    terraform init -backend-config="../../../../../../shared/backend-configs/$environment.hcl" -upgrade
    
    echo "3. Validating configuration..."
    terraform validate || { echo "❌ Validation failed"; exit 1; }
    
    # Generate plan
    echo "4. Generating plan..."
    terraform plan -out="client-$client-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Manual review
    read -p "Continue with apply? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    
    echo "5. Applying changes..."
    terraform apply "client-$client-$environment-$(date +%Y%m%d_%H%M%S).tfplan"
    
    # Verify client resources
    echo "6. Verifying client resources..."
    kubectl get namespace | grep $client
    kubectl get nodes -l client=$client
    
    echo "✅ Client $client deployment completed successfully"
}

deploy_client "mtn-ghana" "production"
```

### 2. Emergency Deployment Procedures

#### Hotfix Deployment
```bash
#!/bin/bash
# Emergency hotfix deployment procedure

emergency_deploy() {
    local layer=$1
    local environment=$2
    local region="us-east-1"
    
    echo "🚨 EMERGENCY DEPLOYMENT INITIATED 🚨"
    echo "Layer: $layer, Environment: $environment"
    
    # Create emergency backup
    echo "1. Creating emergency backup..."
    cd "regions/$region/layers/$layer/$environment"
    terraform state pull > "emergency-backup-$(date +%Y%m%d_%H%M%S).json"
    
    # Fast track deployment
    echo "2. Emergency deployment (skipping manual approval)..."
    terraform init -backend-config="../../../../../shared/backend-configs/$environment.hcl"
    terraform plan -out="emergency.tfplan"
    terraform apply -auto-approve "emergency.tfplan"
    
    # Immediate verification
    echo "3. Emergency verification..."
    if terraform plan -detailed-exitcode; then
        echo "✅ Emergency deployment successful"
    else
        echo "❌ Emergency deployment has issues"
        echo "🔄 Initiating emergency rollback..."
        terraform state push "emergency-backup-$(date +%Y%m%d_%H%M%S).json"
    fi
    
    # Notify teams
    echo "4. Notifying teams..."
    # Add notification commands here (Slack, email, etc.)
}
```

## Troubleshooting Guide

### 1. Common Issues and Solutions

#### State Lock Issues
```bash
# Issue: State is locked by another operation
# Solution: Force unlock (use with caution)

check_and_unlock_state() {
    local layer_path=$1
    
    cd "$layer_path"
    
    # Try to get state info
    if terraform plan > /dev/null 2>&1; then
        echo "✅ State is not locked"
        return 0
    fi
    
    # Check for lock
    echo "State appears to be locked. Checking lock info..."
    terraform force-unlock -force LOCK_ID_HERE
    
    # Verify unlock
    if terraform plan > /dev/null 2>&1; then
        echo "✅ State successfully unlocked"
    else
        echo "❌ Manual intervention required"
    fi
}
```

#### Cross-Layer Communication Failures
```bash
# Issue: Layer cannot access SSM parameters from dependencies
# Solution: Verify and recreate parameters

fix_cross_layer_communication() {
    local environment=$1
    local region="us-east-1"
    
    echo "Diagnosing cross-layer communication for $environment..."
    
    # Check if foundation parameters exist
    if ! aws ssm get-parameter --name "/$environment/$region/foundation/vpc_id" > /dev/null 2>&1; then
        echo "❌ Foundation parameters missing. Recreating..."
        cd "regions/$region/layers/01-foundation/$environment"
        terraform apply -target="aws_ssm_parameter.vpc_id" -auto-approve
    fi
    
    # Check platform parameters
    if ! aws ssm get-parameter --name "/$environment/$region/platform/cluster_name" > /dev/null 2>&1; then
        echo "❌ Platform parameters missing. Recreating..."
        cd "regions/$region/layers/02-platform/$environment"
        terraform apply -target="aws_ssm_parameter.cluster_name" -auto-approve
    fi
    
    echo "✅ Cross-layer communication restored"
}
```

#### EKS Cluster Issues
```bash
# Issue: EKS cluster is not accessible
# Solution: Diagnose and fix common EKS issues

troubleshoot_eks() {
    local cluster_name=$1
    local region="us-east-1"
    
    echo "Troubleshooting EKS cluster: $cluster_name"
    
    # Check cluster status
    echo "1. Checking cluster status..."
    aws eks describe-cluster --name $cluster_name --region $region \
        --query 'cluster.status' --output text
    
    # Update kubeconfig
    echo "2. Updating kubeconfig..."
    aws eks update-kubeconfig --region $region --name $cluster_name
    
    # Check nodes
    echo "3. Checking node status..."
    kubectl get nodes -o wide
    
    # Check system pods
    echo "4. Checking system pods..."
    kubectl get pods -n kube-system
    
    # Check EKS addons
    echo "5. Checking EKS addons..."
    aws eks list-addons --cluster-name $cluster_name --region $region
    
    # Check security groups
    echo "6. Checking security groups..."
    aws eks describe-cluster --name $cluster_name --region $region \
        --query 'cluster.resourcesVpcConfig.securityGroupIds' --output text
}
```

### 2. Debugging Procedures

#### Terraform Debug Mode
```bash
# Enable detailed logging for troubleshooting
export TF_LOG=DEBUG
export TF_LOG_PATH="./terraform-debug.log"

# Run terraform command with debug logging
terraform plan

# Analyze logs
grep "ERROR\|WARN" terraform-debug.log
```

#### State Inspection
```bash
# Inspect terraform state
terraform state list                    # List all resources
terraform state show aws_vpc.main      # Show specific resource
terraform state pull | jq .            # Pretty print entire state
```

#### Resource Import Issues
```bash
# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0

# Verify import
terraform plan  # Should show no changes if import successful
```

## Maintenance Tasks

### 1. Weekly Maintenance

#### State File Cleanup
```bash
#!/bin/bash
# Weekly state file maintenance

weekly_state_maintenance() {
    echo "=== Weekly State File Maintenance ==="
    
    # Check state file sizes
    echo "Current state file sizes:"
    find . -name "terraform.tfstate" -exec ls -lh {} \; | sort -k5 -hr
    
    # Identify large states that might need optimization
    find . -name "terraform.tfstate" -size +10M -exec echo "Large state file: {}" \;
    
    # Clean up old plan files
    echo "Cleaning up old plan files..."
    find . -name "*.tfplan" -mtime +7 -delete
    
    # Clean up old backup files
    echo "Cleaning up old backup files..."
    find . -name "terraform-state-*.json" -mtime +30 -delete
    
    echo "✅ Weekly maintenance completed"
}

weekly_state_maintenance
```

#### Module Updates
```bash
#!/bin/bash
# Check for module updates

check_module_updates() {
    echo "=== Checking Module Updates ==="
    
    # Check for terraform updates
    echo "Current Terraform version:"
    terraform version
    
    # Check module sources for updates
    echo "Checking module sources..."
    grep -r "source.*=" shared/modules/*/main.tf || true
    
    # Update terraform providers
    echo "Updating providers..."
    for env_dir in regions/*/layers/*/production; do
        if [[ -d "$env_dir" ]]; then
            cd "$env_dir"
            terraform init -upgrade
            cd - > /dev/null
        fi
    done
    
    echo "✅ Module update check completed"
}

check_module_updates
```

### 2. Monthly Maintenance

#### Cost Analysis
```bash
#!/bin/bash
# Monthly cost analysis

monthly_cost_analysis() {
    echo "=== Monthly Cost Analysis ==="
    
    # Get cost by service
    echo "Costs by service (last 30 days):"
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d '30 days ago' '+%Y-%m-%d'),End=$(date '+%Y-%m-%d') \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --output table
    
    # Get cost by tag (client)
    echo "Costs by client (last 30 days):"
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d '30 days ago' '+%Y-%m-%d'),End=$(date '+%Y-%m-%d') \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=TAG,Key=Client \
        --output table
    
    echo "✅ Cost analysis completed"
}

monthly_cost_analysis
```

#### Security Audit
```bash
#!/bin/bash
# Monthly security audit

monthly_security_audit() {
    echo "=== Monthly Security Audit ==="
    
    # Check for security groups with open access
    echo "Checking for open security groups..."
    aws ec2 describe-security-groups \
        --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId,GroupName]' \
        --output table
    
    # Check for unused resources
    echo "Checking for unused EBS volumes..."
    aws ec2 describe-volumes \
        --filters Name=status,Values=available \
        --query 'Volumes[*].[VolumeId,Size,CreateTime]' \
        --output table
    
    # Check IAM users without MFA
    echo "Checking IAM users without MFA..."
    aws iam list-users --query 'Users[*].UserName' --output text | \
    while read user; do
        if ! aws iam list-mfa-devices --user-name $user --query 'MFADevices' --output text | grep -q .; then
            echo "User without MFA: $user"
        fi
    done
    
    echo "✅ Security audit completed"
}

monthly_security_audit
```

## Emergency Procedures

### 1. Incident Response

#### Infrastructure Down Response
```bash
#!/bin/bash
# Emergency infrastructure down response

emergency_response() {
    echo "🚨 EMERGENCY RESPONSE ACTIVATED 🚨"
    
    # Immediate assessment
    echo "1. Immediate assessment..."
    
    # Check EKS cluster health
    kubectl cluster-info
    kubectl get nodes
    
    # Check critical services
    kubectl get pods -n kube-system
    kubectl get pods -n monitoring
    
    # Check database connectivity
    for client in mtn-ghana ezra; do
        echo "Checking $client database..."
        # Add database connectivity check
    done
    
    # Document incident
    echo "2. Documenting incident..."
    cat > "incident-$(date +%Y%m%d_%H%M%S).txt" << EOF
Incident Time: $(date)
Incident Type: Infrastructure Down
Initial Assessment: 
$(kubectl get nodes)
$(kubectl get pods --all-namespaces | grep -v Running)
EOF
    
    echo "3. Initiating recovery procedures..."
    # Continue with recovery steps based on assessment
}
```

#### Data Recovery Procedures
```bash
#!/bin/bash
# Data recovery procedures

data_recovery() {
    local backup_date=$1
    local layer=$2
    
    echo "🔄 INITIATING DATA RECOVERY 🔄"
    echo "Backup Date: $backup_date, Layer: $layer"
    
    # Stop current operations
    echo "1. Stopping current operations..."
    # Add commands to gracefully stop services
    
    # Restore state file
    echo "2. Restoring state file..."
    aws s3 cp "s3://terraform-state-backups-$backup_date/$layer-production-$backup_date.json" \
        "regions/us-east-1/layers/$layer/production/terraform.tfstate"
    
    # Verify restoration
    echo "3. Verifying restoration..."
    cd "regions/us-east-1/layers/$layer/production"
    terraform plan
    
    # Restart services
    echo "4. Restarting services..."
    # Add commands to restart services
    
    echo "✅ Data recovery completed"
}
```

### 2. Rollback Procedures

#### Quick Rollback
```bash
#!/bin/bash
# Quick rollback to previous state

quick_rollback() {
    local layer_path=$1
    
    echo "🔄 QUICK ROLLBACK INITIATED 🔄"
    
    cd "$layer_path"
    
    # Find latest backup
    BACKUP_FILE=$(ls -t terraform-state-*.json | head -n 1)
    
    if [[ -n "$BACKUP_FILE" ]]; then
        echo "Rolling back to: $BACKUP_FILE"
        cp "$BACKUP_FILE" terraform.tfstate
        terraform plan
        
        read -p "Apply rollback? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform apply -auto-approve
            echo "✅ Rollback completed"
        fi
    else
        echo "❌ No backup file found"
    fi
}
```

## Monitoring and Alerting

### 1. CloudWatch Integration

#### Custom Metrics
```bash
#!/bin/bash
# Send custom metrics to CloudWatch

send_terraform_metrics() {
    local layer=$1
    local environment=$2
    
    # Count resources in state
    cd "regions/us-east-1/layers/$layer/$environment"
    RESOURCE_COUNT=$(terraform state list | wc -l)
    
    # Send metric to CloudWatch
    aws cloudwatch put-metric-data \
        --namespace "Terraform/Infrastructure" \
        --metric-data MetricName=ResourceCount,Value=$RESOURCE_COUNT,Unit=Count,Dimensions=Layer=$layer,Environment=$environment
    
    # Check state file size
    STATE_SIZE=$(stat -f%z terraform.tfstate 2>/dev/null || stat -c%s terraform.tfstate)
    
    aws cloudwatch put-metric-data \
        --namespace "Terraform/Infrastructure" \
        --metric-data MetricName=StateFileSize,Value=$STATE_SIZE,Unit=Bytes,Dimensions=Layer=$layer,Environment=$environment
}

# Send metrics for all layers
send_terraform_metrics "01-foundation" "production"
send_terraform_metrics "02-platform" "production"
send_terraform_metrics "03-databases" "production"
```

#### Alert Configuration
```bash
#!/bin/bash
# Set up CloudWatch alarms for infrastructure

setup_infrastructure_alarms() {
    # Alarm for failed deployments
    aws cloudwatch put-metric-alarm \
        --alarm-name "TerraformDeploymentFailures" \
        --alarm-description "Alert on terraform deployment failures" \
        --metric-name DeploymentFailures \
        --namespace Terraform/CI \
        --statistic Sum \
        --period 300 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --evaluation-periods 1
    
    # Alarm for large state files
    aws cloudwatch put-metric-alarm \
        --alarm-name "TerraformLargeStateFile" \
        --alarm-description "Alert on large terraform state files" \
        --metric-name StateFileSize \
        --namespace Terraform/Infrastructure \
        --statistic Maximum \
        --period 3600 \
        --threshold 10485760 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 1
}

setup_infrastructure_alarms
```

## Client Onboarding

### 1. New Client Setup

#### Client Onboarding Script
```bash
#!/bin/bash
# Onboard new client to the platform

onboard_client() {
    local client_name=$1
    local environment=${2:-production}
    local region="us-east-1"
    
    echo "=== Onboarding Client: $client_name ==="
    
    # Create client directory structure
    echo "1. Creating directory structure..."
    mkdir -p "regions/$region/clients/$client_name/$environment"
    mkdir -p "shared/client-configs/$client_name"
    
    # Create client configuration
    echo "2. Creating client configuration..."
    cat > "regions/$region/clients/$client_name/$environment/main.tf" << EOF
# $client_name Client Infrastructure - $environment

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  
  backend "s3" {
    key = "$environment/$region/clients/$client_name/terraform.tfstate"
  }
}

module "${client_name}_infrastructure" {
  source = "../../../../../shared/modules/client-infrastructure"
  
  # Client identification
  client_name      = "$client_name"
  environment      = "$environment"
  aws_region       = "$region"
  client_namespace = "$client_name"
  
  # Default node groups
  nodegroups = {
    "general" = {
      capacity_type  = "ON_DEMAND"
      instance_types = ["m5.large", "m5a.large"]
      desired_size   = 2
      max_size       = 4
      min_size       = 1
      max_unavailable_percentage = 25
      tier           = "general"
      workload       = "application"
      performance    = "standard"
      enable_client_isolation = false
      custom_taints  = []
      extra_labels = {}
      extra_tags = {
        CostCenter = "$client_name-$environment"
        Owner      = "$client_name-team"
      }
    }
  }
  
  # Default configurations
  databases = {}
  s3_buckets = {}
  service_accounts = {}
  
  # SSH key for node access
  ec2_key_name = "terraform-key"
  
  # Common tags
  common_tags = {
    Environment = "$environment"
    Client      = "$client_name"
    ManagedBy   = "terraform"
    CostCenter  = "$client_name-$environment"
  }
}
EOF
    
    # Create client-specific variables file
    cat > "shared/client-configs/$client_name/$environment.tfvars" << EOF
# $client_name client configuration for $environment

# Override default configurations here
# Example:
# node_instance_types = ["m5.xlarge", "c5.large"]
# enable_monitoring = true
EOF
    
    # Initialize terraform
    echo "3. Initializing Terraform..."
    cd "regions/$region/clients/$client_name/$environment"
    terraform init -backend-config="../../../../../../shared/backend-configs/$environment.hcl"
    
    # Create initial plan
    echo "4. Creating initial plan..."
    terraform plan -out="$client_name-$environment-initial.tfplan"
    
    echo "✅ Client $client_name onboarded successfully"
    echo "Next steps:"
    echo "1. Review and customize the configuration"
    echo "2. Apply the initial plan: terraform apply $client_name-$environment-initial.tfplan"
    echo "3. Add client-specific resources as needed"
}

# Usage
onboard_client "new-client-name" "production"
```

## Team Procedures

### 1. Development Workflow

#### Feature Development Process
```bash
#!/bin/bash
# Feature development workflow

start_feature_development() {
    local feature_name=$1
    local base_branch=${2:-main}
    
    echo "=== Starting Feature Development: $feature_name ==="
    
    # Create feature branch
    git checkout -b "feature/$feature_name" $base_branch
    
    # Create development workspace (optional)
    export TF_WORKSPACE="dev-$feature_name"
    
    # Work in development environment
    cd regions/us-east-1/layers/01-foundation/development
    
    echo "Development environment ready for feature: $feature_name"
    echo "Workspace: $TF_WORKSPACE"
    echo "Branch: feature/$feature_name"
}
```

#### Code Review Process
```bash
#!/bin/bash
# Code review process

prepare_for_review() {
    local layer=$1
    local environment=$2
    
    echo "=== Preparing for Code Review ==="
    
    # Generate plan for review
    cd "regions/us-east-1/layers/$layer/$environment"
    terraform plan -out="review.tfplan"
    terraform show -json review.tfplan > review-plan.json
    
    # Run security scan
    checkov -f review-plan.json --framework terraform
    
    # Generate documentation
    terraform-docs markdown table . > README.md
    
    echo "✅ Ready for code review"
    echo "Files to review:"
    echo "- Terraform plan: review.tfplan"
    echo "- Security scan results above"
    echo "- Generated documentation: README.md"
}
```

### 2. Team Communication

#### Status Reporting
```bash
#!/bin/bash
# Generate infrastructure status report

generate_status_report() {
    local date=$(date +%Y-%m-%d)
    
    cat > "infrastructure-status-$date.md" << EOF
# Infrastructure Status Report - $date

## Environment Health
$(terraform_health_check)

## Resource Counts
$(get_resource_counts)

## Recent Changes
$(git log --oneline --since="1 week ago" -- regions/)

## Upcoming Maintenance
- [ ] Weekly state cleanup
- [ ] Monthly cost review
- [ ] Quarterly security audit

## Issues and Concerns
$(check_for_issues)
EOF
    
    echo "Status report generated: infrastructure-status-$date.md"
}
```

## Conclusion

This operational runbook provides comprehensive procedures for managing the scalable Terraform architecture. Regular use of these procedures will ensure reliable, secure, and efficient infrastructure operations.

### Key Takeaways:
1. **Automation**: Most routine tasks are automated through scripts
2. **Monitoring**: Continuous monitoring and alerting prevent issues
3. **Documentation**: All procedures are documented and version controlled  
4. **Emergency Preparedness**: Clear emergency procedures minimize downtime
5. **Team Coordination**: Structured workflows enable effective team collaboration

### Next Steps:
1. Customize scripts for your specific environment
2. Set up monitoring and alerting
3. Train team members on procedures
4. Test emergency procedures in staging
5. Regularly review and update runbooks

For questions or issues not covered in this runbook, escalate to the platform engineering team or create an incident ticket.
