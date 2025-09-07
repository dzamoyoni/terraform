# Outputs for Cluster Autoscaler Module

output "iam_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "service_account_name" {
  description = "Name of the cluster autoscaler service account"
  value       = kubernetes_service_account.cluster_autoscaler.metadata[0].name
}

output "service_account_namespace" {
  description = "Namespace of the cluster autoscaler service account"
  value       = kubernetes_service_account.cluster_autoscaler.metadata[0].namespace
}
