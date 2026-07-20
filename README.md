# 온프레미스 인프라 구성 및 운영 가이드

병원 하이브리드 클라우드(온프레미스 + AWS + Azure) 프로젝트의 온프레미스 구간 구성·운영 문서입니다. 디렉토리별로 역할을 나눠 정리했고, 각 디렉토리에는 설치 스크립트(`scripts/`)가 함께 들어 있습니다.

> 이 리포지토리를 GitHub/GitLab에 올리기 전 **[SECURITY.md](./SECURITY.md)를 반드시 확인**해 주세요. 더 자세한 절차형 설명은 별도 문서인 [`docs/설치가이드.docx`](./docs/설치가이드.docx)를 참고하세요 (이 README는 참조용 요약, docx는 처음 구축하는 사람이 처음부터 끝까지 따라갈 수 있는 상세 가이드입니다).

## 디렉토리 구성

| 디렉토리 | 대상 |
|---|---|
| [`pfsense/`](./pfsense/README.md) | pfSense CE 23.3 (방화벽/VPN) |
| [`vyos-router/`](./vyos-router/README.md) | VyOS 코어 라우터 (R1) |
| [`ad-dns-armyadca/`](./ad-dns-armyadca/README.md) | ARMYADCA — AD DC/DNS/AD CS/File/IIS |
| [`mail-guacamole/`](./mail-guacamole/README.md) | mail.example.com — Mailcow / Guacamole(VDI) / 내부 CA(step-ca), 3개 하위 디렉토리 |
| [`his-db-server/`](./his-db-server/README.md) | HIS-DB-Server — MariaDB 10.6.23 (OpenEMR Test DB) |
| [`relay-server/`](./relay-server/README.md) | 릴레이서버 — rsyslog → Kafka 포워딩 |
| [`workstations/`](./workstations/README.md) | 업무망 PC ×6 |

부가 문서: [`SECURITY.md`](./SECURITY.md) (시크릿 관리 원칙 · 절대 커밋 금지 목록), [`TODO.md`](./TODO.md) (확인이 필요한 항목), [`docs/설치가이드.docx`](./docs/설치가이드.docx) (상세 설치 가이드 문서)

## 전체 구성 요약

| 호스트 | IP | OS | 역할 |
|---|---|---|---|
| pfSense CE 23.3 | WAN 192.168.45.2 / LAN 10.10.10.1 | pfSense (FreeBSD 기반) | 방화벽, S2S VPN(AWS/Azure), OpenVPN 원격접속, syslog 릴레이 |
| VyOS 코어 라우터 (R1) | 업링크 10.10.10.2 | VyOS | 서버팜·업무망 대역 라우팅 |
| ARMYADCA | 192.168.100.10 | Windows Server 2022 Standard | AD DC, DNS, AD CS(사설 인증서), File Server, IIS |
| mail.example.com | 192.168.100.20 | Ubuntu 22.04.5 LTS | Mailcow(메일) + Guacamole(VDI 접속) + step-ca(내부 CA), 도커 컴포즈 스택 |
| HIS-DB-Sever | 192.168.100.50 | Ubuntu 22.04.5 LTS | MariaDB 10.6.23 (OpenEMR Test DB) |
| 릴레이서버 (test-virtual-machine) | 192.168.100.100 | Ubuntu 22.04.5 LTS | rsyslog(UDP 5140, pfSense 로그 수신) → Kafka 포워딩 |
| 업무망 PC ×6 | 10.10.10.0/24 DHCP 대역 | Windows 10/11 | 병원 임직원 워크스테이션, AD 도메인 조인 |

내부망 연결 흐름: `재택근무자 → OpenVPN(pfSense) → LAN → VyOS(R1) → 서버팜(192.168.100.0/24)`
