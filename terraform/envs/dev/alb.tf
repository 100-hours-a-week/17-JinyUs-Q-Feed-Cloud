# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "backend" {
  name               = "qfeed-dev-alb-backend"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    data.aws_subnet.public_a.id,
    aws_subnet.public_c.id,
  ]

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-alb-backend"
  })
}

# -----------------------------------------------------------------------------
# Target Group
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "backend" {
  name     = "qfeed-dev-tg-backend"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.dev.id

  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-tg-backend"
  })
}

# -----------------------------------------------------------------------------
# Listener (HTTP:80 — CloudFront가 TLS 종단)
# -----------------------------------------------------------------------------

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-listener-backend"
  })
}
