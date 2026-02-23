# =============================================================================
# Public Subnet C (ALB에 최소 2 AZ 필요, AZ-a는 기존 data source 사용)
# =============================================================================

resource "aws_subnet" "public_c" {
  vpc_id                  = data.aws_vpc.prod.id
  cidr_block              = "10.0.48.0/20"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "qfeed-prod-subnet-public-c" })
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = data.aws_route_table.public.id
}

# =============================================================================
# NAT Gateway (private subnet → 인터넷)
# =============================================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "qfeed-prod-eip-nat" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.public_a.id

  tags = merge(local.common_tags, { Name = "qfeed-prod-natgw" })

  depends_on = [aws_eip.nat]
}

# =============================================================================
# Private-App Subnet (EC2: Backend, AI, Redis)
# =============================================================================

resource "aws_subnet" "private_app_a" {
  vpc_id            = data.aws_vpc.prod.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "ap-northeast-2a"

  tags = merge(local.common_tags, { Name = "qfeed-prod-subnet-private-app-a" })
}

# =============================================================================
# Private-Data Subnets (RDS — subnet group에 최소 2 AZ 필요)
# =============================================================================

resource "aws_subnet" "private_data_a" {
  vpc_id            = data.aws_vpc.prod.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "ap-northeast-2a"

  tags = merge(local.common_tags, { Name = "qfeed-prod-subnet-private-data-a" })
}

resource "aws_subnet" "private_data_c" {
  vpc_id            = data.aws_vpc.prod.id
  cidr_block        = "10.0.80.0/20"
  availability_zone = "ap-northeast-2c"

  tags = merge(local.common_tags, { Name = "qfeed-prod-subnet-private-data-c" })
}

# =============================================================================
# Private Route Table (NAT GW 경유)
# =============================================================================

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.prod.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-rt-private" })
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_a" {
  subnet_id      = aws_subnet.private_data_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_c" {
  subnet_id      = aws_subnet.private_data_c.id
  route_table_id = aws_route_table.private.id
}
