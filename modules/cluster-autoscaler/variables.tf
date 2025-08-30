variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (ARN format)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "autoscaler_version" {
  description = "Version of cluster autoscaler to deploy"
  type        = string
  default     = "v1.30.0"
}
