# ARMYADCA — 조직 구성 단위(OU) 생성
# DC=army,DC=local
# ├─ OU=Domain Controllers (기본 생성됨)
# ├─ OU=Project_Team
# ├─ OU=Service_Accounts
# └─ OU=병원_임직원
#    ├─ OU=개발팀 / 의사 / 간호사 / 사무직 / VDI

New-ADOrganizationalUnit -Name "Project_Team" -Path "DC=army,DC=local"
New-ADOrganizationalUnit -Name "Service_Accounts" -Path "DC=army,DC=local"
New-ADOrganizationalUnit -Name "병원_임직원" -Path "DC=army,DC=local"

$base = "OU=병원_임직원,DC=army,DC=local"
"개발팀", "의사", "간호사", "사무직", "VDI" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $base
}

Write-Host "완료. 역할별(의사/간호사/사무직) GPO를 이 OU 구조에 연결하세요 — workstations/README.md 참고."
