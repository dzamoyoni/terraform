#!/bin/bash

# ============================================================================
# Foundation Layer Validation Script
# ============================================================================
# This script validates that the foundation layer is properly deployed and
# that all layers are correctly configured to use foundation layer outputs.
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
ENVIRONMENT="production"
SSM_PREFIX="/terraform/${ENVIRONMENT}/foundation"

echo -e "${BLUE}🔍 Foundation Layer Validation Script${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Function to check if AWS CLI is configured
check_aws_cli() {
    echo -e "${YELLOW}📋 Checking AWS CLI configuration...${NC}"
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ AWS CLI not configured or credentials invalid${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS CLI configured successfully${NC}"
    echo ""
}

# Function to check SSM parameters
check_ssm_parameters() {
    echo -e "${YELLOW}📊 Checking Foundation Layer SSM Parameters...${NC}"
    
    # List of expected SSM parameters
    expected_params=(
        "vpc_id"
        "vpc_cidr" 
        "private_subnets"
        "public_subnets"
        "private_subnet_cidrs"
        "public_subnet_cidrs"
        "eks_cluster_security_group_id"
        "database_security_group_id"
        "alb_security_group_id"
        "vpn_enabled"
        "deployed"
        "version"
        "region"
        "availability_zones"
    )
    
    missing_params=()
    
    for param in "${expected_params[@]}"; do
        param_path="${SSM_PREFIX}/${param}"
        if aws ssm get-parameter --name "$param_path" --region "$REGION" >/dev/null 2>&1; then
            value=$(aws ssm get-parameter --name "$param_path" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null)
            echo -e "${GREEN}✅ $param: $value${NC}"
        else
            echo -e "${RED}❌ Missing parameter: $param_path${NC}"
            missing_params+=("$param")
        fi
    done
    
    if [ ${#missing_params[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All foundation SSM parameters found${NC}"
    else
        echo -e "${RED}❌ Missing ${#missing_params[@]} SSM parameters${NC}"
        return 1
    fi
    echo ""
}

# Function to check VPC and networking
check_vpc_networking() {
    echo -e "${YELLOW}🌐 Checking VPC and Networking Resources...${NC}"
    
    # Get VPC ID from SSM
    vpc_id=$(aws ssm get-parameter --name "${SSM_PREFIX}/vpc_id" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
    
    if [ -z "$vpc_id" ]; then
        echo -e "${RED}❌ Cannot retrieve VPC ID from SSM${NC}"
        return 1
    fi
    
    # Check VPC exists
    if aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$REGION" >/dev/null 2>&1; then
        vpc_cidr=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --query "Vpcs[0].CidrBlock" --output text --region "$REGION")
        echo -e "${GREEN}✅ VPC exists: $vpc_id ($vpc_cidr)${NC}"
    else
        echo -e "${RED}❌ VPC not found: $vpc_id${NC}"
        return 1
    fi
    
    # Check private subnets
    private_subnets=$(aws ssm get-parameter --name "${SSM_PREFIX}/private_subnets" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
    if [ ! -z "$private_subnets" ]; then
        IFS=',' read -ra SUBNET_ARRAY <<< "$private_subnets"
        for subnet_id in "${SUBNET_ARRAY[@]}"; do
            if aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$REGION" >/dev/null 2>&1; then
                subnet_cidr=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --query "Subnets[0].CidrBlock" --output text --region "$REGION")
                echo -e "${GREEN}✅ Private subnet: $subnet_id ($subnet_cidr)${NC}"
            else
                echo -e "${RED}❌ Private subnet not found: $subnet_id${NC}"
            fi
        done
    fi
    
    # Check public subnets
    public_subnets=$(aws ssm get-parameter --name "${SSM_PREFIX}/public_subnets" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
    if [ ! -z "$public_subnets" ]; then
        IFS=',' read -ra SUBNET_ARRAY <<< "$public_subnets"
        for subnet_id in "${SUBNET_ARRAY[@]}"; do
            if aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$REGION" >/dev/null 2>&1; then
                subnet_cidr=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --query "Subnets[0].CidrBlock" --output text --region "$REGION")
                echo -e "${GREEN}✅ Public subnet: $subnet_id ($subnet_cidr)${NC}"
            else
                echo -e "${RED}❌ Public subnet not found: $subnet_id${NC}"
            fi
        done
    fi
    
    echo ""
}

# Function to check security groups
check_security_groups() {
    echo -e "${YELLOW}🔒 Checking Security Groups...${NC}"
    
    # Security groups to check
    sg_params=(
        "eks_cluster_security_group_id"
        "database_security_group_id" 
        "alb_security_group_id"
    )
    
    for sg_param in "${sg_params[@]}"; do
        sg_id=$(aws ssm get-parameter --name "${SSM_PREFIX}/${sg_param}" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
        if [ ! -z "$sg_id" ]; then
            if aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" >/dev/null 2>&1; then
                sg_name=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query "SecurityGroups[0].GroupName" --output text --region "$REGION")
                echo -e "${GREEN}✅ Security Group: $sg_param = $sg_id ($sg_name)${NC}"
            else
                echo -e "${RED}❌ Security group not found: $sg_id${NC}"
            fi
        else
            echo -e "${RED}❌ Cannot retrieve security group ID for: $sg_param${NC}"
        fi
    done
    echo ""
}

# Function to check VPN configuration
check_vpn() {
    echo -e "${YELLOW}🔗 Checking VPN Configuration...${NC}"
    
    vpn_enabled=$(aws ssm get-parameter --name "${SSM_PREFIX}/vpn_enabled" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "false")
    
    if [ "$vpn_enabled" = "true" ]; then
        echo -e "${GREEN}✅ VPN is enabled${NC}"
        
        # Check for VPN gateway
        vpn_gw_id=$(aws ssm get-parameter --name "${SSM_PREFIX}/vpn_gateway_id" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
        if [ ! -z "$vpn_gw_id" ]; then
            if aws ec2 describe-vpn-gateways --vpn-gateway-ids "$vpn_gw_id" --region "$REGION" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ VPN Gateway: $vpn_gw_id${NC}"
            else
                echo -e "${RED}❌ VPN Gateway not found: $vpn_gw_id${NC}"
            fi
        fi
        
        # Check VPN connections
        vpn_connections=$(aws ec2 describe-vpn-connections --region "$REGION" --query "VpnConnections[?State=='available'].VpnConnectionId" --output text 2>/dev/null || echo "")
        if [ ! -z "$vpn_connections" ]; then
            connection_count=$(echo "$vpn_connections" | wc -w)
            echo -e "${GREEN}✅ Active VPN connections: $connection_count${NC}"
        else
            echo -e "${YELLOW}⚠️ No active VPN connections found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ VPN is disabled${NC}"
    fi
    echo ""
}

# Function to check layer consistency
check_layer_consistency() {
    echo -e "${YELLOW}🔄 Checking Layer Configuration Consistency...${NC}"
    
    # Check platform layer configuration
    platform_dir="/home/dennis.juma/terraform/regions/us-east-1/layers/02-platform/production"
    if [ -f "$platform_dir/main.tf" ]; then
        if grep -q "data.aws_ssm_parameter.vpc_id.value" "$platform_dir/main.tf"; then
            echo -e "${GREEN}✅ Platform layer uses foundation SSM parameters${NC}"
        else
            echo -e "${RED}❌ Platform layer still uses hardcoded values${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Platform layer main.tf not found${NC}"
    fi
    
    # Check client layer configuration  
    client_dir="/home/dennis.juma/terraform/regions/us-east-1/layers/04-client/production"
    if [ -f "$client_dir/main.tf" ]; then
        if grep -q "data.aws_ssm_parameter.vpc_id.value" "$client_dir/main.tf"; then
            echo -e "${GREEN}✅ Client layer uses foundation SSM parameters${NC}"
        else
            echo -e "${RED}❌ Client layer still uses hardcoded values${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Client layer main.tf not found${NC}"
    fi
    
    # Check database layer configuration
    db_dir="/home/dennis.juma/terraform/regions/us-east-1/layers/03-databases/production"
    if [ -f "$db_dir/main.tf" ]; then
        if grep -q "/terraform/production/foundation/" "$db_dir/main.tf"; then
            echo -e "${GREEN}✅ Database layer uses foundation SSM parameters${NC}"
        else
            echo -e "${RED}❌ Database layer still uses old SSM parameter names${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Database layer main.tf not found${NC}"
    fi
    
    echo ""
}

# Function to check regional config consistency
check_regional_config_consistency() {
    echo -e "${YELLOW}📋 Checking Regional Config Consistency...${NC}"
    
    regional_config="/home/dennis.juma/terraform/shared/region-configs/us-east-1/networking.tfvars"
    foundation_tfvars="/home/dennis.juma/terraform/regions/us-east-1/layers/01-foundation/production/terraform.tfvars"
    
    if [ -f "$regional_config" ] && [ -f "$foundation_tfvars" ]; then
        # Check VPC CIDR consistency
        regional_cidr=$(grep 'vpc_cidr' "$regional_config" | cut -d'"' -f2)
        foundation_cidr=$(grep 'vpc_cidr' "$foundation_tfvars" | cut -d'"' -f2)
        
        if [ "$regional_cidr" = "$foundation_cidr" ]; then
            echo -e "${GREEN}✅ VPC CIDR consistent: $regional_cidr${NC}"
        else
            echo -e "${RED}❌ VPC CIDR mismatch: Regional($regional_cidr) vs Foundation($foundation_cidr)${NC}"
        fi
        
        # Check VPN IPs
        regional_vpn_ip=$(grep 'customer_gateway_ip' "$regional_config" | cut -d'"' -f2)
        foundation_vpn_ip=$(grep 'customer_gateway_ip' "$foundation_tfvars" | cut -d'"' -f2)
        
        if [ "$regional_vpn_ip" = "$foundation_vpn_ip" ]; then
            echo -e "${GREEN}✅ VPN Gateway IP consistent: $regional_vpn_ip${NC}"
        else
            echo -e "${RED}❌ VPN Gateway IP mismatch: Regional($regional_vpn_ip) vs Foundation($foundation_vpn_ip)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Configuration files not found for comparison${NC}"
    fi
    
    echo ""
}

# Function to generate summary
generate_summary() {
    echo -e "${BLUE}📊 Foundation Layer Validation Summary${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    
    # Get foundation deployment status
    deployed=$(aws ssm get-parameter --name "${SSM_PREFIX}/deployed" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "false")
    version=$(aws ssm get-parameter --name "${SSM_PREFIX}/version" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "unknown")
    
    if [ "$deployed" = "true" ]; then
        echo -e "${GREEN}✅ Foundation Layer Status: DEPLOYED (v$version)${NC}"
    else
        echo -e "${RED}❌ Foundation Layer Status: NOT DEPLOYED${NC}"
    fi
    
    # Count VPC resources
    vpc_id=$(aws ssm get-parameter --name "${SSM_PREFIX}/vpc_id" --query "Parameter.Value" --output text --region "$REGION" 2>/dev/null || echo "")
    if [ ! -z "$vpc_id" ]; then
        subnet_count=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets | length(@)" --output text --region "$REGION" 2>/dev/null || echo "0")
        sg_count=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups | length(@)" --output text --region "$REGION" 2>/dev/null || echo "0")
        echo -e "${GREEN}📈 VPC Resources: $subnet_count subnets, $sg_count security groups${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🎯 Next Steps:${NC}"
    echo "1. Deploy foundation layer if not already deployed"
    echo "2. Update and deploy platform layer (02-platform)"
    echo "3. Update and deploy database layer (03-databases)" 
    echo "4. Update and deploy client layer (04-client)"
    echo "5. Test end-to-end functionality"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}Starting foundation layer validation...${NC}"
    echo ""
    
    # Run all checks
    check_aws_cli
    check_ssm_parameters || true
    check_vpc_networking || true
    check_security_groups || true
    check_vpn || true
    check_layer_consistency || true
    check_regional_config_consistency || true
    generate_summary
    
    echo -e "${BLUE}Validation completed!${NC}"
}

# Execute main function
main "$@"
