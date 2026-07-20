[← 전체 구성으로 돌아가기](./README.md)

# 보안 주의사항 및 시크릿 관리 원칙

## 원본 덤프에 포함된 시크릿 (필독)

원본 `pfsense_config.xml`에는 다음과 같은 실제 시크릿이 평문/Base64로 포함되어 있습니다. **이 리포지토리 어디에도(사내 Private 리포지토리라도) 커밋하지 마세요.**

- AWS Site-to-Site VPN, Azure VPN Gateway IPsec Pre-Shared Key(PSK) 2건
- OpenVPN 서버 인증서 및 사용자별 클라이언트 인증서의 개인키(RSA Private Key, PEM)
- pfSense 로컬 계정 bcrypt 해시 6건

이 값들은 별도의 비공개 채널(팀 내 1:1 전달, 사내 시크릿 저장소 등)로만 공유하고, 문서에는 "어디서 관리되는지"와 "교체 주기"만 기록하는 것을 권장합니다.

## 시크릿 관리 원칙

이 문서 및 GitLab 리포지토리에는 아래 값을 **절대 평문으로 커밋하지 않습니다.**

| 시크릿 | 위치(원본) | 권장 관리 방식 |
|---|---|---|
| AWS/Azure IPsec PSK | pfSense config.xml | 팀 시크릿 저장소 + pfSense GUI 직접 입력 |
| OpenVPN 서버/클라이언트 개인키 | pfSense Cert Manager | pfSense Cert Manager 내 보관, 필요 시 재발급 |
| pfSense 로컬 계정 비밀번호 | pfSense config.xml (bcrypt) | 계정별 개별 관리, 정기 로테이션 |
| AD 서비스 계정 암호, DB 계정 암호 | - | 팀 시크릿 저장소 |

## .gitignore 권장 설정

GitLab에 올릴 때는 원본 덤프 파일 자체를 제외 목록에 추가하는 것을 권장합니다.

```gitignore
pfsense_config.xml
*_decoded.txt
server_inventory_*.txt
*.pem
*.key
```

`server_inventory_*.txt`(mail.example.com/HIS-DB-Server/릴레이서버 서버 인벤토리 덤프)는 비밀번호 자체는 없지만 iptables 규칙·내부 IP·크론 스케줄 등 공격 표면 정보를 담고 있어 원본은 커밋하지 않고, 이 문서에 요약된 내용만 남깁니다.
