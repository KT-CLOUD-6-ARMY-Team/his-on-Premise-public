# 업무망 PC — army.local 도메인 조인
# 직군에 맞는 OU 경로로 조인합니다. $OU 값을 대상 PC의 직군에 맞게 바꿔서 실행하세요.
# 사용 가능한 OU: 의사 / 간호사 / 사무직 / 개발팀 (모두 OU=병원_임직원,DC=army,DC=local 하위)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("의사","간호사","사무직","개발팀")]
    [string]$Role
)

$OUPath = "OU=$Role,OU=병원_임직원,DC=army,DC=local"

Add-Computer -DomainName "army.local" -OUPath $OUPath -Credential (Get-Credential) -Restart
