output "helm_release_name" {
  description = "Name of the Helm release for AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release for AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.namespace
}

output "alb_ingress_class_name" {
  description = "Name of the ALB IngressClass (created by Helm chart)"
  value       = "alb"
}

