#!/bin/bash
# ============================================================================
# Standardized Tagging Application Script - us-east-2
# ============================================================================
# This script applies standardized tagging to all layers in the us-east-2 region
# by implementing the centralized tagging module consistently across layers.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REGION_DIR/templates"
REGION="us-east-2"

echo "=== Standardized Tagging Application Script ==="
echo "Region: $REGION"
echo "Templates Directory: $TEMPLATES_DIR"
echo ""

# Define layer configurations with their specific settings
declare -A LAYER_CONFIGS=(
    # Layer Name : "Display Name|Purpose|Phase|Additional Config"
    ["01-foundation"]="Foundation|VPC, Subnets, NAT Gateways, VPN Infrastructure|Phase-1|network"
    ["02-platform"]="Platform|EKS Cluster and Platform Services|Phase-2|kubernetes"
    ["03-databases"]="Database|Client Database Infrastructure|Phase-3|database"
    ["03-standalone-compute"]="Standalone Compute|Dedicated Compute Resources|Phase-3.1|compute"
    ["03.5-observability"]="Observability|Monitoring, Logging, Tracing, and Alerting|Phase-3.5|observability"
    ["04-database-layer"]="Database Layer|Database Layer Infrastructure|Phase-4|database"
    ["05-client-nodegroups"]="Client Node Groups|Client-Specific EKS Node Groups|Phase-5|client-kubernetes"
    ["06-shared-services"]="Shared Services|Shared Infrastructure Services|Phase-6|shared"
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages with colors
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

# Function to backup existing main.tf
backup_main_tf() {
    local layer_dir="$1"
    local main_tf="$layer_dir/main.tf"
    
    if [ -f "$main_tf" ]; then
        local backup_file="$main_tf.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$main_tf" "$backup_file"
        log_info "Backed up existing main.tf to $(basename "$backup_file")"
        return 0
    else
        log_warning "No existing main.tf found in $layer_dir"
        return 1
    fi
}

# Function to generate tagging configuration for a layer
generate_tagging_config() {
    local layer_name="$1"
    local config_string="$2"
    
    IFS='|' read -r display_name purpose phase additional_config <<< "$config_string"
    
    local chargeback_code="CPTWN-$(echo "$layer_name" | tr '[:lower:]' '[:upper:]' | tr -d '-')-001"
    
    cat << EOF
# ============================================================================
# Centralized Tagging Configuration
# ============================================================================

module "tags" {
  source = "../../../../../../../modules/tagging"
  
  # Core configuration
  project_name     = var.project_name
  environment      = var.environment
  layer_name       = "$layer_name"
  region           = var.region
  
  # Layer-specific configuration
  layer_purpose    = "$purpose"
  deployment_phase = "$phase"
  
  # Infrastructure classification
  critical_infrastructure = "true"
  backup_required        = "true"
  security_level         = "High"
  
  # Cost management
  cost_center      = "IT-Infrastructure"
  billing_group    = "Platform-Engineering"
  chargeback_code  = "$chargeback_code"
  
  # Operational settings
  sla_tier           = "Gold"
  monitoring_level   = "Enhanced"
  maintenance_window = "Sunday-02:00-04:00-UTC"
  
  # Governance
  compliance_framework = "SOC2-ISO27001"
  data_classification  = "Internal"
EOF

    # Add layer-specific configurations
    case "$additional_config" in
        "network")
            cat << EOF
  
  # Network-specific settings
  additional_tags = {
    NetworkTier      = "Foundation"
    VPCPurpose       = "Multi-Tenant-EKS"
    NATConfiguration = "HighAvailability"
  }
EOF
            ;;
        "kubernetes")
            cat << EOF
  
  # Kubernetes-specific settings
  kubernetes_version = var.cluster_version
  additional_tags = {
    ClusterRole    = "Primary"
    NodeGroupType  = "Mixed"
    PlatformType   = "EKS"
  }
EOF
            ;;
        "database")
            cat << EOF
  
  # Database-specific settings
  database_engine  = "PostgreSQL"
  backup_strategy  = "Daily-Full-Weekly-Archive"
  additional_tags = {
    DatabaseEngine   = "PostgreSQL"
    BackupFrequency = "Daily"
    EncryptionEnabled = "true"
  }
EOF
            ;;
        "observability")
            cat << EOF
  
  # Observability-specific settings
  data_retention = "90-days"
  archive_policy = "Glacier-after-30-days"
  additional_tags = {
    ObservabilityStack = "FluentBit-Tempo-Prometheus-Grafana"
    LogRetention      = "\${var.logs_retention_days}-days"
    TracesRetention   = "\${var.traces_retention_days}-days"
    MetricsEnabled    = "true"
    AlertingEnabled   = "true"
  }
EOF
            ;;
        "client-kubernetes")
            cat << EOF
  
  # Client-specific Kubernetes settings
  kubernetes_version = var.cluster_version
  additional_tags = {
    NodeGroupPurpose = "Client-Specific"
    MultiTenant     = "true"
    ClientSupport   = "Premium"
  }
EOF
            ;;
        "compute")
            cat << EOF
  
  # Compute-specific settings
  additional_tags = {
    ComputeType     = "Standalone"
    AutoScaling     = "Enabled"
    InstanceFamily  = "General-Purpose"
  }
EOF
            ;;
        "shared")
            cat << EOF
  
  # Shared services settings
  additional_tags = {
    ServiceType     = "Shared"
    ResourceScope   = "Multi-Tenant"
    ServiceTier     = "Platform"
  }
EOF
            ;;
    esac
    
    cat << EOF
}

# Provider configuration with standardized default tags
provider "aws" {
  region = var.region

  default_tags {
    tags = module.tags.standard_tags
  }
}
EOF
}

# Function to generate locals block
generate_locals_block() {
    cat << EOF

# ============================================================================
# Locals for Tag Management
# ============================================================================

locals {
  # Standard tags for most resources
  common_tags = module.tags.standard_tags
  
  # Comprehensive tags for critical infrastructure
  critical_tags = module.tags.comprehensive_tags
  
  # Minimal tags for cost-sensitive resources
  minimal_tags = module.tags.minimal_tags
  
  # Client-specific tags for multi-tenant resources (if applicable)
  client_tags = {
    "mtn-ghana-prod" = merge(
      module.tags.standard_tags,
      {
        Client     = "mtn-ghana-prod"
        ClientCode = "MTN-GH"
        ClientTier = "Premium"
        TenantType = "Production"
      }
    )
    "orange-madagascar-prod" = merge(
      module.tags.standard_tags,
      {
        Client     = "orange-madagascar-prod"
        ClientCode = "OMG-MD"
        ClientTier = "Premium"
        TenantType = "Production"
      }
    )
  }
  
  # Kubernetes labels (if applicable)
  kubernetes_labels = module.tags.kubernetes_labels
}
EOF
}

# Function to create tagging configuration for a layer
create_layer_tagging() {
    local layer_name="$1"
    local config_string="$2"
    local layer_dir="$REGION_DIR/layers/$layer_name/production"
    
    log_info "Processing layer: $layer_name"
    
    if [ ! -d "$layer_dir" ]; then
        log_warning "Layer directory not found: $layer_dir"
        return 1
    fi
    
    # Read the current main.tf to preserve existing content
    local main_tf="$layer_dir/main.tf"
    if [ ! -f "$main_tf" ]; then
        log_error "main.tf not found in $layer_dir"
        return 1
    fi
    
    # Create a tagging configuration file
    local tagging_config_file="$layer_dir/tagging-config.tf.new"
    
    log_info "  - Generating tagging configuration"
    {
        generate_tagging_config "$layer_name" "$config_string"
        generate_locals_block
    } > "$tagging_config_file"
    
    log_success "  - Generated tagging configuration: $(basename "$tagging_config_file")"
    log_info "  - Review the generated configuration before applying"
    
    return 0
}

# Function to show usage instructions
show_usage() {
    cat << EOF

=== Generated Files ===
Each layer now has a 'tagging-config.tf.new' file with standardized tagging.

=== Next Steps ===
1. Review each generated tagging-config.tf.new file
2. Backup your existing main.tf files
3. Integrate the tagging configuration into your main.tf files
4. Test with 'terraform validate' in each layer
5. Apply changes with 'terraform plan' and 'terraform apply'

=== Manual Integration Steps ===
For each layer:
1. cp main.tf main.tf.backup
2. # Edit main.tf to integrate tagging configuration
3. terraform validate
4. terraform plan
5. # If plan looks good, apply changes

=== Example Integration ===
Replace existing provider and tags sections with the generated configuration.
Update module calls to use local.common_tags, local.critical_tags, etc.

EOF
}

# Main execution
main() {
    log_info "Starting standardized tagging application process..."
    
    local success_count=0
    local total_count=${#LAYER_CONFIGS[@]}
    
    # Process each layer
    for layer_name in "${!LAYER_CONFIGS[@]}"; do
        if create_layer_tagging "$layer_name" "${LAYER_CONFIGS[$layer_name]}"; then
            ((success_count++))
        fi
        echo ""
    done
    
    # Show summary
    echo "=== Summary ==="
    log_info "Processed: $success_count/$total_count layers"
    
    if [ $success_count -eq $total_count ]; then
        log_success "All layers processed successfully!"
    else
        log_warning "Some layers had issues. Review the output above."
    fi
    
    show_usage
}

# Run main function
main "$@"