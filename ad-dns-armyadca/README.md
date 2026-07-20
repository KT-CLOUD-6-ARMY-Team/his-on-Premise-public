[← 전체 구성으로 돌아가기](../README.md)

# ARMYADCA — AD DC / DNS / AD CS / File / IIS (Windows Server 2022)

## 1. 시스템 정보

| 항목 | 값 |
|---|---|
| OS | Windows Server 2022 Standard Evaluation (Build 20348) |
| 호스트명 | ARMYADCA |
| 도메인 | army.local (NetBIOS: ARMY) |
| IP | 192.168.100.10/24, GW 192.168.100.1 |
| DNS(자체) | 127.0.0.1 (자기 자신이 DNS 서버) |
| 가상화 | VMware (System Model: VMware20,1) |
| CPU | 2 vCPU (AMD EPYC 계열, ~3.19GHz) |
| 메모리 | 8GB (Total Physical Memory 8,191MB) |
| 적용 핫픽스 | KB5008882, KB5011497, KB5010523 |

## 2. 설치된 역할/기능 (PowerShell 재현 커맨드)

새 서버에 동일 구성을 재현할 때는 아래 순서로 진행합니다. 스크립트 파일: [`scripts/`](./scripts/) (`01-install-adds-dns.ps1` → 재부팅 → `02-install-adcs-fileserver-iis.ps1` → `03-create-ou-structure.ps1` → `04-add-dns-forwarders.ps1`)

```powershell
# 1) AD DS + DNS 역할 설치
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# 2) 새 포리스트/도메인 구성 (army.local)
Install-ADDSForest `
  -DomainName "army.local" `
  -DomainNetbiosName "ARMY" `
  -InstallDns:$true `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "SafeModeAdminPassword 입력")

# 3) AD CS(인증서 서비스) 역할 설치 — 재부팅 후
Install-WindowsFeature -Name AD-Certificate, ADCS-Cert-Authority, ADCS-Web-Enrollment -IncludeManagementTools

# 4) AD CS 구성 (사설 Enterprise Root CA)
Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCa `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -KeyLength 2048 -HashAlgorithmName SHA256 `
  -ValidityPeriod Years -ValidityPeriodUnits 10
Install-AdcsWebEnrollment

# 5) File Server 역할
Install-WindowsFeature -Name FS-FileServer, Storage-Services -IncludeManagementTools

# 6) IIS(웹서버) — ASP.NET 4.8 포함 (AD CS 웹 등록 페이지가 IIS 위에서 동작)
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Scripting-Tools -IncludeManagementTools

# 7) RSAT (관리 도구)
Install-WindowsFeature -Name RSAT-AD-Tools, RSAT-ADCS, RSAT-DNS-Server, GPMC -IncludeManagementTools
```

위 역할 전부(AD DS, DNS, AD CS[CA+Web Enrollment], File Server, IIS 전체 스택[ASP.NET 4.8, WCF, HTTP Activation 등], GPMC, RSAT 전체, PowerShell 5.1)가 이미 설치되어 있습니다.

## 3. AD 도메인/포리스트 정보

| 항목 | 값 |
|---|---|
| DistinguishedName | DC=army,DC=local |
| Domain SID | S-1-5-21-3704975763-1204896204-187522340 |
| Domain Mode / Forest Mode | Windows2016Domain / Windows2016Forest |
| PDC Emulator / RID Master / Infra Master / Schema Master / Domain Naming Master | 모두 armyADCA.army.local (단일 DC) |
| Global Catalog | armyADCA.army.local |

## 4. 조직 구성 단위 (OU)

```
DC=army,DC=local
├─ OU=Domain Controllers
├─ OU=Project_Team
├─ OU=Service_Accounts
└─ OU=병원_임직원
   ├─ OU=개발팀
   ├─ OU=의사
   ├─ OU=간호사
   ├─ OU=사무직
   └─ OU=VDI
```

재현용 PowerShell:

```powershell
New-ADOrganizationalUnit -Name "Project_Team" -Path "DC=army,DC=local"
New-ADOrganizationalUnit -Name "Service_Accounts" -Path "DC=army,DC=local"
New-ADOrganizationalUnit -Name "병원_임직원" -Path "DC=army,DC=local"
$base = "OU=병원_임직원,DC=army,DC=local"
"개발팀","의사","간호사","사무직","VDI" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $base
}
```

역할별(의사/간호사/사무직) GPO를 이 OU 구조에 연결해 의료진 맞춤형 업무 환경 정책을 적용합니다 ([workstations](../workstations/README.md) 참고).

## 5. DNS 존

| 존 이름 | 타입 | 용도 |
|---|---|---|
| army.local | Primary | 내부 도메인 정방향 존 |
| 100.168.192.in-addr.arpa | Primary (역방향) | 192.168.100.0/24 역방향 조회 |
| amazonaws.com | Forwarder | AWS 서비스 이름 해석 |
| execute-api.ap-northeast-2.amazonaws.com | Forwarder | API Gateway(ldap_api) 해석 |
| compute.internal | Forwarder | AWS 내부 컴퓨트 이름 해석 |
| azurecontainerapps.io / azurecr.io / privatelink.azurecr.io | Forwarder | Azure DR(Container Apps, ACR) 이름 해석 |

이 조건부 포워딩 존들이 architecture_spec의 "Route53 Resolver ↔ onprem_ad 규칙"과 짝을 이뤄 AD·AWS·Azure 간 이름 해석이 상호 연동됩니다. 스크립트: [`scripts/04-add-dns-forwarders.ps1`](./scripts/04-add-dns-forwarders.ps1). 재현 시:

```powershell
Add-DnsServerConditionalForwarderZone -Name "amazonaws.com" -MasterServers <AWS Route53 Resolver Inbound Endpoint IP>
Add-DnsServerConditionalForwarderZone -Name "execute-api.ap-northeast-2.amazonaws.com" -MasterServers <동일>
Add-DnsServerConditionalForwarderZone -Name "azurecr.io" -MasterServers <Azure Private DNS Resolver Inbound IP>
Add-DnsServerConditionalForwarderZone -Name "azurecontainerapps.io" -MasterServers <동일>
Add-DnsServerConditionalForwarderZone -Name "privatelink.azurecr.io" -MasterServers <동일>
```

(포워더 대상 IP는 Terraform 출력값의 Route53 Resolver / Azure Private DNS Resolver 엔드포인트 IP로 채워야 합니다.)
