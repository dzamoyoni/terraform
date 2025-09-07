# 🏗️ Platform Layer Variables - AF-South-1 Production
# Variables for EKS cluster and platform services

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "af-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cptwn-eks-01"
}

# 🔐 Terraform State Configuration
variable "terraform_state_bucket" {
  description = "S3 bucket for terraform state"
  type        = string
  default     = "cptwn-terraform-state-ezra"
}

variable "terraform_state_region" {
  description = "AWS region for terraform state bucket"
  type        = string
  default     = "af-south-1"
}

# ☸️ EKS Cluster Configuration
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

# 🔐 Management Access
variable "management_cidr_blocks" {
  description = "CIDR blocks for management access"
  type        = list(string)
  default     = [
    "178.162.141.130/32",  # Primary management IP
    "165.90.14.138/32",    # Secondary management IP
    "41.72.206.78/32" ,
    "102.217.4.85/32"     # Your IP address for cluster access
  ]
}

# 🏢 Client Configuration
variable "enable_client_isolation" {
  description = "Enable client isolation features"
  type        = bool
  default     = true
}
