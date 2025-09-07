# 🚀 Shared Services Layer Variables
# Configuration variables for Kubernetes shared services deployment

# 🔧 CORE CPTWN CONFIGURATION
variable "project_name" {
  description = "Name of the CPTWN project"
  type        = string
  default     = "cptwn-eks-01"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "af-south-1"
}

# 📊 TERRAFORM STATE CONFIGURATION
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform remote state"
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region where Terraform state bucket is located"
  type        = string
  default     = "af-south-1"
}

# 🎛️ SHARED SERVICES CONFIGURATION
variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler deployment"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller deployment"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable metrics server deployment"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external DNS controller deployment"
  type        = bool
  default     = false
}

# 📦 SERVICE VERSIONS
variable "cluster_autoscaler_version" {
  description = "Version of cluster autoscaler Helm chart"
  type        = string
  default     = "9.37.0"
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_version" {
  description = "Version of metrics server Helm chart"
  type        = string
  default     = "3.12.1"
}

# 🌐 DNS CONFIGURATION
variable "dns_zone_ids" {
  description = "List of Route 53 hosted zone IDs for external DNS"
  type        = list(string)
  default     = []
}

# 🔐 CLUSTER AUTOSCALER CONFIGURATION
variable "cluster_autoscaler_scale_down_enabled" {
  description = "Enable scale down for cluster autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  description = "How long after scale up that scale down evaluation resumes"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "How long a node should be unneeded before it is eligible for scale down"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_skip_nodes_with_local_storage" {
  description = "Skip nodes with local storage for scale down"
  type        = bool
  default     = false
}

# 🏷️ ADDITIONAL TAGS
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
