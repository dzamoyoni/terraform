# ============================================================================
# IP EXPANSION: Secondary CIDR Block and Subnets (SAFE ADDITION)
# ============================================================================
# This file adds IP capacity without modifying existing infrastructure
# - Secondary CIDR block (10.0.0.0/16) - 65,536 additional IPs
# - New private subnets for high-density workloads
# - New public subnets for load balancers
# - SSM parameters for other layers to use
# ============================================================================

# Get existing VPC (safe reference)
data "aws_vpc" "existing_vpc" {
  id = var.existing_vpc_id
}

# Get existing NAT gateway for routing
data "aws_nat_gateways" "existing" {
  vpc_id = var.existing_vpc_id
}

data "aws_nat_gateway" "existing_nat" {
  count = length(data.aws_nat_gateways.existing.ids) > 0 ? 1 : 0
  id    = data.aws_nat_gateways.existing.ids[0]
}

# Get existing Internet Gateway for routing
data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.existing_vpc_id]
  }
}

# ============================================================================
# Secondary CIDR Block (NON-DISRUPTIVE)
# ============================================================================

# Add secondary CIDR block to existing VPC
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = var.existing_vpc_id
  cidr_block = "172.21.0.0/16"  # Adds 65,536 additional IPs (compatible with 172.20.0.0/16)

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# ============================================================================
# Secondary Private Subnets (High-Density Workloads)
# ============================================================================

# Create new private subnets in secondary CIDR space
resource "aws_subnet" "secondary_private" {
  count = length(var.availability_zones)

  vpc_id            = var.existing_vpc_id
  cidr_block        = "172.21.${count.index * 4}.0/22"  # 1,022 IPs per subnet (172.21.0.0/22, 172.21.4.0/22)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-secondary-private-${count.index + 1}"
    Environment                                 = var.environment
    Type                                        = "private-secondary"
    Purpose                                     = "high-density-workloads"
    ManagedBy                                   = "terraform"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

# Route table for secondary private subnets
resource "aws_route_table" "secondary_private" {
  count  = length(aws_subnet.secondary_private)
  vpc_id = var.existing_vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = length(data.aws_nat_gateway.existing_nat) > 0 ? data.aws_nat_gateway.existing_nat[0].id : null
  }

  tags = {
    Name        = "${var.cluster_name}-secondary-private-rt-${count.index + 1}"
    Environment = var.environment
    Type        = "private-secondary"
    ManagedBy   = "terraform"
  }
}

# Associate route tables with secondary private subnets
resource "aws_route_table_association" "secondary_private" {
  count          = length(aws_subnet.secondary_private)
  subnet_id      = aws_subnet.secondary_private[count.index].id
  route_table_id = aws_route_table.secondary_private[count.index].id
}

# ============================================================================
# Secondary Public Subnets (Load Balancers)
# ============================================================================

# Create new public subnets in secondary CIDR space
resource "aws_subnet" "secondary_public" {
  count = length(var.availability_zones)

  vpc_id                  = var.existing_vpc_id
  cidr_block              = "172.21.${count.index + 101}.0/24"  # 254 IPs per subnet (172.21.101.0/24, 172.21.102.0/24)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-secondary-public-${count.index + 1}"
    Environment                                 = var.environment
    Type                                        = "public-secondary"
    Purpose                                     = "load-balancers"
    ManagedBy                                   = "terraform"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

# Route table for secondary public subnets
resource "aws_route_table" "secondary_public" {
  vpc_id = var.existing_vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }

  tags = {
    Name        = "${var.cluster_name}-secondary-public-rt"
    Environment = var.environment
    Type        = "public-secondary"
    ManagedBy   = "terraform"
  }
}

# Associate route table with secondary public subnets
resource "aws_route_table_association" "secondary_public" {
  count          = length(aws_subnet.secondary_public)
  subnet_id      = aws_subnet.secondary_public[count.index].id
  route_table_id = aws_route_table.secondary_public.id
}

# ============================================================================
# SSM Parameters for Secondary Subnets (Cross-Layer Communication)
# ============================================================================

# Store secondary private subnets for use by client layer
resource "aws_ssm_parameter" "secondary_private_subnets" {
  name  = "/${var.environment}/${var.aws_region}/foundation/secondary_private_subnets"
  type  = "String"
  value = join(",", aws_subnet.secondary_private[*].id)

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    Purpose     = "ip-expansion"
    ManagedBy  = "terraform"
  }

  depends_on = [aws_subnet.secondary_private]
}

# Store secondary public subnets
resource "aws_ssm_parameter" "secondary_public_subnets" {
  name  = "/${var.environment}/${var.aws_region}/foundation/secondary_public_subnets"
  type  = "String"
  value = join(",", aws_subnet.secondary_public[*].id)

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    Purpose     = "ip-expansion"
    ManagedBy  = "terraform"
  }

  depends_on = [aws_subnet.secondary_public]
}

# Store secondary CIDR block info
resource "aws_ssm_parameter" "secondary_cidr_block" {
  name  = "/${var.environment}/${var.aws_region}/foundation/secondary_cidr_block"
  type  = "String"
  value = "172.21.0.0/16"

  tags = {
    Environment = var.environment
    Layer      = "foundation"
    Purpose     = "ip-expansion"
    ManagedBy  = "terraform"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}
