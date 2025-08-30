variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "service_account_name" {
  description = "Name of the service account for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "service_account_namespace" {
  description = "Namespace of the service account for AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "service_account_role_arn" {
  description = "IAM role ARN for the service account"
  type        = string
}

variable "chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.8.1"
}

variable "ecr_account_id" {
  description = "AWS ECR account ID for the Load Balancer Controller image"
  type        = string
  default     = "602401143452" # AWS public ECR account ID for af-south-1
}

variable "set_default_ingress_class" {
  description = "Whether to set ALB as the default ingress class"
  type        = bool
  default     = true
}
