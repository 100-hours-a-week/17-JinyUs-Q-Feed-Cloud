#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR

# --- 설정 ---
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CONTAINER_NAME="qfeed-ai"
SSM_PREFIX="/qfeed/dev/ai"

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
HUGGINGFACE_API_KEY=$(get_ssm "huggingface-api-key")
GEMINI_API_KEY=$(get_ssm "gemini-api-key")
ELEVENLABS_API_KEY=$(get_ssm "elevenlabs-api-key")
LANGFUSE_SECRET_KEY=$(get_ssm "langfuse-secret-key")
LANGFUSE_PUBLIC_KEY=$(get_ssm "langfuse-public-key")
LANGFUSE_BASE_URL=$(get_ssm "langfuse-base-url")

# --- ECR 로그인 ---
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# --- 이미지 Pull ---
docker pull "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# --- 기존 컨테이너 정리 ---
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# .env 파일로 주입 후 배포 후 삭제
ENV_FILE=$(mktemp)
trap 'rm -f "$ENV_FILE"; echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR EXIT
chmod 600 "$ENV_FILE"
cat > "$ENV_FILE" << EOF
ENVIRONMENT=dev
AWS_REGION=${AWS_REGION}
AWS_PARAMETER_STORE_PATH=${SSM_PREFIX}
HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY}
GPU_STT_URL=${GPU_STT_URL}
GPU_LLM_URL=${GPU_LLM_URL}
LANGFUSE_SECRET_KEY=${LANGFUSE_SECRET_KEY}
LANGFUSE_PUBLIC_KEY=${LANGFUSE_PUBLIC_KEY}
LANGFUSE_BASE_URL=${LANGFUSE_BASE_URL}
EOF

# --- 배포 ---
docker run -d \
  --name "$CONTAINER_NAME" \
  --network host \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --env-file "$ENV_FILE" \
  "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# 배포 후 즉시 삭제
rm -f "$ENV_FILE"

# --- 이전 이미지 정리 ---
# 현재 배포 태그를 제외한 이전 버전 이미지 삭제
docker images "${ECR_REGISTRY}/qfeed-ecr-ai" --format '{{.Tag}}' \
  | grep -v "^${IMAGE_TAG}$" \
  | xargs -I{} docker rmi "${ECR_REGISTRY}/qfeed-ecr-ai:{}" 2>/dev/null || true

# dangling 이미지(태그 없는 이미지)도 추가 정리
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
