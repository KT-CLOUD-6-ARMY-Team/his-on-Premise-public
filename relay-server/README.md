[← 전체 구성으로 돌아가기](../README.md)

# 릴레이서버 (192.168.100.100) — rsyslog (pfSense 로그 수신 → Kafka 포워딩)

## 1. 시스템 정보

| 항목 | 값 |
|---|---|
| Hostname | test-virtual-machine (원문 그대로 — "릴레이서버"는 역할명) |
| OS | Ubuntu 22.04.5 LTS |
| IP | 192.168.100.100/24 |
| rsyslog-kafka 패키지 | 설치됨 (`8.2112.0-2ubuntu2.2`) |
| rsyslog.d 파일 | `10-relay.conf`, `20-ufw.conf`, `50-default.conf` |
| apache2 | 실행 중, `/var/www/html`에 `index.html`, `jwks.json`, `openemr/`(777, www-data) 서빙 |

## 2. rsyslog — pfSense 로그 수신 + Kafka 포워딩 (`10-relay.conf`)

pfSense가 UDP 5140으로 보낸 로그를 받아서, 로그 종류별로 4개의 Kafka 토픽으로 분기해서 전달합니다. 동시에 로컬 파일에도 그대로 남깁니다.

```
module(load="imudp")
input(type="imudp" port="5140")
module(load="/usr/lib/x86_64-linux-gnu/rsyslog/omkafka.so")
```

**Kafka 브로커**: `a45121fd7e81f48029ea165552856f1c-2b9c36bf124aa15b.elb.ap-northeast-2.amazonaws.com:9092` (AWS 측 ELB 경유, EKS 자체운영 Kafka)

| `$programname` | 판별 대상 | 로컬 파일 | Kafka 토픽 |
|---|---|---|---|
| `filterlog` | pfSense 방화벽 탐지 로그 | `/var/log/pf-firewall-test.json` | `pf-firewall-log` |
| `openvpn` | OpenVPN 접속 로그(사용자명/IP/이벤트 파싱) | `/var/log/pf-openvpn-test.json` | `pf-vpn-openvpn-log` |
| `php-fpm` | pfSense 설정 변경/접속 로그 | `/var/log/pf-config-test.json` | `pf-config-log` |
| (그 외 전부) | 나머지 원본 그대로 | - | `pf-etc-log` |

각 토픽은 JSON 템플릿(`firewall_json`, `openvpn_json`, `config_json`, `etc_json`)으로 변환되어 전달되며, `compression.codec=snappy` 옵션이 적용되어 있습니다. 방화벽 로그는 정규식으로 인터페이스/액션/방향/프로토콜/출발지·목적지 IP·포트까지 필드 단위로 파싱해서 보냅니다.

## 3. UFW 로그 (`20-ufw.conf`)

```
:msg,contains,"[UFW " /var/log/ufw.log
```

UFW가 남긴 커널 로그를 `/var/log/ufw.log`로 분리 저장합니다 (Kafka 포워딩 대상은 아님).

## 4. 설치

```sh
./scripts/install_rsyslog_relay.sh
```

## 5. apache2 + OpenEMR + JWKS

`/var/www/html`에서 apache2가 80번 포트로 아래 콘텐츠를 서빙 중입니다.

- `jwks.json` — JWT 서명 검증에 쓰이는 JSON Web Key Set 파일입니다. 프로젝트의 AD-AWS 계정 자동 동기화 인증 흐름에서 온프레미스가 발급하는 토큰을 AWS(API Gateway/Lambda authorizer 등)가 검증할 때 참조하는 공개키 엔드포인트로 보입니다 — [ARMYADCA DNS 포워더 문서](../ad-dns-armyadca/README.md#5-dns-존)의 `execute-api.ap-northeast-2.amazonaws.com` 포워딩 존과 연결지어 볼 필요가 있습니다.
- `openemr/` 디렉토리(777 권한, www-data 소유) — OpenEMR 관련 정적 자산 또는 테스트 배포입니다.

정확한 용도는 [TODO.md](../TODO.md)에서 확인 상태를 관리합니다.

## 6. 방화벽

이 서버는 방화벽이 비활성 상태입니다(서버팜 내부망이라 pfSense가 1차 방어선이긴 하지만, 심층 방어 차원에서 활성화 권장).

```sh
sudo apt install -y ufw
sudo ufw allow from 10.10.10.1 to any port 5140 proto udp
sudo ufw allow 80/tcp    # apache2
sudo ufw allow 22/tcp
sudo ufw allow 9100/tcp
sudo ufw --force enable
```
