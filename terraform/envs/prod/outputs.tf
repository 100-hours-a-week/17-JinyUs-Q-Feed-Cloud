output "alb_dns_name" {
  value = aws_lb.backend.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat.public_ip
}

output "backend_asg_name" {
  value = aws_autoscaling_group.backend.name
}

output "ai_asg_name" {
  value = aws_autoscaling_group.ai.name
}

output "redis_asg_name" {
  value = aws_autoscaling_group.redis.name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
