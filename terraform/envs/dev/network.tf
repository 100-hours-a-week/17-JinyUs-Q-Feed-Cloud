# -----------------------------------------------------------------------------
# Public Subnet C — ALB에 필요 (최소 2 AZ)
# -----------------------------------------------------------------------------

resource "aws_subnet" "public_c" {
  vpc_id                  = data.aws_vpc.dev.id
  cidr_block              = "10.1.32.0/20"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-subnet-public-c"
  })
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = data.aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private Subnets — RDS용 (DB Subnet Group에 최소 2 AZ 필요)
# -----------------------------------------------------------------------------

resource "aws_subnet" "private_a" {
  vpc_id            = data.aws_vpc.dev.id
  cidr_block        = "10.1.128.0/20"
  availability_zone = "ap-northeast-2a"

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-subnet-private-a"
  })
}

resource "aws_subnet" "private_c" {
  vpc_id            = data.aws_vpc.dev.id
  cidr_block        = "10.1.160.0/20"
  availability_zone = "ap-northeast-2c"

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-subnet-private-c"
  })
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.dev.id

  # IGW 없음, local route만 (VPC 내부 통신 전용)
  tags = merge(local.common_tags, {
    Name = "qfeed-dev-rt-private"
  })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}