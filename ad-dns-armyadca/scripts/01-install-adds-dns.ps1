# ARMYADCA — AD DS + DNS 역할 설치 및 army.local 포리스트 구성
# 대상: Windows Server 2022 Standard, army.local (NetBIOS ARMY), 단일 DC
# 재부팅이 필요하므로 완료 후 02-install-adcs.ps1 을 이어서 실행하세요.

Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

Install-ADDSForest `
  -DomainName "army.local" `
  -DomainNetbiosName "ARMY" `
  -InstallDns:$true `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "SafeModeAdminPassword 입력")

# 이 명령 실행 후 서버가 자동 재부팅됩니다.
