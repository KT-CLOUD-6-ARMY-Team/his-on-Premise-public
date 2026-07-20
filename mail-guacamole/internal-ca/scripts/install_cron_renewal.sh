#!/usr/bin/env bash
# mail.example.com — step-ca 인증서 자동 갱신 cron 설치
# /etc/cron.d/ 에 등록된 실제 갱신 항목을 그대로 재현합니다 (별도 래퍼 스크립트 없이 cron 한 줄로 동작).
set -euo pipefail

CRON_FILE="/etc/cron.d/step-renew"

sudo tee "$CRON_FILE" > /dev/null <<'EOF'
# step-ca 인증서 자동 갱신 (mail.example.com)
# Mailcow 인증서 — 6시간마다
0 */6 * * * root cd /opt/step-ca && step ca renew certs/mail.crt certs/mail.key --force >> /var/log/step-renew.log 2>&1 && cp certs/mail.crt /opt/mailcow-dockerized/data/assets/ssl/cert.pem && cp certs/mail.key /opt/mailcow-dockerized/data/assets/ssl/key.pem && cd /opt/mailcow-dockerized && docker compose restart nginx-mailcow >> /var/log/step-renew.log 2>&1

# Guacamole 인증서 — 6시간마다 (5분 오프셋으로 충돌 방지)
5 */6 * * * root step ca renew /home/test/guacamole/nginx/certs/guac.crt /home/test/guacamole/nginx/certs/guac.key --force >> /var/log/step-renew.log 2>&1 && cd /home/test/guacamole && docker compose restart guac-nginx >> /var/log/step-renew.log 2>&1

# 재부팅 시 지연 후 재실행
@reboot root sleep 30 && cd /opt/step-ca && step ca renew certs/mail.crt certs/mail.key --force >> /var/log/step-renew.log 2>&1 && cp certs/mail.crt /opt/mailcow-dockerized/data/assets/ssl/cert.pem && cp certs/mail.key /opt/mailcow-dockerized/data/assets/ssl/key.pem && cd /opt/mailcow-dockerized && docker compose restart nginx-mailcow >> /var/log/step-renew.log 2>&1
@reboot root sleep 40 && step ca renew /home/test/guacamole/nginx/certs/guac.crt /home/test/guacamole/nginx/certs/guac.key --force >> /var/log/step-renew.log 2>&1 && cd /home/test/guacamole && docker compose restart guac-nginx >> /var/log/step-renew.log 2>&1
EOF

sudo chmod 644 "$CRON_FILE"
echo "설치 완료: $CRON_FILE"
