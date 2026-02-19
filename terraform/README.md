# Terraform Infrastructure

Q-Feed 프로젝트의 AWS 인프라를 Terraform으로 관리합니다.

[HashiCorp Recommended Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)를 기반으로 환경별 분리, 일관된 네이밍, 원격 상태 관리를 적용하고 있습니다.

## 1. 디렉토리 구조

```
terraform/
└── envs/
    └── dev/
        ├── main.tf
        ├── network.tf
        ├── compute.tf
        ├── alb.tf
        ├── rds.tf
        ├── security_groups.tf
        ├── iam.tf
        ├── data.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

### 1.1 파일 역할

| 파일                 | 역할                                                  |
| -------------------- | ----------------------------------------------------- |
| `main.tf`            | Terraform/Provider 설정, backend 구성, 공통 태그 정의 |
| `network.tf`         | 서브넷, 라우트 테이블 (VPC는 기존 리소스 참조)        |
| `compute.tf`         | Launch Template, Auto Scaling Group (Backend + AI)    |
| `alb.tf`             | Application Load Balancer, Target Group, Listener     |
| `rds.tf`             | RDS PostgreSQL, DB Subnet Group                       |
| `security_groups.tf` | 모든 Security Group (ALB, Backend, AI, RDS)           |
| `iam.tf`             | IAM Role, Policy, Instance Profile (Backend + AI)     |
| `data.tf`            | 기존 AWS 리소스 참조 (VPC, Subnet, SSM Parameter 등)  |
| `variables.tf`       | 입력 변수 선언                                        |
| `outputs.tf`         | 출력 값 (ALB DNS, RDS endpoint, 접속 명령어 등)       |

### 1.2 환경 분리 방식

환경별로 독립된 디렉토리(`envs/<env>`)를 사용합니다. 각 환경은 자체 state 파일을 가지며, 서로 영향을 주지 않습니다.

```
envs/
├── dev/       # 개발 환경 (현재)
└── prod/      # 운영 환경 (예정)
```

## 2. 아키텍처

### 2.1 트래픽 흐름

```
CloudFront ──► ALB (CloudFront에서만 접근 허용)
                 └──► Backend EC2 (ALB에서만 :8080)
                        ├──► AI EC2 (Backend에서만 :8000)
                        └──► RDS PostgreSQL (Backend에서만 :5432)
```

### 2.2 리소스 구성

| 계층         | 주요 리소스                                    | 설명                                                                              |
| ------------ | ---------------------------------------------- | --------------------------------------------------------------------------------- |
| 네트워크     | VPC (기존), Public/Private Subnet, Route Table | VPC는 `data` 블록으로 참조. ALB·RDS의 2 AZ 요건을 위해 서브넷 분리                |
| 컴퓨트       | Launch Template + ASG (Backend, AI 각각)       | Ubuntu ARM64, Docker + SSM Agent 자동 설치. ASG로 관리                            |
| 로드밸런서   | ALB, Target Group, Listener                    | HTTP:80 리스너. TLS 종단은 CloudFront에서 처리                                    |
| 데이터베이스 | RDS PostgreSQL, DB Subnet Group                | Private Subnet 배치, 비공개 접근, 스토리지 암호화, Single-AZ (dev)                |
| 보안         | Security Group (ALB, Backend, AI, RDS)         | 각 계층별 최소 권한 원칙 적용. 상위 계층의 SG만 소스로 허용                       |
| IAM          | EC2 Role + Instance Profile (Backend, AI 각각) | SSM Parameter Store 읽기, ECR Pull, SSM Session Manager. AI는 추가로 S3 읽기/쓰기 |

## 3. 네이밍 규칙

[네이밍 정책 문서](../policy/naming-policy.md)를 따릅니다.

기본 포맷: `{서비스명}-{환경}-{리소스타입}-{용도}`

## 4. 태그 관리

모든 리소스에 `common_tags`를 적용합니다.

```hcl
locals {
  common_tags = {
    Environment = "dev"
    Project     = "qfeed"
    ManagedBy   = "terraform"
  }
}
```

리소스별 `Name` 태그는 `merge()`로 추가합니다:

```hcl
tags = merge(local.common_tags, {
  Name = "{project}-{env}-{service}-{role}"
})
```

## 5. 상태 관리 (State)

S3 Remote Backend + S3 native state lock 방식을 사용합니다.

- **State 저장**: S3 버킷에 환경별 key prefix로 분리하여 저장
- **Locking**: S3 conditional writes 기반 native lock (`use_lockfile = true`)
- **암호화**: 서버 측 암호화 활성화

> 설정은 `main.tf`의 `backend "s3"` 블록을 참고하세요.

## 6. 민감 정보 관리

### 6.1 `.gitignore`

```
*.tfstate
*.tfstate.*
*.tfvars
.terraform/
```

### 6.2 민감 정보 전달 방식

| 정보        | 관리 방식                                             |
| ----------- | ----------------------------------------------------- |
| DB 비밀번호 | SSM Parameter Store (SecureString) → `data` 블록 참조 |
| DB 사용자명 | `terraform.tfvars` (Git 제외)                         |
| 팀원 IP     | `terraform.tfvars` (Git 제외)                         |
| 알림 이메일 | `terraform.tfvars` (Git 제외)                         |

> AMI ID 등 민감하지 않은 설정 값은 `variables.tf`의 default로 관리합니다.

## 7. 사용법

### 7.1 초기 설정

```bash
cd terraform/envs/dev

# 변수 파일 준비
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # 실제 값 입력

# Terraform 초기화 (provider 다운로드, backend 연결)
terraform init
```

### 7.2 일반 워크플로우

```bash
# 현재 상태 확인
terraform plan

# 변경사항 적용
terraform apply

# 특정 리소스만 적용 (주의해서 사용)
terraform apply -target=aws_db_instance.postgres

# 현재 state의 리소스 목록 확인
terraform state list
```

### 7.3 output 명령어

```bash
terraform output alb_dns_name          # ALB DNS 확인
terraform output rds_endpoint          # RDS 엔드포인트 확인
terraform output find_instance_command # Backend EC2 인스턴스 ID 조회
terraform output ssm_connect_command   # SSM 접속 명령어 확인
```

## 8. 팀 규칙

### 8.1 변경 적용 전

- `terraform plan` 출력을 반드시 확인 후 `apply`
- 의도하지 않은 destroy가 포함되어 있으면 즉시 중단
- 큰 변경사항(네트워크, RDS 등)은 팀원 간 공유 후 진행

### 8.2 코드 작성 규칙

- 리소스 파일은 역할별로 분리 (network, compute, security 등)
- 모든 리소스에 `common_tags` + `Name` 태그 필수
- [네이밍 규칙](../policy/naming-policy.md) 준수
- 하드코딩된 값은 `variables.tf`에서 변수로 관리
- 기존 리소스 참조는 `data.tf`에 모아서 관리

### 8.3 State 관련

- `terraform.tfstate` 파일을 직접 수정하지 않기
- `terraform state mv/rm` 명령어는 팀원 확인 후 사용
- State에 문제가 생기면 S3 버전 관리로 복구

### 8.4 보안

- `terraform.tfvars`를 절대 Git에 커밋하지 않기
- 비밀번호/키는 SSM Parameter Store에 저장
- Security Group은 최소 권한 원칙 적용 (필요한 포트/소스만 허용)
- IMDSv2 강제 적용 (`http_tokens = "required"`)

## 9. Provider 버전

| Provider      | 버전 제약 | 현재 Lock 버전 |
| ------------- | --------- | -------------- |
| hashicorp/aws | `~> 5.0`  | `5.100.0`      |
| Terraform     | `>= 1.0`  | -              |

`.terraform.lock.hcl` 파일은 Git에 커밋하여 팀원 간 동일한 provider 버전을 보장합니다.
