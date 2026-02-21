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

HUGGINGFACE_API_KEY=$(get_ssm "huggingface-api-key")
GEMINI_API_KEY=$(get_ssm "gemini-api-key")
ELEVENLABS_API_KEY=$(get_ssm "elevenlabs-api-key")
LANGCHAIN_API_KEY=$(get_ssm "langchain-api-key")
AWS_S3_AUDIO_BUCKET=$(get_ssm "aws-s3-audio-bucket")
# TODO: SSM 등록 후 주석 해제
# VLLM_BASE_URL=$(get_ssm "vllm-base-url")
# VLLM_MODEL_ID=$(get_ssm "vllm-model-id")

# --- ECR 로그인 ---
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# --- 이미지 Pull ---
docker pull "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# --- 기존 컨테이너 정리 ---
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# --- 배포 ---
docker run -d \
  --name "$CONTAINER_NAME" \
  --network host \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -e ENVIRONMENT=dev \
  -e AWS_REGION="$AWS_REGION" \
  -e HUGGINGFACE_API_KEY="$HUGGINGFACE_API_KEY" \
  -e GEMINI_API_KEY="$GEMINI_API_KEY" \
  -e ELEVENLABS_API_KEY="$ELEVENLABS_API_KEY" \
  -e LANGCHAIN_API_KEY="$LANGCHAIN_API_KEY" \
  -e AWS_S3_AUDIO_BUCKET="$AWS_S3_AUDIO_BUCKET" \
  # TODO: SSM 등록 후 주석 해제
  # -e VLLM_BASE_URL="$VLLM_BASE_URL" \
  # -e VLLM_MODEL_ID="$VLLM_MODEL_ID" \
  "${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"

# --- 이전 이미지 정리 ---
docker image prune -f

# --- 결과 확인 ---
echo "배포 완료: ${ECR_REGISTRY}/qfeed-ecr-ai:${IMAGE_TAG}"
docker ps --filter "name=$CONTAINER_NAME"

# --- 헬스체크 ---
echo "헬스체크 대기 중 (최대 60초)..."
for i in $(seq 1 6); do
  sleep 10
  if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo "✅ AI 컨테이너가 정상적으로 실행 중입니다."
    exit 0
  fi
  echo "  ... 대기 중 (${i}0초 경과)"
done
echo "❌ AI 컨테이너 실행 실패 (60초 타임아웃)" >&2
docker logs "$CONTAINER_NAME" --tail 50
exit 1
