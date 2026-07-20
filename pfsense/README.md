[← 전체 구성으로 돌아가기](../README.md)

# pfSense (방화벽 / VPN 게이트웨이)

> 시크릿(PSK 등)은 포함하지 않았습니다 — [SECURITY.md](../SECURITY.md) 참고.

## 1. 개요

| 항목 | 값 |
|---|---|
| 버전 | pfSense CE 23.3 |
| Hostname | pfSense.home.arpa |
| WAN | le0, 192.168.45.2/24, GW `WANGW`(192.168.45.1) |
| LAN | le1, 10.10.10.1/24 |
| OPT1 | ipsec1 — AWS_VGW1 (S2S VPN) |
| OPT2 | ovpns1 — OpenVPN 서버 인터페이스 |
| OPT3 | ipsec2 — Azure VPN DR |
| DNS 서버 | 192.168.100.10 (ARMYADCA) |
| NTP | 2.pfsense.pool.ntp.org |
| SSH | 활성화 |
| Timezone | Asia/Seoul |

## 2. DHCP (LAN)

- 대역: `10.10.10.10` ~ `10.10.10.245` (업무망 PC 6대는 이 범위 내 고정/예약 IP 권장 — [workstations](../workstations/README.md) 참고)

## 3. 정적 라우팅 (서버팜 대역 → VyOS)

pfSense LAN 뒤에 [VyOS(R1, 10.10.10.2)](../vyos-router/README.md)가 있고, 실제 서버팜 대역은 VyOS가 라우팅합니다.

```
목적지 네트워크            게이트웨이
192.168.100.0/24    →     VyOS_GW (10.10.10.2)   # AD/Mail/DB/릴레이서버 대역
192.168.200.0/24    →     VyOS_GW (10.10.10.2)
192.168.4.0/24       →     VyOS_GW (10.10.10.2)
```

GUI 경로: **System → Routing → Static Routes**

## 4. Site-to-Site VPN (IPsec, IKEv2)

두 개의 IPsec 터널이 구성되어 있으며 모두 VTI(라우팅 기반) 모드입니다.

| 구분 | AWS | Azure(DR) |
|---|---|---|
| Phase1 설명 | `AWS_VPN` | `AZURE_vpn_dr` |
| Local ID | 211.37.27.58 (pfSense WAN Public IP) | 211.37.27.58 |
| Remote Gateway | 13.209.213.163 (AWS VPN Gateway) | 20.249.209.119 (Azure VPN Gateway) |
| IKE 버전 | IKEv2 | IKEv2 |
| 암호화 | AES-128, SHA256, DH Group 14 | AES-256, SHA256, DH Group 14 |
| Lifetime | 28800초 | 28800초 |
| NAT-T | force | on |
| DPD | delay 3 / maxfail 5 | delay 10 / maxfail 5 |
| PSK | 별도 채널로 관리 (본 문서 미포함) | 별도 채널로 관리 |
| Phase2 모드 | VTI, ESP, AES-128/128GCM+SHA256, PFS group 14 | VTI, ESP, AES-256+SHA256, PFS group 14 |
| Tunnel(VTI) 내부 IP | Local 169.254.254.126 / Remote 169.254.254.125 | Local 169.254.21.1 / Remote 169.254.21.2 |

설정 경로: **VPN → IPsec → Tunnels**. PSK는 GUI에서 직접 재입력해야 하며 config.xml을 그대로 복사-배포하지 않는 것을 권장합니다(재해복구 시에는 시크릿 저장소에서 값을 가져와 수동 입력).

## 5. OpenVPN 원격 접속 서버 (재택근무자용)

| 항목 | 값 |
|---|---|
| 설명 | `team_vpn` |
| 모드 | server_tls_user (TLS + 사용자 인증) |
| 프로토콜/포트 | TCP 1194 |
| 인증방식 | Local Database, Username-as-Common-Name |
| Data Cipher | AES-256-GCM, AES-128-GCM, CHACHA20-POLY1305 (fallback: AES-256-CBC) |
| Digest | SHA256 |
| Tunnel Network | 172.168.0.0/24 |
| 클라이언트→서버 도달 가능 대역(Local Network) | 192.168.100.0/24, 192.168.200.0/24, 10.0.0.0/16(AWS VPC1), 10.1.0.0/16(AWS VPC2), 10.100.0.0/16(Azure DR) |
| DNS Push | 192.168.100.10 (ARMYADCA) |
| Client-to-Client | 예 |
| Dynamic IP | 예 (재택 사용자 유동 IP 허용) |
| Keepalive | ping 10s / timeout 60s |

배포 시 체크리스트:
1. **System → Cert Manager**에서 CA 및 서버 인증서 재발급(또는 안전하게 이전)
2. 사용자별 클라이언트 인증서는 `openvpn-client-export` 패키지로 개별 발급·배포 (6절 참고)
3. Unbound(DNS Resolver)의 ACL에 OpenVPN 대역(`172.168.0.0/24`) 허용이 포함되어 있는지 확인 (**Services → DNS Resolver → Access Lists**, ACL명 `open_vpn`)

## 6. 설치된 pfSense 패키지

| 패키지 | 버전 | 용도 | 설치 |
|---|---|---|---|
| FRR | 2.0.2_1 | BGP/OSPF 라우팅 데몬 (VyOS·AWS TGW 등과의 동적 라우팅 대비) | `System → Package Manager → Available Packages` 에서 `FRR` 검색 후 Install |
| OpenVPN Client Export Utility | 1.9.2 | OpenVPN 클라이언트 설정 번들(Windows/Mac) 내보내기 | 동일 경로에서 `openvpn-client-export` 검색 후 Install |

CLI로도 설치 가능합니다(pfSense 콘솔 SSH 접속 후): [`scripts/install_packages.sh`](./scripts/install_packages.sh)

```sh
sh scripts/install_packages.sh
```

## 7. 방화벽 규칙 요약

| 인터페이스 | 목적 | 요약 |
|---|---|---|
| WAN | OpenVPN 진입 허용 | UDP/TCP 1194 → WAN IP (`OpenVPN team_vpn wizard`로 자동 생성) |
| WAN | 관리용 | 192.168.45.0/24 → any, TCP |
| LAN | 서버팜 통신 | 192.168.100.0/24, 192.168.200.0/24 → any 허용 |
| LAN | 기본 허용 | `Default allow LAN to any rule` / IPv6 동일 |
| enc0(IPsec) | S2S VPN 트래픽 | any → any, TCP/UDP |
| OpenVPN | 원격접속 트래픽 | any → any (`OpenVPN team_vpn wizard`) |

> 참고: 규칙 대부분이 "허용" 위주로 넓게 열려 있습니다. 병원 민감정보를 다루는 환경 특성상, 실제 운영 전환 시 목적지 포트/서비스 단위로 규칙을 좁히는 것을 권장합니다 ([TODO.md](../TODO.md) 참고).

## 8. 로그 전달 (syslog → 릴레이서버)

```
System → Status/Logging → Settings
Remote Syslog Server: 192.168.100.100:5140
Source Address: LAN
Transport: UDP, RFC3164
Log Config Changes: 활성화
```

릴레이서버 쪽 수신 설정은 [`relay-server/README.md`](../relay-server/README.md) 참고.
