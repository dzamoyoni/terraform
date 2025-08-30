variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Existing cluster security group ID to use (for import scenarios)"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of existing KMS key for cluster encryption (for import scenarios)"
  type        = string
  default     = null
}

variable "cluster_iam_role_arn" {
  description = "ARN of existing IAM role for the cluster (for import scenarios)"
  type        = string
  default     = null
}
