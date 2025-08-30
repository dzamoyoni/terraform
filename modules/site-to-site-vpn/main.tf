# 🔗 Site-to-Site VPN Module - Secure On-Premises Connectivity
# Provides secure IPsec VPN connection to on-premises infrastructure

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 🏢 CUSTOMER GATEWAY - On-Premises Side
resource "aws_customer_gateway" "main" {
  count = var.enabled ? 1 : 0
  
  bgp_asn    = var.bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-customer-gateway-${var.region}"
    Purpose = "Customer Gateway for Site-to-Site VPN"
    Layer   = "Foundation"
    Type    = "CustomerGateway"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 🌐 VIRTUAL PRIVATE GATEWAY - AWS Side  
resource "aws_vpn_gateway" "main" {
  count = var.enabled ? 1 : 0
  
  vpc_id          = var.vpc_id
  amazon_side_asn = var.amazon_side_asn
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-vpn-gateway-${var.region}"
    Purpose = "Virtual Private Gateway for Site-to-Site VPN"
    Layer   = "Foundation"
    Type    = "VPNGateway"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 🔗 VPN CONNECTION - IPsec Tunnels
resource "aws_vpn_connection" "main" {
  count = var.enabled ? 1 : 0
  
  customer_gateway_id   = aws_customer_gateway.main[0].id
  vpn_gateway_id       = aws_vpn_gateway.main[0].id
  type                 = "ipsec.1"
  static_routes_only   = var.static_routes_only
  
  # Tunnel 1 Configuration
  tunnel1_inside_cidr      = var.tunnel1_inside_cidr
  tunnel1_preshared_key    = var.tunnel1_preshared_key
  tunnel1_dpd_timeout_action = "restart"
  tunnel1_dpd_timeout_seconds = 30
  tunnel1_ike_versions     = ["ikev2"]
  tunnel1_startup_action   = "start"
  
  # Tunnel 2 Configuration  
  tunnel2_inside_cidr      = var.tunnel2_inside_cidr
  tunnel2_preshared_key    = var.tunnel2_preshared_key
  tunnel2_dpd_timeout_action = "restart"
  tunnel2_dpd_timeout_seconds = 30
  tunnel2_ike_versions     = ["ikev2"]
  tunnel2_startup_action   = "start"
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-vpn-connection-${var.region}"
    Purpose = "Site-to-Site VPN Connection"
    Layer   = "Foundation"
    Type    = "VPNConnection"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 📋 VPN CONNECTION ROUTE - Static Routes (if enabled)
resource "aws_vpn_connection_route" "onprem" {
  count = var.enabled && var.static_routes_only ? length(var.onprem_cidr_blocks) : 0
  
  vpn_connection_id      = aws_vpn_connection.main[0].id
  destination_cidr_block = var.onprem_cidr_blocks[count.index]
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 📋 VPN GATEWAY ROUTE PROPAGATION - For Platform Subnets
resource "aws_vpn_gateway_route_propagation" "platform" {
  count = var.enabled && !var.static_routes_only ? length(var.platform_route_table_ids) : 0
  
  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = var.platform_route_table_ids[count.index]
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 📋 VPN GATEWAY ROUTE PROPAGATION - For Client Route Tables
resource "aws_vpn_gateway_route_propagation" "clients" {
  count = var.enabled && !var.static_routes_only ? length(var.client_route_table_ids) : 0
  
  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = var.client_route_table_ids[count.index]
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 📊 CLOUDWATCH LOG GROUP for VPN Connection Logs
resource "aws_cloudwatch_log_group" "vpn" {
  count = var.enabled && var.enable_vpn_logging ? 1 : 0
  
  name              = "/aws/vpn/${var.project_name}-${var.region}"
  retention_in_days = var.vpn_log_retention_days
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-vpn-logs"
    Purpose = "VPN Connection Logs"
    Layer   = "Foundation"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# 🚨 CLOUDWATCH ALARMS for VPN Monitoring
resource "aws_cloudwatch_metric_alarm" "vpn_tunnel_1_state" {
  count = var.enabled ? 1 : 0
  
  alarm_name          = "${var.project_name}-vpn-tunnel-1-state"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors VPN tunnel 1 state"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    VpnId    = var.enabled ? aws_vpn_connection.main[0].id : ""
    TunnelIpAddress = var.enabled ? aws_vpn_connection.main[0].tunnel1_address : ""
  }
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-vpn-tunnel-1-alarm"
    Purpose = "VPN Tunnel 1 Monitoring"
    Layer   = "Foundation"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_cloudwatch_metric_alarm" "vpn_tunnel_2_state" {
  count = var.enabled ? 1 : 0
  
  alarm_name          = "${var.project_name}-vpn-tunnel-2-state"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors VPN tunnel 2 state"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    VpnId    = var.enabled ? aws_vpn_connection.main[0].id : ""
    TunnelIpAddress = var.enabled ? aws_vpn_connection.main[0].tunnel2_address : ""
  }
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-vpn-tunnel-2-alarm"
    Purpose = "VPN Tunnel 2 Monitoring"
    Layer   = "Foundation"
  })
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}
