# ============================================================================
# Platform Layer Outputs
# ============================================================================
# Outputs for the platform layer that can be consumed by other layers

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  description = "The security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "ID of the EKS node shared security group"
  value       = module.eks.cluster_security_group_id
}

# ============================================================================
# OIDC Provider Outputs
# ============================================================================

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  value       = module.eks.oidc_provider_url
}

# ============================================================================
# EBS CSI Driver Outputs
# ============================================================================

output "ebs_csi_driver_addon_version" {
  description = "Version of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi.addon_version
}

output "ebs_csi_irsa_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver IRSA"
  value       = module.ebs_csi_irsa.iam_role_arn
}

# ============================================================================
# AWS Load Balancer Controller Outputs
# ============================================================================

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller IRSA"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

# ============================================================================
# Route53 Outputs
# ============================================================================

output "route53_zone_ids" {
  description = "Map of hosted zone names to zone IDs"
  value       = module.route53_zones.hosted_zone_ids
}

output "route53_zone_arns" {
  description = "Map of hosted zone names to zone ARNs"
  value       = module.route53_zones.hosted_zone_arns
}

output "route53_name_servers" {
  description = "Map of hosted zone names to name servers"
  value       = module.route53_zones.hosted_zone_name_servers
}

# ============================================================================
# External DNS Outputs (conditional)
# ============================================================================

output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS IRSA"
  value       = var.enable_external_dns ? module.external_dns_irsa[0].iam_role_arn : null
}

# ============================================================================
# Foundation Layer Data (passed through for reference)
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC from foundation layer"
  value       = local.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs from foundation layer"
  value       = local.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs from foundation layer"
  value       = local.public_subnets
}

output "vpc_cidr" {
  description = "CIDR block of the VPC from foundation layer"
  value       = local.vpc_cidr
}
