#!/bin/sh
# pfSense CE 23.3 — 콘솔(SSH) 접속 후 실행
# 패키지 설치는 GUI(System > Package Manager)로도 가능하지만, 재해복구 시 콘솔에서 빠르게 적용하기 위한 스크립트입니다.
set -e

echo "[1/2] FRR (BGP/OSPF 라우팅 데몬 — VyOS/AWS TGW 동적 라우팅 대비)"
pkg-static install -y pfSense-pkg-frr

echo "[2/2] OpenVPN Client Export Utility (클라이언트 설정 번들 내보내기)"
pkg-static install -y pfSense-pkg-openvpn-client-export

echo "완료. IPsec 터널(AWS/Azure)·OpenVPN 서버·정적 라우팅·방화벽 규칙은 GUI에서 설정합니다 — README.md 참고."
echo "PSK 등 시크릿은 이 스크립트에 포함하지 않았습니다. SECURITY.md 를 확인하세요."
