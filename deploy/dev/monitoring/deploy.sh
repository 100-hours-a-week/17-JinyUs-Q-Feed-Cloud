#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: 배포 실패 (line $LINENO)" >&2' ERR

# --- 설정 ---
AWS_REGION="ap-northeast-2"
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"
SSM_PREFIX="/qfeed/dev/monitoring"

# --- SSM에서 환경변수 조회 ---
get_ssm() {
  aws ssm get-parameter \
    --region "$AWS_REGION" \
    --name "${SSM_PREFIX}/$1" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text
}

echo "SSM 파라미터 조회 중..."
export GF_ADMIN_PASSWORD=$(get_ssm "GF_ADMIN_PASSWORD")
echo "SSM 파라미터 조회 완료 (1개)"

# --- 배포 ---
docker compose -f "$COMPOSE_DIR/docker-compose.yml" pull
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d

# --- 이전 이미지 정리 ---
docker image prune -f

# --- 결과 확인 ---
echo "배포 완료"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps

# --- 헬스체크 ---
SERVICES=("prometheus" "loki" "grafana" "alloy")
echo "헬스체크 대기 중 (최대 120초)..."

for i in $(seq 1 12); do
  sleep 10
  ALL_HEALTHY=true
  for svc in "${SERVICES[@]}"; do
    if ! docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps "$svc" | grep -q "healthy"; then
      ALL_HEALTHY=false
      break
    fi
  done

  if $ALL_HEALTHY; then
    echo "모든 서비스가 정상적으로 실행 중입니다."
    exit 0
  fi
  echo "  ... 대기 중 (${i}0초 경과)"
done

echo "헬스체크 실패 (120초 타임아웃)" >&2
for svc in "${SERVICES[@]}"; do
  echo "=== ${svc} logs ==="
  docker compose -f "$COMPOSE_DIR/docker-compose.yml" logs --tail 20 "$svc"
done
exit 1
