#!/bin/bash

# ============================================================================
# S3 Scripts Configuration - Project-Agnostic Settings
# ============================================================================
# This configuration file provides project-agnostic settings for S3 destruction
# scripts. It automatically detects project settings from Terraform configuration
# or provides sensible defaults.
# ============================================================================

# ============================================================================
# Default Configuration (Used as fallbacks)
# ============================================================================

readonly DEFAULT_SETTINGS=(
    ["region"]="us-east-2"
    ["environment"]="production"
    ["project"]="ohio-01"
    ["account_id"]=""
)

# ============================================================================
# Auto-Detection Functions
# ============================================================================

detect_project_from_terraform() {
    local search_dirs=(
        "./infrastructure/s3-provisioning"
        "./examples/s3-infrastructure-setup"
        "./infrastructure"
        "./terraform"
        "./"
    )
    
    for dir in "${search_dirs[@]}"; do
        if [[ -f "$dir/main.tf" ]]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

extract_terraform_variable() {
    local terraform_file="$1"
    local variable_name="$2"
    local default_value="$3"
    
    if [[ ! -f "$terraform_file" ]]; then
        echo "$default_value"
        return
    fi
    
    # Try multiple patterns to extract variable values
    local patterns=(
        "^[[:space:]]*${variable_name}[[:space:]]*=[[:space:]]*\"([^\"]*)\""
        "${variable_name}[[:space:]]*=[[:space:]]*\"([^\"]*)\""
        "default[[:space:]]*=[[:space:]]*\"([^\"]*)\""
    )
    
    for pattern in "${patterns[@]}"; do
        local value
        value=$(grep -E "$variable_name" "$terraform_file" | grep -oE '"[^"]*"' | head -1 | tr -d '"' 2>/dev/null)
        if [[ -n "$value" && "$value" != "null" ]]; then
            echo "$value"
            return
        fi
    done
    
    echo "$default_value"
}

detect_aws_region() {
    # Try AWS CLI configuration first
    local aws_region
    aws_region=$(aws configure get region 2>/dev/null)
    
    if [[ -n "$aws_region" ]]; then
        echo "$aws_region"
        return
    fi
    
    # Try from environment variables
    if [[ -n "$AWS_DEFAULT_REGION" ]]; then
        echo "$AWS_DEFAULT_REGION"
        return
    fi
    
    # Try from Terraform provider configuration
    local terraform_dir
    if terraform_dir=$(detect_project_from_terraform); then
        local provider_region
        provider_region=$(grep -E 'region[[:space:]]*=' "$terraform_dir/main.tf" | head -1 | grep -oE '"[^"]*"' | tr -d '"' 2>/dev/null)
        if [[ -n "$provider_region" ]]; then
            echo "$provider_region"
            return
        fi
    fi
    
    # Default fallback
    echo "${DEFAULT_SETTINGS[region]}"
}

detect_project_name() {
    local terraform_dir
    
    # Try from Terraform configuration
    if terraform_dir=$(detect_project_from_terraform); then
        local project_name
        project_name=$(extract_terraform_variable "$terraform_dir/main.tf" "project_name" "")
        
        if [[ -n "$project_name" && "$project_name" != "myproject" ]]; then
            echo "$project_name"
            return
        fi
        
        # Try alternative variable names
        for var_name in "project" "app_name" "application"; do
            project_name=$(extract_terraform_variable "$terraform_dir/main.tf" "$var_name" "")
            if [[ -n "$project_name" && "$project_name" != "myproject" ]]; then
                echo "$project_name"
                return
            fi
        done
    fi
    
    # Try from directory structure
    local current_dir
    current_dir=$(basename "$(pwd)")
    
    # If we're in a project-specific directory, use that
    if [[ "$current_dir" != "terraform" && "$current_dir" != "infrastructure" && "$current_dir" != "scripts" ]]; then
        echo "$current_dir"
        return
    fi
    
    # Try parent directory
    local parent_dir
    parent_dir=$(basename "$(dirname "$(pwd)")")
    if [[ "$parent_dir" != "terraform" && "$parent_dir" != "infrastructure" ]]; then
        echo "$parent_dir"
        return
    fi
    
    # Default fallback
    echo "${DEFAULT_SETTINGS[project]}"
}

detect_environment() {
    local terraform_dir
    
    # Try from Terraform configuration
    if terraform_dir=$(detect_project_from_terraform); then
        local environment
        environment=$(extract_terraform_variable "$terraform_dir/main.tf" "environment" "")
        
        if [[ -n "$environment" ]]; then
            echo "$environment"
            return
        fi
    fi
    
    # Try from environment variables
    if [[ -n "$ENVIRONMENT" ]]; then
        echo "$ENVIRONMENT"
        return
    fi
    
    if [[ -n "$ENV" ]]; then
        echo "$ENV"
        return
    fi
    
    # Default fallback
    echo "${DEFAULT_SETTINGS[environment]}"
}

detect_aws_account_id() {
    local account_id
    account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    
    if [[ -n "$account_id" && "$account_id" != "None" ]]; then
        echo "$account_id"
    fi
}

# ============================================================================
# Main Detection Function
# ============================================================================

auto_detect_project_configuration() {
    local detected_project detected_region detected_environment detected_account
    
    echo "🔍 Auto-detecting project configuration..." >&2
    
    detected_project=$(detect_project_name)
    detected_region=$(detect_aws_region) 
    detected_environment=$(detect_environment)
    detected_account=$(detect_aws_account_id)
    
    echo "📋 Detected configuration:" >&2
    echo "   Project: $detected_project" >&2
    echo "   Region: $detected_region" >&2
    echo "   Environment: $detected_environment" >&2
    echo "   AWS Account: ${detected_account:-'Not detected'}" >&2
    
    # Return as comma-separated values
    echo "$detected_project,$detected_region,$detected_environment,$detected_account"
}

# ============================================================================
# Bucket Name Generation Functions
# ============================================================================

generate_standard_bucket_names() {
    local project="$1"
    local region="$2" 
    local environment="$3"
    
    local bucket_names=(
        "${project}-${region}-logs-${environment}"
        "${project}-${region}-traces-${environment}"
        "${project}-${region}-backups-${environment}"
        "${project}-${region}-metrics-${environment}"
        "${project}-${region}-audit-logs-${environment}"
        "${project}-terraform-state-${environment}"
    )
    
    printf '%s\n' "${bucket_names[@]}"
}

generate_dynamodb_table_name() {
    local region="$1"
    
    # Generate standard DynamoDB table name for Terraform locks
    local region_short
    region_short=$(echo "$region" | sed 's/-[0-9]*$//')
    echo "terraform-locks-${region_short}"
}

# ============================================================================
# Discovery Functions for Existing Resources
# ============================================================================

discover_existing_s3_buckets() {
    local project_pattern="$1"
    
    echo "🔍 Discovering existing S3 buckets matching: $project_pattern" >&2
    
    local all_buckets
    all_buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
    
    local matching_buckets=()
    while IFS= read -r bucket; do
        if [[ -n "$bucket" && "$bucket" == *"$project_pattern"* ]]; then
            matching_buckets+=("$bucket")
            echo "   ✓ Found: $bucket" >&2
        fi
    done <<< "$all_buckets"
    
    if [[ ${#matching_buckets[@]} -eq 0 ]]; then
        echo "   ℹ️  No existing buckets found" >&2
        return 1
    fi
    
    printf '%s\n' "${matching_buckets[@]}"
}

discover_existing_dynamodb_tables() {
    local project_pattern="$1"
    
    echo "🔍 Discovering existing DynamoDB tables..." >&2
    
    local all_tables
    all_tables=$(aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null)
    
    local matching_tables=()
    while IFS= read -r table; do
        if [[ -n "$table" && ("$table" == *"terraform-locks"* || "$table" == *"$project_pattern"*) ]]; then
            matching_tables+=("$table")
            echo "   ✓ Found: $table" >&2
        fi
    done <<< "$all_tables"
    
    if [[ ${#matching_tables[@]} -eq 0 ]]; then
        echo "   ℹ️  No related tables found" >&2
        return 1
    fi
    
    printf '%s\n' "${matching_tables[@]}"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_aws_access() {
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI not installed" >&2
        return 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS CLI not configured or invalid credentials" >&2
        return 1
    fi
    
    return 0
}

validate_terraform_access() {
    if ! command -v terraform >/dev/null 2>&1; then
        echo "⚠️  Terraform CLI not found (some features may not work)" >&2
        return 1
    fi
    
    return 0
}

# ============================================================================
# Usage Examples (for testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🧪 Testing S3 Configuration Detection"
    echo "====================================="
    
    # Test auto-detection
    auto_detect_project_configuration
    
    echo ""
    echo "🧪 Testing Bucket Name Generation"
    echo "================================="
    
    # Test with detected values
    IFS=',' read -r project region environment account <<< "$(auto_detect_project_configuration 2>/dev/null)"
    
    echo "Standard bucket names:"
    generate_standard_bucket_names "$project" "$region" "$environment"
    
    echo ""
    echo "DynamoDB table name:"
    generate_dynamodb_table_name "$region"
    
    echo ""
    echo "🧪 Testing Resource Discovery"
    echo "============================="
    
    if validate_aws_access; then
        discover_existing_s3_buckets "$project" || echo "No buckets found"
        echo ""
        discover_existing_dynamodb_tables "$project" || echo "No tables found"
    fi
fi