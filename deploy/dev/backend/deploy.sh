#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR

# --- 설정 ---
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- 인자 확인 ---
IMAGE_TAG="${1:?IMAGE_TAG가 필요합니다 (예: ./deploy.sh abc123)}"

# --- SSM에서 Redis 비밀번호 조회 ---
REDIS_PASSWORD=$(aws ssm get-parameter \
  --region "$AWS_REGION" \
  --name "/qfeed/dev/be/REDIS_PASSWORD" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# --- ECR 로그인 ---
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# --- 환경변수 export ---
export ECR_REGISTRY
export IMAGE_TAG
export REDIS_PASSWORD

# --- 배포 ---
docker compose -f "$COMPOSE_DIR/docker-compose.yml" pull
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d

# --- 이전 이미지 정리 ---
docker image prune -f

# --- 결과 확인 ---
echo "배포 완료: ${ECR_REGISTRY}/qfeed-ecr-backend:${IMAGE_TAG}"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps

# --- 헬스체크 ---
echo "헬스체크 대기 중 (최대 120초)..."
for i in $(seq 1 12); do
  sleep 10
  if docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps backend | grep -q "healthy"; then
    echo "✅ backend 컨테이너가 정상적으로 실행 중입니다."
    exit 0
  fi
  echo "  ... 대기 중 (${i}0초 경과)"
done
echo "❌ backend 컨테이너 실행 실패 (120초 타임아웃)" >&2
docker compose -f "$COMPOSE_DIR/docker-compose.yml" logs --tail 50
exit 1
