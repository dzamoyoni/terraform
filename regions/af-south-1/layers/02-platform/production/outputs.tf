# 🏗️ Platform Layer Outputs - AF-South-1 Production
# Outputs from CPTWN EKS cluster wrapper module

# ☸️ EKS PLATFORM OUTPUTS - From Multi-Region Wrapper
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_platform.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_platform.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_platform.cluster_endpoint
  sensitive   = false
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks_platform.cluster_version
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks_platform.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_platform.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks_platform.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks_platform.oidc_provider_arn
}

# 👥 NODE GROUPS OUTPUTS
output "eks_managed_node_groups" {
  description = "Map of EKS managed node group information"
  value       = module.eks_platform.eks_managed_node_groups
}

# 🔐 SECURITY OUTPUTS
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_platform.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS node groups"
  value       = module.eks_platform.node_security_group_id
}

# 📊 PLATFORM SUMMARY - Enhanced with Standards
output "platform_summary" {
  description = "Comprehensive platform summary with standards applied"
  value       = module.eks_platform.platform_summary
}

# 🚨 SECURITY NOTICE - Enhanced with Best Practices
output "security_notice" {
  description = "Security notice with deployment guidance"
  value       = module.eks_platform.security_notice
}
