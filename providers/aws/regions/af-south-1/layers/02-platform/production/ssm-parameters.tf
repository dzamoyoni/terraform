# ============================================================================
# 🔧 SSM Parameters - Platform Layer Outputs
# ============================================================================
# Store EKS cluster information in SSM parameters for consumption by 
# downstream layers like observability, service mesh, and application layers
# ============================================================================

# ============================================================================
# EKS Cluster Information Parameters
# ============================================================================

resource "aws_ssm_parameter" "cluster_name" {
  name        = "/cptwn-multi-client-eks/${var.environment}/${var.region}/platform/cluster-name"
  description = "EKS Cluster name for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.cluster_name

  tags = {
    Name            = "EKS-Cluster-Name"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name        = "/cptwn-multi-client-eks/${var.environment}/${var.region}/platform/cluster-endpoint"
  description = "EKS Cluster API endpoint for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.cluster_endpoint

  tags = {
    Name            = "EKS-Cluster-Endpoint"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "cluster_certificate_authority_data" {
  name        = "/cptwn-multi-client-eks/${var.environment}/${var.region}/platform/cluster-certificate-authority-data"
  description = "EKS Cluster certificate authority data for ${var.environment} environment in ${var.region}"
  type        = "SecureString"
  value       = module.eks_platform.cluster_certificate_authority_data

  tags = {
    Name            = "EKS-Cluster-CA-Data"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "High"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "cluster_oidc_issuer_arn" {
  name        = "/cptwn-multi-client-eks/${var.environment}/${var.region}/platform/cluster-oidc-issuer-arn"
  description = "EKS Cluster OIDC issuer ARN for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.oidc_provider_arn

  tags = {
    Name            = "EKS-OIDC-Issuer-ARN"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

# ============================================================================
# Additional Cluster Information (Optional but useful for future layers)
# ============================================================================

resource "aws_ssm_parameter" "cluster_arn" {
  name        = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-arn"
  description = "EKS Cluster ARN for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.cluster_arn

  tags = {
    Name            = "EKS-Cluster-ARN"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "cluster_security_group_id" {
  name        = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-security-group-id"
  description = "EKS Cluster security group ID for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.cluster_security_group_id

  tags = {
    Name            = "EKS-Cluster-SG-ID"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "node_security_group_id" {
  name        = "/${var.project_name}/${var.environment}/${var.region}/platform/node-security-group-id"
  description = "EKS Node group security group ID for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.node_security_group_id

  tags = {
    Name            = "EKS-Node-SG-ID"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Medium"
    DeploymentPhase = "Phase-2"
  }
}

resource "aws_ssm_parameter" "cluster_version" {
  name        = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-version"
  description = "EKS Cluster version for ${var.environment} environment in ${var.region}"
  type        = "String"
  value       = module.eks_platform.cluster_version

  tags = {
    Name            = "EKS-Cluster-Version"
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Layer           = "Platform"
    ResourceType    = "SSM-Parameter"
    Region          = var.region
    DataType        = "cluster-info"
    SecurityLevel   = "Low"
    DeploymentPhase = "Phase-2"
  }
}

# ============================================================================
# Note: Output definitions moved to outputs.tf to avoid duplication
# ============================================================================
