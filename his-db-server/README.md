[← 전체 구성으로 돌아가기](../README.md)

# HIS-DB-Server (192.168.100.50) — MariaDB (OpenEMR Test DB, Ubuntu 22.04)

## 1. 시스템 정보

| 항목 | 값 |
|---|---|
| Hostname | HIS-DB-Sever (원문 그대로 — Server 오탈자 있음) |
| OS | Ubuntu 22.04.5 LTS |
| MariaDB | 10.6.23 (`mariadb.service`, active) |
| IP | 192.168.100.50/24 |
| 방화벽 | 비활성 (`ufw`/iptables 정책 전부 ACCEPT) |
| 3306 리스닝 | 0.0.0.0:3306 — 전체 인터페이스에 바인딩된 상태 |
| node_exporter | 9100 (Prometheus 메트릭) |
| cron | `php` 항목 존재 (PHP 세션 GC) |

현재 방화벽이 꺼져 있고 MariaDB가 모든 인터페이스에 노출되어 있어, 서버팜 대역(192.168.100.0/24) 밖에서도 3306에 접근 가능한 상태입니다. 아래 2~3절 하드닝 절차 적용을 권장합니다.

## 2. 설치 (신규 구축 시)

```sh
./scripts/install_mariadb.sh
```

## 3. 하드닝

```sh
./scripts/harden_mariadb.sh
```

수행 내용:
- `bind-address = 192.168.100.50` 로 제한 (현재 0.0.0.0)
- `ufw` 활성화 + 3306을 192.168.100.0/24 로만 허용
- `mysql_secure_installation` 상당 항목(익명 계정/원격 root 제거 등) 점검 안내 출력

## 4. OpenEMR용 DB/계정

```sql
CREATE DATABASE openemr_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'openemr'@'192.168.100.%' IDENTIFIED BY '<시크릿 저장소 참조>';
GRANT ALL PRIVILEGES ON openemr_test.* TO 'openemr'@'192.168.100.%';
FLUSH PRIVILEGES;
```

> 참고: 수행계획서 기준으로 실제 운영 OpenEMR DB는 AWS 측 K8s NodePort MySQL(+EFS)이며, 이 HIS-DB-Server는 온프레미스 테스트/검증용 DB입니다. 운영 DB와 혼동하지 않도록 "Test DB" 표기를 유지해 주세요.
