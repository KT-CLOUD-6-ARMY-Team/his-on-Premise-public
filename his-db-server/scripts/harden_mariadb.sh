#!/usr/bin/env bash
# HIS-DB-Server — 하드닝 스크립트
# 방화벽 비활성 + 0.0.0.0:3306 전체 바인딩 상태를 교정합니다.
set -euo pipefail

SERVER_IP="192.168.100.50"
ALLOWED_CIDR="192.168.100.0/24"
CNF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

echo "[1/3] MariaDB bind-address 를 ${SERVER_IP} 로 제한"
if grep -q '^bind-address' "$CNF_FILE" 2>/dev/null; then
  sudo sed -i "s/^bind-address.*/bind-address = ${SERVER_IP}/" "$CNF_FILE"
else
  echo "bind-address = ${SERVER_IP}" | sudo tee -a "$CNF_FILE"
fi
sudo systemctl restart mariadb

echo "[2/3] ufw 활성화 및 3306을 서버팜 대역으로만 허용"
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow from "$ALLOWED_CIDR" to any port 3306 proto tcp
sudo ufw allow 9100/tcp   # node_exporter — 모니터링 서버 대역으로 추가 제한 권장
sudo ufw --force enable

echo "[3/3] 현재 상태 확인"
sudo ufw status verbose
sudo ss -tulnp | grep 3306 || true

echo "완료. mysql_secure_installation 미실행 항목(익명 계정, 원격 root 등)이 남아있다면 별도로 점검하세요."
