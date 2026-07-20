#!/usr/bin/env bash
# mail.example.com — Mailcow-dockerized 설치 스크립트
# 대상: Ubuntu 22.04.5 LTS, br-mailcow 172.22.1.0/24
set -euo pipefail

MAILCOW_HOSTNAME="${MAILCOW_HOSTNAME:-mail.example.com}"
INSTALL_DIR="${INSTALL_DIR:-/opt/mailcow-dockerized}"

echo "[1/5] 기본 패키지 및 Docker 설치 확인"
sudo apt update
sudo apt install -y curl wget gnupg2 ca-certificates lsb-release git

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "  -> docker 그룹에 추가되었습니다. 재로그인 후 계속하세요."
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin이 없습니다. docker-ce 최신 버전을 설치하세요." >&2
  exit 1
fi

echo "[2/5] mailcow-dockerized 클론"
if [ ! -d "$INSTALL_DIR" ]; then
  sudo git clone https://github.com/mailcow/mailcow-dockerized "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"

echo "[3/5] mailcow.conf 생성 (MAILCOW_HOSTNAME=$MAILCOW_HOSTNAME)"
if [ ! -f mailcow.conf ]; then
  sudo ./generate_config.sh <<EOF
$MAILCOW_HOSTNAME
EOF
fi

echo "[4/5] Let's Encrypt 자동 발급 비활성화 (사설 도메인 — internal-ca 사용)"
if grep -q '^SKIP_LETS_ENCRYPT=' mailcow.conf; then
  sudo sed -i 's/^SKIP_LETS_ENCRYPT=.*/SKIP_LETS_ENCRYPT=y/' mailcow.conf
else
  echo 'SKIP_LETS_ENCRYPT=y' | sudo tee -a mailcow.conf
fi

echo "[5/5] 컨테이너 기동"
sudo docker compose pull
sudo docker compose up -d

echo "완료. 내부 CA 인증서 자동 갱신 cron 설치는 ../internal-ca/scripts/install_cron_renewal.sh 를 참고하세요."
echo "acme-mailcow 컨테이너는 사용하지 않으므로 정지합니다."
sudo docker compose stop acme-mailcow 2>/dev/null || true
