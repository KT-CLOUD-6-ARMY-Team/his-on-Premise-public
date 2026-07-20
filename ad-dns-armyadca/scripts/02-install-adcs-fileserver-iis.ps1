# ARMYADCA — AD CS(사설 Enterprise Root CA) + File Server + IIS + RSAT
# 01-install-adds-dns.ps1 재부팅 완료 후 실행

# AD CS 역할
Install-WindowsFeature -Name AD-Certificate, ADCS-Cert-Authority, ADCS-Web-Enrollment -IncludeManagementTools

Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCa `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -KeyLength 2048 -HashAlgorithmName SHA256 `
  -ValidityPeriod Years -ValidityPeriodUnits 10
Install-AdcsWebEnrollment

# File Server
Install-WindowsFeature -Name FS-FileServer, Storage-Services -IncludeManagementTools

# IIS (AD CS 웹 등록 페이지가 이 위에서 동작)
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Scripting-Tools -IncludeManagementTools

# RSAT (관리 도구)
Install-WindowsFeature -Name RSAT-AD-Tools, RSAT-ADCS, RSAT-DNS-Server, GPMC -IncludeManagementTools

Write-Host "완료. OU 구조는 03-create-ou-structure.ps1, DNS 포워더는 04-add-dns-forwarders.ps1 을 실행하세요."
