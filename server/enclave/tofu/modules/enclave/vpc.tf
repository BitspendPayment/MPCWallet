# VPC + networking (remote only — skipped for localstack).

resource "aws_vpc" "main" {
  count = var.local ? 0 : 1

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.prefix}-vpc" }
}

# Public subnet (for EC2 instance with EIP).
resource "aws_subnet" "public" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.az_a

  tags = { Name = "${local.prefix}-public" }
}

# Private subnet (for VPC endpoints and NAT egress).
resource "aws_subnet" "private" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.az_a

  tags = { Name = "${local.prefix}-private" }
}

# Second private subnet in AZ-b (some services require multi-AZ).
resource "aws_subnet" "private_b" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.3.0/24"
  availability_zone = local.az_b

  tags = { Name = "${local.prefix}-private-b" }
}

# Internet gateway for public subnet.
resource "aws_internet_gateway" "main" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  tags = { Name = "${local.prefix}-igw" }
}

# NAT gateway for private subnet egress.
resource "aws_eip" "nat" {
  count  = var.local ? 0 : 1
  domain = "vpc"

  tags = { Name = "${local.prefix}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count = var.local ? 0 : 1

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = "${local.prefix}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# Route tables.
resource "aws_route_table" "public" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = { Name = "${local.prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = { Name = "${local.prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_b" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.private_b[0].id
  route_table_id = aws_route_table.private[0].id
}

# VPC endpoints — keep traffic to AWS services inside the VPC.
#
# Single-AZ on purpose: the Nitro parent instance is placed in public[0] /
# private[0] (AZ-a only), so adding an endpoint ENI in AZ-b would be paid-for
# capacity no traffic can reach. private_b exists only so resources that
# require a multi-AZ subnet group (future RDS, ALB, etc.) can be added without
# an apply-time VPC redesign. If the parent instance ever becomes multi-AZ,
# add aws_subnet.private_b[0].id back to subnet_ids below.
resource "aws_vpc_endpoint" "kms" {
  count = var.local ? 0 : 1

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[0].id]
  security_group_ids  = [aws_security_group.nitro[0].id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-kms-endpoint" }
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.local ? 0 : 1

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[0].id]
  security_group_ids  = [aws_security_group.nitro[0].id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-ssm-endpoint" }
}

resource "aws_vpc_endpoint" "s3" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public[0].id, aws_route_table.private[0].id]

  tags = { Name = "${local.prefix}-s3-endpoint" }
}
