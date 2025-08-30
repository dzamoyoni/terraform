# ============================================================================
# Platform Layer (02-platform/production)
# ============================================================================
# This layer contains the EKS cluster and shared platform services that are
# used across multiple clients and applications.
#
# Dependencies:
# - 01-foundation layer (VPC, networking, security groups)
#
# Manages:
# - EKS cluster
# - EBS CSI driver and IRSA
# - AWS Load Balancer Controller and IRSA
# - Route53 DNS zones
# - External DNS and IRSA  
# - Ingress classes
# - Istio Service Mesh (optional)
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via -backend-config
    # This allows the same configuration to work across environments
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Layer        = "platform"
      ManagedBy    = "terraform"
      Repository   = "infrastructure"
    }
  }
}

# Foundation Layer Data Sources
# Get foundation layer outputs from SSM parameters
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/${var.environment}/foundation/vpc_id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/terraform/${var.environment}/foundation/private_subnets"
}

data "aws_ssm_parameter" "public_subnets" {
  name = "/terraform/${var.environment}/foundation/public_subnets"
}

data "aws_ssm_parameter" "vpc_cidr" {
  name = "/terraform/${var.environment}/foundation/vpc_cidr"
}

# Check that foundation layer is deployed
data "aws_ssm_parameter" "foundation_deployed" {
  name = "/terraform/${var.environment}/foundation/deployed"
}

locals {
  # Use foundation layer outputs via SSM parameters
  vpc_id          = data.aws_ssm_parameter.vpc_id.value
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
  public_subnets  = split(",", data.aws_ssm_parameter.public_subnets.value)
  vpc_cidr        = data.aws_ssm_parameter.vpc_cidr.value
  
  # Validation that foundation layer is properly deployed
  foundation_deployed = data.aws_ssm_parameter.foundation_deployed.value == "true" ? true : false
  
  # Existing cluster resource identifiers (for import/migration)
  cluster_security_group_id = "sg-014caac5c31fbc765"
  kms_key_arn              = "arn:aws:kms:us-east-1:101886104835:key/9a28c9ff-4a0f-4c19-b098-75ddf95d3da8"
  cluster_iam_role_arn     = "arn:aws:iam::101886104835:role/us-test-cluster-01-cluster-20250811104445757200000003"
}

# ============================================================================
# EKS Cluster
# ============================================================================

module "eks" {
  source          = "../../../../../modules/eks-cluster"
  cluster_name    = var.cluster_name
  vpc_id          = local.vpc_id
  private_subnets = local.private_subnets
  
  # Pass existing resource identifiers for import/migration
  cluster_security_group_id = local.cluster_security_group_id
  kms_key_arn              = local.kms_key_arn
  cluster_iam_role_arn     = local.cluster_iam_role_arn
}

# ============================================================================
# EBS CSI Driver
# ============================================================================

module "ebs_csi_irsa" {
  source       = "../../../../../modules/ebs-csi-irsa"
  cluster_name = var.cluster_name

  depends_on = [module.eks]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_id
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn

  depends_on = [module.eks, module.ebs_csi_irsa]
}

# ============================================================================
# AWS Load Balancer Controller
# ============================================================================

module "aws_load_balancer_controller_irsa" {
  source       = "../../../../../modules/aws-load-balancer-controller-irsa"
  cluster_name = var.cluster_name

  depends_on = [module.eks]
}

# Configure Kubernetes and Helm providers
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
    }
  }
}

module "aws_load_balancer_controller" {
  source = "../../../../../modules/aws-load-balancer-controller"

  cluster_name             = var.cluster_name
  vpc_id                   = local.vpc_id
  service_account_role_arn = module.aws_load_balancer_controller_irsa.iam_role_arn

  depends_on = [module.eks, module.aws_load_balancer_controller_irsa]
}

# ============================================================================
# Route53 DNS Zones
# ============================================================================

module "route53_zones" {
  source = "../../../../../modules/route53-zones"

  hosted_zones = var.dns_zones

  tags = {
    Environment = var.environment
    Cluster     = var.cluster_name
    Layer       = "platform"
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# External DNS
# ============================================================================

module "external_dns_irsa" {
  count  = var.enable_external_dns ? 1 : 0
  source = "../../../../../modules/external-dns-irsa"

  cluster_name      = var.cluster_name
  route53_zone_arns = module.route53_zones.zone_arns_list

  depends_on = [module.eks, module.route53_zones]
}

module "external_dns" {
  count  = var.enable_external_dns ? 1 : 0
  source = "../../../../../modules/external-dns"

  cluster_name             = var.cluster_name
  service_account_role_arn = module.external_dns_irsa[0].iam_role_arn
  domain_filters           = keys(var.dns_zones)
  
  # Use sync policy for robust DNS record management
  policy = "sync"

  depends_on = [module.eks, module.external_dns_irsa]
}

# ============================================================================
# Ingress Classes
# ============================================================================

module "ingress_classes" {
  source = "../../../../../modules/ingress-class"
  
  # ALB IngressClass (default)
  alb_ingress_class_name = var.alb_ingress_class_name
  set_as_default         = var.set_alb_as_default
  
  # Optional: Create NLB IngressClass
  create_nlb_ingress_class = var.create_nlb_ingress_class
  nlb_ingress_class_name   = var.nlb_ingress_class_name
  nlb_scheme               = var.nlb_scheme
  
  # Optional: Create nginx IngressClass for internal services
  create_nginx_ingress_class = var.create_nginx_ingress_class
  nginx_ingress_class_name   = var.nginx_ingress_class_name
  
  depends_on = [module.aws_load_balancer_controller]
}

# ============================================================================
# Istio Service Mesh
# ============================================================================

module "istio" {
  count  = var.enable_istio ? 1 : 0
  source = "../../../../../modules/istio"
  
  cluster_name               = var.cluster_name
  istio_version             = var.istio_version
  enable_ambient_mode       = var.istio_ambient_mode
  enable_ingress_gateway    = var.istio_ingress_gateway
  enable_egress_gateway     = var.istio_egress_gateway
  ingress_gateway_type      = var.istio_ingress_gateway_type
  enable_monitoring         = var.istio_monitoring
  ambient_namespaces        = var.istio_ambient_namespaces
  
  # Resource configuration for production workloads
  istiod_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
  
  gateway_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "2000m"
      memory = "2Gi"
    }
  }
  
  gateway_autoscaling = {
    enabled      = true
    min_replicas = 2
    max_replicas = 10
    target_cpu   = 70
  }
  
  common_tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
  
  depends_on = [
    module.eks,
    module.aws_load_balancer_controller
  ]
}

# ============================================================================
# Store platform layer outputs in SSM for other layers to consume
# ============================================================================

resource "aws_ssm_parameter" "cluster_id" {
  name  = "/terraform/${var.environment}/platform/cluster_id"
  type  = "String"
  value = module.eks.cluster_id

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/terraform/${var.environment}/platform/cluster_endpoint"
  type  = "String"
  value = module.eks.cluster_endpoint

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "cluster_ca_certificate" {
  name  = "/terraform/${var.environment}/platform/cluster_ca_certificate"
  type  = "SecureString"
  value = module.eks.cluster_certificate_authority_data

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "oidc_provider_arn" {
  name  = "/terraform/${var.environment}/platform/oidc_provider_arn"
  type  = "String"
  value = module.eks.oidc_provider_arn

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "route53_zone_ids" {
  name  = "/terraform/${var.environment}/platform/route53_zone_ids"
  type  = "String"
  value = jsonencode(module.route53_zones.hosted_zone_ids)

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

# ============================================================================
# Istio SSM Parameters
# ============================================================================

resource "aws_ssm_parameter" "istio_enabled" {
  name  = "/terraform/${var.environment}/platform/istio_enabled"
  type  = "String"
  value = var.enable_istio

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "istio_version" {
  count = var.enable_istio ? 1 : 0
  name  = "/terraform/${var.environment}/platform/istio_version"
  type  = "String"
  value = module.istio[0].istio_version

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "istio_namespace" {
  count = var.enable_istio ? 1 : 0
  name  = "/terraform/${var.environment}/platform/istio_namespace"
  type  = "String"
  value = module.istio[0].istio_namespace

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}

resource "aws_ssm_parameter" "istio_ingress_gateway_service" {
  count = var.enable_istio && var.istio_ingress_gateway ? 1 : 0
  name  = "/terraform/${var.environment}/platform/istio_ingress_gateway_service"
  type  = "String"
  value = module.istio[0].ingress_gateway_service_name

  tags = {
    Environment = var.environment
    Layer      = "platform"
    ManagedBy  = "terraform"
  }
}
