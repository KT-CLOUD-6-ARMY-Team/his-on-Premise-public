[← 전체 구성으로 돌아가기](../README.md)

# 업무망 PC (병원 임직원 워크스테이션 ×6)

- OU 배치: 직군에 따라 `OU=의사`, `OU=간호사`, `OU=사무직`, `OU=개발팀` (army.local) 중 하나로 도메인 조인 — OU 구조는 [`ad-dns-armyadca/README.md`](../ad-dns-armyadca/README.md#4-조직-구성-단위-ou) 참고
- 도메인 조인 스크립트: [`scripts/join_domain.ps1`](./scripts/join_domain.ps1)

```powershell
.\scripts\join_domain.ps1 -Role 의사
```

- GPO를 통해 직군별 업무 환경(바탕화면 정책, 소프트웨어 제한, 프린터 매핑 등)을 적용 (수행계획서 "VDI 환경 구성" 항목과 연동)
