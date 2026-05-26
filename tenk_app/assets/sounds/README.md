# 사운드 자산

녹화·UI 효과음을 두는 곳. `audioplayers` 가 `AssetSource('sounds/<file>')` 형태로 참조.

## record_start.mp3

녹화가 실제로 시작되는 순간 1회 재생. royalty-free 효과음 (사용자가 직접 다운로드).

변경 이력:
- 1차: 1200Hz 순수 sine wave 합성 — "기계음 같다" 피드백
- 2차: 종소리 chime 합성 (1000Hz + 1500/2200Hz 하모닉, 280ms) — "합성음 같다" 피드백
- 3차: 두 음 ascending ding 합성 (800Hz→1200Hz, 180ms) — 합성음 인상 잔존
- 4차 (현재): royalty-free 효과음 MP3 채택

**교체 방법**: 아래 사이트 중 한 곳에서 다른 효과음(WAV/MP3) 받아 같은 파일명
(`record_start.mp3`) 으로 덮어쓰면 됨. 확장자가 다르면 [amount_camera_screen.dart](../../lib/presentation/amount/amount_camera_screen.dart)
의 `AssetSource('sounds/record_start.<ext>')` 두 곳(`setSource` + `play`)도 같이 갱신.

royalty-free 효과음 사이트:
- [freesound.org](https://freesound.org) — CC0/CC-BY 대량. 출처 표기 필요할 수 있음
- [pixabay.com/sound-effects](https://pixabay.com/sound-effects) — 무료, 출처 표기 불요
- [mixkit.co/free-sound-effects](https://mixkit.co/free-sound-effects) — 큐레이션 양질
- [zapsplat.com](https://zapsplat.com) — 무료 (계정 가입 필요, 출처 표기 권장)
- [soundbible.com](https://soundbible.com) — 카메라 셔터 클래식

짧을수록 좋음 (~100~300ms). 길면 녹화 시작 후 시각/햅틱 시그널과 어긋남.

Flutter 는 자산 변경 시 hot reload 안 됨 — 앱 stop 후 `flutter run` 으로 재시작 필요.
