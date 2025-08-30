# ============================================================================
# Foundation Layer Variables (01-foundation/production)
# ============================================================================

# ============================================================================
# General Configuration
# ============================================================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name for the VPC and related resources"
  type        = string
  default     = "main-vpc"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (used for resource tagging)"
  type        = string
  default     = "us-test-cluster-01"
}

# ============================================================================
# VPC Configuration (from regional configs)
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.20.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["172.20.1.0/24", "172.20.2.0/24"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["172.20.101.0/24", "172.20.102.0/24"]
}

# ============================================================================
# NAT Gateway Configuration
# ============================================================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for outbound internet access from private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = true
}

# ============================================================================
# DNS Configuration
# ============================================================================

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

# ============================================================================
# VPC Flow Logs Configuration
# ============================================================================

variable "enable_flow_log" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}

variable "flow_log_destination_type" {
  description = "Type of flow log destination"
  type        = string
  default     = "cloud-watch-logs"
}

# ============================================================================
# VPN Configuration (from regional configs)
# ============================================================================

variable "enable_vpn" {
  description = "Enable VPN connections for client access"
  type        = bool
  default     = true
}

# ============================================================================
# Existing Infrastructure Configuration
# ============================================================================

variable "existing_vpc_id" {
  description = "ID of your existing VPC"
  type        = string
  default     = "vpc-0ec63df5e5566ea0c"
}

variable "existing_private_subnet_ids" {
  description = "List of your existing private subnet IDs"
  type        = list(string)
  default     = ["subnet-0a6936df3ff9a4f77", "subnet-0ec8a91aa274caea1"]
}

variable "existing_public_subnet_ids" {
  description = "List of your existing public subnet IDs"
  type        = list(string)
  default     = ["subnet-0b97065c0b7e66d5e", "subnet-067cb01bb4e3bb0e7"]
}

variable "existing_igw_id" {
  description = "ID of your existing Internet Gateway"
  type        = string
  default     = ""
}

variable "existing_nat_gateway_ids" {
  description = "List of your existing NAT Gateway IDs"
  type        = list(string)
  default     = []
}

variable "existing_vpn_gateway_id" {
  description = "ID of your existing VPN Gateway (if any)"
  type        = string
  default     = ""
}

# ============================================================================
# Security Group Configuration
# ============================================================================

variable "create_security_groups" {
  description = "Whether to create new security groups (false = use existing)"
  type        = bool
  default     = false
}

variable "existing_eks_cluster_sg_id" {
  description = "ID of your existing EKS cluster security group"
  type        = string
  default     = "sg-014caac5c31fbc765"  # From your platform layer
}

variable "existing_database_sg_id" {
  description = "ID of your existing database security group"
  type        = string
  default     = "sg-067bc5c25980da2cc"  # From your database layer
}

variable "existing_alb_sg_id" {
  description = "ID of your existing ALB security group"
  type        = string
  default     = "sg-0fc956334f67b2f64"  # From your database layer
}
