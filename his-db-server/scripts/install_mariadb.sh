#!/usr/bin/env bash
# HIS-DB-Server — MariaDB 설치 (신규 구축용)
# 버전(10.6.23)에 맞춰 mariadb-10.6 계열을 설치합니다.
set -euo pipefail

sudo apt update
sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable --now mariadb

echo "mysql_secure_installation 을 대화형으로 실행합니다 (root 암호/익명 계정/원격 root 제거 등)."
sudo mysql_secure_installation

echo "완료. 하드닝(바인딩/방화벽)은 ./harden_mariadb.sh 를 실행하세요."
