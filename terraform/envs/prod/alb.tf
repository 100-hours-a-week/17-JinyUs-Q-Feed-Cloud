resource "aws_lb" "backend" {
  name               = "qfeed-prod-alb-backend"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    data.aws_subnet.public_a.id,
    aws_subnet.public_c.id,
  ]

  tags = merge(local.common_tags, { Name = "qfeed-prod-alb-backend" })
}

resource "aws_lb_target_group" "backend" {
  name     = "qfeed-prod-tg-backend"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.prod.id

  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8081"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-tg-backend" })
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-listener-backend" })
}
