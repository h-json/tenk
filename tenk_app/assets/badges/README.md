# 배지 아이콘 (번들 자산)

노출 지점: 챌린지 상세의 [ChallengeBadgesRow](../../lib/presentation/challenge/widgets/challenge_badges.dart)
· 획득 축하 모달 [badge_celebration_dialog.dart](../../lib/presentation/challenge/widgets/badge_celebration_dialog.dart)
· 결과 카드의 배지 row. **별도 '배지 화면' 은 없다** (배지는 챌린지에 귀속되고 획득한 것만 보인다).

모델: [../../lib/data/badge/badge.dart](../../lib/data/badge/badge.dart)

## 파일 (9개)

```
streak_3.png     streak_7.png     streak_14.png     streak_30.png
no_spend_3.png   no_spend_7.png   no_spend_14.png   no_spend_30.png
challenge_success.png
```

서버 `badge.icon_path` (예: `/badges/streak_3.png`) 와 파일명이 1:1 로 맞도록 유지.
배지를 추가할 때 갱신할 네 곳은 CLAUDE.md "배지 카탈로그 변경" 행 참고.

## 사양

- 정사각 1:1, 투명 배경 PNG, **384×384** (화면 최대 표시 크기는 180)
- **여기 있는 파일은 리사이즈 결과물이다.** 1024px 원본은 번들에 들어가지 않는
  [../../assets_src/badges/](../../assets_src/badges/) 에 있고, 다시 만드는 스크립트도 그쪽 README 에 있다.
  원본을 고쳤으면 리사이즈를 다시 돌려 이 디렉토리를 갱신할 것.
- 색은 단계별 사다리(브론즈 3 → 실버 7 → 골드 14 → 주얼골드 30, 성공=금 트로피)를 따른다.
  획득 모달의 글로우·파티클 색이 이걸 그대로 따라가므로
  ([badge_style.dart](../../lib/presentation/challenge/widgets/badge_style.dart)) 색을 바꾸면 그쪽도 함께.

## 파일이 없을 때

`Image.asset` 의 `errorBuilder` 가 트로피 아이콘으로 폴백한다 — 개발 중 비어 있어도 화면은 동작.
