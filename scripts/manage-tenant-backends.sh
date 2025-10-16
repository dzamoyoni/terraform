#!/bin/bash

# ============================================================================
# Multi-Tenant Backend Management Script
# ============================================================================
# This script manages Terraform backends for multi-tenant infrastructure
# with proper isolation and organizational structure.
#
# Structure it creates:
# /backends/aws/
# ├── {region}/
# │   ├── {environment}/
# │   │   ├── {tenant}/
# │   │   │   ├── backend.hcl              # Shared backend config
# │   │   │   ├── foundation.hcl           # Foundation layer backend
# │   │   │   ├── platform.hcl             # Platform layer backend  
# │   │   │   ├── observability.hcl        # Observability layer backend
# │   │   │   └── shared-services.hcl      # Shared services backend
# │   │   └── shared/
# │   │       ├── backend.hcl              # Shared infrastructure backend
# │   │       └── global.hcl               # Global services backend
# │   └── global/
# │       └── backend.hcl                  # Region-wide global services
# └── global/
#     └── backend.hcl                      # Cross-region global services
#
# Usage:
#   ./manage-tenant-backends.sh --region us-west-2 --tenant mtn-ghana --environment production
#   ./manage-tenant-backends.sh --region us-west-2 --list-tenants
#   ./manage-tenant-backends.sh --region us-west-2 --tenant client-a --show-config
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load shared configuration
source "$SCRIPT_DIR/shared-config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENVIRONMENT="production"
DEFAULT_REGION="us-west-2"

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

log_header() {
    echo -e "${CYAN}╭─ $1${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Manages multi-tenant Terraform backend configurations with proper isolation.

OPTIONS:
    -r, --region REGION           AWS region (default: us-west-2)
    -e, --environment ENV         Environment (production, staging, development) (default: production)
    -t, --tenant TENANT           Tenant name (e.g., mtn-ghana, orange-madagascar)
    -p, --project-name NAME       Project name (default: derived from region/environment)
    
ACTIONS:
    --create-tenant              Create backend configurations for new tenant
    --list-tenants               List all configured tenants
    --show-config                Show backend configuration for tenant
    --validate-backends          Validate all backend configurations
    --cleanup-tenant             Remove tenant backend configurations
    --migrate-tenant             Migrate tenant to new backend structure
    --show-structure             Show complete backend directory structure
    --show-all-paths             Show all backend configuration paths (easy copy/paste)
    --check-sync                 Check sync status between AWS infrastructure and backend configs
    
OPTIONS:
    --dry-run                    Show what would be done without making changes
    --force                      Skip confirmation prompts
    -h, --help                   Show this help message

EXAMPLES:
    # Create backend for new tenant in specific region/environment
    $0 --region us-west-2 --environment production --tenant mtn-ghana --create-tenant
    
    # List all tenants in a region
    $0 --region us-west-2 --environment production --list-tenants
    
    # Show configuration for specific tenant
    $0 --region us-west-2 --tenant client-a --show-config
    
    # Validate all backend configurations
    $0 --validate-backends
    
    # Show complete backend structure
    $0 --show-structure
    
    # Show all backend paths for easy copy/paste
    $0 --show-all-paths
    
    # Check if AWS infrastructure and backend configs are in sync
    $0 --region us-west-2 --environment production --project-name myproject --check-sync

EOF
}

# ============================================================================
# Backend Configuration Templates
# ============================================================================

generate_tenant_backend_config() {
    local tenant="$1"
    local layer="$2"
    local bucket_name="$3"
    local region="$4"
    local environment="$5"
    local project_name="$6"
    
    cat << EOF
# ============================================================================
# Terraform Backend Configuration - ${layer^} Layer
# ============================================================================
# Tenant: $tenant
# Environment: $environment
# Region: $region
# Layer: $layer
# Auto-generated by manage-tenant-backends.sh
# ============================================================================

bucket         = "$bucket_name"
key            = "tenants/$tenant/layers/$layer/$environment/terraform.tfstate"
region         = "$region"
dynamodb_table = "$(generate_dynamodb_table_name "$region")"
encrypt        = true

# State locking configuration
dynamodb_table_tags = {
  Project     = "$project_name"
  Environment = "$environment"
  Region      = "$region"
  Tenant      = "$tenant"
  Layer       = "$layer"
  ManagedBy   = "Terraform"
}

# S3 bucket configuration validation
s3_bucket_tags = {
  Project     = "$project_name"
  Environment = "$environment"
  Region      = "$region"
  Purpose     = "terraform-backend"
  Tenant      = "$tenant"
  Layer       = "$layer"
}
EOF
}

generate_shared_backend_config() {
    local scope="$1"       # shared, global
    local bucket_name="$2"
    local region="$3"
    local environment="$4"
    local project_name="$5"
    
    local key_path
    case "$scope" in
        "shared")
            key_path="shared/$environment/terraform.tfstate"
            ;;
        "global")
            key_path="global/$environment/terraform.tfstate"
            ;;
        "cross-region")
            key_path="global/cross-region/terraform.tfstate"
            ;;
    esac
    
    cat << EOF
# ============================================================================
# Terraform Backend Configuration - ${scope^} Infrastructure
# ============================================================================
# Scope: $scope
# Environment: $environment
# Region: $region
# Auto-generated by manage-tenant-backends.sh
# ============================================================================

bucket         = "$bucket_name"
key            = "$key_path"
region         = "$region"
dynamodb_table = "$(generate_dynamodb_table_name "$region")"
encrypt        = true

# State locking configuration
dynamodb_table_tags = {
  Project     = "$project_name"
  Environment = "$environment"
  Region      = "$region"
  Scope       = "$scope"
  ManagedBy   = "Terraform"
}

# S3 bucket configuration validation
s3_bucket_tags = {
  Project     = "$project_name"
  Environment = "$environment"
  Region      = "$region"
  Purpose     = "terraform-backend"
  Scope       = "$scope"
}
EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

parse_arguments() {
    REGION="$DEFAULT_REGION"
    ENVIRONMENT="$DEFAULT_ENVIRONMENT"
    TENANT=""
    PROJECT_NAME=""
    
    # Actions
    CREATE_TENANT=false
    LIST_TENANTS=false
    SHOW_CONFIG=false
    VALIDATE_BACKENDS=false
    CLEANUP_TENANT=false
    MIGRATE_TENANT=false
    SHOW_STRUCTURE=false
    SHOW_ALL_PATHS=false
    CHECK_SYNC=false
    
    # Options
    DRY_RUN=false
    FORCE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--tenant)
                TENANT="$2"
                shift 2
                ;;
            -p|--project-name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --create-tenant)
                CREATE_TENANT=true
                shift
                ;;
            --list-tenants)
                LIST_TENANTS=true
                shift
                ;;
            --show-config)
                SHOW_CONFIG=true
                shift
                ;;
            --validate-backends)
                VALIDATE_BACKENDS=true
                shift
                ;;
            --cleanup-tenant)
                CLEANUP_TENANT=true
                shift
                ;;
            --migrate-tenant)
                MIGRATE_TENANT=true
                shift
                ;;
            --show-structure)
                SHOW_STRUCTURE=true
                shift
                ;;
            --show-all-paths)
                SHOW_ALL_PATHS=true
                shift
                ;;
            --check-sync)
                CHECK_SYNC=true
                shift
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
    
    # Set default project name if not provided
    if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="${REGION}-$(echo "$ENVIRONMENT" | cut -c1-4)"
    fi
    
    # Validate required parameters based on action
    if [[ "$CREATE_TENANT" == true || "$SHOW_CONFIG" == true || "$CLEANUP_TENANT" == true || "$MIGRATE_TENANT" == true ]]; then
        if [[ -z "$TENANT" ]]; then
            log_error "Tenant name is required for this action"
            exit 1
        fi
    fi
}

# ============================================================================
# Backend Management Functions
# ============================================================================

create_tenant_backends() {
    local tenant="$1"
    local region="$2"
    local environment="$3"
    local project_name="$4"
    
    log_header "Creating backend configurations for tenant: $tenant"
    
    # Ensure AWS infrastructure exists first
    if ! ensure_infrastructure_ready "$project_name" "$region" "$environment"; then
        return 1
    fi
    
    # Use shared configuration for consistent naming
    local backends_dir="$PROJECT_ROOT/backends/aws/$region/$environment/$tenant"
    local bucket_name=$(generate_bucket_name "$project_name" "$environment")
    
    # Show the configuration being used
    show_infrastructure_config "$project_name" "$region" "$environment"
    
    # Define layers
    local layers=(
        "foundation"
        "platform" 
        "observability"
        "shared-services"
    )
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would create the following backend configurations:"
        log_info "Directory: $backends_dir"
        for layer in "${layers[@]}"; do
            log_info "  - ${layer}.hcl"
        done
        log_info "  - backend.hcl (main backend config)"
        return 0
    fi
    
    # Create directory structure
    mkdir -p "$backends_dir"
    
    # Generate backend configurations for each layer
    for layer in "${layers[@]}"; do
        local config_file="$backends_dir/${layer}.hcl"
        log_info "Creating backend config: $config_file"
        
        generate_tenant_backend_config "$tenant" "$layer" "$bucket_name" "$region" "$environment" "$project_name" > "$config_file"
        
        log_success "Created: ${layer}.hcl"
    done
    
    # Create main backend configuration (points to foundation)
    local main_config="$backends_dir/backend.hcl"
    log_info "Creating main backend config: $main_config"
    generate_tenant_backend_config "$tenant" "foundation" "$bucket_name" "$region" "$environment" "$project_name" > "$main_config"
    log_success "Created: backend.hcl"
    
    # Create tenant metadata
    create_tenant_metadata "$tenant" "$region" "$environment" "$project_name"
    
    log_success "Backend configurations created for tenant: $tenant"
    echo
    log_info "📁 Backend configurations location:"
    echo "   $(realpath "$backends_dir")"
    echo
    log_info "🚀 Usage examples:"
    echo "   terraform init -backend-config=\"$(realpath "$backends_dir")/foundation.hcl\""
    echo "   terraform init -backend-config=\"$(realpath "$backends_dir")/platform.hcl\""
    echo "   terraform init -backend-config=\"$(realpath "$backends_dir")/observability.hcl\""
    echo "   terraform init -backend-config=\"$(realpath "$backends_dir")/shared-services.hcl\""
}

create_shared_backends() {
    local region="$1"
    local environment="$2"
    local project_name="$3"
    
    log_header "Creating shared backend configurations"
    
    local shared_dir="$PROJECT_ROOT/backends/aws/$region/$environment/shared"
    local global_dir="$PROJECT_ROOT/backends/aws/$region/global"
    local cross_region_dir="$PROJECT_ROOT/backends/aws/global"
    
    local bucket_name="${project_name}-terraform-state-${environment}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would create shared backend configurations:"
        log_info "Shared: $shared_dir/backend.hcl"
        log_info "Global: $global_dir/backend.hcl"
        log_info "Cross-region: $cross_region_dir/backend.hcl"
        return 0
    fi
    
    # Create shared environment backends
    mkdir -p "$shared_dir"
    generate_shared_backend_config "shared" "$bucket_name" "$region" "$environment" "$project_name" > "$shared_dir/backend.hcl"
    log_success "Created shared backend configuration"
    
    # Create global region backends
    mkdir -p "$global_dir"
    generate_shared_backend_config "global" "$bucket_name" "$region" "$environment" "$project_name" > "$global_dir/backend.hcl"
    log_success "Created global region backend configuration"
    
    # Create cross-region global backends
    mkdir -p "$cross_region_dir"
    generate_shared_backend_config "cross-region" "$bucket_name" "$region" "$environment" "$project_name" > "$cross_region_dir/backend.hcl"
    log_success "Created cross-region backend configuration"
    
    echo
    log_info "Shared backend configurations:"
    echo "   Shared:       $(realpath "$shared_dir")/backend.hcl"
    echo "   Global:       $(realpath "$global_dir")/backend.hcl"
    echo "   Cross-region: $(realpath "$cross_region_dir")/backend.hcl"
}

create_tenant_metadata() {
    local tenant="$1"
    local region="$2" 
    local environment="$3"
    local project_name="$4"
    
    local metadata_file="$PROJECT_ROOT/backends/aws/$region/$environment/$tenant/.tenant-metadata.json"
    
    cat > "$metadata_file" << EOF
{
  "tenant_name": "$tenant",
  "region": "$region",
  "environment": "$environment",
  "project_name": "$project_name",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backend_version": "1.0.0",
  "layers": [
    "foundation",
    "platform",
    "observability", 
    "shared-services"
  ],
  "backend_structure": {
    "bucket": "${project_name}-terraform-state-${environment}",
    "key_prefix": "tenants/$tenant/layers",
    "dynamodb_table": "terraform-locks-$(echo "$region" | sed 's/-[0-9]*$//')"
  }
}
EOF
    
    log_success "Created tenant metadata: .tenant-metadata.json"
}

list_tenants() {
    local region="$1"
    local environment="$2"
    
    log_header "Tenants in $region/$environment"
    
    local tenant_base="$PROJECT_ROOT/backends/aws/$region/$environment"
    
    if [[ ! -d "$tenant_base" ]]; then
        log_warning "No tenants found in $region/$environment"
        return 0
    fi
    
    local count=0
    for tenant_dir in "$tenant_base"/*; do
        if [[ -d "$tenant_dir" && "$(basename "$tenant_dir")" != "shared" ]]; then
            local tenant=$(basename "$tenant_dir")
            local metadata_file="$tenant_dir/.tenant-metadata.json"
            
            if [[ -f "$metadata_file" ]]; then
                local created_at=$(jq -r '.created_at // "Unknown"' "$metadata_file" 2>/dev/null || echo "Unknown")
                local layers=$(jq -r '.layers | length // 0' "$metadata_file" 2>/dev/null || echo "0")
                
                printf "  %-20s | Created: %-20s | Layers: %s\n" "$tenant" "$created_at" "$layers"
                printf "    Path: %s\n" "$(realpath "$tenant_dir")"
            else
                printf "  %-20s | %s\n" "$tenant" "No metadata available"
                printf "   Path: %s\n" "$(realpath "$tenant_dir")"
            fi
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_warning "No tenants found in $region/$environment"
    else
        log_success "Found $count tenant(s)"
    fi
}

show_tenant_config() {
    local tenant="$1"
    local region="$2"
    local environment="$3"
    
    log_header "Backend configuration for tenant: $tenant"
    
    local tenant_dir="$PROJECT_ROOT/backends/aws/$region/$environment/$tenant"
    
    if [[ ! -d "$tenant_dir" ]]; then
        log_error "Tenant $tenant not found in $region/$environment"
        exit 1
    fi
    
    # Show metadata if available
    local metadata_file="$tenant_dir/.tenant-metadata.json"
    if [[ -f "$metadata_file" ]]; then
        log_info "Tenant Metadata:"
        jq . "$metadata_file" 2>/dev/null || cat "$metadata_file"
        echo
    fi
    
    # Show available backend configurations
    log_info "Available backend configurations:"
    for config_file in "$tenant_dir"/*.hcl; do
        if [[ -f "$config_file" ]]; then
            local config_name=$(basename "$config_file" .hcl)
            log_info "  ├─ $config_name.hcl"
        fi
    done
    
    echo
    log_info "Full backend configuration paths:"
    for config_file in "$tenant_dir"/*.hcl; do
        if [[ -f "$config_file" ]]; then
            local config_name=$(basename "$config_file" .hcl)
            echo "$config_name: $(realpath "$config_file")"
        fi
    done
    
    echo
    log_info "Usage examples:"
    echo "  terraform init -backend-config=\"$(realpath "$tenant_dir")/foundation.hcl\""
    echo "  terraform init -backend-config=\"$(realpath "$tenant_dir")/platform.hcl\""
    echo "  terraform init -backend-config=\"$(realpath "$tenant_dir")/observability.hcl\""
}

show_backend_structure() {
    log_header "Complete Backend Directory Structure"
    
    local backends_root="$PROJECT_ROOT/backends/aws"
    
    if [[ ! -d "$backends_root" ]]; then
        log_warning "No backend configurations found"
        return 0
    fi
    
    echo "Backend Structure: $(realpath "$backends_root")"
    echo
    
    # Show regions
    for region_dir in "$backends_root"/*; do
        if [[ -d "$region_dir" ]]; then
            local region=$(basename "$region_dir")
            echo "├── $region/"
            
            # Show environments
            for env_dir in "$region_dir"/*; do
                if [[ -d "$env_dir" ]]; then
                    local env=$(basename "$env_dir")
                    echo "│   ├── $env/"
                    
                    # Show tenants
                    for tenant_dir in "$env_dir"/*; do
                        if [[ -d "$tenant_dir" ]]; then
                            local tenant=$(basename "$tenant_dir")
                            if [[ "$tenant" == "shared" ]]; then
                                echo "│   │   ├──  shared/ (shared infrastructure)"
                                echo "│   │   │    $(realpath "$tenant_dir")"
                            else
                                local config_count=$(find "$tenant_dir" -name "*.hcl" | wc -l)
                                echo "│   │   ├── $tenant/ ($config_count configs)"
                                echo "│   │   │   $(realpath "$tenant_dir")"
                            fi
                        fi
                    done
                fi
            done
        fi
    done
}

show_all_backend_paths() {
    log_header "All Backend Configuration Paths"
    
    local backends_root="$PROJECT_ROOT/backends/aws"
    
    if [[ ! -d "$backends_root" ]]; then
        log_warning "No backend configurations found"
        return 0
    fi
    
    echo "🔍 Finding all backend configurations..."
    echo
    
    # Print header for better understanding
    printf "\033[1m%-3s %-15s | %-12s | %-12s | %-15s | %s\033[0m\n" "" "TENANT/TYPE" "REGION" "ENVIRONMENT" "LAYER" "PATH"
    printf "%-3s %-15s | %-12s | %-12s | %-15s | %s\n" "" "---------------" "------------" "------------" "---------------" "----"
    
    # Find all .hcl files and parse their paths correctly
    while IFS= read -r -d '' config_file; do
        local rel_path=$(realpath --relative-to="$backends_root" "$config_file")
        local config_name=$(basename "$config_file" .hcl)
        local abs_path=$(realpath "$config_file")
        
        # Parse path components based on expected structure
        IFS='/' read -ra PATH_PARTS <<< "$rel_path"
        local num_parts=${#PATH_PARTS[@]}
        
        if [[ $num_parts -eq 2 && "${PATH_PARTS[0]}" == "global" ]]; then
            # Structure: global/backend.hcl (cross-region global)
            printf "%-15s | %-12s | %-12s | %-15s | %s\n" "CROSS-REGION" "-" "global" "$config_name" "$abs_path"
            
        elif [[ $num_parts -eq 3 && "${PATH_PARTS[1]}" == "global" ]]; then
            # Structure: region/global/backend.hcl (regional global)
            local region="${PATH_PARTS[0]}"
            printf "%-15s | %-12s | %-12s | %-15s | %s\n" "REGIONAL-GLOBAL" "$region" "global" "$config_name" "$abs_path"
            
        elif [[ $num_parts -eq 4 && "${PATH_PARTS[2]}" == "shared" ]]; then
            # Structure: region/environment/shared/backend.hcl (shared infrastructure)
            local region="${PATH_PARTS[0]}"
            local environment="${PATH_PARTS[1]}"
            printf "%-15s | %-12s | %-12s | %-15s | %s\n" "SHARED" "$region" "$environment" "$config_name" "$abs_path"
            
        elif [[ $num_parts -eq 4 ]]; then
            # Structure: region/environment/tenant/config.hcl (tenant-specific)
            local region="${PATH_PARTS[0]}"
            local environment="${PATH_PARTS[1]}"
            local tenant="${PATH_PARTS[2]}"
            printf "%-15s | %-12s | %-12s | %-15s | %s\n" "$tenant" "$region" "$environment" "$config_name" "$abs_path"
            
        else
            # Handle legacy or non-standard paths
            local region="${PATH_PARTS[0]:-unknown}"
            local environment="${PATH_PARTS[1]:-unknown}"
            local tenant_or_file="${PATH_PARTS[2]:-${config_name}}"
            
            # Check if this might be a legacy structure
            if [[ $num_parts -eq 3 ]]; then
                # Could be: region/environment/config.hcl (legacy single-tenant)
                printf "%-15s | %-12s | %-12s | %-15s | %s\n" "LEGACY" "$region" "$environment" "$config_name" "$abs_path"
            else
                printf "%-15s | %-12s | %-12s | %-15s | %s\n" "UNKNOWN" "$region" "$environment" "$config_name" "$abs_path"
            fi
        fi
        
    done < <(find "$backends_root" -name "*.hcl" -print0 2>/dev/null | sort -z)
    
    echo
    # Show summary statistics
    local tenant_count=$(find "$backends_root" -name "*.hcl" | grep -E '/[^/]+/[^/]+/[^/]+/[^/]+\.hcl$' | grep -v "/shared/" | grep -v "/global/" | wc -l 2>/dev/null)
    local shared_count=$(find "$backends_root" -name "*.hcl" | grep "/shared/" | wc -l 2>/dev/null)
    local global_count=$(find "$backends_root" -name "*.hcl" | grep "/global/" | wc -l 2>/dev/null)
    local total_count=$(find "$backends_root" -name "*.hcl" | wc -l 2>/dev/null)
    
    log_info "Summary:"
    echo "   Tenant backends:   $tenant_count"
    echo "   Shared backends:    $shared_count"
    echo "   Global backends:    $global_count"
    echo "   Total backends:     $total_count"
    
    echo
    log_info "Copy any path above to use in your terraform init command"
    echo "   Example: terraform init -backend-config=\"/path/to/backend.hcl\""
}

validate_all_backends() {
    log_header "Validating all backend configurations"
    
    local backends_root="$PROJECT_ROOT/backends/aws"
    local total_configs=0
    local valid_configs=0
    local invalid_configs=0
    
    # Find all .hcl files
    while IFS= read -r -d '' config_file; do
        ((total_configs++))
        
        log_info "Validating: $(realpath --relative-to="$PROJECT_ROOT" "$config_file")"
        
        # Basic validation - check for required fields
        if grep -q "bucket\s*=" "$config_file" && \
           grep -q "key\s*=" "$config_file" && \
           grep -q "region\s*=" "$config_file" && \
           grep -q "dynamodb_table\s*=" "$config_file"; then
            log_success "  ✓ Valid configuration"
            ((valid_configs++))
        else
            log_error "  ✗ Invalid configuration - missing required fields"
            ((invalid_configs++))
        fi
        
    done < <(find "$backends_root" -name "*.hcl" -print0 2>/dev/null || true)
    
    echo
    log_info "Validation Summary:"
    log_info "  Total configurations: $total_configs"
    log_success "  Valid configurations: $valid_configs"
    if [[ $invalid_configs -gt 0 ]]; then
        log_error "  Invalid configurations: $invalid_configs"
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    parse_arguments "$@"
    
    # Execute requested action
    if [[ "$CREATE_TENANT" == true ]]; then
        create_tenant_backends "$TENANT" "$REGION" "$ENVIRONMENT" "$PROJECT_NAME"
        create_shared_backends "$REGION" "$ENVIRONMENT" "$PROJECT_NAME"
        
    elif [[ "$LIST_TENANTS" == true ]]; then
        list_tenants "$REGION" "$ENVIRONMENT"
        
    elif [[ "$SHOW_CONFIG" == true ]]; then
        show_tenant_config "$TENANT" "$REGION" "$ENVIRONMENT"
        
    elif [[ "$VALIDATE_BACKENDS" == true ]]; then
        validate_all_backends
        
    elif [[ "$SHOW_STRUCTURE" == true ]]; then
        show_backend_structure
        
    elif [[ "$SHOW_ALL_PATHS" == true ]]; then
        show_all_backend_paths
        
    elif [[ "$CHECK_SYNC" == true ]]; then
        check_sync_status "$PROJECT_NAME" "$REGION" "$ENVIRONMENT"
        
    elif [[ "$CLEANUP_TENANT" == true ]]; then
        log_warning "Cleanup functionality not yet implemented"
        exit 1
        
    elif [[ "$MIGRATE_TENANT" == true ]]; then
        log_warning "Migration functionality not yet implemented"
        exit 1
        
    else
        log_error "No action specified"
        show_usage
        exit 1
    fi
}

# Run the script
main "$@"