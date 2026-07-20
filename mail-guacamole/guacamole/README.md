[← mail.example.com으로 돌아가기](../README.md) · [← 전체 구성으로 돌아가기](../../README.md)

# Guacamole — 웹 기반 VDI 접속 게이트웨이

## 1. 역할

병원 임직원/개발팀이 브라우저만으로 AWS VPC2의 VDI(EC2 Warm Pool, ASG)에 RDP 접속할 수 있게 해주는 게이트웨이입니다. 접속 경로는 `사용자 브라우저 → guac-nginx(HTTPS) → guacamole-web → guacd → RDP(S2S VPN) → AWS VDI`.

## 2. 컨테이너 구성 (guacamole_default 네트워크)

| 컨테이너 | 이미지 | 포트 |
|---|---|---|
| `guac-nginx` | `nginx:stable` | 0.0.0.0:8443→443 (외부 접속 지점, ufw `8443/tcp ALLOW`와 일치) |
| `guacamole-web` | `guacamole/guacamole` | 0.0.0.0:8080→8080 (직접 노출도 되어 있음 — nginx 없이도 접속 가능한 상태) |
| `guacamole-postgres` | `postgres:latest` | 5432 (미노출, 내부 전용) — DB 백엔드는 PostgreSQL |
| `guacd` | `guacamole/guacd` | 4822 (미노출, 내부 전용) |

## 3. 리버스 프록시 하위 경로 빈 화면 문제 (트러블슈팅 #7)

**겪은 문제**: `guac-nginx`가 루트 경로(`/`) 요청을 그대로 `guacamole-web` 컨테이너로 전달했는데, Guacamole 웹앱은 `/guacamole/` 하위 경로 구조로 동작하기 때문에 경로가 어긋나 접속 시 빈 화면만 표시되었습니다.

**해결**: nginx 설정에서 리다이렉트 규칙과 쿠키 경로(`proxy_cookie_path`)를 Guacamole의 하위 경로에 맞춰 정렬했습니다.

```nginx
location / {
    return 301 /guacamole/;
}

location /guacamole/ {
    proxy_pass http://guacamole-web:8080/guacamole/;
    proxy_buffering off;
    proxy_http_version 1.1;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;

    proxy_cookie_path /guacamole/ /guacamole/;
}
```

## 4. 배포 경로

compose 파일은 `/home/test/guacamole/docker-compose.yml`과 `/root/guacamole/docker-compose.yml` 두 곳에 있습니다. [내부 CA 인증서 갱신 cron](../internal-ca/README.md)은 `/home/test/guacamole` 경로를 대상으로 동작하고 있어, 이쪽이 운영 디렉토리입니다. `/root/guacamole`는 [TODO.md](../../TODO.md)에서 정리 여부를 확인 중입니다.

## 5. RDP 연결 대상

RDP 연결 대상은 AWS VPC2의 EC2 VDI(ASG Warm Pool)이며, pfSense S2S VPN 경로를 그대로 사용합니다. 연결 정보(호스트/자격증명)는 Guacamole 관리자 콘솔(`/guacamole/`, 최초 계정 `guacadmin`)에서 등록하고, `guacamole-postgres`에 저장됩니다.

## 6. 인증서

`guac-nginx`(8443→443)가 사용하는 인증서는 mailcow와 동일하게 [내부 CA(step-ca)](../internal-ca/README.md)에서 발급받으며, `/home/test/guacamole/nginx/certs/guac.crt`·`guac.key`에 배치되고 6시간마다 자동 갱신됩니다.
