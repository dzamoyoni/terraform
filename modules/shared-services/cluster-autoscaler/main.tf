# 🔄 Cluster Autoscaler Module
# Deploys and configures cluster autoscaler for EKS with CPTWN standards

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
  }
}

# 📊 DATA SOURCES
data "aws_caller_identity" "current" {}

# 🔐 IAM ROLE FOR CLUSTER AUTOSCALER
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:${var.service_account_name}"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name    = "${var.cluster_name}-cluster-autoscaler-role"
    Purpose = "Cluster Autoscaler IRSA Role"
  })
}

# 📋 IAM POLICY FOR CLUSTER AUTOSCALER
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "Policy for cluster autoscaler to manage ASG scaling"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name    = "${var.cluster_name}-cluster-autoscaler-policy"
    Purpose = "Cluster Autoscaler IAM Policy"
  })
}

# 🔗 ATTACH POLICY TO ROLE
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# 🔧 KUBERNETES SERVICE ACCOUNT
resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = var.service_account_name
    namespace = "kube-system"
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
    }
    
    labels = {
      "app.kubernetes.io/name"       = "cluster-autoscaler"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/part-of"    = var.cluster_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# 🎡 HELM RELEASE FOR CLUSTER AUTOSCALER
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.helm_chart_version
  namespace  = "kube-system"
  
  # Core configuration
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "awsRegion"
    value = var.region
  }
  
  # Service account configuration
  set {
    name  = "serviceAccount.create"
    value = "false"  # We create our own with IRSA
  }
  
  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }
  
  # Scaling behavior
  set {
    name  = "extraArgs.scale-down-enabled"
    value = var.scale_down_enabled
  }
  
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = var.scale_down_delay_after_add
  }
  
  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = var.scale_down_unneeded_time
  }
  
  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = var.skip_nodes_with_local_storage
  }
  
  # Resource management
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  
  set {
    name  = "resources.requests.memory"
    value = "300Mi"
  }
  
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }
  
  set {
    name  = "resources.limits.memory"
    value = "300Mi"
  }
  
  # Security context
  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "securityContext.runAsUser"
    value = "65534"
  }
  
  # Node selection for stability
  set {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  
  # Tolerations for system workloads
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
  
  # Priority class for system workloads
  set {
    name  = "priorityClassName"
    value = "system-cluster-critical"
  }
  
  depends_on = [
    kubernetes_service_account.cluster_autoscaler,
    aws_iam_role_policy_attachment.cluster_autoscaler
  ]
}
