[← mail.example.com으로 돌아가기](../README.md) · [← 전체 구성으로 돌아가기](../../README.md)

# 내부 인증서 발급/갱신 (step-ca)

## 1. 역할

[ARMYADCA의 AD CS(Windows Enterprise Root CA)](../../ad-dns-armyadca/README.md)와는 별도로, mail.example.com 위에서 컨테이너 서비스용 인증서(Mailcow, Guacamole)를 발급/자동 갱신하는 경량 내부 CA입니다. 사설 도메인(`mail.example.com`)은 공인 CA로 인증서를 받을 수 없기 때문에 필요한 구성입니다.

## 2. 컨테이너

| 컨테이너 | 이미지 | 포트 | 컴포즈 위치 |
|---|---|---|---|
| `step-ca` | `smallstep/step-ca:latest` | 0.0.0.0:9000→9000 | `/opt/step-ca/` |

## 3. 갱신 자동화 (`/etc/cron.d/`, root 소유)

한 개의 통합 스크립트가 아니라, **인증서별로 별도의 cron 한 줄짜리 명령**이 등록되어 있습니다. 6시간마다(5분 간격을 두어 충돌 방지) 갱신하고, 서버 재부팅 시에도 별도로 한 번 더 실행됩니다.

```cron
# Mailcow 인증서 — 6시간마다
0 */6 * * * root cd /opt/step-ca && step ca renew certs/mail.crt certs/mail.key --force >> /var/log/step-renew.log 2>&1 \
  && cp certs/mail.crt /opt/mailcow-dockerized/data/assets/ssl/cert.pem \
  && cp certs/mail.key /opt/mailcow-dockerized/data/assets/ssl/key.pem \
  && cd /opt/mailcow-dockerized && docker compose restart nginx-mailcow >> /var/log/step-renew.log 2>&1

# Guacamole 인증서 — 6시간마다 (5분 오프셋)
5 */6 * * * root step ca renew /home/test/guacamole/nginx/certs/guac.crt /home/test/guacamole/nginx/certs/guac.key --force >> /var/log/step-renew.log 2>&1 \
  && cd /home/test/guacamole && docker compose restart guac-nginx >> /var/log/step-renew.log 2>&1

# 재부팅 시 (지연 후 동일 작업 재실행)
@reboot root sleep 30 && cd /opt/step-ca && step ca renew certs/mail.crt certs/mail.key --force >> /var/log/step-renew.log 2>&1 \
  && cp certs/mail.crt /opt/mailcow-dockerized/data/assets/ssl/cert.pem \
  && cp certs/mail.key /opt/mailcow-dockerized/data/assets/ssl/key.pem \
  && cd /opt/mailcow-dockerized && docker compose restart nginx-mailcow >> /var/log/step-renew.log 2>&1

@reboot root sleep 40 && step ca renew /home/test/guacamole/nginx/certs/guac.crt /home/test/guacamole/nginx/certs/guac.key --force >> /var/log/step-renew.log 2>&1 \
  && cd /home/test/guacamole && docker compose restart guac-nginx >> /var/log/step-renew.log 2>&1
```

인증서 원본은 `/opt/step-ca/certs/mail.crt`·`mail.key`에 있고, Mailcow용은 `mailcow-dockerized/data/assets/ssl/`로, Guacamole용은 `/home/test/guacamole/nginx/certs/`로 각각 복사된 뒤 해당 컨테이너(`nginx-mailcow`, `guac-nginx`)가 재시작됩니다. 로그는 `/var/log/step-renew.log`에 누적됩니다.

설치 스크립트: [`scripts/install_cron_renewal.sh`](./scripts/install_cron_renewal.sh) — 위 4개 cron 항목을 `/etc/cron.d/step-renew`에 그대로 설치합니다.

## 4. 최초 발급 (참고 절차)

```sh
# step CLI 설치 (클라이언트)
curl -fsSL https://raw.githubusercontent.com/smallstep/cli/master/scripts/install.sh | sudo bash -s -- -y

# CA 루트 지문(fingerprint)로 부트스트랩
step ca bootstrap --ca-url https://192.168.100.20:9000 --fingerprint <CA_FINGERPRINT>

# 인증서 최초 발급
step ca certificate mail.example.com /opt/step-ca/certs/mail.crt /opt/step-ca/certs/mail.key
step ca certificate mail.example.com /home/test/guacamole/nginx/certs/guac.crt /home/test/guacamole/nginx/certs/guac.key
```

`<CA_FINGERPRINT>`는 step-ca 최초 구축 시 1회 생성되는 값으로, 팀 시크릿 저장소에서 관리합니다 — [SECURITY.md](../../SECURITY.md) 참고.
