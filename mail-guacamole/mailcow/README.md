[← mail.example.com으로 돌아가기](../README.md) · [← 전체 구성으로 돌아가기](../../README.md)

# Mailcow-dockerized — 메일 서버

## 1. 컨테이너 목록 (18개, mailcowdockerized_mailcow-network)

| 컨테이너 | 이미지 | 호스트 노출 포트 |
|---|---|---|
| `postfix-mailcow` | `ghcr.io/mailcow/postfix:3.7.11-2` | 25, 465, 587 |
| `dovecot-mailcow` | `ghcr.io/mailcow/dovecot:2.3.21.1-2` | 110, 143, 993, 995, 4190, 127.0.0.1:19991→12345 |
| `nginx-mailcow` | `ghcr.io/mailcow/nginx:1.30.2-1` | 80, 443 (웹메일/SOGo/관리자 UI — mailcow 자체 nginx가 직접 종단, 별도 리버스 프록시 없음) |
| `mysql-mailcow` | `mariadb:10.11` | 127.0.0.1:13306→3306 (로컬 전용) |
| `redis-mailcow` | `redis:7.4.6-alpine` | 127.0.0.1:7654→6379 (로컬 전용) |
| `rspamd-mailcow` | `ghcr.io/mailcow/rspamd:3.14.3-1` | 미노출 (스팸 필터링) |
| `sogo-mailcow` | `ghcr.io/mailcow/sogo:5.12.8-1` | 미노출 (웹메일 백엔드, nginx가 프록시) |
| `clamd-mailcow` | `ghcr.io/mailcow/clamd:1.71` | 미노출 (바이러스 스캔) |
| `unbound-mailcow` | `ghcr.io/mailcow/unbound:1.25.1-1` | 미노출 (mailcow 내부 DNS 리졸버) |
| `php-fpm-mailcow` | `ghcr.io/mailcow/phpfpm:8.2.29-2` | 미노출 (내부 9000 — step-ca의 9000과는 별개 네트워크 네임스페이스) |
| `memcached-mailcow` | `memcached:alpine` | 미노출 |
| `watchdog-mailcow` | `ghcr.io/mailcow/watchdog:2.11` | 헬스체크 |
| `acme-mailcow` | `ghcr.io/mailcow/acme:1.97` | 아래 2절 참고 |
| `ofelia-mailcow` | `mcuadros/ofelia:latest` | 내부 cron 스케줄러 (mailcow 자체 정기 작업용) |
| `dockerapi-mailcow` | `ghcr.io/mailcow/dockerapi:2.12` | 관리 API |
| `netfilter-mailcow` | `ghcr.io/mailcow/netfilter:1.64` | host 네트워크 — iptables `MAILCOW` 체인을 만드는 주체 |
| `olefy-mailcow` | `ghcr.io/mailcow/olefy:1.15` | 첨부파일 미리보기(LibreOffice 변환) |
| `postfix-tlspol-mailcow` | `ghcr.io/mailcow/postfix-tlspol:1.8.23` | Postfix TLS 정책 |

## 2. 설치

```sh
./scripts/install_mailcow.sh
```

## 3. 인증서 (트러블슈팅 #8)

**겪은 문제**: mail.example.com은 사설 도메인이라 Let's Encrypt 인증(HTTP-01/DNS-01) 자체가 불가능한데, `acme-mailcow` 컨테이너가 자동 발급을 계속 시도해 실패를 반복했습니다.

**해결**: `mailcow.conf`에서 `SKIP_LETS_ENCRYPT=y`로 설정하고, [내부 CA(step-ca)](../internal-ca/README.md)가 발급한 인증서를 `docker-compose.yml`에 정의된 인증서 경로(`mailcow-dockerized/data/assets/ssl/cert.pem`, `key.pem`)에 배치합니다.

인증서 갱신은 [내부 CA 문서](../internal-ca/README.md)의 cron 항목이 담당합니다 — `mail.crt`/`mail.key`를 갱신한 뒤 이 디렉토리에 복사하고 `nginx-mailcow`를 재시작합니다. `mailcow.conf`의 `SKIP_LETS_ENCRYPT` 값과 `acme-mailcow` 실행 상태는 [TODO.md](../../TODO.md)에서 확인 상태를 관리합니다.

## 4. 레거시: Modoboa

호스트 네이티브 PostgreSQL에 `modoboa`, `amavis`, `spamassassin` 데이터베이스가 남아 있습니다. Mailcow 도입 이전에는 Modoboa(Postfix+Dovecot+Amavis+SpamAssassin+PostgreSQL 조합의 오픈소스 메일 관리 플랫폼)를 네이티브로 운영하다가 Mailcow로 전환한 것으로 보이며, DB와 스캐너(Amavis/SpamAssassin/ClamAV 데몬)가 완전히 정리되지 않고 남아있습니다. 호스트 네이티브 Postfix는 포트 충돌이 없는 것으로 보아(25/587/465는 Mailcow 컨테이너가 점유) 이미 내려가 있는 것으로 보이지만, `systemctl status postfix`로 확인 후 잔재 서비스·DB 정리를 권장합니다.

## 5. 방화벽 (ufw)

| 포트 | 용도 | 상태 |
|---|---|---|
| 25/587/465/tcp | SMTP/Submission/SMTPS | ALLOW |
| 993/995/tcp | IMAPS/POP3S | ALLOW |
| 143/110/tcp | IMAP/POP3(평문) | ALLOW — 사내망 전용이면 STARTTLS 강제 권장 |
| 443/tcp | 웹메일/관리 UI | ALLOW |
| 80/tcp | HTTP | DENY (mailcow ACME는 어차피 미사용이므로 문제 없음) |

## 6. 백업

mailcow는 자체 백업 스크립트(`helper-scripts/backup_and_restore.sh`)를 제공합니다. `ofelia-mailcow`가 mailcow 내부 정기 작업을 스케줄링하는 컨테이너이지만, 백업 작업이 등록돼 있는지는 `ofelia.ini`/라벨 설정 확인이 필요합니다.
