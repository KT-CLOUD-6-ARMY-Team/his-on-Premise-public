[← 전체 구성으로 돌아가기](../README.md)

# VyOS 코어 라우터 (R1)

## 1. 역할

[pfSense](../pfsense/README.md) LAN(10.10.10.0/24) 뒤에서 서버팜/업무망 대역을 라우팅하는 내부 코어 라우터입니다.

## 2. 인터페이스 구성

| 인터페이스 | 용도 | IP |
|---|---|---|
| eth0 | pfSense LAN 방향(업링크) | 10.10.10.2/24 |
| eth1 | Server_Zone (VLAN 100, 서버팜) | 192.168.100.1/24 |
| eth2 | PC_Zone (VLAN 200, 업무망 PC) | 192.168.200.1/24 |

pfSense 쪽 정적 라우팅 문서([pfsense/README.md](../pfsense/README.md#3-정적-라우팅-서버팜-대역--vyos))에는 `192.168.4.0/24 → VyOS_GW` 항목도 있습니다. 해당 대역용 인터페이스(eth3 등)는 [TODO.md](../TODO.md)에서 확인 상태를 관리합니다.

## 3. 라우팅

```
set protocols static route 0.0.0.0/0 next-hop 10.10.10.1
set protocols static route 10.8.0.0/24 next-hop 10.10.10.1
set protocols static route 192.168.45.0/24 next-hop 10.10.10.1
```

- 기본 게이트웨이(0.0.0.0/0)는 pfSense LAN(10.10.10.1)입니다.
- `10.8.0.0/24`는 재택근무자 VPN 리턴 트래픽용입니다. [pfSense OpenVPN 문서](../pfsense/README.md#5-openvpn-원격-접속-서버-재택근무자용)의 현재 터널 대역(`172.168.0.0/24`)과 값이 다르니 최신 설정에서 함께 확인해 주세요.
- `192.168.45.0/24`는 pfSense WAN 쪽 관리망 리턴 트래픽용입니다.
- Azure DR(10.100.0.0/16, [pfSense OpenVPN 문서](../pfsense/README.md#5-openvpn-원격-접속-서버-재택근무자용) 참고)로 가는 라우트는 아래와 같이 추가합니다.

```
set protocols static route 10.100.0.0/16 next-hop 10.10.10.1
```

## 4. 설정 스크립트

```sh
./scripts/configure_vyos.sh
```

## 5. SSH 관리

```
set service ssh port 22
```

## 6. 신규 설치 시 참고 (VyOS 이미지가 없는 경우)

```sh
# VyOS ISO 부팅 후
install image
# 이후 설정은 scripts/configure_vyos.sh 참고
```
