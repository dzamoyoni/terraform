# Variables for Shared Services Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "URL of the OIDC issuer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable metrics server"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external DNS"
  type        = bool
  default     = false
}

variable "cluster_autoscaler_version" {
  description = "Version of cluster autoscaler"
  type        = string
  default     = "9.37.0"
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller"
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_version" {
  description = "Version of metrics server"
  type        = string
  default     = "3.12.1"
}

variable "dns_zone_ids" {
  description = "DNS zone IDs"
  type        = list(string)
  default     = []
}

variable "cluster_autoscaler_scale_down_enabled" {
  description = "Enable scale down for cluster autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  description = "Scale down delay after add"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "Scale down unneeded time"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_skip_nodes_with_local_storage" {
  description = "Skip nodes with local storage"
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
