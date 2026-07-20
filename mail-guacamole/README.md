[← 전체 구성으로 돌아가기](../README.md)

# mail.example.com (192.168.100.20) — 메일 / VDI 게이트웨이 / 내부 인증서

이 서버 하나에 서로 다른 컴포즈 스택 4개와 호스트 네이티브 레거시 스택 1개가 동거하고 있습니다.

| 컴포즈 위치 | 스택 | 컨테이너 |
|---|---|---|
| `/opt/mailcow-dockerized/` | [Mailcow](./mailcow/README.md) (메일) | postfix, dovecot, nginx, mysql, redis, rspamd, sogo, unbound, clamd, watchdog, acme, ofelia, dockerapi, netfilter, olefy, php-fpm, postfix-tlspol — 18개 |
| `/opt/step-ca/` | [내부 CA](./internal-ca/README.md) | `step-ca` (smallstep/step-ca:latest) |
| `/home/test/guacamole/` 와 `/root/guacamole/` (중복 — [TODO.md](../TODO.md)) | [Guacamole](./guacamole/README.md) | `guac-nginx`, `guacamole-web`, `guacamole-postgres`, `guacd` |
| `/home/test/patient-portal-eks/`, `/home/test/app-service/` | 용도 확인 필요 ([TODO.md](../TODO.md)) | `patient-portal-app`, `app` (이미지 `patient-portal-eks-app` 계열, bridge 네트워크, 외부 포트 노출 없음) |

## 레거시: Modoboa

호스트 네이티브 PostgreSQL에 `modoboa`, `amavis`, `spamassassin` 데이터베이스가 남아 있습니다. Mailcow 도입 이전에 쓰던 옛 Modoboa 스택(호스트 네이티브 `amavis.service`, `clamav-daemon.service`, `postgresql@14-main.service`)의 잔재로, Mailcow 자체 컨테이너(`clamd-mailcow`, `rspamd-mailcow`)와 기능이 중복됩니다. 호스트 네이티브 Postfix는 포트 충돌이 없어 이미 내려간 것으로 보이나, `systemctl status postfix`로 확인 후 DB·스캐너 잔재 정리를 권장합니다 ([TODO.md](../TODO.md)).

## 하위 디렉토리

| 디렉토리 | 내용 |
|---|---|
| [`mailcow/`](./mailcow/README.md) | 메일 서버 (Postfix/Dovecot/SOGo/Rspamd/ClamAV, mailcow-dockerized) |
| [`guacamole/`](./guacamole/README.md) | 웹 기반 VDI 접속 게이트웨이 (AWS VDI RDP 프록시) |
| [`internal-ca/`](./internal-ca/README.md) | 내부 인증서 발급/갱신 (step-ca) |
