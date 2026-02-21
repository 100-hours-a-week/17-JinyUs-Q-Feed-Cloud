# -----------------------------------------------------------------------------
# ALB Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "qfeed-dev-sg-alb"
  description = "ALB - allow HTTP from CloudFront"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-alb"
  })
}

# -----------------------------------------------------------------------------
# Backend EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "backend" {
  name        = "qfeed-dev-sg-backend"
  description = "Backend EC2 - allow 8080 from ALB, 22 from team IPs"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Actuator health check from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from team IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-backend"
  })
}

# -----------------------------------------------------------------------------
# AI Server EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ai" {
  name        = "qfeed-dev-sg-ai"
  description = "AI EC2 - allow 8000 from Backend SG, 22 from team IPs"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "FastAPI from Backend"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description = "SSH from team IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-ai"
  })
}

# -----------------------------------------------------------------------------
# RDS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "qfeed-dev-sg-rds"
  description = "RDS - allow 5432 from Backend and team IPs"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "PostgreSQL from Backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-rds"
  })
}
