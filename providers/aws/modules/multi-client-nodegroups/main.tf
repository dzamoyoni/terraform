# Multi-Client EKS NodeGroups Module
# Supports isolated auto-scaling nodegroups per client with proper taints/tolerations

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_vpc" "cluster_vpc" {
  id = var.vpc_id
}

# Security group for node group remote access
resource "aws_security_group" "node_group_sg" {
  name_prefix = "${var.cluster_name}-nodegroup-sg"
  description = "Security group for EKS node group remote access"
  vpc_id      = var.vpc_id

  # SSH access from VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.cluster_vpc.cidr_block]
    description = "SSH access from VPC"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-nodegroup-sg"
    Environment = var.environment
    Cluster     = var.cluster_name
  }
}

# Shared IAM role for all client nodegroups
resource "aws_iam_role" "node_group_role" {
  name = "${var.cluster_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    Name        = "${var.cluster_name}-nodegroup-role"
    Environment = var.environment
    Cluster     = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

# Launch template for advanced configurations (prefix delegation, etc.)
resource "aws_launch_template" "client_nodegroup" {
  for_each = {
    for k, v in var.client_nodegroups : k => v
    if v.use_launch_template || v.enable_prefix_delegation
  }

  name_prefix = "${var.cluster_name}-${each.key}-"
  
  # SSH key configuration for launch template
  key_name = var.ec2_key_name

  vpc_security_group_ids = [aws_security_group.node_group_sg.id]
  
  # User data for prefix delegation and advanced configurations
  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    cluster_name                = var.cluster_name
    cluster_endpoint           = data.aws_eks_cluster.cluster.endpoint
    cluster_ca                 = data.aws_eks_cluster.cluster.certificate_authority[0].data
    enable_prefix_delegation   = each.value.enable_prefix_delegation
    max_pods                   = each.value.max_pods_per_node
    bootstrap_extra_args       = each.value.bootstrap_extra_args
  }))

  # Enhanced security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags = "enabled"
  }

  # EBS optimization
  ebs_optimized = true

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type          = "gp3"
      iops                 = 3000
      throughput           = 125
      encrypted            = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name        = "${var.cluster_name}-${each.key}-enhanced"
      Environment = var.environment
      Client      = each.key
      Feature     = "ip-optimization"
      }, each.value.extra_tags)
  }

  tags = {
    Name        = "${var.cluster_name}-${each.key}-template"
    Environment = var.environment
    Client      = each.key
    Feature     = "ip-optimization"
  }
}

# Client-specific nodegroups
resource "aws_eks_node_group" "client_nodegroups" {
  for_each = var.client_nodegroups

  cluster_name    = data.aws_eks_cluster.cluster.name
  node_group_name = "${each.key}-nodegroup"
  node_role_arn   = aws_iam_role.node_group_role.arn
  
  # Use dedicated subnets if provided, otherwise fall back to shared subnets
  subnet_ids = length(each.value.dedicated_subnet_ids) > 0 ? each.value.dedicated_subnet_ids : var.private_subnets

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable_percentage = each.value.max_unavailable_percentage
  }

  # Use launch template if advanced features are enabled
  dynamic "launch_template" {
    for_each = (each.value.use_launch_template || each.value.enable_prefix_delegation) ? [1] : []
    content {
      id      = aws_launch_template.client_nodegroup[each.key].id
      version = "$Latest"
    }
  }

  # Client-specific labels
  labels = merge(
    {
      client             = each.key
      environment        = var.environment
      tier               = each.value.tier
      workload           = each.value.workload
      performance        = each.value.performance
      instance_lifecycle = each.value.capacity_type == "SPOT" ? "spot" : "on-demand"
      managed_by         = "terraform"
    },
    each.value.extra_labels
  )

  # Client isolation taint - only applied if explicitly enabled via custom_taints
  # The enable_client_isolation flag only controls labels, not taints
  # Use custom_taints to add NO_SCHEDULE taints if needed

  # Additional custom taints
  dynamic "taint" {
    for_each = each.value.custom_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # SSH access configuration (only when NOT using launch template)
  dynamic "remote_access" {
    for_each = var.ec2_key_name != null && !(each.value.use_launch_template || each.value.enable_prefix_delegation) ? [1] : []
    content {
      ec2_ssh_key               = var.ec2_key_name
      source_security_group_ids = [aws_security_group.node_group_sg.id]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(
    {
      Name         = "${var.cluster_name}-${each.key}-nodegroup"
      Environment  = var.environment
      Client       = each.key
      Tier         = each.value.tier
      CostCenter   = "${each.key}-${var.environment}"
      Workload     = each.value.workload
      InstanceType = each.value.capacity_type
      ManagedBy    = "terraform"
      # Cluster Autoscaler tags
      "k8s.io/cluster-autoscaler/enabled"            = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    },
    each.value.extra_tags
  )
}

# Shared system nodegroup for cluster system workloads (no taints)
# resource "aws_eks_node_group" "system_nodegroup" {
#   count = var.enable_system_nodegroup ? 1 : 0

#   cluster_name    = data.aws_eks_cluster.cluster.name
#   node_group_name = "system-nodegroup"
#   node_role_arn   = aws_iam_role.node_group_role.arn
#   subnet_ids      = var.private_subnets

#   capacity_type  = var.system_nodegroup.capacity_type
#   instance_types = var.system_nodegroup.instance_types

#   scaling_config {
#     desired_size = var.system_nodegroup.desired_size
#     max_size     = var.system_nodegroup.max_size
#     min_size     = var.system_nodegroup.min_size
#   }

#   update_config {
#     max_unavailable_percentage = 25
#   }

#   labels = {
#     client             = "system"
#     environment        = var.environment
#     tier               = "system"
#     workload           = "cluster-system"
#     performance        = "standard"
#     instance_lifecycle = var.system_nodegroup.capacity_type == "SPOT" ? "spot" : "on-demand"
#     managed_by         = "terraform"
#   }

#   # SSH access configuration
#   dynamic "remote_access" {
#     for_each = var.ec2_key_name != null ? [1] : []
#     content {
#       ec2_ssh_key               = var.ec2_key_name
#       source_security_group_ids = [aws_security_group.node_group_sg.id]
#     }
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
#   ]

#   tags = {
#     Name         = "${var.cluster_name}-system-nodegroup"
#     Environment  = var.environment
#     Client       = "system"
#     Tier         = "system"
#     CostCenter   = "cluster-system"
#     Workload     = "cluster-system"
#     InstanceType = var.system_nodegroup.capacity_type
#     ManagedBy    = "terraform"
#   }
# }
