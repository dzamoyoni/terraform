#!/bin/bash
# ============================================================================
# AWS Tag Compliance Validation Script
# ============================================================================
# This script helps validate that your tags comply with AWS requirements:
# - Tag values must be 256 characters or less
# - Tag values can only contain: letters, numbers, spaces, and these symbols: _.:/=+\-@
# - No commas allowed in tag values
# ============================================================================

set -e

echo "=== AWS Tag Compliance Validation ==="
echo ""

# Function to check tag compliance
check_tag_compliance() {
    local tag_key="$1"
    local tag_value="$2"
    local issues=""
    
    # Check length
    if [ ${#tag_value} -gt 256 ]; then
        issues="$issues LENGTH(${#tag_value}>256)"
    fi
    
    # Check for commas
    if [[ "$tag_value" == *","* ]]; then
        issues="$issues COMMA"
    fi
    
    # Check for invalid characters (simplified check)
    if [[ "$tag_value" =~ [^a-zA-Z0-9\ \._:/=+\-@] ]]; then
        issues="$issues INVALID_CHARS"
    fi
    
    if [ -n "$issues" ]; then
        echo "❌ $tag_key: $issues"
        echo "   Value: $tag_value"
        return 1
    else
        echo "✅ $tag_key: OK"
        return 0
    fi
}

# Test common problematic tag values
echo "Testing common tag patterns:"
echo ""

# Test cases based on your error
test_tags=(
    "LayerPurpose:VPC, Subnets, NAT Gateways, VPN Infrastructure"
    "LayerPurpose:VPC and Network Infrastructure"
    "ContactEmail:dennis.juma00@gmail.com"
    "ComplianceFramework:SOC2-ISO27001"
    "ChargebackCode:EST1-FOUNDATION-001"
    "DeploymentPhase:Phase-1"
    "Project:ohio-01"
    "Environment:production"
)

total_tests=0
passed_tests=0

for test_case in "${test_tags[@]}"; do
    IFS=':' read -r key value <<< "$test_case"
    total_tests=$((total_tests + 1))
    
    if check_tag_compliance "$key" "$value"; then
        passed_tests=$((passed_tests + 1))
    fi
    echo ""
done

# Summary
echo "=== Results ==="
echo "Passed: $passed_tests/$total_tests tests"

if [ $passed_tests -eq $total_tests ]; then
    echo "All tag patterns are AWS compliant!"
    exit 0
else
    echo "⚠️  Some tag patterns need fixing"
    echo ""
    echo "Common fixes:"
    echo "- Replace commas with hyphens or 'and'"
    echo "- Shorten long descriptions"
    echo "- Remove special characters except: _.:/=+-@"
    exit 1
fi