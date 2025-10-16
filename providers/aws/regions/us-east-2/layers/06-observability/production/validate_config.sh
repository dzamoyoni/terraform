#!/bin/bash

# ============================================================================
# Observability Layer Configuration Validation Script
# ============================================================================
# This script validates the observability configuration to prevent common
# deployment issues like PVC binding failures and application crashes.
# ============================================================================

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo " Validating Observability Layer Configuration..."
echo "============================================================================"

# Function to print status messages
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN} $message${NC}"
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "${RED} $message${NC}"
    fi
}

# Function to check if kubectl is available and cluster is reachable
check_cluster_access() {
    echo "Checking cluster access..."
    
    if ! command -v kubectl &> /dev/null; then
        print_status "ERROR" "kubectl is not installed or not in PATH"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_status "ERROR" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    print_status "OK" "Cluster access verified"
    return 0
}

# Function to validate storage classes
check_storage_classes() {
    echo
    echo "Checking Storage Classes..."
    
    # Check if gp2 storage class exists
    if kubectl get storageclass gp2 &> /dev/null; then
        print_status "OK" "GP2 storage class exists"
        
        # Check if gp2 is default
        if kubectl get storageclass gp2 -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null | grep -q "true"; then
            print_status "OK" "GP2 is set as default storage class"
        else
            print_status "WARNING" "GP2 is not set as default storage class - may cause PVC issues"
            echo "  Run: kubectl patch storageclass gp2 -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
        fi
    else
        print_status "ERROR" "GP2 storage class does not exist - PVCs will fail to bind"
    fi
    
    # Check EBS CSI driver
    if kubectl get daemonset ebs-csi-node -n kube-system &> /dev/null; then
        print_status "OK" "EBS CSI driver is installed"
    else
        print_status "ERROR" "EBS CSI driver is not installed"
    fi
}

# Function to check existing PVCs
check_pvcs() {
    echo
    echo "Checking Existing PVCs in monitoring namespace..."
    
    if ! kubectl get namespace monitoring &> /dev/null; then
        print_status "WARNING" "monitoring namespace does not exist yet"
        return 0
    fi
    
    local pending_pvcs=$(kubectl get pvc -n monitoring --field-selector=status.phase=Pending -o name 2>/dev/null | wc -l)
    
    if [ "$pending_pvcs" -gt 0 ]; then
        print_status "ERROR" "$pending_pvcs PVC(s) are stuck in Pending state"
        echo "  Pending PVCs:"
        kubectl get pvc -n monitoring --field-selector=status.phase=Pending
    else
        print_status "OK" "No PVCs are stuck in Pending state"
    fi
}

# Function to validate Terraform configuration files
check_terraform_config() {
    echo
    echo " Checking Terraform Configuration..."
    
    # Check if variables.tf exists
    if [ -f "$SCRIPT_DIR/variables.tf" ]; then
        print_status "OK" "variables.tf exists"
        
        # Check alertmanager_storage_class default
        local storage_class=$(grep -A 3 'variable "alertmanager_storage_class"' "$SCRIPT_DIR/variables.tf" | grep 'default' | sed 's/.*= *"\([^"]*\)".*/\1/')
        if [ "$storage_class" = "gp2" ]; then
            print_status "OK" "AlertManager storage class is set to gp2"
        else
            print_status "ERROR" "AlertManager storage class is set to '$storage_class' (should be 'gp2')"
        fi
    else
        print_status "ERROR" "variables.tf not found"
    fi
    
    # Check if main.tf exists
    if [ -f "$SCRIPT_DIR/main.tf" ]; then
        print_status "OK" "main.tf exists"
        
        # Check if enable_gp3_storage is set to false
        if grep -q "enable_gp3_storage.*=.*false" "$SCRIPT_DIR/main.tf"; then
            print_status "OK" "GP3 storage is disabled (using GP2)"
        else
            print_status "WARNING" "GP3 storage setting not found or enabled"
        fi
        
        # Check if alertmanager variables are passed
        if grep -q "alertmanager_storage_class.*=.*var.alertmanager_storage_class" "$SCRIPT_DIR/main.tf"; then
            print_status "OK" "AlertManager storage class variable is passed to module"
        else
            print_status "ERROR" "AlertManager storage class variable is not passed to module"
        fi
    else
        print_status "ERROR" "main.tf not found"
    fi
}

# Function to check module templates
check_module_templates() {
    echo
    echo " Checking Module Templates..."
    
    local module_path="$SCRIPT_DIR/../../../../../../../modules/observability-layer"
    local tempo_template="$module_path/templates/tempo-values.yaml.tpl"
    
    if [ -f "$tempo_template" ]; then
        print_status "OK" "Tempo template exists"
        
        # Check if S3 endpoint is configured
        if grep -q "endpoint: s3.\${region}.amazonaws.com" "$tempo_template"; then
            print_status "OK" "Tempo S3 endpoint is configured"
        else
            print_status "ERROR" "Tempo S3 endpoint is missing - will cause crashes"
        fi
        
        # Check if storage class is set to gp2
        if grep -q "storageClassName: gp2" "$tempo_template"; then
            print_status "OK" "Tempo storage class is set to gp2"
        else
            print_status "WARNING" "Tempo storage class may not be set to gp2"
        fi
    else
        print_status "ERROR" "Tempo template not found at $tempo_template"
    fi
}

# Function to check running pods
check_running_pods() {
    echo
    echo "🚀 Checking Running Observability Pods..."
    
    if ! kubectl get namespace monitoring &> /dev/null; then
        print_status "WARNING" "monitoring namespace does not exist yet"
        return 0
    fi
    
    # Check specific pods
    local pods=("prometheus-stack-monitorin-alertmanager-0" "tempo-0")
    
    for pod in "${pods[@]}"; do
        local pod_status=$(kubectl get pod "$pod" -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        case $pod_status in
            "Running")
                print_status "OK" "$pod is running"
                ;;
            "Pending")
                print_status "ERROR" "$pod is stuck in Pending state"
                kubectl describe pod "$pod" -n monitoring | grep -A 5 "Events:"
                ;;
            "CrashLoopBackOff")
                print_status "ERROR" "$pod is in CrashLoopBackOff state"
                echo "  💡 Check logs: kubectl logs $pod -n monitoring"
                ;;
            "NotFound")
                print_status "WARNING" "$pod does not exist yet"
                ;;
            *)
                print_status "WARNING" "$pod is in $pod_status state"
                ;;
        esac
    done
}

# Main validation flow
main() {
    echo "Starting validation at $(date)"
    echo
    
    local exit_code=0
    
    # Run all checks
    check_cluster_access || exit_code=1
    check_storage_classes || exit_code=1
    check_pvcs || exit_code=1
    check_terraform_config || exit_code=1
    check_module_templates || exit_code=1
    check_running_pods || exit_code=1
    
    echo
    echo "============================================================================"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}🎉 All validations passed! Ready to deploy.${NC}"
    else
        echo -e "${RED}❌ Some validations failed. Please review the issues above.${NC}"
    fi
    
    echo
    echo "📚 For more information, see: STORAGE_CLASS_GUIDE.md"
    echo "🔧 To apply fixes, run: terraform plan && terraform apply"
    
    exit $exit_code
}

# Run validation
main "$@"
