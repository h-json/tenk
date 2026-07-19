# 의사결정 회의록 — Tenk

> 주요 기능을 도입/변경할 때의 **의사결정 근거**(회의록). 영구 규칙은 [../CLAUDE.md](../CLAUDE.md), 현재 진행 상태는 [handoff.md](handoff.md)에 있고, 이 문서는 **"왜 이렇게 결정했나"**를 남긴다. **관련 코드를 건드릴 때만** 참고하면 됨.
>
> 수록: ① 기록 수정/촬영 분리 (2026-05-23) ② 결과 카드 (2026-05-26) ③ 영상 내보내기 (2026-05-21). 영상 export 관련 **함정(mpeg4 인코더 / drawtext 한글 회귀)**은 ③ 회의록의 "구현 시 주의사항"에 있다.

---

## 기록 수정/촬영 분리 회의록 (2026-05-23)

> "지출은 영상 필수 / 카메라가 기록 화면에 인라인 / 등록 후 수정 불가" 세 가지를 한 번에 정리한 회의. 회의록 형식이 아니라 사용자 지시 → 명확화 질의 1회 → 합의된 결정의 요약.

### 사용자 요구 (원문 요약)
1. 영상 첨부는 지출/무지출 양쪽 모두 **선택**.
2. 영상 촬영은 기록 화면 안이 아니라 **전용 카메라 화면**.
3. 기록 카드 탭 → **수정 화면** 진입. 내용 + 영상 모두 수정 (영상은 추가/교체/삭제).

### 결정 사항

| # | 항목 | 결정 |
|---|---|---|
| 1 | 지출 영상 | 필수 → **선택**. 백엔드 `AMOUNT_VIDEO_REQUIRED` 에러코드 자체 삭제. `LocalFileStorage.store()` 의 null 가드는 호출자 책임으로 옮기고 들어오면 `INVALID_INPUT` (프로그래머 오류). |
| 2 | 촬영 화면 분리 | 신규 [AmountCameraScreen](../tenk_app/lib/presentation/amount/amount_camera_screen.dart). `Navigator.pop<String>(path)` 로 결과 반환. 사용 안 한 임시 파일은 본인이 정리 (호출자 책임 X). |
| 3 | 영상 첨부 UI 공용 | 신규 [VideoAttachmentSection](../tenk_app/lib/presentation/amount/widgets/video_attachment_section.dart). "없음 → 촬영하기 / 있음 → 다시 촬영 + 삭제" 두 상태만. record + edit 화면 공용. |
| 4 | 수정 화면 진입 | 기록 카드 탭. 기존 카드의 X 삭제 버튼은 **제거** — 삭제는 수정 화면 안의 별도 버튼에서만. |
| 5 | 지출 일시 수정 범위 | **시간만**, 날짜 고정. 백엔드 DTO 는 `LocalTime` 만 받고 기존 spentDt 의 LocalDate 와 결합. 날짜를 바꾸고 싶으면 삭제 후 재등록. (사용자 지시) |
| 6 | 무지출 일시 수정 | 불가. 서버 now() 강제 그대로. 수정 화면에 일시 섹션 자체 숨김. |
| 7 | 영상 액션 표현 | `videoAction: KEEP / REMOVE / REPLACE` enum. REPLACE 면 video part 필수. backend enum + Flutter enum 1:1 매칭. |
| 8 | 배지 재평가 | **안 한다**. 수정에서는 날짜·noSpend 여부가 안 바뀌므로 STREAK/NO_SPEND 가 변할 수 없음. 영상만 바꿔도 마찬가지. |
| 9 | 종료/시작 전 챌린지 | 수정도 record 와 동일하게 `CHALLENGE_ALREADY_FINISHED` / `CHALLENGE_NOT_STARTED` 로 막음. |
| 10 | 응답 형태 | record 는 기존 `AmountRecordResult` 유지, update 는 갱신된 `AmountResponse` 단건. |

### 동기 사유 (왜 이번에 바꾸나)
- **영상 필수 강제는 마찰** — 2초 영상 자체가 부담스러운 사용자가 있어 진입을 가로막고 있었음. export 는 "있는 영상만 합친다" 정책이라 누락이 생겨도 파이프라인은 영향 없음.
- **카메라 인라인은 폼을 무겁게** — 카메라 초기화 실패가 폼 입력 자체를 막는 케이스가 있었음. 단계 분리로 폼 / 촬영을 독립화.
- **수정 불가의 비용 > 구현 비용** — 이미 `Amount.update()` 가 있었고 엔드포인트만 없는 상태였음. 영상 핸들링까지 합쳐도 PUT 하나로 끝남.

### 백엔드 변경 요약
- DTO: 신규 [AmountUpdateRequest](../tenk-backend/src/main/java/com/hjson/tenk/domain/amount/dto/AmountUpdateRequest.java) + `VideoAction` enum.
- 엔드포인트: `PUT /api/challenges/{cid}/amounts/{aid}` (multipart, [AmountController.update](../tenk-backend/src/main/java/com/hjson/tenk/domain/amount/AmountController.java)).
- 서비스: [AmountService.update](../tenk-backend/src/main/java/com/hjson/tenk/domain/amount/AmountService.java) — 소유권/상태 검증 + spentDt 시간 결합 + `applyVideoAction(KEEP/REMOVE/REPLACE)`.
- 엔티티: [Amount.update](../tenk-backend/src/main/java/com/hjson/tenk/domain/amount/Amount.java) 시그니처에 `LocalDateTime spentDt` 추가 (지출만 검증·반영, 무지출은 무시).
- 테스트: `AmountTest` 의 4-arg `update` 호출을 5-arg 로 갱신 + 일시 변경/범위 회귀 2개. `AmountServiceTest` 의 "영상 필수" 케이스 2개 뒤집기 + `update_*` 6개 추가.

### 프론트 변경 요약
- 데이터: [VideoAction enum](../tenk_app/lib/data/amount/amount.dart) + [AmountApi.update](../tenk_app/lib/data/amount/amount_api.dart) (`PUT` multipart).
- 화면: [AmountCameraScreen](../tenk_app/lib/presentation/amount/amount_camera_screen.dart) 신설, [AmountEditScreen](../tenk_app/lib/presentation/amount/amount_edit_screen.dart) 신설, [AmountRecordScreen](../tenk_app/lib/presentation/amount/amount_record_screen.dart) 의 카메라 인라인 제거.
- 공용 위젯: [VideoAttachmentSection](../tenk_app/lib/presentation/amount/widgets/video_attachment_section.dart) (record + edit 공유).
- 챌린지 상세: `_AmountTile` 의 X 삭제 IconButton 제거 + `ListTile.onTap` 으로 수정 진입. `_buildGroupedAmounts` 시그니처에서 `busy` 인자 삭제, `onDelete` → `onEdit` 로 변경.

### Verification 메모
- 백엔드: `./gradlew.bat test --rerun-tasks` 통과.
- Flutter: `flutter analyze` 통과 — 추가 lint 0건.
- E2E: 에뮬레이터에서 영상 없이 지출 기록·수정·삭제·영상 추가/교체/삭제 모두 동작 확인 (2026-05-23). **주의**: 카메라 인라인 제거 + 필드 삭제는 구조적 변경이라 Flutter **hot reload 로는 안 들어감 — hot restart (`R`) 또는 풀 재실행 필수**. 카메라 프리뷰가 폼 안에 보이면 구코드 동작 중이므로 재시작 필요.

### 알려진 갭
- **PUT 엔드포인트 통합 테스트 없음** — 현재 [AmountServiceTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/amount/AmountServiceTest.java) 가 Mockito 단위 테스트라 multipart 파싱·`@Valid`·시큐리티 필터를 거치지 않는다. `AmountController.record/delete` 도 통합 테스트가 없어 컨벤션과는 일관이지만, multipart wiring 회귀를 잡을 가드가 없는 건 사실. 다음에 amount 컨트롤러 만질 일 있으면 [BadgeEventIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeEventIntegrationTest.java) 패턴으로 `AmountControllerIntegrationTest` 추가하는 게 좋음.

---

## 결과 카드 회의록 (2026-05-26)

> 영상 내보내기와는 무관하게 챌린지 확정 후 결과를 1장 카드로 보여주는 기능. 영상 export 와는 별개 도메인이지만 마지막 클립으로 합성하는 옵션도 같이 결정.

### 사용자 요구사항 (원문 요약)
- 챌린지 종료 후 그 챌린지에 대한 결과 카드. 이미지로 저장하기, 내보내기.
- 영상 내보내기 했을 때 제일 마지막에도 결과 카드를 포함시킬 수 있게.

### 결정 사항 (9)
1. **진입점 = finalize 직후 자동 + 챌린지 상세 진입점 둘 다**. 확정 순간엔 페이오프 모먼트로 자동 풀스크린 push, 나중에 공유하려고 다시 볼 수 있게 상세 화면에 카드 한 장 추가.
2. **비율 = 세로 9:16 / 480x864**. 영상 export 해상도와 1:1 — 마지막 정지 카드로 그대로 붙일 수 있고 (스케일링 0), 스토리/릴스 공유 동선과 일치.
3. **영상 export 포함 = 체크박스 (기본 ON)**. export 화면에 "결과 카드를 영상 끝에 포함" 토글. 끄고 싶은 사용자만 끔.
4. **모달 충돌 = 배지 모달 → 결과 카드 순차**. 결과 카드 안에 획득 배지 row 가 있지만 배지 모달도 그대로 진행해 페이오프 계단을 만든다. 결과 카드가 페이오프 통합 후보였지만, 챌린지 성과가 헤드라인이고 배지는 후속 보상이라 두 단계로 가는 게 명확.
5. **닉네임 = "○○님의 만원 챌린지" 포함** (카카오 닉네임 fetch). 카드 진입 시점에 한 번 `/api/users/me` 호출. fetch 실패하면 그냥 "만원 챌린지" 로 폴백 — 안 깨짐. 영상 export 의 카드는 fetch 안 함 (compose 시작 지연 회피).
6. **성공/실패 색 = 드라마틱 대비**. 성공 = 따뜻한 노랑 그라데이션 + 보라 accent + 🎉. 실패 = 그레이 그라데이션 + 다크 그레이 accent + 💪. 결과가 증명사진처럼 명확해야.
7. **카테고리 분포 제외**. 9:16 자리 빡빡 + 숫자/배지로 정보감 충분. 통계 카드 = 목표/사용/절약(또는 초과)/무지출 4개 라인만.
8. **표시 형태 = 풀스크린 라우트** (모달 X). 480x864 비율을 화면에 띄우면 거의 꽉 차 모달로 띄울 이유가 없음. 영상 export 결과 화면 ([export_result_screen.dart](../tenk_app/lib/presentation/challenge/export/export_result_screen.dart)) 의 갤러리 저장/공유 두 버튼 패턴 그대로 차용.
9. **영상 마지막 카드 정지 시간 = 3초**. 영상 클립 2초 + xfade 0.3초 흐름에 이어서 수자/배지/닉네임 읽을 시간 확보. 2.5초는 짧고 4초는 임팩트로 끝나야 하는 마지막을 늘어뜨림.

### 보류·미반영
- **닉네임 옵션화** — 카드에 닉네임 노출을 설정에서 끄는 토글은 안 둠 (설정 화면 자체가 아직 없음 — 회원가입 시 닉네임 설정 화면 백로그 작업 시 같이 검토).
- **결과 카드 자체 캐싱** — 같은 챌린지 결과 카드를 PNG 로 백엔드/디스크에 영구 저장은 안 함. 매번 challenge + amounts 응답으로 동적 생성 (가벼움).

### 함정·교훈
- **색은 ThemeData 안 쓰고 hardcode**. RepaintBoundary 캡처 시 ThemeData 가 영향 안 받게. 위젯 안에서 모든 색을 const Color 로 박아둠. 회귀 금지.
- **배지 자산 precache 필수**. Image.asset 의 첫 프레임이 placeholder 라 캡처에 비어 들어갈 수 있음. ResultCardCapture 가 호출 전 challenge.badges 전체를 precacheImage 로 미리 캐시.
- **off-screen Overlay + RepaintBoundary 패턴**. 위치는 안 보여도 layout/paint 가 정상 수행되고 RepaintBoundary 가 layer 를 그대로 캡처. Off-screen 좌표는 `-2*width` 로 충분히 멀게.
- **`_concatWithXfade` 가 단일 clipLen 가정**이었던 부분 — 마지막 3초 카드 추가로 가변 duration 으로 변경했음. 다른 가변 클립이 들어와도 그대로 동작. 회귀 시 단일 길이 가정 코드로 돌아가지 말 것.

---

## 영상 내보내기 회의록 (2026-05-21)

> CLAUDE.md "영상 내보내기는 이번 범위에서 제외" 결정을 뒤집은 회의. 챌린지 확정 후 기록 영상들을 시간순으로 합쳐 하나의 MP4 로 만드는 기능을 이번 범위로 편입.

### 사용자 요구사항 (사전 정의)
1. 챌린지 내 모든 기록 목록에 선택 박스. 기본값 전체 선택. 해제하면 그 기록의 영상은 합본 제외.
2. 각 기록에 코멘트 작성 가능 — 영상 중간에 텍스트로 자막 표시. 메모(`amount.memo`)가 있으면 그것이 디폴트.
3. 영상 상단에 대시보드 — 일시 + 잔여금액(목표 - 사용금액). 기록 영상마다 갱신.

### 결정 사항 (13)

| # | 항목 | 결정 |
|---|---|---|
| 1 | 처리 위치 | 클라이언트 (Flutter, `ffmpeg_kit_flutter`). 서버 부담 0, 앱 크기 +30~50MB 감수. |
| 2 | 노출 시점 | 챌린지 확정 후에만 (SUCCESS/FAIL 결정 후) |
| 3 | 선택 화면 row | 축소형 리스트 (체크박스 + 날짜 + 내용 + 금액). 영상 썸네일 없음 — 텍스트만 보고 판단. 코멘트 편집은 row 탭 → 모달 |
| 4 | 기록별 자막 디폴트 | `memo` 있으면 memo, 없으면 지출="내용 금액원" / 무지출="무지출". 사용자가 편집 가능 |
| 5 | 자막 영상 안 표시 | 클립 내내 하단 고정 자막. **구현은 Flutter TextPainter PNG + ffmpeg overlay** (drawtext 폐기, 아래 "함정 — drawtext 한글 회귀" 참고) |
| 6 | 상단 대시보드 | `Day N · 잔여 X,XXX원` 포맷 (절대 날짜 대신 상대 진행도 — 스토리라인 느낌) |
| 7 | 잔여금 갱신 | 클립 시작=직전 잔여, 끝=차감 후 잔여로 카운트다운 |
| 8 | 무지출 + 영상 없음 | 2초 텍스트 카드 삽입 (검정 배경 + "무지출 ✓" + 코멘트) |
| 9 | 클립 간 트랜지션 / BGM | 0.3초 cross-fade + 무음 (ffmpeg xfade) |
| 10 | 출력 해상도 | 세로 480x864 통일 (모바일 카메라가 세로 녹화이므로 가로 출력이면 좌우 검은 패딩). 입력 원본은 ResolutionPreset.medium 이라 디바이스마다 다름 — 클립별 스케일 필요 |
| 11 | 합성 진행 UX | 전체화면 진행률 + 캔슬 버튼 (백그라운드 처리 X) |
| 12 | 원본 영상 누락 시 | 1개라도 실패하면 전체 중단 + 재시도 버튼. 부분 합본 안 만듦 |
| 13 | 결과 캐싱 | 안 함 — 매번 새로 합성. 같은 입력으로 다시 들어가도 ffmpeg 재실행 |
| - | 완료 후 동작 | 미리보기(`video_player`) + 갤러리 저장(`gal`) + OS 공유 시트(`share_plus`) 셋 다 노출 |
| - | 기존 `/export` JSON | 유지 (통계·외부 연동용으로 남김) |

### 보류 — 결과 카드 (영상 마지막 3초)

영상 끝에 "성공! 8,200/10,000원" 같은 결과 카드를 붙일지 vs 챌린지 확정 시 별도 결과 화면으로 보여줄지 미정.
챌린지 확정 화면 자체가 별도 의사결정 항목으로 분리될 가능성이 있어 영상 내보내기 구현 도중 함께 정리. (→ 위 "결과 카드 회의록"에서 결정됨)

### 구현 시 주의사항

- **백엔드 추가 작업 거의 없음** — 영상 다운로드 엔드포인트가 이미 있으면 그대로. 없으면 인증된 사용자가 자신의 amount 영상을 받을 수 있는 엔드포인트 1개 (현재 [MediaController](../tenk-backend/src/main/java/com/hjson/tenk/domain/media/MediaController.java) 확인 필요).
- **패키지/인코더 선택**: `ffmpeg_kit_flutter_new_video` (LGPL 'video' 변종) 사용 중. sw 인코더는 최종적으로 ffmpeg 내장 **`mpeg4` (MPEG-4 Part 2, LGPL)** 채택. 회의 결정 #1 의 "h264" 표현은 H.264 고집이 아니라 "표준 동영상 코덱" 의미였고 MP4 컨테이너에 MPEG-4 Part 2 도 어디서나 재생 가능하니 무방.
- **함정 — H.264/HEVC sw 인코더 다 막힘**: 후보를 다 돌려본 결과 ffmpeg_kit_flutter_new_video 환경에선 mpeg4 외 선택지가 없다. 다음은 모두 실격 — 같은 함정에 다시 들어가지 말 것:
  - `h264_mediacodec` (hw): lavfi `color` 소스/짧은(2초) 클립 인코딩 시 return code 0 인데 duration N/A + 스트림 없는 빈 컨테이너를 뱉는다. 정규화는 통과한 척 → concat 에서 `[N:v] matches no streams` 로 죽음. 디바이스/펌웨어 의존이라 재현이 일정치 않음.
  - `libx264` (sw H.264): GPL — 현재 'video' 변종 빌드에 미포함, 라이센스 이슈로 채택 X.
  - `libkvazaar` (sw HEVC): 빌드엔 있지만 native crash. ffmpeg `exit_program` → `of_close` → `avcodec_free_context` → `pthread_mutex_destroy` 에서 `FORTIFY: called on a destroyed mutex` SIGABRT. kvazaar 자체 스레드풀과 ffmpeg cleanup 의 더블 프리. 패키지 버그라 사용자 코드 우회 불가.
- **함정 — drawtext 한글 회귀 (ffmpeg 8.0)**: `ffmpeg_kit_flutter_new_video` 2.0.0 은 ffmpeg n8.0 (HarfBuzz 통합 drawtext) 을 쓰는데 multi-codepoint 한글 입력에서 **첫 글리프만 그리고 뒤를 silent drop** 한다. "무지출" → "무", "도시락 챙겼다" → "도", "Day 1 · 잔여 8,000원" → "D" 패턴. 다음 모두 무효였음 — drawtext 로 회귀 X:
  - `text='무지출'` 인라인, `textfile='...'` + `expansion=none`: 둘 다 같은 출력. textfile 내용은 hex dump 로 9바이트 (eb ac b4 ec a7 80 ec b6 9c) 전부 정확히 박혀있는데도 첫 글자만 렌더.
  - `text_shaping=0` 으로 HarfBuzz shaping path 우회 시도: 옵션은 수락되는데 출력 동일. ffmpeg 8.0 drawtext 가 옵션을 받기만 하고 실제로는 새 shaping path 만 쓰는 것으로 추정.
  - 폰트 교체 (Tmoney RoundWind → Pretendard): cmap 으로 한글 11172자 다 커버하는 폰트로 바꿔도 동일. 폰트 글리프 문제 아님.
  - `-loglevel verbose` 에서도 drawtext 가 어떤 경고도 안 뱉음 — 디버그 단서 0.
  - **해결**: drawtext 완전 폐기하고 Flutter `TextPainter` 로 PNG 그려 ffmpeg `overlay` 필터로 합성. Flutter/Skia 가 Android 시스템 폰트 (Noto Sans CJK) 폴백으로 한글 렌더 → ffmpeg 는 그냥 픽셀만 합성하니까 텍스트 렌더링 경로 자체를 차단. 구현은 [video_composer.dart](../tenk_app/lib/data/export/video_composer.dart) `_renderTextOverlayPng` / `_drawTextBlock`.
- **앱 크기**: `ffmpeg_kit_flutter_new_video` 빌드는 +30~50MB. 더 줄이고 싶으면 `_min` 계열도 mpeg4 는 들어있으므로 시도 가능.
- **메모리/배터리**: 30일치(최대 ~60개 클립 × 2초) 합성은 저사양 폰에서 수십 초 걸릴 수 있음. 캔슬 가능해야 함. ffmpeg_kit 의 `Session.cancel()` 활용.
- **자막 렌더**: ffmpeg drawtext 가 한글에서 막혀서 (위 함정) **Flutter TextPainter PNG + ffmpeg overlay** 로 갈아탐. 시스템 폰트 폴백을 쓰니까 별도 폰트 자산 불필요. 자막 폰트를 명시 지정하고 싶으면 [tenk_app/assets/fonts/Korean.ttf](../tenk_app/assets/fonts/) 를 pubspec.yaml `flutter.fonts` 에 family 로 등록 + `_drawTextBlock` 의 TextStyle 에 fontFamily 박기.
- **잔여금 카운트다운**: 한 클립(2초)에서 시작값→끝값으로 보간된 텍스트를 매 프레임 그리려면 drawtext 의 `t` 변수(현재 재생시간)와 expression 활용. 또는 클립 길이를 짧은 세그먼트로 쪼개고 각 세그먼트마다 다른 텍스트 — 후자가 단순.
- **음성 트랙 없음**: 원본 녹화가 `enableAudio:false` 라 입력에 오디오 트랙이 없을 수도 — ffmpeg 명령에 `-an` 명시 또는 무음 트랙 강제 생성으로 출력 일관성 확보.
