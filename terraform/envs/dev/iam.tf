# -----------------------------------------------------------------------------
# EC2 IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ec2_backend" {
  name = "qfeed-dev-role-ec2-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-ec2-backend"
  })
}

# -----------------------------------------------------------------------------
# SSM Parameter Store 읽기 권한 (/qfeed/dev/*)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ssm_params" {
  name = "qfeed-dev-policy-ssm"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECR Pull 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecr" {
  name = "qfeed-dev-policy-ecr"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# S3 읽기/쓰기 권한 (dev 버킷 전체)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "s3" {
  name = "qfeed-dev-policy-s3"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::qfeed-dev-s3-*",
          "arn:aws:s3:::qfeed-dev-s3-*/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Logs 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "qfeed-dev-policy-cloudwatch-logs"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SSM Session Manager 접속 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_backend" {
  name = "qfeed-dev-profile-ec2-backend"
  role = aws_iam_role.ec2_backend.name

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-profile-ec2-backend"
  })
}

# =============================================================================
# AI Server EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_ai" {
  name = "qfeed-dev-role-ec2-ai"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-ec2-ai"
  })
}

# -----------------------------------------------------------------------------
# AI Server - SSM Parameter Store 읽기 권한 (/qfeed/dev/*)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_ssm_params" {
  name = "qfeed-dev-policy-ai-ssm"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI Server - ECR Pull 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_ecr" {
  name = "qfeed-dev-policy-ai-ecr"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI Server - S3 읽기/쓰기 권한 (dev 버킷 전체)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_s3" {
  name = "qfeed-dev-policy-ai-s3"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::qfeed-dev-s3-*",
          "arn:aws:s3:::qfeed-dev-s3-*/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI Server - CloudWatch Logs 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_cloudwatch_logs" {
  name = "qfeed-dev-policy-ai-cloudwatch-logs"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI Server - SSM Session Manager 접속 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ai_ssm_managed" {
  role       = aws_iam_role.ec2_ai.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# AI Server Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_ai" {
  name = "qfeed-dev-profile-ec2-ai"
  role = aws_iam_role.ec2_ai.name

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-profile-ec2-ai"
  })
}
