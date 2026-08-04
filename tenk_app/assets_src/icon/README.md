# TenK 로고 · 런처 아이콘 (번들 제외)

앱 아이콘과 로고 마크의 **원본이자 생성기**. 이 디렉토리는 `pubspec.yaml` 의
`flutter.assets` 에 등록돼 있지 않아 **APK/AAB 에 포함되지 않는다** — 산출물이 Android
`res/` 와 iOS `Assets.xcassets` 로 직접 들어가기 때문이다.

## 마크

**`10`** — 세로획+깃발이 `1`, 오른쪽 링이 `0` 이면서 **예산 게이지**다. 옅은 트랙(완전한
원)이 갭을 메워 `0` 으로 읽히고, 그 위에 진한 링이 얹힌다. 바탕은 흰색, 마크는 민트
(`AppColors.primary` = `#1FBE9C`), 트랙은 `AppColors.logoTrack` = `#C6EEE4`.

**왜 이 형태인가**: 워드마크가 `TenK` 를 담당하므로 마크는 `10` 만 지면 된다 — 세 글자를
두 글자로 줄여 48px(mdpi 런처)에서 형태가 남는다. 링을 게이지로 쓰면 "예산 안에서 쓴다"
는 앱의 본질이 마크 하나에 들어간다. 트랙을 **완전한 원**으로 둔 건 갭만 있는 안이 작은
크기에서 `1C` 로 읽혔기 때문이다. 탈락한 안과 근거는 [decisions.md](../../../docs/decisions.md)
"로고·앱 아이콘" 참고.

## 왜 PNG 를 스크립트로 그리나

`flutter_launcher_icons` 는 **원본 PNG 를 리사이즈만** 하는 도구라 원본 자체는 어차피
손으로 만들어야 하고, 그 원본이 비트맵이면 획 굵기 하나 바꾸는 데 외부 편집기가 필요해진다.
[generate_icons.py](generate_icons.py) 는 마크를 **폰트·외부 자산 없이 기하학으로** 그리므로
① 어느 머신에서든 결과가 같고 ② 상수만 고치면 전 밀도·전 플랫폼이 한 번에 다시 나온다.
그래서 이 스크립트가 **마크 형상의 진실의 원천**이다.

⚠️ **같은 형상을 Flutter 쪽에서도 그린다** — [lib/design/tenk_logo.dart](../../lib/design/tenk_logo.dart)
의 `TenkLogoPainter`. 비율 상수(`STROKE`/`FLAG`/`RING_*`/`GAP_*`)를 바꾸면 **양쪽을 같이
고칠 것.** Dart 가 쓰는 잉크 bbox 는 `--ink` 로 다시 뽑아 `_ink*` 에 반영한다.

**`MARK_EXTENT` 는 그 목록에 없다** — 형상이 아니라 *아이콘 캔버스 안의 여백*을 정하는
값이고, Dart painter 는 주어진 박스를 꽉 채워 그려서 여백 개념이 없다. 이 값만 바꾸면
**Dart 무변경이 정상**이고 잉크 bbox 도 안 변한다.

## 다시 만드는 법

```bash
cd tenk_app/assets_src/icon
pip install Pillow                 # 최초 1회
python generate_icons.py           # 전 산출물 갱신 (아래 표 전부, 41개)
python generate_icons.py --preview # preview.png 만
python generate_icons.py --ink     # Dart painter 용 잉크 bbox 출력
```

| 산출물 | 경로 | 비고 |
|---|---|---|
| Android legacy | `res/mipmap-*/ic_launcher.png` (48~192) | API 25 이하엔 마스크가 없어 **라운드를 구워 넣는다** |
| Android legacy 원형 | `res/mipmap-*/ic_launcher_round.png` | 매니페스트 `android:roundIcon` |
| Android adaptive 전경 | `res/mipmap-*/ic_launcher_foreground.png` (108~432) | 투명 배경 + 마크만 |
| Android themed (API 33+) | `res/mipmap-*/ic_launcher_monochrome.png` | 단색 실루엣 — 시스템이 색을 입힌다 |
| Android adaptive 정의 | `res/mipmap-anydpi-v26/ic_launcher{,_round}.xml` | background/foreground/monochrome |
| Android 바탕색 | `res/values/colors.xml` | `ic_launcher_background` = `#FFFFFF` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` | 기존 `Contents.json` 의 파일명·크기를 그대로 덮어쓴다 |
| Play Console 업로드용 | `play_store_512.png` | 콘솔에 손으로 올리는 것 — 번들 아님 |
| 원본/미리보기 | `icon_master_1024.png`, `preview.png` | 검토용 |

## 함정

- **iOS 아이콘에 알파 채널이 있으면 App Store 업로드가 거부된다.** `build_ios()` 가 RGB 로
  평탄화해 저장하는 이유. 라운드도 굽지 않는다(시스템이 마스킹한다).
- **adaptive icon 의 108dp 캔버스 중 실제로 보이는 건 가운데 72dp** 뿐이다. 전경 마크는
  `MARK_EXTENT * ADAPTIVE_SAFE` 로 줄여 그 안에 들어오게 하고, 그래서 legacy 와 화면상
  크기가 같아진다. 이 배율을 빼면 **원형 런처에서 획이 잘린다.**
- **`Contents.json` 은 건드리지 않는다.** 스크립트가 그걸 읽어 필요한 크기만 그린다. iOS
  아이콘 슬롯을 늘리려면 Xcode 에서 `Contents.json` 을 먼저 갱신하고 다시 돌릴 것.
- **themed(monochrome) 는 트랙까지 같은 색**이라 게이지 두 톤이 사라지고 꽉 찬 링이 된다.
  의도된 동작이다 — 시스템이 단색으로 칠하므로 두 톤을 유지할 방법이 없다.
- **`flutter_launcher_icons` 를 도입하지 말 것.** 생성기가 둘이 되어 산출물이 갈라진다.
