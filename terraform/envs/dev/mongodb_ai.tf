# =============================================================================
# EBS 데이터 볼륨 (dev: 30GB, 3개 노드 디렉토리 공유)
# =============================================================================

resource "aws_ebs_volume" "mongodb_ai" {
  availability_zone = "ap-northeast-2a"
  size              = 30
  type              = "gp3"
  encrypted         = true

  tags = merge(local.common_tags, { Name = "qfeed-dev-ebs-mongodb-ai" })
}

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "mongodb_ai" {
  name          = "qfeed-dev-lt-mongodb-ai"
  image_id      = var.ami_id
  instance_type = "t4g.small"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_mongodb_ai.name
  }

  # 루트 볼륨 (OS): 20GB
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(<<-USERDATA
#!/bin/bash
set -euxo pipefail

timedatectl set-timezone Asia/Seoul

# -------------------------------------------------------
# Docker 설치
# -------------------------------------------------------
apt-get update -y
apt-get install -y ca-certificates curl unzip
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# -------------------------------------------------------
# SSM Agent
# -------------------------------------------------------
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

# -------------------------------------------------------
# AWS CLI v2 (ARM64)
# -------------------------------------------------------
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -qo awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# -------------------------------------------------------
# SSM Parameter Store에서 인증 정보 로드 (dev 경로)
# -------------------------------------------------------
MONGO_ROOT_PASSWORD=$(aws ssm get-parameter \
  --region ap-northeast-2 \
  --name "/qfeed/dev/mongo/ROOT_PASSWORD" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

MONGO_REPLICA_KEY=$(aws ssm get-parameter \
  --region ap-northeast-2 \
  --name "/qfeed/dev/mongo/REPLICA_KEY" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# -------------------------------------------------------
# 추가 EBS 마운트 (/dev/sdf → /data/mongodb-ai)
# -------------------------------------------------------
while [ ! -b /dev/nvme1n1 ] && [ ! -b /dev/xvdf ]; do sleep 2; done
DEVICE=$(ls /dev/nvme1n1 2>/dev/null || echo /dev/xvdf)
if ! blkid "$DEVICE" | grep -q ext4; then
  mkfs.ext4 "$DEVICE"
fi
mkdir -p /data/mongodb-ai
mount "$DEVICE" /data/mongodb-ai
echo "$DEVICE /data/mongodb-ai ext4 defaults,nofail 0 2" >> /etc/fstab

# 노드별 데이터 디렉토리 분리
mkdir -p /data/mongodb-ai/node1 /data/mongodb-ai/node2 /data/mongodb-ai/node3
chown -R 999:999 /data/mongodb-ai

# -------------------------------------------------------
# keyFile 생성 (3개 컨테이너 공유)
# -------------------------------------------------------
mkdir -p /data/mongo-keyfile
echo "$MONGO_REPLICA_KEY" > /data/mongo-keyfile/keyfile
chmod 400 /data/mongo-keyfile/keyfile
chown 999:999 /data/mongo-keyfile/keyfile

# -------------------------------------------------------
# Docker 네트워크 (컨테이너 간 내부 통신)
# -------------------------------------------------------
docker network create mongo-repl

# -------------------------------------------------------
# MongoDB 컨테이너 3개 기동
# 호스트 포트: 27017 / 27018 / 27019
# 컨테이너 내부는 항상 27017 사용
# -------------------------------------------------------
for i in 1 2 3; do
  PORT=$(( 27016 + i ))
  docker run -d \
    --name "mongodb-ai-node$${i}" \
    --network mongo-repl \
    --restart unless-stopped \
    --log-driver json-file \
    --log-opt max-size=20m \
    --log-opt max-file=3 \
    -p "$${PORT}:27017" \
    -v "/data/mongodb-ai/node$${i}:/data/db" \
    -v "/data/mongo-keyfile:/etc/mongo-keyfile:ro" \
    -e MONGO_INITDB_ROOT_USERNAME=admin \
    -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD" \
    mongo:8.2.5 \
    mongod \
      --replSet "rs0" \
      --bind_ip_all \
      --keyFile /etc/mongo-keyfile/keyfile \
      --wiredTigerCacheSizeGB 0.25
done

# -------------------------------------------------------
# Replica Set 초기화
# node1이 기동될 때까지 대기 후 rs.initiate() 실행
# 컨테이너명(hostname)으로 멤버 등록 → Docker 네트워크 DNS 활용
# -------------------------------------------------------
sleep 15
docker exec mongodb-ai-node1 mongosh \
  --username admin \
  --password "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --eval '
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-ai-node1:27017", priority: 2 },
    { _id: 1, host: "mongodb-ai-node2:27017", priority: 1 },
    { _id: 2, host: "mongodb-ai-node3:27017", priority: 1 }
  ]
})'
USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, { Name = "qfeed-dev-ec2-mongodb-ai" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, { Name = "qfeed-dev-ec2-mongodb-ai-root" })
  }
  tags = merge(local.common_tags, { Name = "qfeed-dev-lt-mongodb-ai" })
}

# =============================================================================
# EC2 인스턴스 (고정 단일)
# =============================================================================

resource "aws_instance" "mongodb_ai" {
  launch_template {
    id      = aws_launch_template.mongodb_ai.id
    version = "$Latest"
  }

  availability_zone = "ap-northeast-2a"
  subnet_id         = data.aws_subnet.public_a.id
  associate_public_ip_address     = true
  vpc_security_group_ids = [aws_security_group.mongodb_ai.id]

  tags = merge(local.common_tags, { Name = "qfeed-dev-ec2-mongodb-ai" })
}

# =============================================================================
# EBS 볼륨 연결
# =============================================================================

resource "aws_volume_attachment" "mongodb_ai" {
  device_name  = "/dev/sdf"
  volume_id    = aws_ebs_volume.mongodb_ai.id
  instance_id  = aws_instance.mongodb_ai.id
  force_detach = false
}

# =============================================================================
# Output
# =============================================================================

output "mongodb_ai_private_ip" {
  description = "MongoDB-AI EC2 Private IP"
  value       = aws_instance.mongodb_ai.private_ip
}

output "mongodb_ai_connection_string" {
  description = "MongoDB-AI Replica Set 연결 문자열 (password는 SSM에서 확인)"
  value = format(
    "mongodb://admin:<password>@%s:27017,%s:27018,%s:27019/?replicaSet=rs0&authSource=admin",
    aws_instance.mongodb_ai.private_ip,
    aws_instance.mongodb_ai.private_ip,
    aws_instance.mongodb_ai.private_ip
  )
}