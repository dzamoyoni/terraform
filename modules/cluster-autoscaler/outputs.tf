output "iam_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "service_account_name" {
  description = "Name of the cluster autoscaler service account"
  value       = kubernetes_service_account.cluster_autoscaler.metadata[0].name
}

output "deployment_name" {
  description = "Name of the cluster autoscaler deployment"
  value       = kubernetes_deployment.cluster_autoscaler.metadata[0].name
}
