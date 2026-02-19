variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS ARM64 AMI"
  type        = string
  default     = "ami-066f9893a857529ea"
}

variable "key_pair_name" {
  description = "EC2 키 페어 이름"
  type        = string
  default     = "qfeed-keypair-2"
}

variable "allowed_ips" {
  description = "팀원 IP 목록"
  type        = list(string)
}

variable "db_username" {
  description = "RDS 마스터 유저"
  type        = string
}

variable "alert_email" {
  description = "알림 수신 이메일"
  type        = string
}
