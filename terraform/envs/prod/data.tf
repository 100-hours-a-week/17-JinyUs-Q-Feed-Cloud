# AWS 계정 정보
data "aws_caller_identity" "current" {}

# 기존 리소스 참조

data "aws_vpc" "prod" {
  id = "vpc-0cd05ba717f09a29e"
}

data "aws_subnet" "public_a" {
  id = "subnet-05db546c3af102bc5"
}

data "aws_route_table" "public" {
  route_table_id = "rtb-075c74888f471c953"
}

# RDS 마스터 비밀번호 (SSM Parameter Store SecureString)
data "aws_ssm_parameter" "db_password" {
  name = "/qfeed/prod/db-password"
}

# OIDC Provider (계정에 1개, dev에서 생성 완료)
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}
