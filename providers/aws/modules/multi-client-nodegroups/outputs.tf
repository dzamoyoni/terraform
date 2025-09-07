output "node_group_role_arn" {
  description = "ARN of the shared node group IAM role"
  value       = aws_iam_role.node_group_role.arn
}

output "node_group_role_name" {
  description = "Name of the shared node group IAM role"
  value       = aws_iam_role.node_group_role.name
}

output "security_group_id" {
  description = "Security group ID for node groups"
  value       = aws_security_group.node_group_sg.id
}

output "client_nodegroups" {
  description = "Map of client nodegroups with their details"
  value = {
    for client, nodegroup in aws_eks_node_group.client_nodegroups : client => {
      arn                = nodegroup.arn
      status             = nodegroup.status
      capacity_type      = nodegroup.capacity_type
      instance_types     = nodegroup.instance_types
      scaling_config     = nodegroup.scaling_config
      labels             = nodegroup.labels
      taints             = nodegroup.taint
      node_group_name    = nodegroup.node_group_name
      cost_center        = "${client}-${var.environment}"
    }
  }
}

# output "system_nodegroup" {
#   description = "Details of the system nodegroup"
#   value = var.enable_system_nodegroup ? {
#     arn             = aws_eks_node_group.system_nodegroup[0].arn
#     status          = aws_eks_node_group.system_nodegroup[0].status
#     capacity_type   = aws_eks_node_group.system_nodegroup[0].capacity_type
#     instance_types  = aws_eks_node_group.system_nodegroup[0].instance_types
#     scaling_config  = aws_eks_node_group.system_nodegroup[0].scaling_config
#     labels          = aws_eks_node_group.system_nodegroup[0].labels
#     node_group_name = aws_eks_node_group.system_nodegroup[0].node_group_name
#   } : null
# }

# output "nodegroup_summary" {
#   description = "Summary of all nodegroups for monitoring and cost allocation"
#   value = {
#     client_nodegroups = {
#       for client, nodegroup in aws_eks_node_group.client_nodegroups : client => {
#         min_nodes     = nodegroup.scaling_config[0].min_size
#         max_nodes     = nodegroup.scaling_config[0].max_size
#         desired_nodes = nodegroup.scaling_config[0].desired_size
#         instance_types = nodegroup.instance_types
#         capacity_type  = nodegroup.capacity_type
#         cost_center    = "${client}-${var.environment}"
#         isolation      = var.client_nodegroups[client].enable_client_isolation
#       }
#     }
#     system_nodegroup = var.enable_system_nodegroup ? {
#       min_nodes      = aws_eks_node_group.system_nodegroup[0].scaling_config[0].min_size
#       max_nodes      = aws_eks_node_group.system_nodegroup[0].scaling_config[0].max_size
#       desired_nodes  = aws_eks_node_group.system_nodegroup[0].scaling_config[0].desired_size
#       instance_types = aws_eks_node_group.system_nodegroup[0].instance_types
#       capacity_type  = aws_eks_node_group.system_nodegroup[0].capacity_type
#       cost_center    = "cluster-system"
#     } : null
#     total_clients = length(var.client_nodegroups)
#   }
# }
