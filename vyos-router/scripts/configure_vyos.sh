#!/bin/vbash
# VyOS 코어 라우터 (R1) — 설정 스크립트 (show configuration commands 결과 기반)
source /opt/vyatta/etc/functions/script-template

configure

# 1. 인터페이스 IP 설정
set interfaces ethernet eth0 address '10.10.10.2/24'    # pfSense LAN 방향(업링크)
set interfaces ethernet eth1 address '192.168.100.1/24' # Server_Zone (VLAN 100)
set interfaces ethernet eth2 address '192.168.200.1/24' # PC_Zone (VLAN 200)

# 2. 기본 게이트웨이
set protocols static route 0.0.0.0/0 next-hop 10.10.10.1

# 3. 리턴 트래픽용 정적 라우팅
set protocols static route 10.8.0.0/24 next-hop 10.10.10.1      # OpenVPN 대역 리턴 (172.168.0.0/24와 값 대조 — TODO.md 참고)
set protocols static route 192.168.45.0/24 next-hop 10.10.10.1  # pfSense WAN 관리망 리턴

# Azure DR 라우팅 (TODO.md 참고)
# set protocols static route 10.100.0.0/16 next-hop 10.10.10.1

# 192.168.4.0/24 대역 인터페이스 (TODO.md 참고)
# set interfaces ethernet eth3 address '192.168.4.1/24'

# 4. SSH 관리
set service ssh port 22

# 5. 적용 및 저장
commit
save
exit
