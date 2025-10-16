#!/bin/bash

# ============================================================================
# Shared Configuration for Multi-Tenant Backend Management
# ============================================================================
# This file ensures consistency between provision-s3-infrastructure.sh and
# manage-tenant-backends.sh by providing unified naming conventions and
# configuration standards.
# ============================================================================

# ============================================================================
# Naming Convention Functions
# ============================================================================

generate_bucket_name() {
    local project_name="$1"
    local environment="$2"
    
    # Unified bucket naming: {project}-terraform-state-{environment}
    echo "${project_name}-terraform-state-${environment}"
}

generate_dynamodb_table_name() {
    local region="$1"
    
    # Extract region short name (e.g., us-west-2 -> us-west)
    local region_short=$(echo "$region" | sed 's/-[0-9]*$//')
    
    # Unified DynamoDB naming: terraform-locks-{region-short}
    echo "terraform-locks-${region_short}"
}

generate_project_name() {
    local project_name="$1"
    local region="$2"
    local environment="$3"
    
    # If no project name provided, generate default
    if [[ -z "$project_name" ]]; then
        # Use region-env pattern for compatibility
        local env_short=$(echo "$environment" | cut -c1-4)
        echo "${region}-${env_short}"
    else
        echo "$project_name"
    fi
}

# ============================================================================
# Validation Functions  
# ============================================================================

validate_infrastructure_exists() {
    local project_name="$1"
    local region="$2" 
    local environment="$3"
    
    local bucket_name=$(generate_bucket_name "$project_name" "$environment")
    local dynamodb_table=$(generate_dynamodb_table_name "$region")
    
    log_info "🔍 Validating AWS infrastructure exists..."
    
    # Check S3 bucket
    if ! aws s3api head-bucket --bucket "$bucket_name" --region "$region" 2>/dev/null; then
        log_error "❌ S3 bucket not found: $bucket_name"
        log_error "📋 Run this first: ./provision-s3-infrastructure.sh --region $region --environment $environment --project-name $project_name"
        return 1
    fi
    
    # Check DynamoDB table
    if ! aws dynamodb describe-table --table-name "$dynamodb_table" --region "$region" &>/dev/null; then
        log_error "❌ DynamoDB table not found: $dynamodb_table"
        log_error "📋 Run this first: ./provision-s3-infrastructure.sh --region $region --environment $environment --project-name $project_name"
        return 1
    fi
    
    log_success "✅ AWS infrastructure validated"
    log_info "   🪣 S3 Bucket: $bucket_name"
    log_info "   🗃️  DynamoDB Table: $dynamodb_table"
    
    return 0
}

# ============================================================================
# Configuration Display Functions
# ============================================================================

show_infrastructure_config() {
    local project_name="$1"
    local region="$2"
    local environment="$3"
    
    local bucket_name=$(generate_bucket_name "$project_name" "$environment")
    local dynamodb_table=$(generate_dynamodb_table_name "$region")
    
    echo
    log_info "📋 Infrastructure Configuration:"
    echo "   🏷️  Project Name:    $project_name"
    echo "   🌍 Region:          $region"  
    echo "   🏗️  Environment:     $environment"
    echo "   🪣 S3 Bucket:       $bucket_name"
    echo "   🗃️  DynamoDB Table:  $dynamodb_table"
}

check_sync_status() {
    local project_name="$1"
    local region="$2"
    local environment="$3"
    
    log_info "🔄 Checking sync status between scripts..."
    
    # Check if infrastructure exists
    if validate_infrastructure_exists "$project_name" "$region" "$environment"; then
        log_success "✅ AWS infrastructure is provisioned"
    else
        log_warning "⚠️  AWS infrastructure missing - run provision-s3-infrastructure.sh first"
        return 1
    fi
    
    # Check for existing tenant backends
    local backends_dir="$HOME/terraform/backends/aws/$region/$environment"
    if [[ -d "$backends_dir" ]]; then
        local tenant_count=$(find "$backends_dir" -maxdepth 1 -type d | grep -v "/shared$" | wc -l)
        tenant_count=$((tenant_count - 1))  # Subtract the parent directory
        
        if [[ $tenant_count -gt 0 ]]; then
            log_success "✅ Found $tenant_count tenant backend(s) configured"
        else
            log_info "ℹ️  No tenant backends configured yet"
        fi
    else
        log_info "ℹ️  No backend configurations found"
    fi
    
    return 0
}

# ============================================================================
# Utility Functions (copied from manage-tenant-backends.sh for consistency)
# ============================================================================

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_header() {
    echo -e "\033[0;36m╭─ $1\033[0m"
}

# ============================================================================
# Integration Functions
# ============================================================================

ensure_infrastructure_ready() {
    local project_name="$1"
    local region="$2"
    local environment="$3"
    
    log_header "Infrastructure Readiness Check"
    
    if ! validate_infrastructure_exists "$project_name" "$region" "$environment"; then
        echo
        log_warning "⚠️  Required AWS infrastructure is missing!"
        echo
        log_info "🚀 To fix this, run:"
        echo "   ./scripts/provision-s3-infrastructure.sh \\"
        echo "     --region $region \\"
        echo "     --environment $environment \\"
        echo "     --project-name $project_name"
        echo
        
        read -p "Would you like to run the provisioning script now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "🏗️  Running infrastructure provisioning..."
            "$HOME/terraform/scripts/provision-s3-infrastructure.sh" \
                --region "$region" \
                --environment "$environment" \
                --project-name "$project_name"
            
            if [[ $? -eq 0 ]]; then
                log_success "✅ Infrastructure provisioned successfully!"
                return 0
            else
                log_error "❌ Infrastructure provisioning failed"
                return 1
            fi
        else
            log_error "❌ Cannot proceed without AWS infrastructure"
            return 1
        fi
    fi
    
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

# Export functions for use in other scripts
export -f generate_bucket_name
export -f generate_dynamodb_table_name  
export -f generate_project_name
export -f validate_infrastructure_exists
export -f show_infrastructure_config
export -f check_sync_status
export -f ensure_infrastructure_ready
export -f log_info log_success log_warning log_error log_header