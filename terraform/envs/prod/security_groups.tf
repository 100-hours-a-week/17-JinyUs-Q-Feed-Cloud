# ALB SG: HTTP:80 퍼블릭 오픈

resource "aws_security_group" "alb" {
  name        = "qfeed-prod-sg-alb"
  description = "ALB - allow HTTP from anywhere"
  vpc_id      = data.aws_vpc.prod.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-sg-alb" })
}

# Backend EC2 SG: ALB에서 8080/8081

resource "aws_security_group" "backend" {
  name        = "qfeed-prod-sg-backend"
  description = "Backend EC2 - allow 8080/8081 from ALB"
  vpc_id      = data.aws_vpc.prod.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-sg-backend" })
}

# AI EC2 SG: Backend에서 8000

resource "aws_security_group" "ai" {
  name        = "qfeed-prod-sg-ai"
  description = "AI EC2 - allow 8000 from Backend SG"
  vpc_id      = data.aws_vpc.prod.id

  ingress {
    description     = "FastAPI from Backend"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-sg-ai" })
}

# Redis EC2 SG: Backend에서 6379만

resource "aws_security_group" "redis" {
  name        = "qfeed-prod-sg-redis"
  description = "Redis EC2 - allow 6379 from Backend SG"
  vpc_id      = data.aws_vpc.prod.id

  ingress {
    description     = "Redis from Backend"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-sg-redis" })
}

# RDS SG: Backend에서 5432만

resource "aws_security_group" "rds" {
  name        = "qfeed-prod-sg-rds"
  description = "RDS - allow 5432 from Backend SG"
  vpc_id      = data.aws_vpc.prod.id

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

  tags = merge(local.common_tags, { Name = "qfeed-prod-sg-rds" })
}
