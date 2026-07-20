# ARMYADCA — AWS/Azure 조건부 포워딩 존 등록
# <AWS Route53 Resolver Inbound Endpoint IP>, <Azure Private DNS Resolver Inbound IP> 는
# Terraform 출력값(각 클라우드 Resolver 엔드포인트)으로 실행 전 채워 넣으세요.

param(
    [Parameter(Mandatory=$true)][string]$AwsResolverInboundIp,
    [Parameter(Mandatory=$true)][string]$AzureResolverInboundIp
)

# AWS 이름 해석 (온프레미스 -> AWS 방향)
Add-DnsServerConditionalForwarderZone -Name "amazonaws.com" -MasterServers $AwsResolverInboundIp
Add-DnsServerConditionalForwarderZone -Name "execute-api.ap-northeast-2.amazonaws.com" -MasterServers $AwsResolverInboundIp
Add-DnsServerConditionalForwarderZone -Name "compute.internal" -MasterServers $AwsResolverInboundIp

# Azure 이름 해석 (온프레미스 -> Azure 방향. Azure -> 온프레미스 역방향은 구성하지 않음: 비대칭 구조)
Add-DnsServerConditionalForwarderZone -Name "azurecontainerapps.io" -MasterServers $AzureResolverInboundIp
Add-DnsServerConditionalForwarderZone -Name "azurecr.io" -MasterServers $AzureResolverInboundIp
Add-DnsServerConditionalForwarderZone -Name "privatelink.azurecr.io" -MasterServers $AzureResolverInboundIp

Write-Host "완료. army.local 정방향/100.168.192.in-addr.arpa 역방향 존은 AD DS 설치 시 자동 생성됩니다."
