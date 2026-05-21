# 배지 아이콘

화면 코드: [../../lib/presentation/badge/badge_list_screen.dart](../../lib/presentation/badge/badge_list_screen.dart)
카탈로그: [../../lib/data/badge/badge.dart](../../lib/data/badge/badge.dart) `badgeCatalog`

## 필요한 파일 (9개, PNG 권장)

```
streak_3.png
streak_7.png
streak_14.png
streak_30.png
no_spend_3.png
no_spend_7.png
no_spend_14.png
no_spend_30.png
challenge_success.png
```

서버 `badge.icon_path` (예: `/badges/streak_3.png`) 와 파일명이 1:1로 맞도록 유지.
새 배지를 추가할 때는 `docs/schema.sql` 의 INSERT, `badgeCatalog`, 그리고 이 디렉토리의 자산
세 곳을 같이 갱신할 것.

## 권장 사양

- 정사각 (1:1) — 그리드와 상세 시트 모두 정사각으로 렌더
- 투명 배경 PNG, 약 256×256 이상 (Retina 대응)
- 잠금 상태는 화면이 자동으로 grayscale + 자물쇠 오버레이를 입히므로 컬러 원본 1장만 있으면 됨

## 파일이 없을 때

`Image.asset` 의 `errorBuilder` 가 트로피 아이콘으로 폴백한다 — 개발 중 비어 있어도 화면은 그대로 동작.
production 배포 전에 9개 다 채워질 것을 가정.
