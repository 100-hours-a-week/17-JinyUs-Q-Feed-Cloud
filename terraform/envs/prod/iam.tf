# =============================================================================
# Backend EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_backend" {
  name = "qfeed-prod-role-ec2-backend"

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

  tags = merge(local.common_tags, { Name = "qfeed-prod-role-ec2-backend" })
}

resource "aws_iam_role_policy" "backend_ssm_params" {
  name = "qfeed-prod-policy-backend-ssm"
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
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/prod/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "backend_ecr" {
  name = "qfeed-prod-policy-backend-ecr"
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

resource "aws_iam_role_policy" "backend_s3" {
  name = "qfeed-prod-policy-backend-s3"
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
          "arn:aws:s3:::qfeed-prod-s3-*",
          "arn:aws:s3:::qfeed-prod-s3-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "backend_cloudwatch_logs" {
  name = "qfeed-prod-policy-backend-cloudwatch-logs"
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
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/prod/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_ssm_managed" {
  role       = aws_iam_role.ec2_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_backend" {
  name = "qfeed-prod-profile-ec2-backend"
  role = aws_iam_role.ec2_backend.name

  tags = merge(local.common_tags, { Name = "qfeed-prod-profile-ec2-backend" })
}

# =============================================================================
# AI EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_ai" {
  name = "qfeed-prod-role-ec2-ai"

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

  tags = merge(local.common_tags, { Name = "qfeed-prod-role-ec2-ai" })
}

resource "aws_iam_role_policy" "ai_ssm_params" {
  name = "qfeed-prod-policy-ai-ssm"
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
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/prod/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ai_ecr" {
  name = "qfeed-prod-policy-ai-ecr"
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

resource "aws_iam_role_policy" "ai_s3" {
  name = "qfeed-prod-policy-ai-s3"
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
          "arn:aws:s3:::qfeed-prod-s3-*",
          "arn:aws:s3:::qfeed-prod-s3-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ai_cloudwatch_logs" {
  name = "qfeed-prod-policy-ai-cloudwatch-logs"
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
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/prod/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ai_ssm_managed" {
  role       = aws_iam_role.ec2_ai.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ai" {
  name = "qfeed-prod-profile-ec2-ai"
  role = aws_iam_role.ec2_ai.name

  tags = merge(local.common_tags, { Name = "qfeed-prod-profile-ec2-ai" })
}

# =============================================================================
# Redis EC2 IAM Role (SSM params + SSM Session Manager)
# =============================================================================

resource "aws_iam_role" "ec2_redis" {
  name = "qfeed-prod-role-ec2-redis"

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

  tags = merge(local.common_tags, { Name = "qfeed-prod-role-ec2-redis" })
}

resource "aws_iam_role_policy" "redis_ssm_params" {
  name = "qfeed-prod-policy-redis-ssm"
  role = aws_iam_role.ec2_redis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/prod/be/REDIS_PASSWORD"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "redis_ssm_managed" {
  role       = aws_iam_role.ec2_redis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_redis" {
  name = "qfeed-prod-profile-ec2-redis"
  role = aws_iam_role.ec2_redis.name

  tags = merge(local.common_tags, { Name = "qfeed-prod-profile-ec2-redis" })
}

# =============================================================================
# GitHub Actions IAM Role (Prod 전용)
# =============================================================================

resource "aws_iam_role" "github_actions" {
  name = "qfeed-prod-role-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:100-hours-a-week/17-JinyUs-Q-Feed-BE:ref:refs/heads/main",
              "repo:100-hours-a-week/17-JinyUs-Q-Feed-AI:ref:refs/heads/main",
            ]
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "qfeed-prod-role-github-actions" })
}

# GitHub Actions - ECR Push (공용 ECR repo 참조)

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "qfeed-prod-policy-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = [
          "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/qfeed-ecr-backend",
          "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/qfeed-ecr-ai"
        ]
      }
    ]
  })
}

# GitHub Actions - SSM Run Command (prod EC2만)

resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "qfeed-prod-policy-github-actions-ssm"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:ap-northeast-2:*:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Project"     = "qfeed"
            "ssm:resourceTag/Environment" = "prod"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

# GitHub Actions - S3 (prod 버킷)

resource "aws_iam_role_policy" "github_actions_s3" {
  name = "qfeed-prod-policy-github-actions-s3"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = [
          "arn:aws:s3:::qfeed-prod-s3-*",
          "arn:aws:s3:::qfeed-prod-s3-*/*"
        ]
      }
    ]
  })
}
