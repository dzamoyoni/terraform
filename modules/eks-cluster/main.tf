module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"
  vpc_id          = var.vpc_id
  subnet_ids      = var.private_subnets

  # Match existing cluster configuration to avoid replacement
  bootstrap_self_managed_addons = false  # Match existing cluster
  
  # Enable IRSA (required for other modules)
  enable_irsa = true

  # Match existing cluster logging configuration
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = 90

  # Match existing cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Match existing cluster network configuration
  cluster_service_ipv4_cidr = "10.100.0.0/16"
  cluster_ip_family = "ipv4"

  # Match existing access configuration
  authentication_mode = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = false

  # Match existing upgrade policy - note: this might not be supported in module
  # cluster_upgrade_policy = {
  #   support_type = "EXTENDED"
  # }

  # Disable cluster addons here - will be managed separately
  cluster_addons = {}

  # Don't create new security groups - use existing ones
  create_cluster_security_group = false
  create_node_security_group = false
  cluster_security_group_id = var.cluster_security_group_id
  
  # Encryption configuration - use existing KMS key
  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  # Manage existing IAM role
  create_iam_role = false
  iam_role_arn    = var.cluster_iam_role_arn

  # Use existing KMS key
  create_kms_key = false
  kms_key_enable_default_policy = false
}
