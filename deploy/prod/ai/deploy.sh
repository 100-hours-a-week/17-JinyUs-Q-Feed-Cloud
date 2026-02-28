#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR

# --- 설정 ---
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CONTAINER_NAME="qfeed-ai"
SSM_PREFIX="/qfeed/prod/ai"

# --- 인자 확인 ---
IMAGE_TAG="${1:?IMAGE_TAG가 필요합니다 (예: ./deploy.sh abc123)}"

# --- SSM에서 환경변수 조회 ---
get_ssm() {
  aws ssm get-parameter \
    --region "$AWS_REGION" \
    --name "${SSM_PREFIX}/$1" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text
}

GPU_STT_URL=$(get_ssm "gpu-stt-url")
GPU_LLM_URL=$(get_ssm "gpu-llm-url")

# --- ECR 로그인 ---
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# --- 이미지 Pull ---
docker pull "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# --- 기존 컨테이너 정리 ---
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# --- 로그 디렉토리 생성 (없거나 권한 없을 때만) ---
LOG_DIR="/var/log/qfeed/ai"
if [ ! -d "$LOG_DIR" ] || [ ! -w "$LOG_DIR" ]; then
  sudo mkdir -p "$LOG_DIR"
  sudo chown 1000:101 "$LOG_DIR"
  sudo chmod 755 /var/log/qfeed "$LOG_DIR"
fi

# --- 배포 ---
docker run -d \
  --name "$CONTAINER_NAME" \
  --network host \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v /var/log/qfeed/ai:/var/log/qfeed/ai \
  -e ENVIRONMENT=prod \
  -e AWS_REGION="$AWS_REGION" \
  -e AWS_PARAMETER_STORE_PATH="$SSM_PREFIX" \
  -e GPU_STT_URL="$GPU_STT_URL" \
  -e GPU_LLM_URL="$GPU_LLM_URL" \
  "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# --- 이전 이미지 정리 ---
# 현재 배포 태그를 제외한 이전 버전 이미지 삭제
docker images "${ECR_REGISTRY}/qfeed-ecr-ai" --format '{{.Tag}}' \
  | grep -v "^${IMAGE_TAG}$" \
  | xargs -I{} docker rmi "${ECR_REGISTRY}/qfeed-ecr-ai:{}" 2>/dev/null || true
docker image prune -f


# --- 결과 확인 ---
echo "배포 완료: ${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"
docker ps --filter "name=$CONTAINER_NAME"

# --- 헬스체크 ---
echo "헬스체크 대기 중 (최대 60초)..."
for i in $(seq 1 6); do
  sleep 10
  RESTART_COUNT=$(docker inspect "$CONTAINER_NAME" --format '{{.RestartCount}}')
  if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME" && [ "$RESTART_COUNT" = "0" ]; then
    echo "✅ AI 컨테이너가 정상적으로 실행 중입니다."
    exit 0
  fi
  echo "  ... 대기 중 (${i}0초 경과)"
done
echo "❌ AI 컨테이너 실행 실패 (60초 타임아웃)" >&2
docker logs "$CONTAINER_NAME" --tail 50
exit 1
