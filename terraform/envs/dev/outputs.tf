output "alb_dns_name" {
  description = "ALB DNS name (CloudFront 오리진으로 사용)"
  value       = aws_lb.backend.dns_name
}

output "rds_endpoint" {
  description = "RDS 엔드포인트 (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS 호스트 (포트 제외)"
  value       = aws_db_instance.postgres.address
}

output "asg_name" {
  description = "ASG 이름"
  value       = aws_autoscaling_group.backend.name
}

output "ssm_connect_command" {
  description = "SSM 접속 명령어 (instance ID는 ASG에서 조회)"
  value       = "aws ssm start-session --target <INSTANCE_ID>"
}

output "find_instance_command" {
  description = "ASG 인스턴스 ID 조회"
  value       = "aws autoscaling describe-auto-scaling-instances --query 'AutoScalingInstances[?AutoScalingGroupName==`${aws_autoscaling_group.backend.name}`].InstanceId' --output text"
}

# -----------------------------------------------------------------------------
# AI Server
# -----------------------------------------------------------------------------

output "ai_asg_name" {
  description = "AI Server ASG 이름"
  value       = aws_autoscaling_group.ai.name
}

output "ai_sg_id" {
  description = "AI Server Security Group ID"
  value       = aws_security_group.ai.id
}

output "find_ai_instance_command" {
  description = "AI Server ASG 인스턴스 ID 조회"
  value       = "aws autoscaling describe-auto-scaling-instances --query 'AutoScalingInstances[?AutoScalingGroupName==`${aws_autoscaling_group.ai.name}`].InstanceId' --output text"
}
