#!/bin/bash

# ============================================================================
# S3 Infrastructure Provisioning Script - Enterprise Standards
# ============================================================================
# This script automates the provisioning of S3 buckets and related infrastructure
# when introducing new clusters or regions. It follows enterprise conventions and
# integrates with your existing Terraform backend structure.
#
# Usage:
#   ./scripts/provision-s3-infrastructure.sh --region af-south-1 --environment production
#   ./scripts/provision-s3-infrastructure.sh --region us-east-1 --environment staging --project-name cptwn
#
# Features:
# - Creates backend state S3 buckets and DynamoDB tables
# - Provisions observability buckets (logs, traces)
# - Generates backend configuration files
# - Validates AWS credentials and permissions
# - Follows your existing naming conventions
# - Supports cross-region replication setup
# ============================================================================

set -euo pipefail

# ============================================================================
# Script Configuration and Defaults
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values following enterprise standards
DEFAULT_PROJECT_NAME="myproject"
DEFAULT_ENVIRONMENT="production"
DEFAULT_AWS_REGION="us-west-2"
DEFAULT_COMPANY_NAME=""

# Enterprise naming conventions
BACKEND_BUCKET_PREFIX="terraform-state"
LOGS_BUCKET_PREFIX="logs"
TRACES_BUCKET_PREFIX="traces"
DYNAMODB_TABLE_PREFIX="terraform-locks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Provisions S3 infrastructure for new Terraform deployments following enterprise standards.

OPTIONS:
    -r, --region REGION          AWS region (default: af-south-1)
    -e, --environment ENV        Environment (production, staging, development) (default: production)
    -p, --project-name NAME      Project name (default: myproject)
    -c, --company-name NAME      Company name for tagging (default: project name)
    -s, --region-short NAME      Short region name for DynamoDB (e.g., af-south)
    --backend-only              Only create backend infrastructure (S3 + DynamoDB)
    --observability-only         Only create observability buckets
    --with-replication           Enable cross-region replication
    --replica-region REGION      Replica region for cross-region replication
    --kms-key-id KEY_ID         KMS key ID for encryption
    --dry-run                   Show what would be created without creating resources
    --force                     Skip confirmation prompts
    -h, --help                  Show this help message

EXAMPLES:
    # Create backend infrastructure for new region
    $0 --region us-east-1 --environment production

    # Create all buckets with cross-region replication
    $0 --region af-south-1 --with-replication --replica-region us-east-1

    # Dry run to see what would be created
    $0 --region eu-west-1 --dry-run

    # Create only observability buckets
    $0 --region af-south-1 --observability-only

EOF
}

# ============================================================================
# Command Line Argument Parsing
# ============================================================================

parse_arguments() {
    AWS_REGION="$DEFAULT_AWS_REGION"
    ENVIRONMENT="$DEFAULT_ENVIRONMENT"
    PROJECT_NAME="$DEFAULT_PROJECT_NAME"
    COMPANY_NAME="$DEFAULT_COMPANY_NAME"
    REGION_SHORT=""
    BACKEND_ONLY=false
    OBSERVABILITY_ONLY=false
    WITH_REPLICATION=false
    REPLICA_REGION=""
    KMS_KEY_ID=""
    DRY_RUN=false
    FORCE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--project-name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -c|--company-name)
                COMPANY_NAME="$2"
                shift 2
                ;;
            -s|--region-short)
                REGION_SHORT="$2"
                shift 2
                ;;
            --backend-only)
                BACKEND_ONLY=true
                shift
                ;;
            --observability-only)
                OBSERVABILITY_ONLY=true
                shift
                ;;
            --with-replication)
                WITH_REPLICATION=true
                shift
                ;;
            --replica-region)
                REPLICA_REGION="$2"
                shift 2
                ;;
            --kms-key-id)
                KMS_KEY_ID="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Set region short name if not provided
    if [[ -z "$REGION_SHORT" ]]; then
        REGION_SHORT=$(echo "$AWS_REGION" | sed 's/-[0-9]*$//')
    fi
    
    # Set company name default if not provided
    if [[ -z "$COMPANY_NAME" ]]; then
        COMPANY_NAME="$PROJECT_NAME"
    fi

    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(production|staging|development|test)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        log_error "Must be one of: production, staging, development, test"
        exit 1
    fi

    # Validate cross-region replication
    if [[ "$WITH_REPLICATION" == true && -z "$REPLICA_REGION" ]]; then
        log_error "Replica region must be specified when using --with-replication"
        exit 1
    fi
}

# ============================================================================
# AWS Validation Functions
# ============================================================================

validate_aws_credentials() {
    log_info "Validating AWS credentials..."
    
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_error "Please run: aws configure"
        exit 1
    fi

    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    
    log_success "AWS credentials validated"
    log_info "Account ID: $account_id"
    log_info "User/Role: $user_arn"
}

validate_aws_region() {
    log_info "Validating AWS region: $AWS_REGION"
    
    if ! aws ec2 describe-regions --region-names "$AWS_REGION" &>/dev/null; then
        log_error "Invalid AWS region: $AWS_REGION"
        exit 1
    fi
    
    log_success "AWS region validated: $AWS_REGION"
}

check_existing_resources() {
    log_info "Checking for existing resources..."
    
    local backend_bucket="${PROJECT_NAME}-${BACKEND_BUCKET_PREFIX}-${ENVIRONMENT}"
    local dynamodb_table="${DYNAMODB_TABLE_PREFIX}-${REGION_SHORT}"
    
    # Check S3 bucket
    if aws s3api head-bucket --bucket "$backend_bucket" 2>/dev/null; then
        log_warning "Backend bucket already exists: $backend_bucket"
        if [[ "$FORCE" != true ]]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Check DynamoDB table
    if aws dynamodb describe-table --table-name "$dynamodb_table" --region "$AWS_REGION" &>/dev/null; then
        log_warning "DynamoDB table already exists: $dynamodb_table"
        if [[ "$FORCE" != true ]]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# ============================================================================
# Terraform Infrastructure Provisioning Functions
# ============================================================================

create_terraform_workspace() {
    local workspace_dir="$PROJECT_ROOT/infrastructure/s3-provisioning"
    
    log_info "Creating Terraform workspace: $workspace_dir"
    
    mkdir -p "$workspace_dir"
    
    # Create main Terraform configuration
    cat > "$workspace_dir/main.tf" << EOF
# ============================================================================
# S3 Infrastructure Provisioning - Auto-generated
# ============================================================================
# This file is auto-generated by provision-s3-infrastructure.sh
# Region: $AWS_REGION
# Environment: $ENVIRONMENT
# Project: $PROJECT_NAME
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "$AWS_REGION"
  
  default_tags {
    tags = {
      Project            = "$PROJECT_NAME"
      Environment        = "$ENVIRONMENT"
      Region             = "$AWS_REGION"
      ManagedBy          = "Terraform"
      ProvisionedBy      = "s3-provisioning-script"
      Company            = "$COMPANY_NAME"
      Architecture       = "Multi-Client"
    }
  }
}

# Backend State Infrastructure
EOF

    if [[ "$BACKEND_ONLY" != true && "$OBSERVABILITY_ONLY" != true ]] || [[ "$BACKEND_ONLY" == true ]]; then
        cat >> "$workspace_dir/main.tf" << EOF
module "terraform_backend_state" {
  source = "../../modules/terraform-backend-state"
  
  # Core configuration
  project_name       = "$PROJECT_NAME"
  environment        = "$ENVIRONMENT"
  region            = "$AWS_REGION"
  region_short_name = "$REGION_SHORT"
  
  # Custom naming
  custom_bucket_name   = "${PROJECT_NAME}-${BACKEND_BUCKET_PREFIX}-${ENVIRONMENT}"
  custom_dynamodb_name = "${DYNAMODB_TABLE_PREFIX}-${REGION_SHORT}"
  
  # Security - Enhanced for critical infrastructure
  kms_key_id     = "$KMS_KEY_ID"
  prevent_destroy = true
  
  # Enterprise Security Features
  enable_versioning = true
  enable_mfa_delete = false   # Set to true in production with MFA device
  object_ownership = "BucketOwnerEnforced"
  
  # Access Logging - Critical for state file access tracking
  enable_access_logging = true
  
  # Advanced Monitoring - Essential for state management
  enable_cloudwatch_metrics = true
  enable_eventbridge = true
  
  # Cross-region replication
  enable_cross_region_replication = $WITH_REPLICATION
  replication_destination_bucket_arn = "$REPLICA_REGION" != "" ? "arn:aws:s3:::${PROJECT_NAME}-${BACKEND_BUCKET_PREFIX}-${ENVIRONMENT}-replica" : ""
  
  # Backend configuration generation
  generate_backend_configs = true
  backend_config_output_path = "../../backends/aws"
  
  # Monitoring
  enable_backend_monitoring = true
  enable_state_monitoring  = true
  
  # Common tags
  common_tags = {
    CreatedBy = "provision-s3-infrastructure.sh"
    Purpose   = "Terraform-Backend-Infrastructure"
    SecurityLevel = "Critical"
    MonitoringEnabled = "true"
    DataClassification = "Infrastructure"
  }
}
EOF
    fi

    if [[ "$BACKEND_ONLY" != true && "$OBSERVABILITY_ONLY" != true ]] || [[ "$OBSERVABILITY_ONLY" == true ]]; then
        cat >> "$workspace_dir/main.tf" << EOF

# Observability Buckets
module "logs_bucket" {
  source = "../../modules/s3-bucket-management"
  
  project_name   = "$PROJECT_NAME"
  environment    = "$ENVIRONMENT"
  region        = "$AWS_REGION"
  bucket_purpose = "logs"
  
  # Lifecycle optimized for logs with structured keys
  logs_retention_days = 90
  enable_intelligent_tiering = true
  enable_structured_keys = true
  
  # Enterprise Security Features
  enable_versioning = true
  enable_mfa_delete = false  # Enable in production with MFA device
  versioning_mfa_delete = false
  object_ownership = "BucketOwnerEnforced"
  
  # Access Logging
  enable_access_logging = true
  access_logs_prefix = "access-logs/logs-bucket/"
  
  # Performance Optimization
  enable_transfer_acceleration = false  # Enable for global access
  enable_request_payer = false
  
  # Advanced Monitoring
  enable_cloudwatch_metrics = true
  enable_analytics_configuration = true
  enable_inventory_configuration = true
  
  # Notifications
  enable_bucket_notifications = true
  enable_eventbridge = true
  
  # Custom key patterns for better organization
  custom_key_patterns = {
    logs = {
      enabled = true
      pattern = "logs/cluster=\$\${cluster_name}/tenant=\$\${tenant}/service=\$\${service}/year=%Y/month=%m/day=%d/hour=%H/fluent-bit-logs-%Y%m%d-%H%M%S-\$\$UUID.gz"
      partitions = ["cluster_name", "tenant", "service", "year", "month", "day", "hour"]
    }
  }
  
  # Security
  kms_key_id = "$KMS_KEY_ID"
  
  # Cross-region replication
  enable_cross_region_replication = $WITH_REPLICATION
  replication_destination_bucket_arn = "$REPLICA_REGION" != "" ? "arn:aws:s3:::${PROJECT_NAME}-${AWS_REGION}-logs-${ENVIRONMENT}-replica" : ""
  
  common_tags = {
    CreatedBy = "provision-s3-infrastructure.sh"
    Purpose   = "Application-Logs-Storage"
    SecurityLevel = "High"
    MonitoringEnabled = "true"
  }
}

module "traces_bucket" {
  source = "../../modules/s3-bucket-management"
  
  project_name   = "$PROJECT_NAME"
  environment    = "$ENVIRONMENT"
  region        = "$AWS_REGION"
  bucket_purpose = "traces"
  
  # Lifecycle optimized for traces with structured keys
  traces_retention_days = 30
  enable_intelligent_tiering = true
  enable_structured_keys = true
  
  # Enterprise Security Features
  enable_versioning = true
  enable_mfa_delete = false
  versioning_mfa_delete = false
  object_ownership = "BucketOwnerEnforced"
  
  # Access Logging
  enable_access_logging = true
  access_logs_prefix = "access-logs/traces-bucket/"
  
  # Performance Optimization
  enable_transfer_acceleration = false
  enable_request_payer = false
  
  # Advanced Monitoring
  enable_cloudwatch_metrics = true
  enable_analytics_configuration = true
  enable_inventory_configuration = true
  
  # Notifications
  enable_bucket_notifications = true
  enable_eventbridge = true
  
  # Custom key patterns for better organization
  custom_key_patterns = {
    traces = {
      enabled = true
      pattern = "traces/cluster=\$\${cluster_name}/tenant=\$\${tenant}/service=\$\${service}/year=%Y/month=%m/day=%d/hour=%H/tempo-traces-%Y%m%d-%H%M%S-\$\$UUID.gz"
      partitions = ["cluster_name", "tenant", "service", "year", "month", "day", "hour"]
    }
  }
  
  # Security
  kms_key_id = "$KMS_KEY_ID"
  
  # Cross-region replication
  enable_cross_region_replication = $WITH_REPLICATION
  replication_destination_bucket_arn = "$REPLICA_REGION" != "" ? "arn:aws:s3:::${PROJECT_NAME}-${AWS_REGION}-traces-${ENVIRONMENT}-replica" : ""
  
  common_tags = {
    CreatedBy = "provision-s3-infrastructure.sh"
    Purpose   = "Distributed-Traces-Storage"
    SecurityLevel = "High"
    MonitoringEnabled = "true"
  }
}

module "metrics_bucket" {
  source = "../../modules/s3-bucket-management"
  
  project_name   = "$PROJECT_NAME"
  environment    = "$ENVIRONMENT"
  region        = "$AWS_REGION"
  bucket_purpose = "metrics"
  
  # Lifecycle optimized for metrics with structured keys
  metrics_retention_days = 90
  enable_intelligent_tiering = true
  enable_structured_keys = true
  
  # Enterprise Security Features
  enable_versioning = true
  enable_mfa_delete = false
  versioning_mfa_delete = false
  object_ownership = "BucketOwnerEnforced"
  
  # Access Logging
  enable_access_logging = true
  access_logs_prefix = "access-logs/metrics-bucket/"
  
  # Performance Optimization
  enable_transfer_acceleration = false
  enable_request_payer = false
  
  # Advanced Monitoring
  enable_cloudwatch_metrics = true
  enable_analytics_configuration = true
  enable_inventory_configuration = true
  
  # Notifications
  enable_bucket_notifications = true
  enable_eventbridge = true
  
  # Custom key patterns for better organization
  custom_key_patterns = {
    metrics = {
      enabled = true
      pattern = "metrics/cluster=\$\${cluster_name}/metric_type=\$\${metric_type}/year=%Y/month=%m/day=%d/hour=%H/prometheus-metrics-%Y%m%d-%H%M%S-\$\$UUID.json.gz"
      partitions = ["cluster_name", "metric_type", "year", "month", "day", "hour"]
    }
  }
  
  # Security
  kms_key_id = "$KMS_KEY_ID"
  
  # Cross-region replication
  enable_cross_region_replication = $WITH_REPLICATION
  replication_destination_bucket_arn = "$REPLICA_REGION" != "" ? "arn:aws:s3:::${PROJECT_NAME}-${AWS_REGION}-metrics-${ENVIRONMENT}-replica" : ""
  
  common_tags = {
    CreatedBy = "provision-s3-infrastructure.sh"
    Purpose   = "Prometheus-Metrics-Storage"
    SecurityLevel = "High"
    MonitoringEnabled = "true"
  }
}

module "audit_logs_bucket" {
  source = "../../modules/s3-bucket-management"
  
  project_name   = "$PROJECT_NAME"
  environment    = "$ENVIRONMENT"
  region        = "$AWS_REGION"
  bucket_purpose = "audit_logs"
  
  # Lifecycle optimized for audit logs with long retention
  audit_logs_retention_days = 2555  # 7 years for compliance
  enable_intelligent_tiering = true
  enable_structured_keys = true
  
  # Enterprise Security Features - Enhanced for compliance
  enable_versioning = true
  enable_mfa_delete = false   # Set to true for production compliance
  versioning_mfa_delete = false
  object_ownership = "BucketOwnerEnforced"
  
  # Access Logging - Required for audit trails
  enable_access_logging = true
  access_logs_prefix = "access-logs/audit-logs-bucket/"
  
  # Performance Optimization
  enable_transfer_acceleration = false
  enable_request_payer = false
  
  # Advanced Monitoring - Critical for compliance
  enable_cloudwatch_metrics = true
  enable_analytics_configuration = true
  enable_inventory_configuration = true
  
  # Notifications - Required for security monitoring
  enable_bucket_notifications = true
  enable_eventbridge = true
  
  # Custom key patterns for better organization
  custom_key_patterns = {
    audit_logs = {
      enabled = true
      pattern = "audit-logs/cluster=\$\${cluster_name}/component=\$\${component}/year=%Y/month=%m/day=%d/hour=%H/k8s-audit-%Y%m%d-%H%M%S-\$\$UUID.json.gz"
      partitions = ["cluster_name", "component", "year", "month", "day", "hour"]
    }
  }
  
  # Security - Enhanced for compliance
  kms_key_id = "$KMS_KEY_ID"  # Consider using KMS for audit logs in production
  
  # Cross-region replication - Recommended for audit logs
  enable_cross_region_replication = $WITH_REPLICATION
  replication_destination_bucket_arn = "$REPLICA_REGION" != "" ? "arn:aws:s3:::${PROJECT_NAME}-${AWS_REGION}-audit-logs-${ENVIRONMENT}-replica" : ""
  
  common_tags = {
    CreatedBy = "provision-s3-infrastructure.sh"
    Purpose   = "Kubernetes-Audit-Logs-Storage"
    Compliance = "SOC2-PCI-GDPR"
    SecurityLevel = "Critical"
    MonitoringEnabled = "true"
    DataClassification = "Sensitive"
  }
}
EOF
    fi

    # Create outputs
    cat > "$workspace_dir/outputs.tf" << EOF
# ============================================================================
# S3 Infrastructure Provisioning Outputs
# ============================================================================

output "provisioning_summary" {
  description = "Summary of provisioned infrastructure"
  value = {
    project_name = "$PROJECT_NAME"
    environment  = "$ENVIRONMENT"
    region      = "$AWS_REGION"
    timestamp   = timestamp()
  }
}
EOF

    if [[ "$BACKEND_ONLY" != true && "$OBSERVABILITY_ONLY" != true ]] || [[ "$BACKEND_ONLY" == true ]]; then
        cat >> "$workspace_dir/outputs.tf" << EOF

output "backend_infrastructure" {
  description = "Backend infrastructure details"
  value = {
    s3_bucket_name    = module.terraform_backend_state.backend_bucket_name
    s3_bucket_arn     = module.terraform_backend_state.backend_bucket_arn
    dynamodb_table    = module.terraform_backend_state.dynamodb_table_name
    region           = "$AWS_REGION"
    iam_policy_arn   = module.terraform_backend_state.access_policy_arn
  }
}
EOF
    fi

    if [[ "$BACKEND_ONLY" != true && "$OBSERVABILITY_ONLY" != true ]] || [[ "$OBSERVABILITY_ONLY" == true ]]; then
        cat >> "$workspace_dir/outputs.tf" << EOF

output "observability_infrastructure" {
  description = "Observability infrastructure details"
  value = {
    logs_bucket_name       = module.logs_bucket.bucket_id
    logs_bucket_arn        = module.logs_bucket.bucket_arn
    traces_bucket_name     = module.traces_bucket.bucket_id
    traces_bucket_arn      = module.traces_bucket.bucket_arn
    metrics_bucket_name    = module.metrics_bucket.bucket_id
    metrics_bucket_arn     = module.metrics_bucket.bucket_arn
    audit_logs_bucket_name = module.audit_logs_bucket.bucket_id
    audit_logs_bucket_arn  = module.audit_logs_bucket.bucket_arn
  }
}
EOF
    fi

    log_success "Terraform workspace created: $workspace_dir"
}

provision_infrastructure() {
    local workspace_dir="$PROJECT_ROOT/infrastructure/s3-provisioning"
    
    log_info "Provisioning infrastructure..."
    
    cd "$workspace_dir"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    if ! terraform init; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Plan infrastructure
    log_info "Planning infrastructure changes..."
    if ! terraform plan -out=tfplan; then
        log_error "Terraform planning failed"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run completed. Infrastructure plan saved to: $workspace_dir/tfplan"
        log_info "To apply the plan, run: cd $workspace_dir && terraform apply tfplan"
        return 0
    fi
    
    # Confirm deployment
    if [[ "$FORCE" != true ]]; then
        echo
        log_info "The following infrastructure will be created:"
        terraform show tfplan
        echo
        read -p "Do you want to proceed with the deployment? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Apply infrastructure
    log_info "Applying infrastructure changes..."
    if ! terraform apply tfplan; then
        log_error "Terraform apply failed"
        exit 1
    fi
    
    # Show outputs
    log_success "Infrastructure provisioning completed!"
    echo
    log_info "Infrastructure Summary:"
    terraform output -json | jq -r '.'
    
    cd - > /dev/null
}

# ============================================================================
# Backend Configuration Generation
# ============================================================================

generate_backend_configs() {
    local backend_dir="$PROJECT_ROOT/backends/aws/$ENVIRONMENT/$AWS_REGION"
    local bucket_name="${PROJECT_NAME}-${BACKEND_BUCKET_PREFIX}-${ENVIRONMENT}"
    local dynamodb_table="${DYNAMODB_TABLE_PREFIX}-${REGION_SHORT}"
    
    log_info "Generating backend configuration files..."
    
    mkdir -p "$backend_dir"
    
    # Generate backend configs for each layer
    declare -A layers=(
        ["foundation"]="providers/aws/regions/$AWS_REGION/layers/01-foundation/$ENVIRONMENT/terraform.tfstate"
        ["platform"]="regions/$AWS_REGION/layers/02-platform/$ENVIRONMENT/terraform.tfstate"
        ["databases"]="regions/$AWS_REGION/layers/03-databases/$ENVIRONMENT/terraform.tfstate"
        ["observability"]="regions/$AWS_REGION/layers/03.5-observability/$ENVIRONMENT/terraform.tfstate"
        ["shared-services"]="regions/$AWS_REGION/layers/06-shared-services/$ENVIRONMENT/terraform.tfstate"
    )
    
    for layer in "${!layers[@]}"; do
        local config_file="$backend_dir/${layer}.hcl"
        local key_path="${layers[$layer]}"
        
        cat > "$config_file" << EOF
# Backend configuration for $AWS_REGION $layer layer
# Generated automatically by provision-s3-infrastructure.sh
bucket         = "$bucket_name"
key            = "$key_path"
region         = "$AWS_REGION"
encrypt        = true
dynamodb_table = "$dynamodb_table"
EOF
        
        log_success "Generated backend config: $config_file"
    done
    
    # Generate README
    cat > "$backend_dir/README.md" << EOF
# Backend Configuration for $AWS_REGION $ENVIRONMENT

Generated automatically on $(date) by \`provision-s3-infrastructure.sh\`.

## Backend Infrastructure

- **S3 Bucket**: \`$bucket_name\`
- **DynamoDB Table**: \`$dynamodb_table\`
- **Region**: \`$AWS_REGION\`
- **Environment**: \`$ENVIRONMENT\`

## Usage

To use these backend configurations with Terraform:

\`\`\`bash
# Initialize with foundation layer backend
terraform init -backend-config=../../../../backends/aws/$ENVIRONMENT/$AWS_REGION/foundation.hcl

# Initialize with platform layer backend  
terraform init -backend-config=../../../../backends/aws/$ENVIRONMENT/$AWS_REGION/platform.hcl
\`\`\`

## Files

EOF

    for layer in "${!layers[@]}"; do
        echo "- \`${layer}.hcl\` - Backend config for $layer layer" >> "$backend_dir/README.md"
    done
}

# ============================================================================
# Post-Provisioning Validation
# ============================================================================

validate_infrastructure() {
    log_info "Validating provisioned infrastructure..."
    
    local backend_bucket="${PROJECT_NAME}-${BACKEND_BUCKET_PREFIX}-${ENVIRONMENT}"
    local dynamodb_table="${DYNAMODB_TABLE_PREFIX}-${REGION_SHORT}"
    
    # Validate S3 bucket
    if aws s3api head-bucket --bucket "$backend_bucket" 2>/dev/null; then
        log_success "Backend S3 bucket validated: $backend_bucket"
        
        # Check versioning
        local versioning=$(aws s3api get-bucket-versioning --bucket "$backend_bucket" --query Status --output text)
        if [[ "$versioning" == "Enabled" ]]; then
            log_success "S3 bucket versioning is enabled"
        else
            log_warning "S3 bucket versioning is not enabled"
        fi
        
        # Check encryption
        if aws s3api get-bucket-encryption --bucket "$backend_bucket" &>/dev/null; then
            log_success "S3 bucket encryption is enabled"
        else
            log_warning "S3 bucket encryption configuration not found"
        fi
    else
        log_error "Backend S3 bucket not found: $backend_bucket"
        exit 1
    fi
    
    # Validate DynamoDB table
    if aws dynamodb describe-table --table-name "$dynamodb_table" --region "$AWS_REGION" &>/dev/null; then
        log_success "DynamoDB table validated: $dynamodb_table"
        
        # Check encryption
        local encryption=$(aws dynamodb describe-table --table-name "$dynamodb_table" --region "$AWS_REGION" --query Table.SSEDescription.Status --output text)
        if [[ "$encryption" == "ENABLED" ]]; then
            log_success "DynamoDB table encryption is enabled"
        else
            log_warning "DynamoDB table encryption is not enabled"
        fi
    else
        log_error "DynamoDB table not found: $dynamodb_table"
        exit 1
    fi
    
    log_success "Infrastructure validation completed successfully!"
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    log_info "Cleaning up temporary files..."
    # Add cleanup logic here if needed
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    log_info "Starting S3 infrastructure provisioning..."
    log_info "Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Region: $AWS_REGION"
    
    # Pre-flight checks
    validate_aws_credentials
    validate_aws_region
    check_existing_resources
    
    # Create Terraform workspace and provision infrastructure
    create_terraform_workspace
    provision_infrastructure
    
    # Only generate backend configs if not in dry-run mode
    if [[ "$DRY_RUN" != true ]]; then
        generate_backend_configs
        validate_infrastructure
        
        log_success "S3 infrastructure provisioning completed successfully!"
        echo
        log_info "Next steps:"
        log_info "1. Review the generated backend configuration files in: backends/aws/$ENVIRONMENT/$AWS_REGION/"
        log_info "2. Use the backend configs in your Terraform deployments"
        log_info "3. Consider setting up cross-region replication for disaster recovery"
        
        if [[ "$WITH_REPLICATION" == true ]]; then
            log_info "4. Cross-region replication has been configured to: $REPLICA_REGION"
        fi
    fi
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Set up error handling
trap cleanup EXIT

# Parse command line arguments
parse_arguments "$@"

# Run main function
main