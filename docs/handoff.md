# Handoff — Tenk

> 다른 컴퓨터/세션에서 이 작업을 이어받는 사람(또는 미래의 나)을 위한 인계 노트.
> 영구적인 규칙·결정은 [../CLAUDE.md](../CLAUDE.md)에 있고, 이 문서는 **현재 진행 상태와 다음 할 일**만 기록함.

> **📂 문서 분할 안내 (2026-07-19)** — handoff 가 무거워져 셋으로 나눔:
> - **이 파일 (handoff.md)** = **현상황**: 시작 순서 · 완료 요약 · 남은 일(미착수) · 비-git 자산 · 함정. **매 세션 기본으로 읽는 파일.**
> - **[handoff-archive.md](handoff-archive.md)** = **이력**: 시간순 변경 로그(changelog) + 완료된 백로그 상세. "언제/왜 이렇게 됐지"를 추적할 때만.
> - **[decisions.md](decisions.md)** = **회의록**: 주요 기능별 의사결정 근거(기록수정·촬영분리 / 결과 카드 / 영상 내보내기 / 연령·선택수집 / 테스터 로그인 / 앱 버전·업데이트 게이트 등 — 전체 목록은 문서 상단 "수록") + 영상 export 함정(mpeg4 인코더·drawtext 한글). 관련 코드를 건드릴 때만.
>
> 회귀 방지 지뢰(함정)는 짧고 매 세션 가치가 높아 이 파일 하단 "알려진 주의사항 / 함정"에 그대로 둠.

**최근 상태 요약** — 상세 시간순 로그는 [handoff-archive.md](handoff-archive.md) "최근 변경 이력" 참고.
- ✅ UI 전면 리뉴얼(디자인 시스템 Wave 0~5 + 리모델) 완료·에뮬 검증 — 방향 "절제된 베이스 + 리워드만 화려", 규칙은 [../CLAUDE.md](../CLAUDE.md) "디자인 시스템" / "챌린지 목록 IA".
- ✅ Android 릴리스 실기기 전체 흐름 스모크 완료 / Play Console 내부 테스트 게시·카카오 로그인 확인 / devtools 테스트 로그인·시딩 운영 배포 / 서버 타임존 KST 고정 버그픽스 배포.
- ✅ **필수 동의 플로우(이용약관+개인정보) 구현·prod 배포·에뮬 E2E 검증 완료 (2026-07-20)** — 상세는 아래 "운영 고려사항".
- ✅ **통합 테스트 2종 추가 (2026-07-20)** — 필수 동의 엔드포인트 E2E 5건 + 탈퇴 계정 파기 5건.
- ✅ **연령 확인 게이트 + Play 앱 콘텐츠 답안지 (2026-07-20)** — 만 14세 미만 차단(즉시 파기), 계정 삭제 안내 페이지 신설, [play-console-app-content.md](play-console-app-content.md) 작성.
- ✅ **성별 선택 수집 + '내 정보' 하위 화면 분리 (2026-07-21)** — 성별은 통계용 선택 항목으로 '내 정보'에서만 입력·해제(가입 흐름 무변경). 닉네임·성별을 '내 정보'로 묶고 상위 화면은 순수 메뉴로 재편 — **상위 화면 이름은 '메뉴'(임시), 확정은 아래 §1 남은 일**. 테스트 **151개** 전원 통과, **에뮬 E2E 검증 완료**. **남은 것은 prod 배포 + Play 콘솔 폼 입력뿐** — 아래 "남은 일 §0".
- ✅ **테스터 로그인 회의 + 구현 + prod 배포 완료 (2026-07-25)** — 결정: App access=**데모 카카오 계정**, 앱/서버의 **테스트 로그인 완전 제거**, 시딩은 **계정 role(USER/TESTER)** 로 재게이팅. 회의록 [decisions.md](decisions.md) "테스터 로그인 회의", Play 답안 [play-console-app-content.md](play-console-app-content.md) §2. **테스트 147개 전원 통과 + flutter analyze clean**. **prod 배포 완료** — 연령 게이트·성별도 이번에 함께 LIVE(3컬럼 ALTER + 새 이미지). §0.
- ✅ **이메일 수집 중단 (#10, 2026-07-26)** — 원인은 카카오 이메일 동의항목 **'권한 없음'**(개인 개발자 앱). 쓰이는 곳이 표시 한 곳뿐이라 수집을 접고 **컬럼까지 DROP**. privacy.html·Play 데이터 안전의 **고지 불일치도 함께 해소**. 테스트 161개 통과 + **에뮬 E2E 검증 완료**. ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **닉네임 안내 문구 정리 + 제한 규칙 24시간화 (#11) · 메뉴 진입 로딩 제거 (#12) — 2026-07-26.** #11: 상시 라벨 제거·탭 시에만 안내, 어긋나 있던 "다음 날 자정" 판정을 **정확히 24시간**으로 통일. 테스트 **161개** 전원 통과 + **에뮬 E2E 검증 완료**. #12: 메뉴를 낙관적 렌더로 전환(`/me` 안 기다림) + `flutter analyze` 완전 clean. ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **폼 키보드 이동 통일 (#13, 2026-07-26)** — 생년월일 3칸 자동 이동·백스페이스 복귀가 발단이었지만 **키보드 '다음' 동선을 전 폼으로 전수 적용**(기록/수정 내용→금액, 챌린지 생성 이름→목표금액). 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — Flutter" 에 명문화. **앱 전용 변경이라 백엔드 재배포와 무관** (다음 앱 릴리스에 실림). `flutter analyze` clean + 에뮬 E2E 검증 완료.
- ✅ **날짜·시간 picker 정리 (#3, 2026-07-27)** — ① 로케일 `ko` 고정(`flutter_localizations`)으로 picker 한국어화 + 시각 표기를 기기 12/24h 설정 따라가게 통일(폼 `10:11 PM` vs 목록 `22:11` 로 갈라져 있던 것 해소) ② **시각 picker 를 카카오톡 예약·갤럭시 알람식 휠로 교체** — 오전·오후 / 시 1~12 / 분 00~59 무한 순환, 가운데 탭 직접 입력, 시가 11↔12 넘으면 오전/오후 자동 전환, **아날로그 시계(dial) 제거** ③ 기록 화면 일시를 `날짜 | 시간` 2칸으로 분리(수정 화면과 공용 위젯). **앱 전용 변경이라 백엔드 재배포와 무관** (다음 앱 릴리스에 실림). `flutter analyze` clean + 에뮬 E2E 검증 완료.
- ✅ **탈퇴 UX 재설계 (#1, 2026-07-27)** — 탈퇴 후 **유예 1개월**(3개월에서 단축), 그 안에 돌아오면 **철회 / 재가입을 사용자가 고른다**(U0007 → 선택 다이얼로그 → `/api/auth/kakao/restore` 또는 `/rejoin`). **재가입은 옛 계정을 즉시 파기해 기다리지 않는다** — "탈퇴 후 한 달간 재가입 불가" UX 를 만들지 않는 게 핵심 원칙. 보관 목적도 "부정 이용 방지" → **"탈퇴 철회 대응"** 으로 바로잡고 privacy·delete-account 갱신. 회의록은 [decisions.md](decisions.md) "탈퇴 UX 회의". 테스트 **175개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **키보드 닫기 전역 처리 + 탈퇴 사유 항목 재설계 (2026-07-28)** — 빈 곳 탭 시 키보드가 안 닫히는 문제가 **앱 전체**에 있어 `MaterialApp.builder` 한 곳에서 처리. 탈퇴 사유는 사용자 언어로 7종 재설계(개인정보 항목 제외). **에뮬 E2E 검증 완료.** 함정: `main.dart` 최상단 변경은 hot reload 로 안 실릴 수 있어 `R` 필요.
- ✅ **브랜드 표기 `Tenk` → `TenK` 통일 (2026-07-28)** — 사용자 노출 문자열 전부(앱 문구 7곳 + Android/iOS 표시 이름 + 법적 문서 3종). 내부 식별자·도메인·**갤러리 앨범명은 유지**(앨범이 갈라짐). Play Console 스토어 등록명은 **이미 TenK 로 등록돼 있음**(2026-07-28 확인). 규칙은 [../CLAUDE.md](../CLAUDE.md) "릴리스 빌드 / 배포".
- ✅ **탈퇴 사유 수집 (#14, 2026-07-28)** — 탈퇴를 화면으로 옮기고 사유 1문항을 **선택**으로 수집. 저장은 **익명 테이블**(user_id 없음)이라 개인정보 수집표가 안 늘고 계정 파기 후에도 통계가 남는다. 곁가지로 잘못된 요청 body 가 500 이던 전역 갭을 400 으로 수정. 테스트 **183개** 통과 + **에뮬 E2E 검증 완료**. ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **메뉴 '앱 버전' 행 로딩 제거 + #12·#14 잔여 갈래 종결 (2026-07-28)** — 로딩의 원인이 네트워크가 아니라 **부팅 때 이미 한 판정을 버리고 다시 묻던 것**이었다. `AppApi` 가 성공한 판정만 캐시하고 타일이 동기로 읽어 **정상 경로 네트워크 0회**. '탭하면 확인' 안은 기각(업데이트 안내는 push 여야 함). '내 정보' 스피너는 **정상으로 결론**, #14 잔여 2건은 **삭제**. `flutter analyze` clean + **에뮬 E2E 검증 완료**. 회의록 [decisions.md](decisions.md) "메뉴 앱 버전 행". **앱 전용이라 §0-DEPLOY 와 무관.**
- ✅ **의견 보내기 + 문의 창구 (#2, 2026-07-28)** — 메뉴에 '의견 보내기' 신설(유형 4종 + 내용 + **회신 이메일 선택**). 저장은 **익명 테이블**(user_id 없음)이고 회신 이메일만 개인정보라 **1년 상한 배치**로 지운다. 곁가지로 **법적 고지에 '문의' 행(mailto)** 추가 — privacy 를 열어 스크롤해야 보이던 창구를 두 단계로 줄였다. 문의≠피드백 구분과 리서치 근거는 [decisions.md](decisions.md) "의견 보내기 회의"(문구 다듬기 2차 포함 — 칩→셀렉박스, 감사 인사는 인트로가 전담). 테스트 **195개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **모달 → 화면·바텀시트 전환 (#4, 2026-07-29)** — 모달 16곳 전수 조사 후 성격별로 갈랐다: **확인·차단은 다이얼로그 유지**, **'내 정보' 속성 편집은 화면**, **폼 안 선택은 바텀시트**. 공용 위젯 4종 신설로 `DropdownButtonFormField` 를 걷어내면서도 **`FormField` 로 `validator` 를 보존**. 곁가지로 **성별 `OTHER` 제거 + 3칸 토글**. 테스트 **195개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. 기준은 [../CLAUDE.md](../CLAUDE.md) "모달 사용 기준", 회의록 [decisions.md](decisions.md). ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **성별 회의 (#16, 2026-07-29)** — "수정할 수 있게 두면 무의미한 데이터가 쌓이나"에 대해 **현행 유지** 결론. 노이즈는 편집이 아니라 최초 입력에서 들어오고, 편집 차단은 오탭을 영구 고착시켜 오히려 나빠진다. 법상 정정·철회권 + privacy.html 의 공개 약속 때문에 막을 수도 없다. **변경 이력 저장 금지**를 규칙으로 신설(아웃팅 위험). 회의록 [decisions.md](decisions.md) "성별 수집·변경".
- 🔵 **Play 앱 콘텐츠 폼 진행 중** — 개인정보처리방침·광고·콘텐츠 등급 ✅ / App access **답안 확정(데모 계정)**·타겟층·데이터 안전 **콘솔 입력 미완**. 데모 카카오 계정 생성 남음. §0.
- ✅ **Flutter 상태 관리 재검토 (#15, 2026-07-29)** — Scope 7개로 자체 임계(5개)를 넘긴 건 사실이나, **Scope 에 든 게 전부 stateless API 객체라 지금 있는 건 상태 관리가 아니라 DI** 였다. **현행 유지 + 임계 5→10 상향 + "진짜 트리거는 화면 간 공유 상태" 명문화**로 종결(코드 변경은 주석 2곳). 회의록 [decisions.md](decisions.md) "Flutter 상태 관리 재검토".
- ✅ **DB 코드성 컬럼 정리 (#9, 2026-07-30)** — 조사해보니 **두 축**이 따로 어긋나 있었다: ⓐ DB 자료형(네이티브 `ENUM` 3개 vs `VARCHAR` 5개 — 시간순 흔적) ⓑ Java 매핑(`amount.category` 만 raw String). **둘 다 정리** — ⓐ `VARCHAR` 통일(Java 변경 0), ⓑ `@Enumerated(STRING)` 전환 + 레거시 → `ETC` (DTO 는 String 유지라 **Flutter 변경 0**). 룩업 테이블은 기준상 `badge` 하나뿐이고 이미 그래서 도입 안 함. 테스트 **200개** 통과 + **에뮬 E2E 검증 완료**(유일한 실질 리스크였던 wire format 이 Jackson→Flutter 까지 그대로임을 확인). 회의록 [decisions.md](decisions.md) "DB 코드성 컬럼 정리". ✅ **prod 배포 완료 (2026-07-30)**.
- ✅ **§0-DEPLOY 9건 prod 배포 완료 (2026-07-30)** — 밀려 있던 #5·#10·#11·#1·#14·#2·#4·#9ⓐ·#9ⓑ 를 **한 번에** 라이브 반영. 사용자가 데이터 소멸을 승인해 런북의 8단계 마이그레이션 SQL 대신 **DB 를 통째로 재생성**(볼륨 3개 삭제 → `dbinit` 재시딩 → clean init)했고, 그래서 순서 함정(레거시 값 정리·`DROP COLUMN`)이 성립하지 않았다. **서버 측 검증 전항목 통과.** 실행 기록은 [handoff-archive.md](handoff-archive.md), 재사용 가능한 절차는 [docker-deployment.md](docker-deployment.md) §5.7.
  - ⚠️ **부수 효과: 라이브 계정·챌린지·업로드 영상이 전부 소멸했다.** 다음 로그인은 전원 신규 가입(연령→동의→닉네임)이고, **TESTER role 재승격**이 필요하다(§0 잔여).
- ✅ **예외처리 전수 점검 (#7, 2026-07-31)** — 커버리지는 이미 좋았고, 문제는 **양쪽 다 아는 규칙을 일부가 안 지킨 것**이었다. 앱: 네트워크 오류가 **영문으로 뜨던 것**을 원인별 3분기 한국어 폴백으로 교체 + 예외 원문을 직접 찍던 5곳 정리. 백엔드: **잘못된 호출 6종이 전부 500** 이던 것을 실측으로 확인하고 400/404/405/415 로 정정. **에뮬 검증에서 갭이 하나 더 나와**(새로고침 실패가 무피드백이라 *성공한 것처럼* 보였다) `AsyncStateMixin` 한 곳으로 해결. 테스트 **207개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. ⚠️ **백엔드 재배포 필요** (§0). 상세는 아래 §1-A #7.
- ✅ **배지 획득 연출 재설계 + 설정 화면 신설 (#8, 2026-08-01)** — 착수해보니 **`confetti.json` 이 아예 없어서**(errorBuilder 가 조용히 생략) 백로그가 말하던 "Lottie 컨페티" 가 실물이 아니었다 — 절반이 미완 메우기였다. 레퍼런스(듀오링고·챌린저스·토스)를 뜯어 **모달 내부를 3막 타임라인으로 재설계**(무대 → 임팩트 520ms → 여운) + **CustomPainter 컨페티**(`lottie` 의존성 제거) + **단계별 5색**(자산이 이미 브론즈→실버→골드→주얼 사다리였다) + **전폭 CTA `다음 (1/2)`** + **'다음 목표' 한 줄**. 곁가지로 **효과음 도입 → 메뉴에 '설정'(효과음·진동) 신설, '계정 설정'→'계정 정보' 개명**, `noSpend` 라벨 오표기 정정, 배지 PNG 384px 리사이즈(6.7MB→1.3MB). 회의록 [decisions.md](decisions.md) "배지 획득 연출". **앱 전용이라 백엔드 재배포와 무관** (다음 앱 릴리스에 실림). 상세는 §1-A #8.
- ✅ **결과 카드 디자인 재설계 (#18, 2026-08-01~02)** — 기준은 **"예뻐야 자랑하고 싶다"**. 최종안은 **2블록**(상단 컬러 블록 — 성공 **브랜드 민트** / 실패 **앱 `danger`** + 하단 화이트) + **히어로 문장**(`N일 동안 / 목표액 / 챌린지 성공`) + 예산 바 + **배지 3칸 → 일자 그리드**(카뱅 26주적금 방식) + **풀블리드 화면**(AppBar 제거). **7라운드에 걸쳐 다크·링 게이지·카테고리 분포·절약액 히어로·딥레드를 차례로 폐기**했고 그 실패들이 규칙이 됐다 — *리워드의 특별함을 표면색으로 만들지 말 것* / *도넛·링 금지(척도를 못 나른다)* / *카테고리 분포 금지(자랑거리가 아니라 정산서)* / *절약액은 성취가 아니라 부산물* / *유색 면 위의 강조는 더 눌러서가 아니라 더 밝게*. 실패 카드는 **게이지 초과분과 지출한 날**에도 빨강을 쓴다. 축하는 **카드 안 정적 컨페티 + 확정 직후 진입 연출** 두 겹. analyze clean + 에뮬 전 분기 재검증 + 저장 PNG 확인 + **영상 마지막 3초 클립 검증 완료(2026-08-02) — 미검증 항목 없이 종결**. **앱 전용이라 백엔드 재배포와 무관.** 상세는 §1-A #18.
- ✅ **알림 기능 구현 (#17, 2026-08-02)** — 회의에서 확정한 설계를 그대로 구현. **로컬 알림만**(FCM 없음) / 발신 채널 3종 + **배지 근접은 리마인더 문구 승격** / 겹치면 발신 1개 + 문구 우선순위 / 설정 마스터 1 + 종류별 3 + 시각 / 가입 직후 프라이밍(**게이트 아님**). 구현 중 **무지출 근접 문구도 값이 필요**하다는 게 드러나 백엔드를 한 번 더 정리했다 — `BadgeGrantService` 안의 집계를 **[ChallengeStatsCalculator](../tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeStatsCalculator.java) 로 뽑아 배지 지급과 응답이 같은 함수·같은 조회**를 쓰게 하고 `currentStreak`/`noSpendDays` 를 함께 내린다. 곁가지로 **`dart format lib/` 를 통째로 돌려 62개 파일이 재포맷된 것을 되돌렸다**(이 리포는 일괄 포맷된 적이 없다 — 전체 경로에 포맷터를 돌리지 말 것). 테스트 **226개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. ⚠️ **백엔드 재배포 필요**(#7 과 함께). 상세는 §1-A #17.
- ✅ **로고 / 앱 아이콘 (#6, 2026-08-02)** — 기본 Flutter 아이콘이던 걸 **`10` 마크**(세로획+깃발=`1`, 오른쪽 링=`0`이자 예산 게이지)로 교체. 마크는 자산 PNG 가 아니라 **코드로 그린다** — 파이썬 생성기([assets_src/icon/generate_icons.py](../tenk_app/assets_src/icon/generate_icons.py))가 **41개 산출물**(Android 5밀도 × legacy·원형·adaptive 전경·themed + `anydpi-v26` XML + `colors.xml` + iOS 15장 + Play 512)을 한 번에 뽑고, 앱 안 로고는 같은 형상의 [TenkLogoPainter](../tenk_app/lib/design/tenk_logo.dart) 가 그린다. **adaptive icon 이 아예 없던 것**(원형·themed 런처 미대응)도 같이 메웠다. `flutter analyze` clean + **Dart 렌더가 파이썬 산출물과 일치함을 실측 확인**. ⚠️ **실기기 확인은 남아 있다**(§0 ①). 규칙은 [../CLAUDE.md](../CLAUDE.md) "로고 / 앱 아이콘", 근거는 [decisions.md](decisions.md) "로고·앱 아이콘".
- ✅ **백엔드 재배포 + 새 AAB 빌드 (2026-08-03)** — 밀려 있던 백엔드 2건(#7 예외처리 · #17 알림 지표)을 **이미지 교체만으로** 배포하고(스키마 변경 없음), 앱은 **`1.0.0+3` → `1.1.0+4`** 로 올려 릴리스 AAB 를 구웠다. 테스트 226개 `--rerun-tasks` 전원 통과 / `flutter analyze` 0건 / 병합 매니페스트 실측(`versionCode=4`, `SCHEDULE_EXACT_ALARM` 없음). `app_config` 는 `latest`·**`min` 둘 다 `1.1.0`**(내부 테스터 강제 통일 — 되돌리려면 UPDATE 한 줄). **검증 명령 자체가 틀렸던 게 두 번** 나와 §0 에 박아뒀다 — 맥에서 자기 도메인 curl(NAT 헤어핀) / `/api/nope` 로 #7 확인(Security 가 먼저 401). **남은 건 Play 게시 → 실기기 검증 → 콘솔 폼 3종.**
- ✅ **Play 내부 테스트 게시 + 실기기 검증 완료 (2026-08-03)** — 설치본으로 전 항목 통과. **결함 2건 발견 → §1-B #19(하단 버튼 잘림 — 원인은 CLAUDE.md 의 틀린 SafeArea 규칙) · #20(결과 카드 진입 컨페티가 데이터를 가림, 저장 PNG 는 정상)**. 오해였던 2건(`다음 (1/2)` 미표시 · 상태바 뒤 색)은 정상 동작으로 확인.
- ✅ **#19 하단 액션 잘림 수정 (2026-08-03)** — 백로그가 짚은 SafeArea 2곳 외에 **바텀시트 1곳**과 **키보드가 입력칸을 자르는 별개 원인**(사용자 지적)이 더 나왔다. 공용 위젯 [BottomActionScrollView](../tenk_app/lib/presentation/common/bottom_action_scroll_view.dart) 로 게이트 3화면을 통일하고, **위젯 테스트 회귀 가드 11건**을 신설해 규칙 대신 테스트가 지키게 했다(이 자리는 *틀린 규칙 때문에* 깨진 곳이다). `flutter analyze` clean + 테스트 12개 통과 + **에뮬 제스처/3버튼 양쪽 검증**. 상세는 §1-B.
- ✅ **#24 휠 시각 picker + 세로 고정 (2026-08-04)** — 시각 picker 는 **접지 않는다**: 공간이 되면 `Dialog` 기본대로 키보드 위로 올라가고, 모자랄 때만 크기를 유지한 채 키보드가 덮게 한다(사용자 결정). 가용 높이를 `LayoutBuilder` 로 재려다 **다이얼로그가 통째로 렌더 실패**한 함정 포함 — 위젯 테스트는 그걸 통과시켰다. 곁가지로 **앱에 방향 고정이 없어 가로에선 키보드 없이도 눌리던 것**을 발견해 세로로 잠갔다. 가드 5건, 테스트 17개 통과.
- ✅ **#20 결과 카드 진입 컨페티 잔존 수정 (2026-08-04)** — 백로그의 원인 추정(좌표계 어긋남)이 틀렸고, 실제로는 **연출이 끝나도 조각 15개가 화면에 얼어붙어** 일자 그리드·범례를 가리고 있었다(`delay + fallSpan > 1` → 낙하 미완 + 마지막 프레임 영구 유지). `fallSpan` 클램프 + 완료 시 트리 제거 2겹으로 수정, 가드 3건(**되돌려 실패 확인**), 테스트 20개 통과, **에뮬에서 연출 전후 프레임 MD5 동일**로 잔존 0 확인. **이로써 §1-B 실기기 결함 3건 전부 종결.** 상세는 [handoff-archive.md](handoff-archive.md).
- ✅ **#21 설정 화면 문구 정리 + #26 앱 전체 문구 정리 완료 (2026-08-04)** — #21 은 5건 삭제(백로그 3 + 전수 나열에서 나온 2), #26 은 앱 전체 조사 9건 중 **삭제 2 · 말투 정정 2**(나머지는 실물 비교 후 현행 유지). **에뮬로 실제 화면을 찍어 판정**했다.
- ✅ **#22 알림 권유 위치 재설계 (2026-08-05)** — 안건은 "온보딩 뒤에 화면을 하나 더 세우는 게 맞나" 였는데, **가입 직후엔 챌린지가 0개라 승인해도 예약되는 알림이 0건**이라는 게 드러났다(문구로 못 고치는 자리 문제). **첫 챌린지 생성 직후 바텀시트**로 옮기고 온보딩은 3화면으로 줄였다. 테스트 **21건** + **에뮬 E2E 8항목 전건 통과**. **앱 전용이라 백엔드 재배포와 무관.**
- ✅ **#25 런처 아이콘 마크 키우기 (2026-08-05)** — `MARK_EXTENT` **0.56 → 0.70** 한 줄로 41개 산출물 재생성(실제 변경 39개 — XML·colors 는 내용 동일). 안전영역(72dp) 원 반지름 대비 잉크가 **62% → 78%** 로 찼다. **후보 4종을 원형·스퀘어클·테마 마스크 + 실제 크기로 그려 놓고 골랐다**(Artifact 시안). 착수해보니 백로그의 "두 파일을 같이 고쳐라" 경고는 **이 값엔 해당하지 않았다** — `MARK_EXTENT` 는 형상 비율이 아니라 **아이콘 캔버스 안의 여백**이라 Dart 에 대응 상수가 없다(잉크 bbox 불변으로 실측 확인). ⚠️ **실기기 확인 + Play 512 재업로드가 남는다**(§0 ①).
- ✅ **#23 문의 창구 정리 + 관리자 알림 (2026-08-05)** — 안건은 "창구가 둘이라 헷갈리니 '문의'를 지우자"였는데, 따져보니 **지울 수 없는 창구**였다(privacy·terms 에 고지된 권리 요구 접수처 + 앱 밖 사용자의 유일한 경로). 그래서 **'의견 보내기'는 메뉴 최상위(설정 위), '문의하기'는 메뉴 → '고객센터' 안**으로 자리를 갈랐다 — 한 번 나란히 모아봤다가 되돌렸다(익명 창구가 고객센터 안에 있으면 문턱이 올라간다). 곁가지가 더 컸다 — mailto 를 **인앱 폼**으로 바꾸고(신규 `inquiry` 도메인: **`user_id` 저장 · 회신 이메일 필수 · 유형 4종 · 탈퇴 시까지 보관**, 익명인 `feedback` 과 정반대 계약) **관리자 알림 2겹(SMTP+텔레그램)** 과 **미처리 리마인드(매일 09:00)** 를 붙였다. 사용자가 짚은 *"한 번 놓치면 모른다"* 에 대한 답이 리마인드다. 문의처 주소도 개인 메일 → **서비스 전용 계정**으로 교체. 테스트 **239개**(+13) + 앱 **22개**(+1) + analyze clean + **에뮬 E2E 전항목 통과**. ⚠️ **백엔드 재배포 + `CREATE TABLE inquiry` 선적용 필요**(텔레그램 자격증명은 채웠다). 회의록 [decisions.md](decisions.md) "문의 창구 정리".
- ✅ **관리자 패널 (#27, 2026-08-06)** — 안건은 "문의·의견을 운영할 수 있게" 였는데, 조사에서 **백로그 ①의 문제의식이 반대 방향**이라는 게 드러났다: 걱정하던 PK 노출이 아니라 **알림 본문에 `inquiry_id` 가 아예 없어서**(리마인드 SQL 도 `WHERE inquiry_id=?` 물음표 그대로) 처리하려면 `SELECT` 로 id 를 찾아야 했다. **사용자 판단으로 최소 관리자 웹 UI 를 짓기로** 방침을 뒤집었고(⑥ 의 "트리거는 UGC 모더레이션" 을 앞당김), 결과적으로 **SQL 의례 4가지(문의 처리·의견 열람·TESTER 승격·앱 버전 정책)와 SSH + `docker exec` 자체가 사라졌다.** ⭐ **백로그 4건 중 2건이 패널로 소멸**(①접수번호·③미처리 조회) — 남은 ②는 `handler_note` 컬럼 하나, ④는 알림 본문 링크로 끝났다. 몸통은 화면이 아니라 **인증**이었다(앱 로그인이 카카오 SDK 전용이라 브라우저 진입로가 없었다) — **보안 체인을 2개로 쪼개** 앱 인증은 한 줄도 안 건드렸다. 관리자 계정은 사용자 제안(`user` 컬럼 추가)을 조정해 **`admin_user` 별도 테이블**로 갔다(생명주기가 다르다). 테스트 **254개**(+15, **앱 체인 무회귀 2 · 접속기록 5 포함**) + 로컬 구동 검증 전항목 통과. **곁가지로 안전성 확보조치까지 메웠다** — privacy.html §8 신설 + 접속기록 완성(IP·로그인·열람·1년 보관 볼륨), **변호사 검수는 드롭하고 "문서 = 실제 동작"을 유지 기준으로** 대체(사용자 결정). 회의록 [decisions.md](decisions.md) "관리자 패널". ⚠️ **백엔드 재배포 + 스키마 3건**(§0).
- ✅ **관리자 패널 로컬 구동 검증 + 유형 라벨 (2026-08-07)** — 배포 전이라 운영 URL 은 아직 안 열려서 **로컬에서 5화면을 전부 눌러봤다**(로그인 → 대시보드 → 문의 목록·상세·**처리 완료 + 메모** → 의견 → 사용자 → 앱 버전). 처리 결과가 DB 에 반영되고 **접속기록에 본문·이메일·검색어 없이** 찍히는 것까지 확인. 그 과정에서 **유형이 `PRIVACY` 처럼 코드 그대로 노출**되는 걸 발견해 `InquiryType`·`FeedbackType` 에 `label` 을 달았다 — **의견 라벨은 앱 문구와 일부러 다르다**(앱은 선택지 문장, 패널은 목록 한 칸). 곁가지로 **local 관리자 자격증명 방침**(ID 는 운영과 공유, 비밀번호는 로컬 전용)과 **테스트 계정 함정**을 규칙으로 박았다. 테스트 **254개** 전원 통과. 근거는 [decisions.md](decisions.md) "관리자 패널 — 로컬 검증 후속", 상세는 [handoff-archive.md](handoff-archive.md). ⚠️ **앱 코드 변경 없음 · 백엔드는 §0-DEPLOY 에 같이 실린다.**
- ✅ **관리자 알림을 신호로 축약 + 답장 초안 (2026-08-07)** — 알림 3종에서 **본문·회신 이메일·계정·유형·`#id` 를 전부 뺐다**. 편의가 아니라 두 가지 이유다: 내용을 실으면 **메일함·텔레그램이 수집표·파기 배치 어디에도 안 잡히는 개인정보 보관소**가 되고, **알림으로 읽으면 접속기록이 안 남아** `AdminAudit` 를 세워둔 의미가 사라진다. 리마인드는 **오전 9시 → 저녁 6시**(답장할 시간이 남아 있을 때). ⚠️ **대가로 "알림 메일에 회신" 경로가 사라져** 패널 상세에 **[메일로 답장]**(Gmail 작성 링크 + 원문 인용)과 **[초안 복사]** 를 붙였다 — `mailto:` 는 한글 본문이 인코딩되며 9배로 불어 **OS 한도에서 잘린다**. **이 둘은 한 세트**라 인용을 빼면 *"메일 스레드가 이미 아카이브"* 전제(익명 사본 기각 · `handler_note` 답변 전문 금지)가 무너진다. 테스트 **255개**(+1 원문 인용 가드) 전원 통과. 회의록 [decisions.md](decisions.md) "관리자 알림 — 내용을 싣지 않는다". ⚠️ **앱 코드 변경 없음 · 백엔드는 §0-DEPLOY 에 같이 실린다.**
- ✅ **§0-DEPLOY 3건 배포 + 앱 `1.2.0+5` 업로드 (2026-08-08)** — 밀려 있던 백엔드 3건(#23 문의하기+관리자 알림 / #27 관리자 패널 / 알림 축약·답장 초안)을 **스키마 3건 선적용 → 이미지 교체** 순으로 한 번에 반영했고, 앱도 마지막 릴리스(`1.1.0+4`, 08-03) 이후 **8커밋**이 쌓여 있어 `1.2.0+5` 로 올려 Play 에 업로드했다. **서버 측·화면·알림 검증 전항목 통과** — 핵심은 **앱 체인 무회귀**(`GET /api/users/me` 가 로그인 리다이렉트가 아니라 401 `C0003`).
  배포 직후 **사용자 결정으로 prod DB 를 통째로 재생성**했고([docker-deployment.md](docker-deployment.md) §5.7) `app_config` 는 **`1.2.0` 으로 재설정 완료**. 상세·검증 결과·함정은 [handoff-archive.md](handoff-archive.md).
  - 🐞 **이 과정에서 백로그 3건이 나왔다** — **#28** 접속기록 IP(§1-F) · ~~**#29** 결과 카드 양옆 여백~~(✅ 2026-08-17 완료) · **#30** prod 로그에 개인정보 노출(§1-H, **운영에 노출 중**).
  - ⚠️ **남은 후처리 1건**: **TESTER 재승격** — 클린 재생성으로 계정이 전부 사라졌다. **카카오 재로그인으로 계정이 생긴 뒤** 패널 → '사용자' 에서.
- ✅ **#29 결과 카드 양옆 여백 (2026-08-17)** — 풀블리드가 **세 겹**(뜬 액션 Row + `fitWidth` + Column `stretch`)으로 성립한다는 걸 확정하고 가드 9건을 남겼다. ⚠️ **앱 전용 · 다음 릴리스에 실린다 · 실기기 확인 미완**(§1-G).
- ✅ **#30 prod 로그 위생 (2026-08-17)** — prod 가 **JPA 를 지나는 모든 값**(닉네임·문의 본문·회신 이메일·생년월일·관리자 BCrypt 해시)을 **무제한으로** 로그에 찍고 있었다. 원인은 개발용 SQL 로깅 4개가 **공통** yaml 에 있던 것 — `application-local.yaml` 로 내렸다. 곁가지가 셋 더 나왔다: **로테이션 부재**(도커 기본 json-file 무제한 → 탈퇴자 데이터를 파기해도 로그엔 영원히 남는다), **예외 메시지·외부 응답 body·로그인 ID 를 찍던 4곳**, **`<springProfile>` 중첩 오류로 한 번도 동작한 적 없던 local 접속기록 콘솔 출력**. 테스트 **255개** 통과 + **로컬 부팅 실검증**(테스트 출력에 SQL·파라미터 0건 / logback WARN 소멸 / 접속기록이 콘솔·파일 양쪽에 + 입력 비밀번호 미노출). ⚠️ **백엔드 재배포 필요 + 맥 compose 파일 갱신**(§0). 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "로그 위생".
- 🔵 **#28 착수 → 전제 회의로 확장, 본안은 미결 (2026-08-17).** 원인 진단은 **한 번 더 확정**했고(XFF 가 오는데 그 값이 이미 게이트웨이 = Traefik 조차 진짜 IP 를 못 받는다), 그 과정에서 **선택지 D(맥 네이티브 프록시)가 새로 나와** 2택이 4택이 됐다 — *IP 는 봉투 겉면이라 사라지지만 **HTTP 헤더는 편지 내용이라 살아남는다***. 한 단계 위 질문(*"맥+Docker 운영 서버가 통상적인가"*)은 **별도 회의로 결론**냈다: **3중 특수 케이스이고, 지금까지 겪은 인프라 함정이 전부 그 산물**이며, 통상적 정답인 **리눅스 이전은 트리거를 달아 §4 에 등록**(#28 을 그것으로 풀지 않는다). ✅ **본안은 D2(맥에 HAProxy + PROXY protocol)로 확정** — Traefik 을 그대로 두고 얇은 TCP 중계기만 앞세운다. A(Colima vmnet) 를 뺀 결정적 이유는 *되돌리는 난이도* 였다(엣지 설정은 즉시 원복, **Colima 재부팅 실패는 집에 가야 안다**). ⏭️ **실행은 맥 세션 몫**(§1-F 에 3단 절차·함정 2개·원복). 회의록 [decisions.md](decisions.md) ㉔ "서버 전제".
  - ⚠️ **답변 태도 교정 2건이 이 회의에서 나왔다** — *"이용자 0명이라 필요 없다"* 는 논거 금지(§1-F), *"맥에서 Docker 는 흔하다"* 처럼 **용도를 뭉뚱그린 통상성 판정** 금지(㉔).
- ✅ **#30 prod 배포 + TESTER 재승격 완료 (2026-08-17).** 검증 전항목 통과(⭐ `app_config` 를 읽는 요청 뒤 **`binding parameter` 0건**). 🕳️ **그 과정에서 08-08 의 조용한 사고가 드러났다** — `admin-audit` 볼륨이 그때 안 붙어(**compose 파일을 안 옮겼다**) **관리자 접속기록 9일치가 소실**됐다. **#30 로그 로테이션과 정확히 같은 실패 모드**라 [docker-deployment.md](docker-deployment.md) **§5.1 ⓪ 에 "compose md5 대조" 를 필수 단계로 신설**했다. 상세는 [handoff-archive.md](handoff-archive.md).
- ✅ **#28 ⓐ 완료 — D2 적용·검증 (2026-08-17).** 관리자 접속기록 IP 가 상수 `172.19.0.1` → **실제 공인 IP `223.38.225.21`**. privacy.html §8 은 **문구 수정 불필요**(이제 고지대로 동작). Traefik 의 라벨 라우팅·ACME 무변경. 🕳️ **외부 2시간 장애 — macOS 방화벽(ALF)이 HAProxy 를 차단**했고, **loopback 검증만으로는 구조적으로 발견 불가능**했다 → 함정·검증 3지점을 [docker-deployment.md](docker-deployment.md) **§8.4·§8.5** 에 박았다. ⏭️ **후속 3건은 §1-F ⓓ(8/30 ACME 갱신 확인 — 날짜 정해짐)·ⓔ(공유기 DHCP 예약)·ⓕ(AdminAudit 정리)**.
- ✅ **#28 ⓑⓒⓕ 완료 (2026-08-17, ⚠️ 배포 대기)** — 이용자 접속기록을 **백엔드 logback·3개월**로 신설(Traefik 안은 **용량 순환이라 고지보다 오래 보관**해 기각). ⭐ **'오류 기록'까지 같은 볼륨·같은 기간으로 옮긴 게 핵심** — 안 그랬으면 ⓒ 가 절반만 닫혔다. privacy §3 신설, `AdminAudit` 죽은 코드는 **실증 후** 제거. 테스트 **259개**(+4) 통과 + 로그 3파일 실물 확인(유출 0). ⚠️ **새 볼륨 `app-logs` 라 배포 시 compose 전송 필수**(§0).
- ⏭️ 다음 후보: **#28 ⓑⓒⓕ 배포** / **#28 잔여(ⓓ 8/30 ACME 갱신 확인 · ⓔ 공유기 DHCP 예약)** / **§0 잔여(Play 콘솔 폼 3종 + 데모 계정 + 아이콘 재업로드)** / iOS 빌드(맥 필요, 보류 — Sign in with Apple 4.8 요건 [decisions.md](decisions.md) 참고) / 페이지네이션 / 업적 시스템(최후순위).
---

## 새 컴퓨터에서 시작하는 순서

> 리포 구조는 모노레포: `tenk-backend/`(Spring Boot) + `tenk_app/`(Flutter). 자세한 건 [../CLAUDE.md](../CLAUDE.md) "리포 구조" 섹션.

1. 저장소 클론 후 IntelliJ/VS Code 등으로 열기. JDK 21 확인. (Flutter 작업까지 한다면 Flutter SDK도)
2. MariaDB 준비 → `docs/schema.sql` 적용. 리포 루트에서 `mysql -u tenk -p tenk < docs/schema.sql`.
3. `tenk-backend/src/main/resources/application-local.yaml`의 `spring.datasource.username/password`를 본인 로컬 계정으로 수정.
4. **카카오 앱 등록**:
   - https://developers.kakao.com → 내 애플리케이션 추가
   - 제품 설정 → **카카오 로그인 활성화**. (모바일 SDK가 토큰을 받아오므로 Redirect URI는 백엔드와 무관)
   - 동의 항목에서 `프로필 정보(닉네임)`, `카카오계정(이메일)` 활성화
   - 앱 키의 **앱 ID(숫자)**를 `tenk-backend/src/main/resources/application.yaml`의 `tenk.auth.kakao.app-id`에 박기 (server-side `access_token_info`의 `app_id`와 매칭 검증용)
5. 백엔드 실행: `cd tenk-backend && ./gradlew.bat bootRun` → `http://localhost:8080/swagger-ui.html`
6. 백엔드 테스트: `cd tenk-backend && ./gradlew.bat test` (총 **254개** — 단위 159 + 통합 90 + WebMvc 4 + ContextLoads 1. 2026-08-07 실측, 전원 통과). ⚠️ **테스트 실행 시 로컬 `tenk` DB의 user/challenge/amount/challenge_badge/refresh_token/inquiry 데이터가 비워진다** (badge·app_config 마스터는 유지). Flutter 재로그인으로 복구 가능. ⚠️ **`app_config`·`withdrawal_feedback`·`feedback`·`inquiry`·`admin_user` 테이블 선적용 필요** (schema.sql 참고).
7. **Flutter 앱 셋업** (앱 작업까지 할 거면):
   - 새 머신의 `~/.android/debug.keystore`에서 키해시 추출:
     `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64` (Git Bash). PowerShell `Get-FileHash` 안 됨 — [[reference-kakao-android-keyhash]] 참고.
   - 출력값을 카카오 디벨로퍼스 → Tenk 앱 → 플랫폼 → Android의 키해시 목록에 **추가** 등록 (기존 머신 키해시는 그대로 두고 추가). 한 플랫폼에 여러 해시 등록 가능.
   - `cd tenk_app && flutter pub get && flutter run`. 에뮬레이터에서 글자가 안 보이면 [[reference-flutter-android-impeller-text-glitch]] 참고.
8. Claude 세션 시작: 리포 루트에서 `claude` (CLAUDE.md 자동 로딩됨). 첫 메시지로 *"docs/handoff.md 읽고 이어서 진행해줘"* 라고 말하면 컨텍스트 빠르게 복구.

---

## 완료된 것 (요약)

> 디테일은 git log/blame에 있음. 여기엔 "어디까지 왔는지" + "코드에 안 보이는 결정"만. 시간순 이력은 [handoff-archive.md](handoff-archive.md).

**백엔드**
- ✅ **골격**: JPA 엔티티 7종 + Repository, 공통 응답/에러, REST API(User/Challenge/Amount/Media/Badge), 영상 업로드, Swagger UI, JPA Auditing. Spring Boot 4 + Jackson v3(`tools.jackson.*`).
- ✅ **인증**: 카카오 SDK + 자체 JWT(AT 1시간/RT 14일 회전). `KakaoTokenVerifier` `app_id` 매칭 검증, RT는 SHA-256 해시 저장. **Swagger 시나리오 1·2·3 통과** (RT 회전/logout 일괄 무효화/만료 AT `AU0002`≠`AU0001`). JWT secret 환경별 분리(공통 yaml엔 없음).
- ✅ **배지 자동 지급**: 이벤트(AFTER_COMMIT + REQUIRES_NEW) + 새벽 1시 배치 재평가. 유저 단위 → **챌린지 단위**로 재편(`challenge_badge`, `ChallengeResponse.badges` 인라인, 전용 화면 없음). 회수(revoke)는 `applyLadder` 단일 패스.
- ✅ **결과 export**: `GET /api/challenges/{id}/export` 일별/카테고리별 JSON. **CORS 비활성화**(네이티브 앱 전용).
- ✅ **amount.memo**(VARCHAR 500, 빈값 null 정규화) + **무지출/배지 정합성**(일시 서버 now 강제, 하루 1회 UNIQUE, 지출 시 같은 날 무지출 자동 삭제 + 배지 revoke, NO_SPEND=누적/STREAK=연속).
- ✅ **테스트 현황**: `./gradlew.bat test` 총 **255개**(단위 159 + 통합 91 + WebMvc 4 + 컨텍스트 1, 2026-08-07 실측). **전원 통과**. 통합 63 = 기존 40 + 탈퇴 복귀 7 + 탈퇴 사유 4 + 의견 보내기 5 + 잘못된 요청 상태 코드 7. 단위 139 = 기존 116 + 탈퇴 복귀 7 + 탈퇴 사유 4 + 의견 엔티티 7 + 지출 카테고리 enum 5(`SpendCategoryTest` 4 + `AmountTest` wire format 1). ⚠️ **`withdrawal_feedback`·`feedback` 테이블이 있어야 돈다** (schema.sql 참고). (2026-07-26: 닉네임 제한이 24시간 기준으로 바뀌면서 `UserServiceTest` 의 날짜 의존 테스트 2건을 상대 시간 기준으로 교체 — 자정 flaky 요인 자체가 사라짐.) `LocalDate.now()` 정적이라 종료 상태는 reflection backdate. 통합은 로컬 `tenk` 스키마 공유 → 실행 시 dev 데이터 비워짐(Flutter 재로그인 복구). 상세 패턴은 [../CLAUDE.md](../CLAUDE.md) 테스트 컨벤션 행 + 아래 "함정".
- ✅ **카카오 키**(git 추적): 네이티브 앱 키 `589078d3c7daa590c71d9a6e77080b18` 3곳(kakao_config.dart/Android build.gradle/iOS Info.plist), 백엔드 `tenk.auth.kakao.app-id = 1459747`. Android **debug** 키해시 `Dt3/ajH81vV0Ex78dS1ACaqelWc=`(이 머신 기준, 새 머신은 [[reference-kakao-android-keyhash]]). Android **release** 키해시(`tenk-release.keystore`, alias `tenk`) `NsYpNZftCOyk4LygMWF7mdtowdg=` — **카카오 콘솔에 이 값도 추가 등록해야 릴리스 APK 에서 로그인 됨** (미등록 시 로그인만 실패). keystore 이동·재생성하면 이 값도 바뀌니 재추출: `keytool -exportcert -alias tenk -keystore tenk-release.keystore -storepass '<pw>' | openssl sha1 -binary | openssl base64`.

**Flutter 앱** (구조: `lib/app`(셸) + `lib/data` + `lib/presentation` 3층, 컨벤션은 [../CLAUDE.md](../CLAUDE.md))
- ✅ **핵심 흐름**: 카카오 로그인 + 챌린지 CRUD + 지출/무지출 기록 + 2초 영상 녹화·업로드(`camera` medium, enableAudio:false) + 일시 picker + finalize. 에뮬레이터 E2E 통과.
- ✅ **챌린지 상세 UX**: amount 날짜별 그룹화, 오늘 상태 기반 동적 액션 패널(3분기), 무지출 성취감 카드(NO_SPEND 사다리 게이지).
- ✅ **영상 합본 export**: 확정 후 기록 영상 시간순 합성 → 갤러리 저장·공유. `ffmpeg_kit_flutter_new_video`, sw `mpeg4` 인코더 고정, 자막은 TextPainter PNG + overlay. 상세·함정은 [decisions.md](decisions.md) "영상 내보내기 회의록".
- ✅ **결과 카드**: 확정 후 480x864 1장 카드(풀스크린 + 영상 마지막 3초 클립 옵션). 색 hardcode, off-screen RepaintBoundary 캡처. 상세는 [decisions.md](decisions.md) "결과 카드 회의록".
- ✅ **카메라 녹화 시작 UX**: preview freeze 제거(camera 패키지 fork, eager bind), transitional morph, 효과음(royalty-free MP3 탭 즉시 트리거).
- ✅ **배지 획득 축하 모달**(Lottie): 챌린지 상세 reload diff 로 신규 배지 감지 → 순차 큐 모달.
- ✅ **영상 미리보기**: 촬영 직후 자동 재생 + 수정 화면 lazy 다운로드 미리보기(retake/delete).
- ✅ **UI 리뉴얼**(Wave 0~5 + 리모델): 디자인 토큰/테마 + 상태 탭 목록 IA + 상세 정합 + 폼 별표 + 리워드 골드 글로우 + 카테고리 통계. 규칙은 [../CLAUDE.md](../CLAUDE.md) "디자인 시스템".

---

## 남은 일 (우선순위 순)

> 완료(✅)된 항목의 상세는 [handoff-archive.md](handoff-archive.md) "완료된 백로그 상세"로 이관. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md). 여기엔 **미착수·진행 중**만 둔다.

### 0. 🚀 테스트 배포 빌드 (Android ✅ 완료 · iOS/Play 콘텐츠만 잔여)

> 릴리스 빌드 규칙·함정은 [../CLAUDE.md](../CLAUDE.md) "릴리스 빌드 / 배포". 완료 이력(Android 서명/키해시/스모크, Play 게시·카카오 로그인)은 [handoff-archive.md](handoff-archive.md) "§0 완료된 체크리스트".

**환경 제약 (중요)**
- **iOS 빌드는 이 Windows 머신에서 불가** — `flutter build ios/ipa`/`pod install`/Xcode 전부 macOS + Xcode 필수. iOS 작업은 전부 맥에서 (도커 배포하던 그 맥).
- **iOS 앱스토어/TestFlight 배포만 Apple Developer Program($99/년) 필요** — 미보유라 배포는 보류. 하지만 **빌드·실행은 공짜로 가능**(시뮬레이터=계정 불필요, 본인 아이폰=무료 Apple ID 개인팀). 아래 iOS 항목 참고.

**Android (직접 서명 APK 공유) — ✅ 빌드·전체 흐름 스모크 완료 (2026-07-13).** 남은 선택 항목만:
- [x] ✅ **앱 아이콘 교체 완료 (2026-08-02, #6)** — 생성기로 Android/iOS 전 크기 + adaptive/themed 신설. `flutter_launcher_icons` 는 **도입하지 않았다**([../CLAUDE.md](../CLAUDE.md) "로고 / 앱 아이콘"). Play Console 아이콘은 `tenk_app/assets_src/icon/play_store_512.png` 를 콘솔에 직접 업로드.
- [ ] (선택) APK 크기(~165MB) 줄이려면 `--split-per-abi` (arch별 ~55MB)

**Play Console 내부 테스트 — ✅ 게시·카카오 로그인 확인 (2026-07-08).**

**백엔드 — 🟠 미배포 1건: #28 ⓑⓒⓕ 이용자 접속기록 (2026-08-17).** 스키마 변경 없음.
- ⚠️ **compose 전송이 필수다 — 새 볼륨 `app-logs` 가 생겼다.** 이미지만 교체하면 로그가 **정상적으로 쓰이면서** 재배포에 사라지고 **에러가 하나도 안 난다**(08-08 `admin-audit` 사고와 같은 모양). **§5.1 ⓪ md5 대조 → 전송 → `pull && up -d`** 순서.
- 배포 후 확인: `docker compose config` 에 **`app-logs` 볼륨**이 보이는지 / `docker compose exec backend ls -la /app/app-logs` 에 `access.log`·`application.log` 두 개 / 아무 요청이나 쏜 뒤 그 줄에 **쿼리스트링·토큰이 없는지** / **`/api/users/me` 401 도 기록되는지**(필터 순서가 살아 있다는 증거).
- 그 이전 건들(#30 로그 위생 등)은 2026-08-17·08-08 에 반영 완료. 검증 결과·소실 사고는 [handoff-archive.md](handoff-archive.md).
- ⚠️ **다음 배포 때 반드시 `deploy/docker-compose.yml` md5 를 맥 것과 대조할 것** — [docker-deployment.md](docker-deployment.md) **§5.1 ⓪** 로 신설된 필수 단계다. `pull && up -d` 는 **이미지만** 갈아끼우고 compose 변경은 **아무 에러 없이 조용히 누락**된다. **이미 두 번 밟았다**(08-08 `admin-audit` 볼륨 → 접속기록 9일치 소실 / 08-17 로그 로테이션).

- [x] ✅ **라이브 DB 스키마 3건 선적용 완료 (2026-08-08)** — DBeaver 로 직접 적용. `inquiry` 는 schema.sql 블록에 `handler_note` 가 **이미 포함**돼 있어 별도 ALTER 가 필요 없었고, `feedback` 만 ALTER 를 쳤다.
  ```sql
  CREATE TABLE `inquiry` (...);     -- handler_note 포함
  CREATE TABLE `admin_user` (...);  -- ⚠️ 행은 넣지 않는다 (부팅 시 tenk.admin.account 로 자동 생성)
  ALTER TABLE `feedback` ADD COLUMN `handler_note` VARCHAR(500) NULL AFTER `os_version`;
  ```
  ⭐ **부팅 성공(`Started TenkApplication in 4.758 seconds`) 자체가 이 3건의 검증**이다 — `ddl-auto=validate` 라 하나라도 빠지면 거기서 죽는다.
- [x] ✅ **dbinit 볼륨 시드 갱신 완료 (2026-08-08)** — ⚠️ **처음엔 맥에 있던 구버전(18.1kB)이 그대로 들어갔다.** 라이브는 멀쩡하고 **다음 DB 클린 재구축 때만** 부팅 실패하는 종류라 가장 놓치기 쉽다. **`docker cp` 후 전송 바이트 수를 리포의 `docs/schema.sql` 크기와 대조할 것**(당시 23,973B → `Successfully copied 24kB` 확인). 파일 이송은 SSH 키가 깨져 있어 `tailscale file cp docs/schema.sql macmini:` → 맥에서 `tailscale file get .` 로 했다.
- [x] ✅ **텔레그램 자격증명 채움** (2026-08-06). chat_id `8946220822`.
- [x] ✅ **서버 측 배포 검증 전항목 통과 (2026-08-08)** — 윈도우에서 공개 HTTPS 로 실측:
  - **앱 체인 무회귀(제일 중요)**: `GET /api/users/me` → **401 `{"success":false,"error":{"code":"C0003",…}}`**. 로그인 화면 리다이렉트가 아니다 = 보안 체인 2개 분리가 살아 있다
  - 관리자 체인: `/admin` → **302 → `/admin/login`**, 로그인 페이지 **200**
  - `POST /api/inquiry` 미인증 → **401** (PERMIT_ALL 에 안 샜음) / OpenAPI 에 `/api/inquiry` 등록
  - privacy.html **§8 안전성 확보조치** 노출 / HSTS 정상
- [ ] 배포 후 검증 — **사람 눈이 필요한 잔여분**:
  - #23 — `POST /api/inquiry`(인증) → 행 생성 + **메일·텔레그램 수신** / 인증 없이 → 401 / 회신 이메일 없이 → 400
  - #27 — `https://tenk.hjson248.com/admin` 로그인(prod yaml 계정) → 문의 목록·처리 / **`GET /api/users/me` 가 여전히 401 JSON `C0003`**(앱 체인 무회귀, 제일 중요) / 알림 본문 끝에 패널 링크
  - **알림에 내용이 안 들어가는지** (2026-08-07 추가) — 문의·의견을 1건씩 넣어 메일·텔레그램이 **`새 문의가 도착했어요.` + `미처리 문의 개수 : N` + 링크**만 담는지. **본문·회신 이메일·닉네임·`#id` 가 한 글자라도 보이면 회귀다.** 이어서 패널 상세의 **[메일로 답장]** 을 눌러 **원문이 인용된 채로** Gmail 작성 창이 열리는지(⚠️ 이게 답장 스레드를 아카이브로 만드는 유일한 장치다). 리마인드 시각은 **저녁 6시**.
  - **유형이 한글 라벨로 뜨는지** (2026-08-07 추가) — 문의 목록·상세 / 의견 목록의 '유형' 칸이 `PRIVACY` 가 아니라 `개인정보`. 라벨은 `InquiryType`·`FeedbackType` 의 `label` 이고 **앱의 선택지 문구와 별개**다(의견은 일부러 다르다 — [../CLAUDE.md](../CLAUDE.md) "의견 보내기" 참고).
  - [x] ✅ **#23·#27 화면·알림 검증 완료 (2026-08-08)** — 패널 로그인·문의 처리·유형 한글 라벨·[메일로 답장] 원문 인용, 알림 2겹 수신 + **내용 미포함** 확인. **Gmail 스팸 필터 문제도 해결됨**(수신 계정에 `from:system.tenk@gmail.com` 필터).
  - [ ] 🐞 **접속기록 IP 가 전부 `172.19.0.1`** → **백로그 #28** (§1-F). 기록 자체는 정상적으로 남으므로 배포를 막지 않는다.
- [x] ✅ **관리자 계정 설정 완료 (2026-08-06)** — [application-prod.yaml](../tenk-backend/src/main/resources/application-prod.yaml) 의 `tenk.admin.account`. **ID 는 개인 메일이 아니라 서비스 전용 `admin.tenk@`** 로 잡았다(개인 메일을 ID 로 두면 대입 공격에 ID 를 이미 넘겨준 셈이고, 로그인 실패 로그에도 쌓인다). 바꾸려면 그 값을 고치고 재시작 — DB 해시가 자동 동기화된다(패널에 변경 화면은 없다, 의도).
- [x] ✅ **#7 예외처리 + #17 알림 지표 배포 완료 (2026-08-03)** — 스키마 변경이 없어 **이미지 교체만** ([docker-deployment.md](docker-deployment.md) §5.1). 테스트 226개 `--rerun-tasks` 전원 통과 후 push → 맥에서 `pull && up -d`. 검증 전항목 통과: `/v3/api-docs` 에 **`currentStreak`·`noSpendDays`**(#17) / **`C0005`·`C0006`·`C0007` 3종 실측**(#7) / 401 envelope `C0003` / HTTPS·HSTS 정상 / 버전 게이트 `UPDATE_REQUIRED`·`LATEST`.
  - ⚠️ **`curl /api/nope` 로 #7 을 확인하려던 예전 메모는 틀린 값이었다** — `PERMIT_ALL` 이 **와일드카드가 아니라 정확 경로 목록**이라 인증 없는 미등록 경로는 Security 가 먼저 **401 C0003** 으로 자른다(디스패치까지 안 간다). `handleMalformedRequest` 를 인증 없이 찌르려면 **PERMIT_ALL 안에서** 골라야 한다: `GET /swagger-ui/nope.html`→404 C0005 / `GET /api/auth/refresh`(POST 전용)→405 C0006 / `POST /api/auth/refresh` + `Content-Type: text/plain`→415 C0007.
  - ⚠️ **맥에서 자기 도메인으로 curl 하면 연결 자체가 안 된다**(공유기 NAT 헤어핀 미지원 — [docker-deployment.md](docker-deployment.md) §8.2). 맥 로컬 검증은 `http://localhost:8080` 직결 또는 `--resolve tenk.hjson248.com:443:127.0.0.1`.
- [x] ✅ **백엔드 재배포 완료 (2026-07-25)** — 연령 게이트 + 성별 + role/테스트로그인 제거를 prod 에 배포. 라이브 DB 3컬럼(`birth_date`/`gender`/`role`) `ALTER` 선적용 → `docker compose pull && up -d` → 부팅 정상 + `/api/auth/test/login` 제거 확인(401=security-first). `tenk_dbinit` 볼륨 `01-schema.sql` 도 갱신(클린 재구축 대비). `delete-account.html`/`privacy.html` 은 이미지에 구워져 함께 반영. 배포 순서·함정은 [docker-deployment.md](docker-deployment.md) §5.5.
- [x] ✅ **§0-DEPLOY 9건 prod 배포 완료 (2026-07-30)** — #5·#10·#11·#1·#14·#2·#4·#9ⓐ·#9ⓑ 일괄. **DB 클린 재생성** 방식(볼륨 3개 삭제 → `dbinit` 재시딩 → clean init)이라 마이그레이션 SQL 8단계를 안 탔다. **서버 측 검증 전항목 통과** — 401 envelope / 버전 게이트 `LATEST`·`UPDATE_REQUIRED` / 새 테이블 3종 / `user.email` 부재 / 코드성 8개 컬럼 전부 `varchar`(enum 0) / badge 9행. 실행 기록은 [handoff-archive.md](handoff-archive.md), **재사용 가능한 절차는 [docker-deployment.md](docker-deployment.md) §5.7**.
- [x] **연령 확인 게이트 에뮬 E2E — ✅ 완료 (2026-07-21)** — 신규 가입(연령→동의→닉네임), 기존 미확인 계정(앱 시작 시 연령 게이트), 만 14세 미만 입력 시 안내→로그아웃→계정 파기 확인. (실기기 재확인은 새 화면 추가 시 상시 체크 항목)
- [x] **'내 정보' 성별 선택 입력 — ✅ 완료 (2026-07-21)** — 입력 / '입력 안 함'으로 되돌리기 양방향
- [x] ✅ **테스터 로그인 회의 완료 (2026-07-25)** — 결정·구현 완료. App access=데모 카카오 계정, 앱/서버 테스트 로그인 제거, 시딩은 계정 role(USER/TESTER)로 재게이팅. 회의록·근거는 [decisions.md](decisions.md) "테스터 로그인 회의". 남은 실행 항목은 아래 "앱 릴리스 + Play 콘솔 폼" 으로 흡수됨.
- ~~terms.html / privacy.html 변호사 검수~~ → **드롭 (2026-08-06, 사용자 결정).** 백로그에서 제외한다. 대신 **문서를 실제 동작과 일치시키는 것**을 유지 기준으로 삼는다 — 두 문서의 모든 문장은 코드·배치·설정에 대응하는 사실이어야 하고(보관 기간 상수, 파기 순서, 안전성 확보조치 등), 정책을 바꾸면 같은 커밋에서 문서도 고친다. 법률 자문이 필요해지는 트리거는 **결제 도입 · 광고 SDK · 제3자 제공 · 해외 이전** 처럼 문서가 사실 서술을 넘어 법적 판단을 요구하게 될 때.

**🟠 앱 릴리스 + Play 콘솔 폼 — 한 묶음으로 처리 (다음 착수 후보).** 답안은 [play-console-app-content.md](play-console-app-content.md) 에 전부 준비됨.

> **왜 묶는가**: 백엔드는 LIVE 지만 **앱에는 그동안의 변경이 안 실려 있었다** — Play 에 게시된 마지막 빌드가 2026-07-08 분이고 그 뒤 #11·#13·#3·#1·#14·#2·#4·#8·#17·#18·#6 이 계속 쌓였다.
>
> **실제 순서는 빌드·업로드가 먼저였다** (아래 ③ 완료). 실기기 검증을 앞에 두면 APK 를 따로 굽고 AAB 를 또 굽게 되는데, **내부 테스트 트랙에 올려 그 설치본으로 검증하면 한 번만 구우면 되고 심사자·테스터가 받는 것과 같은 바이너리를 보게 된다**(Play App Signing 재서명본이라 카카오 키해시 경로까지 실물로 확인됨).

- [x] ✅ **① 실기기 검증 완료 (2026-08-03)** — Play 내부 테스트 설치본(Play App Signing 재서명본)으로 전 항목 통과. 로고·런처 아이콘(원형/스퀘어클/테마) · 온보딩 3단 · **알림 프라이밍이 '나중에' 로 넘어감(게이트 아님 확인)** · TESTER 승격·시딩 · 확정→배지 모달→결과 카드 · 갤러리 저장 PNG · 영상 export 마지막 클립 · 카테고리 9종 · 알림 설정 토글·시각 · 성별 3칸 · 닉네임 쿨다운 안내 · 의견 보내기(익명 저장) · 비행기 모드 · 정적 문서 · **탈퇴 → U0007 → 철회/재가입 양쪽**.
  - **오해였던 것 2건(정상 동작)**: ⓐ 확정 시 **`다음 (1/2)` 이 안 뜬 건 정상** — 체인 표기는 *신규* 배지가 2개 이상일 때만이고, 시딩된 확정 대기 챌린지는 STREAK·NO_SPEND 를 이미 받은 상태라 새로 지급된 건 트로피 하나뿐이었다. ⓑ "상태바 뒤 블록색" 은 실제로 칠해져 있었다.
  - 🐞 **결함 2건 발견 → 백로그 #19·#20 으로 등록** (아래 §1-A).
  - [ ] 카카오 로그인 → 온보딩 전체(연령 → 동의 → 닉네임) 통과
  - [ ] 메뉴 → 앱 버전 행 "최신 버전이에요" (#5)
  - [ ] **지출 기록 → 카테고리 9종 선택 → 상세에 아이콘·라벨 정상** ← #9-ⓑ 의 유일한 실질 리스크(wire format 이 Jackson→Flutter 까지 이어지는지)
  - [ ] 닉네임 변경 후 재탭 → "내일 오후 ○시 ○분부터 가능해요" (#11)
  - [ ] 의견 보내기(이메일 없이) → `SELECT * FROM feedback;` 에 행 + `reply_email` NULL (#2)
  - [ ] 내 정보 → 성별 3칸 토글 저장·되돌리기 (#4)
  - [ ] 탈퇴(사유 미선택으로도 가능) → 재로그인 시 U0007 선택 다이얼로그 → 철회/재가입 양쪽 (#1·#14)
  - [ ] 정적 문서 — privacy 수집표에 '의견 보내기' 행 / 보관 목적 "탈퇴 철회 대응" · 기간 1개월 / delete-account 에 `TenK` (#10·#1·#2)
  - [ ] **비행기 모드 훑기 (#7)** — 에뮬에선 완료(내 정보·의견 보내기·목록 새로고침·메뉴). 실기기에선 **아직 안 본 화면만** 확인: 챌린지 상세 / 기록 저장 / 영상 업로드 중 끊김
  - [ ] **로고·아이콘 (#6·#25) — 기기에 설치해봐야만 알 수 있는 것들**
    - [ ] 런처 아이콘 — **홈 화면 아이콘 모양을 원형/스퀘어클로 바꿔가며** 확인(adaptive 마스크에 획이 잘리지 않는지). Android 13+ 는 **테마 아이콘**도 켜서 확인(단색이라 게이지 두 톤이 사라지는 게 정상). ⚠️ **2026-08-05 에 마크를 키웠으므로(#25, extent 0.70) 이 항목은 반드시 다시 볼 것** — 잉크가 안전원 반지름의 78% 까지 닿는다(이전 62%)
    - [ ] Play Console 아이콘 **재업로드** — `tenk_app/assets_src/icon/play_store_512.png` (#25 로 갱신됨)
    - [ ] **밝은 배경화면 위에서 아이콘 경계** — 바탕이 흰색이라 흐려진다. 견딜 만한지 보고, 아니면 민트 반전으로 전환 검토(마크 색만 바꾸면 되고 생성기 재실행 1회)
    - [ ] 로그인 화면 로고 lockup(마크 88 + 워드마크 40) — 작은 화면에서 카카오 버튼을 밀어내지 않는지
    - [ ] 결과 카드 워터마크 — 캡처 PNG·영상 마지막 클립 **양쪽**에서 마크가 나오는지
- [x] ✅ **② TESTER role 재승격 완료 (2026-08-17)** — #30 배포 검증 후 카카오 재로그인 → 패널에서 승격. **배포 → 재로그인 순서**를 지켜 본인 프로필이 구버전 로그에 안 남게 했다. (아래는 다음에 또 필요해질 때의 절차)
  - **절차 (DB 클린 재생성 때마다 다시 필요하다)** — ⚠️ **카카오로 한 번 로그인해 계정이 만들어진 뒤에** 승격할 것 — 계정 자체가 없으면 검색이 안 된다. **#27 이후로는 [관리자 패널](https://tenk.hjson248.com/admin) → '사용자'** 에서 카카오 회원번호로 검색해 버튼 한 번(패널 배포 후). 폴백 SQL: `UPDATE user SET role='TESTER' WHERE provider='KAKAO' AND provider_user_id='<카카오회원번호>';` — **심사자 데모 계정은 승격 금지**(시딩 버튼이 노출됨).
- [x] ✅ **③ 새 AAB 빌드 완료 (2026-08-03)** — `pubspec` **`1.0.0+3` → `1.1.0+4`**(기능 추가라 minor) → `flutter analyze` 0건 → `flutter build appbundle --release --dart-define=API_BASE_URL=https://tenk.hjson248.com` → `build/app/outputs/bundle/release/app-release.aab` (100.4MB). 병합 매니페스트 실측: `versionCode=4`/`versionName=1.1.0`, **`SCHEDULE_EXACT_ALARM` 없음**(inexact 방침대로), 알림 권한 4종 반영.
  - ✅ **`app_config` 갱신 완료** — `latest_version='1.1.0'` + **`min_supported_version='1.1.0'`(강제)**. 내부 테스터를 최신 빌드로 통일하려는 의도적 선택이라, **1.1.0 미만은 전원 ForceUpdateScreen 에 갇힌다.** 되돌리려면 `min_supported_version='1.0.0'` 으로 UPDATE 한 줄(재배포 불필요). 검증: 구버전→`UPDATE_REQUIRED` / 신버전→`LATEST`.
  - ✅ **Play 내부 테스트 게시 + 실기기 다운로드 확인 (2026-08-03)** — `min` 을 올려둔 상태였으므로 게시 전까지 구버전이 잠겨 있었고, 게시로 그 구간이 닫혔다. ⚠️ **다음에도 이 UPDATE 는 게시 반영 뒤에** — 스토어에 구버전뿐인 상태에서 min 을 올리면 업데이트 버튼을 눌러도 나갈 길이 없다.
  - **Play 업로드 시 "난독화 파일 없음" 경고는 정상** — R8 을 의도적으로 꺼둬서(카카오 Pigeon 제거 회귀) 매핑 파일이 애초에 없다. 난독화가 없으니 크래시 스택트레이스도 이미 읽을 수 있다.
- [x] ✅ **⑤ `1.2.0+5` 빌드·업로드 완료 (2026-08-08)** — `1.1.0+4`(08-03) 이후 **8커밋**이 안 실려 있었다: `#19` 하단 액션 잘림 · `#24` 휠 picker+세로 고정 · `#20` 컨페티 잔존 · `#21`/`#26` 문구 정리 · `#22` 알림 권유 위치 · `#25` 런처 아이콘 확대 · **`#23` 고객센터 문의하기(신규 기능 → minor bump)**. `flutter analyze` 0건 + `flutter test` **22개** 통과 → `flutter build appbundle --release --dart-define=API_BASE_URL=https://tenk.hjson248.com` (100.5MB). 병합 매니페스트 실측: **`versionCode=5`/`versionName=1.2.0`**, `POST_NOTIFICATIONS` 있고 **`SCHEDULE_EXACT_ALARM` 없음**(inexact 방침대로).
  - [x] ✅ **`app_config` 를 `1.2.0` 으로 설정 완료 (2026-08-08)** — 게시 반영 후 **관리자 패널 → '앱 버전'** 에서. ⚠️ **DB 클린 재생성을 하면 이 값이 시드(`1.0.0/1.0.0`)로 되돌아가니 재설정할 것**(이번에도 그랬다). ⚠️ **`min` 을 올릴 땐 항상 스토어 게시 반영을 먼저 확인** — 스토어에 그 버전이 없으면 강제 업데이트 화면에서 나갈 길이 없다.
  - [ ] Play Console 앱 아이콘 **재업로드** (`tenk_app/assets_src/icon/play_store_512.png` — #25 로 마크가 커졌다)
- **DB 3306 포트 노출 — 열어둔 채로 간다 (2026-08-08 사용자 결정).** 상세·지켜야 할 선은 [docker-deployment.md](docker-deployment.md) §5.6. **매 세션 다시 지적하지 말 것.**
- [ ] **④ Play Console 폼 입력**:
  - [x] 개인정보처리방침 URL / 광고 / 콘텐츠 등급 설문 — ✅ 완료 (2026-07-21)
  - [ ] **앱 액세스 권한(로그인 세부정보)** — 답안 확정(**데모 카카오 계정**, [play-console-app-content.md](play-console-app-content.md) §2). 남은 실행: **데모 카카오 계정 생성** + 콘솔 폼에 아이디/비번 입력 + **새 기기 로그인 재현**(추가 인증 안 뜨는지)
  - [ ] **타겟층 및 콘텐츠** (13~15 포함 → 가족 정책 확인란) — 미완
  - [ ] **데이터 안전** + 데이터 삭제 URL — 미완

---

**iOS — 맥에서. 빌드·실행은 지금 무료로 가능, TestFlight 만 유료(나중)**
- 공통 사전: `xcode-select --install`, `sudo gem install cocoapods`(또는 brew), `cd tenk_app && flutter pub get && (cd ios && pod install)`.
- 첫 빌드 걸림돌: **ffmpeg_kit/camera pod 의 iOS 최소버전** — `ios/Podfile` 의 `platform :ios, 'xx'` 를 14.0 정도로 올려야 pod install 될 수 있음. 카카오 iOS URL scheme·권한 usage description 은 이미 Info.plist 에 있음. **단 카카오 콘솔에 iOS 플랫폼(번들 ID) 추가 등록 필요**(현재 Android 만 등록). iOS 는 키해시 개념 없음.
  - **(무료) 시뮬레이터**: `open -a Simulator` → `flutter run --dart-define=API_BASE_URL=https://tenk.hjson248.com`. 계정 불필요. ⚠️ 시뮬레이터엔 카메라 없어 영상 녹화 테스트 불가(로그인·챌린지·기록 흐름은 OK).
  - **(무료) 본인 아이폰 실기기**: `open ios/Runner.xcworkspace` → Runner 타깃 → Signing & Capabilities → Team=무료 Apple ID(Personal Team), Bundle ID 유니크(예 `com.hjson.tenkApp`), automatic signing. 아이폰 개발자 모드 ON + "이 컴퓨터 신뢰" → `flutter run -d <iphone>`. 무료 서명은 **7일 만료**(재실행으로 갱신).
  - **(유료·나중) TestFlight**: Apple Developer Program 가입 → App Store Connect 앱 레코드 → `flutter build ipa --release --dart-define=...` → Transporter 업로드 → 내부 테스터 초대.
- **SSH 로 원격 빌드 가능 범위**: 컴파일·`flutter build`·`xcodebuild`·`xcrun simctl`(시뮬레이터 부팅/설치/실행/스크린샷)은 SSH OK → **시뮬레이터 목표면 SSH로 거의 다 됨**. 단 **코드 서명 키체인**(codesign 이 GUI 팝업 → `security unlock-keychain` + `set-key-partition-list` 로 사전 인가 필요), **무료 개인팀 자동 프로비저닝**(Xcode GUI 한 번 필수), **실기기 신뢰·개발자 모드**(아이폰 화면 탭)는 순수 SSH 불가. 권장: **첫 서명·기기신뢰 세팅은 화면공유(VNC)로 한 번, 이후 반복 빌드만 SSH**.

### 1. 앱 UX 다듬기 (백로그)

> 2026-07-11 배치의 완료 항목(챌린지 상태색 / 카테고리 목록화+아이콘 / 금액입력 보조표시 / 필수 별표 / '메모'→'한 줄 평' / 성공 트로피 배지 / 7·11 날짜 타임존 버그 / 챌린지 이름 필드 / 영상 자막 위치·스타일)과 2026-06-16 실기기 3블록 검증은 전부 ✅ 완료 → 상세는 [handoff-archive.md](handoff-archive.md). **드롭**: "챌린지 색깔 기능"(같은 문서) / "목록에 메모 노출"(2026-07-19 — 긴 메모가 목록 높이를 흔들고, 상세 진입으로 확인 가능해 목록 노출 가치가 낮다고 판단).

#### 1-A. 등록된 할 일 배치 (2026-07-25)

> 사용자가 한 번에 넘긴 미착수 목록. 각 항목은 착수 전 별도 설계/합의 필요 ([[feedback-plan-before-code-edit]]). 규모가 큰 건은 회의 안건으로 승격 ([[feedback-defer-decisions-to-dedicated-meeting]]).

- ~~#1 탈퇴 철회 흐름~~ → ✅ 완료 (2026-07-27), **탈퇴 UX 전반 재설계로 확장**. 유예 1개월 + 복귀 시 **철회/재가입 선택**(U0007 → 선택 다이얼로그 → `/restore` 또는 `/rejoin`, 재가입은 2차 확인 후 옛 계정 즉시 파기). 판정은 계정 row 생존 하나뿐(배치 타이밍 사각지대 방지). 보관 목적을 "탈퇴 철회 대응"으로 바로잡고 privacy.html·delete-account.html 갱신, 탈퇴 확인 문구는 철회를 광고하지 않으면서 참인 문장으로. 테스트 **175개** 전원 통과 + `flutter analyze` clean + **에뮬 E2E 검증 완료**. 상세는 [handoff-archive.md](handoff-archive.md), 회의록 [decisions.md](decisions.md) "탈퇴 UX 회의", 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증 — 탈퇴 후 유예 기간". ⚠️ ✅ **prod 배포 완료 (2026-07-30)**.
- ~~#2 메뉴 항목 추가~~ → ✅ 완료 (2026-07-28). 이름·아이콘 확정('메뉴' + `Icons.menu`, 07-25) → 앱 버전 행(07-26) → **의견 보내기 + 문의 창구(07-28)** 로 마무리. 의견은 **익명 저장**(user_id 없음)이고 **회신 이메일을 적었는지가 '답변이 필요한가'의 유일한 스위치**다. 곁가지로 법적 고지에 **'문의' 행(mailto)** 을 넣어 고지한 창구를 앱 안에서 두 단계로 닿게 했다. 문의≠피드백 구분과 국내 사례 리서치는 [decisions.md](decisions.md) "의견 보내기 회의", 규칙은 [../CLAUDE.md](../CLAUDE.md) "의견 보내기 (피드백)". 테스트 **195개** 통과 + `flutter analyze` clean + **에뮬 E2E 검증 완료**(이메일 유/무 전송·형식 오류 차단·문의 mailto). ✅ **prod 배포 완료 (2026-07-30)**.
  - (예고했던 효과음/진동 설정은 **#8 에서 '설정' 하위 화면으로 신설됨**(2026-08-01). 이름은 '알림/효과 설정' 이 아니라 **'설정'** — 푸시 알림이 아직 없어서고, 생기면 그 화면에 들어온다(#17). 최상위 토글 금지는 그대로.)
- ~~#3 날짜·시간 선택 UI 정리~~ → ✅ 완료 (2026-07-27, 2단계). ① 로케일 `ko` 고정 + **시각 표기를 로케일 기반으로 통일**(24h 고정 `formatDateTime` 제거) + 공용 헬퍼 [common/date_time_picker.dart](../tenk_app/lib/presentation/common/date_time_picker.dart) ② **시각 picker 를 휠(드럼) 자체 위젯으로 교체**([wheel_time_picker.dart](../tenk_app/lib/presentation/common/wheel_time_picker.dart) — 무한 순환·직접 입력·오전/오후 자동 전환, **dial 제거**) + 기록 화면 일시를 `날짜 | 시간` **2칸**으로 분리([DateTimeFields](../tenk_app/lib/presentation/amount/widgets/date_time_fields.dart) 공유). 날짜 picker 는 Material 그대로. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — Flutter". **앱 전용 변경이라 백엔드 재배포와 무관**.
- ~~#4 모달 → 화면 전환~~ → ✅ 완료 (2026-07-29). 모달 **16곳을 전수 조사**해 성격별로 갈랐다 — **확인·차단 다이얼로그는 유지**(화면으로 빼면 되돌릴 자리가 멀어짐), **'내 정보' 의 내 속성 편집은 화면**(닉네임·성별), **폼·목록 안에서 값 하나 고르기는 바텀시트**(카테고리 ×2·의견 유형·챌린지 이름·자막). 백로그가 짚은 3개 외에 **챌린지 이름 변경·의견 유형 2건을 더 찾아** 같이 처리했다([[feedback-consistency-over-pinpoint]]). 공용 위젯 4종 신설(`showSelectionSheet`/`showTextInputSheet`/`SelectionField`/`TapFieldBox`) — 특히 `SelectionField` 는 **`FormField` 로 감싸 `validator` 를 유지**해 드롭다운을 걷어내고도 기록/수정 화면의 검증 흐름이 그대로 돈다. 곁가지로 **성별 `Gender.OTHER` 제거 + 3칸 토글**(남성/입력 안 함/여성)이 같이 들어갔다. 테스트 **195개 통과** + `flutter analyze` clean + **에뮬 E2E 검증 완료** (닉네임·성별 화면 push/pop 과 '내 정보' 즉시 반영 / 성별 3칸 토글 저장·'입력 안 함' 되돌리기 / 카테고리·의견 유형 바텀시트 선택 + **미선택 저장 시 검증 에러**(FormField 배선) / 챌린지 이름·자막 바텀시트 + 키보드 인셋). 회의록은 [decisions.md](decisions.md) "모달 → 화면·바텀시트 전환", 규칙은 [../CLAUDE.md](../CLAUDE.md) "모달 사용 기준". ✅ **prod 배포 완료 (2026-07-30)**.
- [x] ✅ **#5 앱 시작 강제/권장 업데이트 — 구현 완료 (2026-07-26)** — 판정은 **서버가 진실의 원천**(클라 semver 비교 안 함). 정책은 `app_config` **단일 행**(min/latest/스토어 URL)에 두고 **재배포 없이 SQL 로 갱신**(관리자 UI 없음 — TESTER 승격과 동일 운영 방식으로 결정, [decisions.md](decisions.md) "앱 버전·업데이트 게이트 회의"). `GET /api/app/version`(PERMIT_ALL) → [SessionGate](../tenk_app/lib/app/session_gate.dart) 가 **버전 게이트를 가장 먼저** 판정 → 강제=[ForceUpdateScreen](../tenk_app/lib/presentation/update/update_gate.dart)(back 차단)/권장=[RecommendedUpdateHost](../tenk_app/lib/presentation/update/update_gate.dart)(1회 안내). fail-open(서버·버전 이상 시 미적용). 규칙 진실의 원천은 [../CLAUDE.md](../CLAUDE.md) "앱 버전 / 강제·권장 업데이트". ✅ **로컬 DB `app_config` 적용 + 백엔드 테스트 160개 전원 통과 + 에뮬 E2E 검증 완료 (2026-07-26)**. ✅ **prod 배포 완료 (2026-07-30)** — `app_config` 시드 1행(1.0.0/1.0.0/Play URL) 적용 + 버전 게이트 응답 확인. iOS 스토어 URL 은 iOS 출시 때 SQL 로 채움. 배포 메모는 아래 "운영 고려사항" 참고.
- ~~#6 로고 / 앱 아이콘 정리~~ → ✅ 완료 (2026-08-02). 착수해보니 **아이콘만의 문제가 아니었다** — 런처 아이콘이 기본 Flutter 아이콘인 건 알고 있었지만, `mipmap-anydpi-v26` 이 없어 **adaptive icon 자체가 없었고**(원형 런처·Android 13 테마 아이콘 미대응) 앱 안에도 로고라 할 게 없었다(로그인 화면이 `Text('TenK', 48)` + 하드코딩 `Colors.black54`, 디자인 토큰조차 안 씀).
  - **마크 = `10`** (세로획+깃발=`1`, 오른쪽 링=`0`이자 예산 게이지). 후보를 **실제로 그려서 48px 에서 형태가 남는가**로 골랐다 — `T`·`10K`·`KK`·`K` 를 다 그려봤고, 특히 "링 게이지로 K 를 만들자" 는 안은 **닫힌 곡선이 K 의 '팔' 로 안 읽힌다**는 걸 6가지로 확인하고 접었다. 트랙을 **완전한 원**으로 둔 건 갭만 있는 안이 `1C` 로 읽혔기 때문. 근거는 [decisions.md](decisions.md) "로고·앱 아이콘".
  - **자산 PNG 대신 코드로 그린다** — 파이썬 생성기가 런처 PNG 41개를, Dart `TenkLogoPainter` 가 앱 안 렌더를 담당. ⚠️ **비율 상수가 두 파일에 있으니 같이 고칠 것.** `flutter_launcher_icons` 는 **도입하지 않았다**(원본은 어차피 손으로 만들어야 해 얻는 게 없고 생성기가 둘이 된다).
  - 곁가지: `android:roundIcon` 선언 + `values/colors.xml` 신설 + `AppColors.logoTrack` 토큰 + 결과 카드 워터마크에 마크 추가(`CustomPainter` 라 캡처 경로에 `precacheImage` 불필요) + `__pycache__` gitignore.
  - `flutter analyze` clean. **Dart painter 가 파이썬 산출물과 같은 형상을 그리는지 실제 렌더로 확인**(임시 위젯 테스트 → PNG 추출, 확인 후 삭제). 그 과정에서 워터마크를 단색으로 두면 `1C` 로 읽히는 걸 발견해 **뮤트 톤이되 트랙은 유지**하도록 고쳤다. ⚠️ **실기기 확인은 §0 ① 에** — 마스크 잘림·밝은 배경화면 경계는 설치해봐야 안다.
- ~~#7 예외처리 전수 점검~~ → ✅ 완료 (2026-07-31). 커버리지는 이미 좋았고(백엔드 `throw` 40여 곳이 전부 `BusinessException`, Flutter 의 `catch (_) {}` 41곳도 근거 주석이 붙은 의도된 침묵), 진짜 문제는 **양쪽 다 아는 규칙을 일부가 안 지킨 것**이었다 ([[feedback-consistency-over-pinpoint]]). **앱**: 네트워크 오류가 영문(dio `message`/`toString()`)으로 뜨던 걸 **원인별 3분기 한국어 폴백**으로 교체 + 예외 원문을 직접 찍던 5곳 정리(곁가지로 카메라 권한 안내를 따로 갈라 회귀 예방). **백엔드**: 잘못된 호출 6종이 **전부 500** 이던 것을 실측으로 확인하고 `handleMalformedRequest` 로 400/404/405/415 정정. **에뮬 검증이 갭을 하나 더 잡아**(새로고침 실패 무피드백 — 성공한 것처럼 보였다) [async_state.dart](../tenk_app/lib/presentation/common/async_state.dart) 한 곳으로 해결. 테스트 **207개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — 백엔드/Flutter". ⚠️ **백엔드 재배포 필요** (§0).
- ~~#8 배지 획득 효과 개선~~ → ✅ 완료 (2026-08-01). **출발점이 백로그 문구와 달랐다** — `assets/lottie/confetti.json` 이 **아예 없어서**(코드의 `errorBuilder` 가 조용히 생략) 실제 연출은 줌·wobble·글로우·햅틱뿐이었다. 레퍼런스는 사용자가 지정한 **듀오링고 + 챌린저스**(리포의 [references/](../references/) 에 이미 있던 토스 리워드 화면 포함)를 뜯어 우리에게 없던 것 4가지(획득의 크기·다음 목표·명시적 CTA·정체성 언어)를 뽑았다.
  - **핵심 결정**: 모달 유지 / **9종 전부 동일한 최대 연출**(위계는 연출이 아니라 **자산의 색** — 열어보니 이미 브론즈 3 → 실버 7 → 골드 14 → 주얼 30 사다리였다) / 칭호 없음 / 색은 **타입이 아니라 단계**로 갈려 매핑이 **5개** / 컨페티는 `CustomPainter`(Lottie 는 색 연동 불가 → 의존성 제거) / **'다음 목표'는 `현재값 + 남은 일수 >= 다음 칸` 일 때만 사다리, 아니면 챌린지 완주로 폴백**(사용자 지적 "5일짜리는 7일 배지를 못 딴다"에서 나온 규칙).
  - **곁가지**: 메뉴에 **'설정'(효과음·진동) 신설** + **'계정 설정' → '계정 정보'** 개명 + 토글 전수 적용 / `noSpend` 라벨 오표기 정정 / 배지 PNG 384px 리사이즈 / **수동 시드 [seed-badge-demo.sql](seed-badge-demo.sql)**(색 사다리·체인·폴백·트로피 6종, 반복 실행 가능 — ⚠️ 앱의 '테스트 데이터 재생성'을 누르면 wipe 된다).
  - **에뮬 검증이 결함 3건을 잡았다** — barrier 가 옅어 뒤 화면과 경쟁(→0.93) / `Material` 조상이 없어 텍스트가 노란 밑줄로 렌더 / **확정 시 트로피가 누락되고 결과 카드로 직행**(`finalize` 응답엔 `AFTER_COMMIT` 지급분이 없어서 → `reload()` 재조회로 교체).
  - `flutter analyze` clean + **에뮬 E2E 전 분기 검증 완료**. **앱 전용이라 백엔드 재배포와 무관.** 상세는 [handoff-archive.md](handoff-archive.md), 회의록 [decisions.md](decisions.md) "배지 획득 연출", 규칙은 [../CLAUDE.md](../CLAUDE.md) "배지 획득 연출" · "설정".
- ~~#17 알림 기능 및 설정~~ → ✅ **구현 완료 (2026-08-02).** 회의록 [decisions.md](decisions.md) "알림 기능", 규칙은 [../CLAUDE.md](../CLAUDE.md) "알림".
  - **로컬 알림만**(FCM 금지) / 발신 채널 **3종**(매일 리마인더·종료 임박·확정 대기) + **배지 근접은 리마인더 문구 승격** / 겹치면 **발신 1개 + 문구 우선순위** / 설정 토글 **마스터 1 + 종류별 3 + 시각 선택** / 가입 직후 프라이밍(**게이트 아님**) / 탭하면 **앱만 열기**.
  - **서버가 지표를 준다** — `ChallengeResponse.currentStreak`/`noSpendDays` 신설. 배지 지급과 **같은 계산기**([ChallengeStatsCalculator](../tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeStatsCalculator.java))를 쓰게 뽑아냈다. 백엔드 테스트 **226개**(신규 19) 통과.
  - ⚠️ **백엔드 재배포 필요** — 스키마 변경은 없고 이미지만. #7 미배포 건과 **같이 나가면 왕복이 준다** (§0).
  - ⚠️ **iOS 미검증** — 로컬 알림이라 무료 계정으로 동작하지만 빌드가 맥에서만 되므로 확인 못 했다.
- ~~#18 결과 카드 디자인 수정~~ → ✅ 완료 (2026-08-01). **요구사항 한 문장이 기준을 바꿨다** — "제일 큰 건 안 예쁘다는 거야, 결과 카드가 예뻐야 자랑하고 싶을텐데". 그래서 정보 위계·중복 제거는 수단이 되고 **미감이 목표**가 됐다(보통 화면과 반대. 공유 카드는 공유되지 않으면 존재 이유가 없다).
  - **총 7라운드가 걸렸고 마지막 3라운드는 실패 카드 하나 때문이었다.** ①다크+링 → ②화이트+카테고리 → ③2블록+그리드+풀블리드 → ④민트 채움 → ⑤사용자 가이드 6항목 → ⑥실패 카드 색 3안 → **⑦확정**. 되돌린 것들이 이 회의의 핵심 교훈이다:
    - **다크 폐기 → 옅은 틴트도 폐기 → 브랜드 민트 꽉 채움** — 다크는 앱과 너무 따로 놀았고, 옅은 민트 틴트(명도 94%)는 **썸네일·피드에서 그냥 흰 카드**로 읽혔다. 외부 레퍼런스(Spotify Wrapped·Strava)의 공통 항목이 **배경색을 완전히 커밋하는 것**이었다.
    - **링 폐기** — *"최대값이 몇이고 얼마 쓴 건지 링으로 전혀 안 나타난다"*. **도넛은 비율만 인코딩하고 척도를 못 나른다.**
    - **카테고리 폐기** — 링 자리를 카테고리로 채운 게 실수였다. **카테고리 분포는 자랑거리가 아니라 정산서**고 카드의 40%를 먹었다. 필요한 건 "유의미한 데이터"가 아니라 **자랑할 만한 그림**이었다.
    - ⭐ **히어로가 내내 틀려 있었다** — 절약액(부산물)을 주인공에 두고 있었는데, 성취는 **기간 안에서 목표를 지킨 것**이다. 사용자가 4라운드 만에 직접 짚어줬고 **절약액 계산 자체를 코드에서 제거**했다.
  - **최종 구조**: 상단 **컬러 블록**(성공 민트 `#1FBE9C` / 실패 **앱 `danger` `#FF6B6B`**) — 헤더 + **히어로 문장**(`N일 동안 / 목표액 / 챌린지 성공`) + 예산 바. 하단 **화이트** — **배지 3칸 → 일자 그리드** → 워터마크. 화면은 **풀블리드**(AppBar 제거, 우상단 X, 상태바 뒤를 블록색으로).
  - **실패 카드는 색면 + 데이터 양쪽에 빨강을 쓴다** — 게이지는 목표까지 흐린 흰색·**넘긴 만큼만 불투명 흰색**(빨강 위 딥레드는 *"빈 색으로 보인다"* 고 반려됨 → **어두운 색은 배경으로 읽힌다**), 목표 지점에 흰 눈금, 초과액은 흰 칩. 그리드의 **지출한 날도 빨강**(무지출은 늘 민트). ⚠️ **막대 아래 라벨 줄을 두지 말 것** — 그만큼 빨강 면이 내려와 성공 카드와 블록 높이가 어긋난다.
  - **축하는 두 겹** — 카드 안 **정적 컨페티**(캡처에 포함 → 저장 PNG·영상 클립에 남음) + **진입 연출**(오버레이, 캡처 제외). 진입 연출은 **확정 직후에만**.
  - **곁가지**: `AppColors.reward*` 재정합(`rewardFailTop` = `danger`, `rewardSpendMark`·`rewardSlotBorder` 신설) + **`rewardTint`/`rewardTintInk` 분리**(상세의 결과 카드 **입구**는 표면색과 용도가 달라 — 안 나눴으면 상세 화면이 조용히 깨졌다).
  - **프로세스**: 5라운드부터 **HTML 시안 → Artifact 게시 → 확정 후 위젯 1회 반영**으로 바꿨다(사용자 요청). 카드 4~5장을 나란히 두고 비교할 수 있어 판단이 빨라졌다 — **디자인이 흔들리는 동안은 이 방식이 기본값.**
  - `flutter analyze` clean + **에뮬 전 분기 재검증 완료**(성공/실패 × 8일·30일, 배지 0~3칸, 긴 이름 2줄) + **갤러리 저장 PNG 확인**. ⚠️ 최악 케이스(**이름 2줄 + 30일 + 배지**)에서 **7.2px 오버플로우**가 나 하단 간격을 다시 맞췄다 — 간격을 늘릴 땐 30일 카드로 재확인할 것. ✅ **영상 마지막 3초 클립도 검증 완료 (2026-08-02)** — 유일하게 남아 있던 미검증 경로(시드에 영상 파일이 없어 ffmpeg 합성을 못 돌렸던 것)를 실제 합성으로 확인. `pixelRatio: 1.0` 캡처 경로라 레이아웃은 화면과 동일하고 `VideoComposer` 는 무변경이었음이 실물로 확인됐다. **이로써 #18 은 미검증 항목 없이 종결.** **앱 전용이라 백엔드 재배포와 무관.** 회의록 [decisions.md](decisions.md) "결과 카드 디자인", 규칙은 [../CLAUDE.md](../CLAUDE.md) "결과 카드".
- ~~#9 DB 컬럼 enum 전환 검토~~ → ✅ 완료 (2026-07-30). 목록화를 해보니 **두 개의 다른 축**이 각각 어긋나 있었고 백로그 문구는 하나만 가리키고 있었다 — ⓐ **DB 자료형**: `user.provider`·`challenge.result`·`badge.type` 만 네이티브 `ENUM`, 나머지 5개는 `VARCHAR`(설계가 아니라 시간순 흔적) ⓑ **Java 매핑**: 8개 중 7개가 이미 `@Enumerated(STRING)`, `amount.category` 만 raw String. **둘 다 실행했다.**
  - ⓐ **네이티브 `ENUM` 3개 → `VARCHAR`** (Java 코드 변경 0). 상수 목록이 코드와 DB 두 곳에 생겨 어긋나고(`AuthProvider.TEST` 가 그 상태였다) 값 변경마다 `ALTER` 가 붙는다 — `Gender.OTHER` 제거가 `UPDATE` 한 줄로 끝난 게 바로 전날 사례.
  - ⓑ **`amount.category` → `SpendCategory` + `@Enumerated(STRING)`**, 컬럼도 `VARCHAR(255)→(20)`. "읽기는 관대" 의 근거(검증 이전 자유 텍스트)가 유효기간이 지났다. **변환은 `SpendCategory.from()` 한 곳, 호출은 엔티티 정적 팩토리 안에서만** — 서비스로 올리면 에러 코드가 뭉개지고(A0005 vs A0008) 무지출의 "카테고리 무시" 규칙이 깨진다. **DTO 는 `String` 유지라 wire format 무변경 → Flutter 변경 0.**
  - **룩업 테이블은 도입 안 함** — 기준("코드 말고 딸린 정보가 있나")에 맞는 건 `badge` 하나뿐이고 이미 그렇다.
  - 곁가지로 **네이티브 SQL 로 `'x'` 를 박던 테스트 헬퍼 2곳**을 찾아 고쳤다(엔티티 검증 우회 → 읽을 때 죽음). enum 전환이 실제로 잡아낸 문제.
  - 테스트 **200개** 전원 통과(신규 5 — `SpendCategoryTest` 4 + wire format 가드 1) + **에뮬 E2E 검증 완료**. 앱 코드 변경이 0이라 위험은 낮았지만, 단위 테스트가 못 덮는 구간(Jackson 직렬화 → Flutter 파싱 → 카테고리 아이콘·라벨 매핑)이 실제로 이어지는지가 이 작업의 유일한 실질 리스크였다. 회의록은 [decisions.md](decisions.md) "DB 코드성 컬럼 정리", 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — 백엔드". ✅ **prod 배포 완료 (2026-07-30)**.
- ~~#10 email NULL 원인 분석~~ → ✅ 완료 (2026-07-26). 원인 = 카카오 '카카오계정(이메일)' 동의항목이 **개인 개발자 일반 앱에선 '권한 없음'**(콘솔 확인). 코드 버그 아님. **수집을 접기로 결정** — 컬럼까지 삭제. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증".
- ~~#11 닉네임 변경 안내 날짜 텍스트 삭제~~ → ✅ 완료 (2026-07-26). 제한 규칙까지 실제 24시간으로 통일. 상세는 [handoff-archive.md](handoff-archive.md), 문구 근거는 [decisions.md](decisions.md) "닉네임 쿨다운 안내 문구".
- ~~#12 메뉴 진입 시 매번 로딩 대기 UX 개선~~ → ✅ **완결 (2026-07-26 본체 + 2026-07-28 잔여 갈래 종결)**. 본체: 메뉴를 **낙관적 렌더**로 전환(`/me` 안 기다림, 실패해도 내비게이션 안 막음). 잔여 갈래 2건은 회의로 닫음 ([decisions.md](decisions.md) "메뉴 앱 버전 행") — ① **'앱 버전' 행의 로딩 제거**: 원인이 네트워크가 아니라 *부팅 때 이미 한 판정을 버리고 다시 묻던 것* 이라, `AppApi` 가 성공한 판정만 캐시하고 타일이 동기로 읽게 바꿔 **정상 경로 네트워크 0회**. 최신 상태도 탭되게(SnackBar) + 확인 실패 시 탭=재확인. ② **'내 정보' 스피너는 정상으로 결론** — 닉네임·성별이 콘텐츠 자체이고 캐시를 끼우면 재로그인 시 이전 계정 값이 비쳐서 **드롭**. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "메뉴 화면" / "앱 버전".
- ~~#13 생년월일 입력 자동 포커스 이동~~ → ✅ 완료 (2026-07-26). age gate 3칸 자동 이동 + 빈 칸 백스페이스 복귀 + 년 칸 autofocus. **범위를 폼 전체로 넓혀** 기록/수정(내용→금액)·챌린지 생성(이름→목표금액)의 키보드 '다음' 이동까지 통일하고 규칙을 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — Flutter" 에 박음 ([[feedback-consistency-over-pinpoint]]). 중립성 3원칙은 그대로. `flutter analyze` clean + **에뮬 E2E 검증 완료** (년 autofocus→월→일 자동 이동, 빈 칸 백스페이스 복귀, 마지막 칸 액션 키가 '다음'→'완료'로 전환, 이름→목표금액이 기간 탭 필드를 건너뜀, 내용→금액).

- ~~#14 탈퇴 사유 피드백 수집~~ → ✅ 완료 (2026-07-28). 탈퇴를 **화면**([WithdrawScreen](../tenk_app/lib/presentation/profile/withdraw_screen.dart))으로 옮기고 사유 1문항을 **선택**으로 수집. 저장은 **익명 테이블 `withdrawal_feedback`**(user_id 없음 → 개인정보 아님 → privacy 수집표 무변경 + 계정 파기 후에도 잔존). '기타' 선택 시에만 자유 서술(200자, 개인정보 미기재 안내). 곁가지로 **잘못된 요청 body 가 500 으로 나가던 전역 갭**을 400 으로 수정. 테스트 **183개** 통과 + analyze clean + **에뮬 E2E 검증 완료**. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증 — 탈퇴 사유". ✅ **prod 배포 완료 (2026-07-30)**.
  - **잔여 갈래 2건은 삭제 (2026-07-28)** — "잃는 것을 숫자로"·"탈퇴 전 영상 내보내기". 사유 화면 문구 규칙과 충돌하고 결국 탈퇴를 어렵게 만드는 방향이라 백로그에서 뺐다 ([decisions.md](decisions.md) "메뉴 앱 버전 행" 곁가지).
- ~~#15 Flutter 상태 관리 재검토 (Scope 7개)~~ → ✅ 완료 (2026-07-29). **현행 유지 — 임계를 5→10 으로 올리고 진짜 트리거를 따로 명문화. 코드 변경은 주석 2곳뿐.** 진단이 결론을 갈랐다: Scope 에 든 건 전부 **값이 안 바뀌는 stateless API 객체**라 `updateShouldNotify` 가 사실상 영원히 false — **지금 있는 건 상태 관리가 아니라 DI** 이고, Riverpod 은 둘을 한 몸으로 파는 물건이라 상태 관리 수요가 0 인 지금 도입하면 전 화면 이관 비용만 치른다. 5 라는 숫자엔 근거가 없었고(감으로 잡은 값), **숫자만 올리면 8개째에서 같은 고민이 반복되므로** "개수는 보조 지표, 착수 트리거는 **화면 간 공유 상태가 생길 때**"를 규칙에 같이 박았다 — 구체적 예는 배지 알림의 global `BadgeNotifier` 승격. 중첩 평탄화도 지금은 보류(임계 10 도달 시 1순위 후보). 회의록은 [decisions.md](decisions.md) "Flutter 상태 관리 재검토", 규칙은 [../CLAUDE.md](../CLAUDE.md) "레이어 규칙".
- ~~#16 성별 회의~~ → ✅ 완료 (2026-07-29). **현행 유지 — 코드·스키마·문서(privacy.html) 변경 0.** 우려는 *수정할 수 있게 두면 무의미한 데이터가 쌓인다* 였으나, **노이즈는 편집이 아니라 최초 입력에서 들어오고** 편집을 막으면 오탭이 영구 고착돼 오히려 나빠진다(우리가 여는 건 '성별 변경'이 아니라 **'입력값 정정'**). 법상 정정·삭제·철회권 + privacy.html 의 공개 약속 때문에 막을 수도 없다. 곁가지로 **변경 이력 저장 금지**를 규칙으로 신설(아웃팅 위험). 진짜 위험은 편집이 아니라 **자기선택 편향**인데 그건 항목 존폐로만 답할 문제라 함께 다뤘고, **수집 항목도 현행 유지**(제거 트리거 없음)로 결론. 회의록은 [decisions.md](decisions.md) "성별 수집·변경", 규칙은 [../CLAUDE.md](../CLAUDE.md) "성별 (선택 수집)".
#### 1-B. 실기기 검증에서 나온 결함 (2026-08-03 등록) — ✅ 전건 종결 (2026-08-04)

> 완료분(#19 하단 액션 잘림 · #24 휠 picker 찌그러짐 · 세로 고정 · #20 결과 카드 컨페티)의 상세는 [handoff-archive.md](handoff-archive.md) 2026-08-03·08-04 항목으로 이관. 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — Flutter" · "결과 카드".
>
> **교훈**: 세 건 중 두 건이 **백로그가 적어둔 원인 추정과 실제 원인이 달랐다**(#19 는 SafeArea 2곳이 아니라 키보드가 별개 원인, #20 은 좌표계가 아니라 애니메이션 잔존). 등록 시점의 추정은 증상 기록으로만 읽고 **착수할 때 다시 진단할 것.**

- ~~#19 하단 액션 버튼이 제스처 바에 잘림~~ → ✅ 완료 (2026-08-03). 백로그가 짚은 2곳 외에 **바텀시트 1곳**과 **키보드가 입력칸을 자르는 별개 원인**이 더 나와 총 6건을 고쳤다. 공용 위젯 [BottomActionScrollView](../tenk_app/lib/presentation/common/bottom_action_scroll_view.dart) 로 게이트·온보딩 4화면 통일 + 회귀 가드 11건.
- ~~#24 휠 시각 picker — 직접 입력 키보드가 뜨면 찌그러진다~~ → ✅ 완료 (2026-08-04). **접지 않고**, 공간이 되면 키보드 위로 올라가고 모자랄 때만 안 줄이고 덮게 했다. 가드 5건.
- ~~세로 고정 없음~~ → ✅ 완료 (2026-08-04). 가로에선 앱 영역이 387dp 로 줄어 키보드 없이도 눌렸다 — [main.dart](../tenk_app/lib/main.dart) 에서 잠갔다.

- ~~#20 결과 카드 — 진입 컨페티가 카드 콘텐츠를 가린다~~ → ✅ 완료 (2026-08-04). 원인은 좌표계가 아니라 **연출이 끝난 뒤 조각 15개가 얼어붙는 것**이었다(`delay + fallSpan > 1` → 낙하 미완 + 마지막 프레임 영구 유지). `fallSpan` 클램프 + 완료 시 트리 제거 2겹, 가드 3건, 에뮬에서 **연출 전후 프레임 MD5 동일**로 잔존 0 확인.
  - ⚠️ **실기기 재확인은 다음 릴리스 때** — 결함이 실기기에서 발견된 건이라 설치본에서 한 번 더 볼 것(확정 → 배지 모달 → 결과 카드 진입 시 컨페티가 다 사라지는지).

#### 1-C. 문구 정리 · 알림 온보딩 · 문의 창구 (2026-08-03 등록 · #21·#26·#22 완료, #23 미착수)

- ~~#21 '설정' 화면에서 군더더기 문구 삭제~~ → ✅ 완료 (2026-08-04). 백로그가 짚은 3건 + 전수 나열에서 나온 2건, 총 **5건 삭제**. 푸터 **뒤 문장까지 삭제**한 건 백로그 경고와 반대되는 **사용자 결정**이다(설정 화면을 설명서로 만들지 않는 쪽). 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "설정 (효과음·진동)".
  - ⏭️ **곁가지로 앱 전체 문구 조사를 돌렸고 후속 후보가 나왔다 → 아래 #26.**
- ~~#26 앱 전체 부가 설명 정리~~ → ✅ 완료 (2026-08-04). #21 의 곁가지로 `presentation/` 전 화면을 훑어 **9건을 한 건씩 판정**했고 실제 편집은 **4건**(삭제 2 · 말투 정정 2)이다. 판단이 갈리는 건은 **에뮬로 A/B 를 찍어 비교**했고 그 과정에서 결론이 두 번 뒤집혔다. 경위·함정·**"현행 유지" 5건 목록**은 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "코딩 컨벤션 — Flutter"(해요체 통일 + 설명을 늘리지 않는 기준)에 박아뒀다.
- ~~#22 [회의] 첫 가입 때 알림 권유 화면~~ → ✅ 완료 (2026-08-05). **온보딩 끝에서 빼고 첫 챌린지 생성 직후 바텀시트로.** 안건은 "화면을 하나 더 세우는 게 맞나" 였는데, **가입 직후엔 챌린지가 0개라 승인해도 예약이 0건**이라는 게 드러나 자리 자체를 옮겼다. 온보딩은 연령→동의→닉네임 **3화면**으로 끝난다. 형태는 **실제 치수 시안 3종**을 그려 정했고(실기 시트 높이 약 63%), 회귀 가드가 **엉뚱한 요소를 재고 있던 것**도 같이 잡았다. 테스트 21건 + **에뮬 E2E 8항목 전건 통과**. 상세·함정(스텁 서버 · `SharedPreferences` 잔존)은 [handoff-archive.md](handoff-archive.md), 회의록 [decisions.md](decisions.md) "알림 권유 화면", 규칙은 [../CLAUDE.md](../CLAUDE.md) "알림" · "모달 사용 기준".
- ~~#23 [회의] '법적 고지'의 '문의' 행을 없애고 '의견 보내기'로 합칠 수 있나~~ → ✅ 완료 (2026-08-05). **합치지 않는다** — privacy.html 이 의견의 익명성을 공개 약속해 놔서 한 화면에서 어떤 유형만 계정과 연결되면 그 약속이 흐려진다. 발단이던 "헷갈린다"는 **역할별로 자리를 갈라** 풀었다 — **'의견 보내기'는 메뉴 최상위**(설정 위), **'문의하기'는 메뉴 → '고객센터' 안**. 한 번 둘을 고객센터에 나란히 모아봤다가 되돌렸다(익명으로 가볍게 남기는 창구가 고객센터 안에 있으면 문턱이 올라간다). 곁가지로 **mailto 를 인앱 폼으로 교체**(신규 `inquiry` 도메인, 계정 연결·회신 이메일 필수·유형 4종·탈퇴 시까지 보관)하고 **관리자 알림 2겹(메일+텔레그램) + 미처리 리마인드**를 신설했다 — "받아놓고 모르면 창구가 없는 것과 같다"가 근거. 테스트 **239개**(+13) + 앱 **22개**(+1) + analyze clean + 에뮬 E2E 전항목 통과. 회의록 [decisions.md](decisions.md) "문의 창구 정리", 규칙은 [../CLAUDE.md](../CLAUDE.md) "문의하기" · "관리자 알림".
  - ⚠️ **백엔드 재배포 + 라이브 DB `CREATE TABLE inquiry` 가 따라온다** (`ddl-auto=validate` 라 테이블이 먼저 있어야 부팅된다). §0 참고.
  - ✅ **에뮬 E2E 전항목 통과 (2026-08-06)** — 메뉴 순서(의견 보내기가 설정 위) / 고객센터 → 문의하기(유형 4종·이메일 필수·전송·`inquiry` 행 `user_id`+`PENDING`) / 의견 보내기(이메일 선택·익명 저장·진단정보) / 법적 고지 3항목. **알림 2겹 실발송까지 확인.** ⭐ 그 과정에서 **메일이 조용히 실패하던 버그**를 잡았다(From 미설정 → `can't determine local email address`). 텔레그램 자격증명도 채움.
  - ⚠️ **알림 메일이 Gmail 스팸함으로 간다** — SMTP·배달은 정상이고 수신측 필터 문제다. `support.tenk@` 에 `from:system.tenk@gmail.com` → '스팸으로 보내지 않기' 필터를 걸고 기존 메일을 '스팸이 아님' 으로 학습시킬 것(사용자 실행 항목). 코드로는 못 고친다.

#### 1-D. 앱 아이콘 (2026-08-04 등록) — ✅ 종결 (2026-08-05)

- ~~#25 런처 아이콘의 마크를 키우기~~ → ✅ 완료 (2026-08-05). `MARK_EXTENT` **0.56 → 0.70**(안전원 채움 62%→78%), 형상·잉크 bbox 는 불변. **Dart 는 안 건드렸다** — 백로그의 "두 파일" 경고는 형상 비율 상수 얘기였고 `MARK_EXTENT` 는 아이콘 캔버스 전용이다. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "로고 / 앱 아이콘".
  - ⚠️ **남은 것 2개** — ① 실기기에서 **원형/스퀘어클/테마 아이콘 3종** 재확인(§0 ①) ② Play Console 아이콘 **재업로드**(`tenk_app/assets_src/icon/play_store_512.png`).

#### 1-E. 문의·의견 운영 도구 (2026-08-06 등록) — ✅ 종결 (2026-08-06)

- ~~#27 문의·의견을 실제로 '운영'할 수 있게~~ → ✅ **관리자 패널로 해결** (2026-08-06). 규칙은 [../CLAUDE.md](../CLAUDE.md) "관리자 패널", 회의록 [decisions.md](decisions.md) "관리자 패널".
  - **갈림길은 "짓는다"로 결론** (사용자 판단) — ⑥ 이 정한 트리거(UGC 모더레이션)보다 앞당겼다. 흡수 대상이 문의 하나가 아니라 **4가지 SQL 의례**(문의 처리·의견 열람·TESTER 승격·앱 버전 정책)였고, ⑥ 자신이 *"그때 이 값들이 전부 DB 행 편집이라 패널에 자연히 흡수"* 라고 예고한 자리였다.
  - ⭐ **백로그 4건 중 2건이 착수와 함께 소멸했다** — ①(접수번호)은 화면에서 클릭하니 사람이 id 를 옮겨적을 일이 없어져 **컬럼도 생성 규칙도 불필요**해졌고, ③(미처리 조회)은 목록 화면이 곧 답이다. **①의 문제의식은 방향이 반대였다**: 걱정한 PK 노출이 아니라 **알림에 `inquiry_id` 가 아예 없던 것**(리마인드 SQL 도 `WHERE inquiry_id=?` 물음표)이 실제 병목이었다.
  - **②는 `handler_note` 한 컬럼**(문의·의견 양쪽)으로. ⚠️ **답변 전문은 저장하지 않는다** — 메일 스레드가 아카이브고, 옮겨 담으면 privacy §1·§3 + Play §6-2 가 따라온다. **④는 알림 본문 끝의 패널 링크**로 끝났다.
  - 몸통은 화면이 아니라 **인증**이었다(앱 로그인이 카카오 SDK 전용이라 브라우저 진입로가 없었다). **보안 체인 2개로 분리**해 앱 인증 무변경, 관리자 계정은 **`admin_user` 별도 테이블**.
  - 테스트 **250개**(+11) + 로컬 구동 검증 전항목 통과. ⚠️ **백엔드 재배포 + 스키마 3건**(§0).
  - ✅ **후속(같은 날) — 안전성 확보조치를 문서·코드 양쪽에서 메움.** 진단해보니 **조치는 대부분 이미 하고 있었고 빠진 건 문서화**였다(HTTPS·BCrypt·RT 해시·세션 만료·DB 포트 미공개·파기 배치). **조치 자체가 미흡한 건 접속기록 하나** — IP 가 없고 앱 로그로만 나가 재배포에 사라져 "1년 보관"이 성립하지 않았다. privacy.html **§8 신설**(적은 5가지는 전부 실제 조치, 대응 코드를 HTML 주석으로 병기) + **접속기록 완성**(IP · 로그인 성공/실패 · **열람 기록** · 전용 파일 13개월 롤링 + `admin-audit` 볼륨). ⚠️ **로그에 본문·비밀번호·검색어를 담지 않는다**(가드 5건). 테스트 **254개**.
  - ✅ **변호사 검수는 백로그에서 드롭** (사용자 결정) — 대신 **"문서 = 실제 동작"** 을 유지 기준으로 못박았다([../CLAUDE.md](../CLAUDE.md) "회원 탈퇴" 항목 하위). 트리거는 결제·광고 SDK·제3자 제공·해외 이전.

#### 1-F. 접속기록 IP + 사용자 액세스 로그 — 🟠 **ⓐⓑⓒⓕ 완료 (2026-08-17, ⚠️ 배포 대기) · ⓓⓔ 잔여**

> ⓐ(D2) → ⓑ(접속기록 신설) → ⓒ(문서) → ⓕ(죽은 코드)까지 같은 날 이어서 닫았다. 근거는 [decisions.md](decisions.md) ㉔ 결정 5·6, 실행 기록은 [handoff-archive.md](handoff-archive.md).
> ⚠️ **ⓑⓒⓕ 는 백엔드 재배포 + compose 전송이 남았다** (§0). **새 볼륨 `app-logs` 가 생겨서 이미지 교체만으론 안 붙는다** — 08-08 `admin-audit` 사고와 같은 모양이라 **§5.1 ⓪ md5 대조 필수.**

- [x] ✅ **ⓐ #28 관리자 접속기록 IP — D2 로 해결 완료 (2026-08-17).** 상수 `172.19.0.1` → **실제 공인 IP**(`223.38.225.21` 실측). privacy.html §8 은 **문구 수정 불필요**(이제 고지대로 동작한다). 실행 상세는 [handoff-archive.md](handoff-archive.md), 근거는 [decisions.md](decisions.md) ㉔, 엣지 설정의 진실의 원천은 **`reverse-proxy` 리포 README §8**.
  - ⚠️ **딸려 나온 영구 함정 2개는 [docker-deployment.md](docker-deployment.md) 에 박았다** — **§8.4 macOS 방화벽(ALF)이 도커 밖 서비스를 차단**(외부 2시간 장애의 원인, 새 맥이면 반드시 재발) · **§8.5 검증 3지점**(loopback 만 보면 §8.4 를 구조적으로 발견 못 한다).
  - **남은 후속 2건**은 아래 ⓓ·ⓔ.
  - **원복**(필요해지면): `bash ~/backup/d2-20260817/scripts/d2-rollback.sh` — 볼륨·DB·VM 무관이라 데이터 손실 위험 없음. 원복하면 IP 는 다시 `172.19.0.1` 이 된다.


- [x] ✅ **ⓑ 이용자 접속기록 신설 (2026-08-17)** — **백엔드 logback, 3개월.** [AccessLogFilter](../tenk-backend/src/main/java/com/hjson/tenk/common/logging/AccessLogFilter.java) 가 **시각·IP·메서드·경로·상태·소요시간**만 남긴다. Traefik 안은 **용량 기준 순환이라 고지보다 오래 보관**하게 돼 기각. 근거는 [decisions.md](decisions.md) ㉔ 결정 6.
  - ⭐ **'오류 기록'도 같이 옮겼다** — 안 했으면 ⓒ 를 절반만 닫을 뻔했다(§1 의 자동생성정보는 "접속 로그 **및 오류 기록**"인데 후자는 여전히 기간이 없었다). 같은 `app-logs` 볼륨·같은 3개월.
  - ⚠️ **`CONSOLE` 은 유지** — 빼면 `docker compose logs -f backend` 가 안 보인다. 파일은 보관용 사본이다.

- [x] ✅ **ⓒ privacy.html §3 보관 기간 신설 (2026-08-17)** — "접속 로그 및 오류 기록 → **수집일로부터 3개월**". §1 의 '접속 로그' 는 **이제 참이라 그대로 유지**. 문서 옆에 대응 코드를 HTML 주석으로 병기했다.

- [x] ✅ **ⓕ [AdminAudit](../tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAudit.java) 죽은 코드 정리 (2026-08-17)** — XFF 분기 제거 + 주석 정정. 지우고 테스트에 `server.forward-headers-strategy=framework` 를 넣었더니 **같은 단언이 그대로 통과** — 죽은 코드였음이 실증됐고 그 테스트는 이제 **prod 와 같은 경로**를 검증한다.

- [ ] **ⓓ 2026-08-30 전후 ACME 실제 갱신 확인 — ⚠️ 필수, 날짜가 정해져 있다** (D2 후속). 인증서 만료가 **tenk 9/29 · english 9/30** 이고 Let's Encrypt 는 30일 전부터 갱신하므로 **8/30~8/31 에 첫 실제 갱신**이 일어난다. **D2 에서 가장 늦게 드러나는 실패 지점**이다(ACME 는 httpChallenge / entryPoint `web`(:80) 을 쓴다).
  ```bash
  docker compose -f ~/Documents/projects/claude/reverse-proxy/docker-compose.yml logs traefik | grep -i acme
  echo | openssl s_client -connect 127.0.0.1:443 -servername tenk.hjson248.com 2>/dev/null | openssl x509 -noout -enddate
  ```
  실패하면 **`web` 진입점의 `trustedIPs`** 와 **HAProxy 의 80 경로**부터 볼 것.

- [ ] **ⓔ 공유기 DHCP 예약 (사용자 작업)** — 맥 `en0` 이 DHCP 이고 **리스가 2시간**이다. 지금은 `192.168.0.8` 이라 포트포워딩과 맞지만, **리스 갱신·재부팅으로 IP 가 바뀌면 D2 와 무관하게 외부 접속이 죽는다.** 공유기(`192.168.0.1`)에서 MAC `00:8a:76:e5:f8:2d` → `192.168.0.8` 고정 할당.


#### 1-G. 결과 카드 화면 비율 (2026-08-08 등록) — ✅ 완료 (2026-08-17)

- ~~#29 결과 카드 화면에 양옆 여백이 생긴다~~ → ✅ **A+B 결합으로 종결.** 상세·진단 경로는 [handoff-archive.md](handoff-archive.md) 2026-08-17 항목, 규칙은 [../CLAUDE.md](../CLAUDE.md) "결과 카드" 의 풀블리드 항목.
  - ⚠️ **실기기 확인은 다음 릴리스 때** — 에뮬·기기 없이 위젯 테스트 기하로만 검증했다(가드 [test/result_card_layout_test.dart](../tenk_app/test/result_card_layout_test.dart) 9건). 확정 → 결과 카드 진입 시 **상단 블록이 화면 좌우 끝까지 닿는지**, 그리고 **하단 워터마크가 액션 버튼에 안 가리는지** 볼 것.

#### 1-H. prod 로그 위생 (2026-08-08 등록) — ✅ **종결 (2026-08-17 코드 + 같은 날 prod 배포·검증 완료)**

- ~~#30 prod 가 모든 JPA 바인딩 파라미터를 애플리케이션 로그에 찍는다~~ → ✅ **수정 완료 (2026-08-17).** 상세는 [handoff-archive.md](handoff-archive.md) 2026-08-17 항목, 규칙은 [../CLAUDE.md](../CLAUDE.md) "로그 위생".
  - **0단계(재배포 없는 env 중간 조치)는 건너뛰었다 (사용자 결정)** — 이용자가 아직 없어 무인 상태에서 새는 건 **관리자 BCrypt 해시·로그인 ID** 뿐이고, 그 로그는 맥 로컬 docker json-file 에만 있어 외부 노출이 없다. 미배포 백엔드가 0건이라 **다음 배포 = 이 수정의 배포**여서 막을 공백 자체가 없었고, env 를 넣었다 빼는 드리프트만 남았을 것이다.
  - ⚠️ **이미 찍힌 로그는 배포가 알아서 폐기한다** — 새 이미지로 `up -d` 하면 컨테이너가 재생성되고 json-file 로그는 컨테이너에 딸린 파일이라 같이 사라진다. 별도 정리 작업 불필요.
  - ⚠️ **배포 전에 카카오 재로그인(TESTER 재승격, §0 ②)을 하지 말 것** — 그 순간 본인 프로필이 구버전 로그에 찍힌다. **수정 배포 → 재로그인** 순서.
  - ⏭️ **에러 알림(ERROR → AdminNotifier)은 백로그로 등록하지 않기로 했다 (사용자 결정).** 필요해지면 [../CLAUDE.md](../CLAUDE.md) "로그 위생" 마지막 항목에 방향만 적혀 있다 — **에러를 DB 테이블에 쌓는 안은 기각**(DB 장애 때 정작 못 남고, 롤백에 같이 말려들고, 스택트레이스가 다시 개인정보 보관소가 된다).
  - ⏭️ **곁가지 2건은 #28 로 묶었다** (§1-F ⓑ·ⓒ) — 사용자 HTTP 액세스 로그가 0줄인 것 / privacy.html §1 이 실제보다 넓게 적혀 있는 것. **셋 다 "IP 를 제대로 못 남긴다"는 같은 뿌리**라 따로 착수하면 두 번 판단해야 한다.

- **실기기 점검** — ✅ 현재까지 대상 화면 전부 통과(기존 3블록 닉네임/결과카드/SafeArea 2026-06-16 전원 통과, [handoff-archive.md](handoff-archive.md)). 미착수 작업이 아니라 상시 체크 항목: **새 화면을 추가할 때만** 하단 가림 / 제스처·3버튼 내비 / 키보드 inset 을 실기기에서 재점검.

> **업적(achievement) 시스템**은 우선순위를 최후로 내렸다 → 맨 아래 §5.

### 2. 페이지네이션 / 정렬
- `/api/challenges`, `/api/challenges/{id}/amounts`가 전체 목록 반환 중. `Pageable` 도입 시점 결정 (지금은 사용자당 챌린지 수가 적어 무방).

### 3. Google / Naver 로그인 추가 (예정)
- 동일 패턴: `GoogleTokenVerifier` / `NaverTokenVerifier` + `AuthService`에 분기 + `POST /api/auth/google/login` / `/naver/login`. **브라우저 redirect 흐름은 사용하지 않음** (모바일 SDK 전제).

### 4. 운영 고려사항 (필요해지면)

- ⭐ **"실제 운영 시작" 은 별도 이벤트이고, 그 배포 시점은 사용자가 알려준다 (2026-08-17 확정).** 지금은 내부 테스트 단계라 **이용자가 0명**이고, 그래서 아래 성격의 항목은 **그 시점 전까지 느슨하게 가도 된다**:
  - **로그·기록의 보존** — 관리자 접속기록이 재배포로 날아가도 문제 삼지 않는다(실제로 08-08~08-17 에 소실됐고 **면제로 종결**, [handoff-archive.md](handoff-archive.md)). 열람 대상인 이용자 개인정보 자체가 없기 때문이다.
  - **DB 클린 재생성** — 계정·챌린지·영상이 다 날아가도 되는 이유가 같다(2026-07-30 · 08-08 두 번 했다).
  - **다운타임** — 인프라 작업(#28 D2 등)을 지금 하는 게 가장 싼 이유.
  - ⚠️ **반대로 그 시점부터는 위 셋이 전부 실제 비용이 된다.** 운영 시작 배포를 준비할 땐 **이 목록을 체크리스트로 다시 읽을 것** — 특히 ① **로그 볼륨 2개(`admin-audit` 13개월 · `app-logs` 3개월)가 실제로 붙어 있고 파일이 쌓이는지**([docker-deployment.md](docker-deployment.md) §9.3) ② 백업 절차가 있는지 ③ 파기 배치가 도는지.
    - ⚠️ **①은 "붙어 있나"뿐 아니라 "쌓이고 있나"까지 봐야 한다** — 볼륨이 없어도 로그는 **정상적으로 쓰이면서** 재배포에 사라지고 **에러가 하나도 안 난다.** 두 번 다 늦게 발견한 이유가 이것이다.

- **미배포 백엔드 변경 — ✅ 0건 (2026-08-17 기준).** 지켜야 할 것: `ios_store_url` 은 iOS 출시 전까지 NULL 유지. **앱 버전 값은 이제 [관리자 패널](https://tenk.hjson248.com/admin) → '앱 버전' 에서 바꾼다** — 아래 SQL 은 패널이 안 뜰 때의 폴백이다. **앱 버전을 올릴 땐 재배포 없이** `UPDATE app_config SET latest_version=..., min_supported_version=... WHERE app_config_id=1;` — 맥에서는 DB 포트 퍼블리시가 없어 `docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" tenk -e "..."` 로 친다(`set -a; . ./.env; set +a` 로 비번을 셸에 올린 뒤). **`min` 을 올릴 땐 Play 게시 반영을 먼저 확인할 것** — 스토어에 새 버전이 없는 상태에서 올리면 강제 업데이트 화면에서 나갈 길이 없다. 배포 절차는 [docker-deployment.md](docker-deployment.md) §5.1(코드만 변경) / §5.5(라이브 스키마 변경) / §5.7(DB 클린 재생성).
- **관리자 패널 — ✅ 구현됨 (2026-08-06, #27).** `https://tenk.hjson248.com/admin` (배포 후). 문의 처리 · 의견 열람 · TESTER 승격 · 앱 버전 정책 4가지를 흡수해 **SSH + `docker exec db mariadb` + SQL 의례가 사라졌다.** 규칙은 [../CLAUDE.md](../CLAUDE.md) "관리자 패널", 회의록 [decisions.md](decisions.md) "관리자 패널".
  - 예고했던 트리거(UGC 모더레이션)보다 **앞당겨 지었다** — 흡수 대상이 이미 4개였고 ⑥ 자신이 "패널에 자연히 흡수" 라고 예고한 값들이었다. **UGC 신고/모더레이션이 실제로 생기면 이 패널에 화면을 추가**하면 된다(그때 `UserRole.ADMIN` 이 이용자 측 게이트로 쓰인다).
  - ⚠️ **범위를 늘릴 땐 [../CLAUDE.md](../CLAUDE.md) 의 "안 만들 것" 목록을 먼저 볼 것** — 이용자 데이터 편집·삭제, 답변 발송, 비밀번호 변경은 **의도적으로 뺀 것**이지 미구현이 아니다.
- **서버 이전 (맥미니 → 리눅스) — 트리거가 오면 검토** (2026-08-17 등록). **지금 결정할 일이 아니다.** 근거·전제는 [decisions.md](decisions.md) ㉔ "서버 전제".
  - **왜 후보인가**: 우리 구성(맥 서버 × Docker × 공개 서비스)은 **3중 특수 케이스**라 인프라 함정을 직접 뚫어야 한다. 리눅스로 가면 **#28(클라이언트 IP 소실)·TCC bind mount·NAT 헤어핀·Colima 재부팅 복귀 검증이 전부 문제 자체로서 사라진다.** 통상적인 정답은 이쪽이다.
  - **⭐ 이전 비용은 낮다** — Docker 로 묶여 있어 `docker-compose.yml` + **named volume 4개**(`db-data`·`uploads`·`admin-audit`·`dbinit`) 복사 + DNS·방화벽이 사실상 전부. **그래서 #28 을 지금 환경에서 닫는 노력도 버려지지 않는다.**
  - **선택지**: ① 안 쓰는 PC·노트북 재활용(비용 0 — 단 데스크탑은 전력 50~100W 라 24시간이면 VPS 가 더 싸다) ② 미니PC(N100 급 15~25만원, 홈랩 사실상 표준) ③ VPS(**오라클 Always Free** 는 ARM 4코어/24GB 무료 + **춘천 리전**이라 지연도 좋다. 단 생성 재고·무료 정책 변동 리스크 / 유료는 국내 월 1~2만원, 해외는 월 6천원이나 **한국에서 150~250ms**) ④ ~~맥미니에 Asahi Linux~~ — 실서버로 쓸 만큼 성숙하지 않아 **권하지 않음**.
  - ⚠️ **착수 트리거 (이 중 하나라도 오면 재검토)**: 이용자가 붙어 **가용성(정전·인터넷 끊김)이 실제 손해**가 될 때 / 집 업로드 대역폭이 **영상 다운로드에 부족**해질 때 / **인프라 함정에 쓰는 시간이 월 비용보다 비싸다고 느껴질 때**.
  - ⚠️ **잃는 것도 적을 것**: 클라우드면 **월 비용** + **디스크가 비싸진다**(영상이 쌓이는 서비스라 이게 실제 변수 — 집 서버는 디스크가 싸다) + 물리적 통제권.
- **영상 저장소 S3/MinIO 이전** — `LocalFileStorage`를 인터페이스로 추출 후 구현체 분리.
- **AT 강제 무효화(블랙리스트)** — 필요 시 Redis. 현재는 AT 만료 시간(1시간)에 의존.
- **CI 도입** — 현재 통합 테스트가 로컬 `tenk` 스키마를 비우는 구조라 CI 에서 그대로 못 돈다. 도입 시 Testcontainers + 별도 `tenk_test` 스키마로 갈아탈 것.
- **개인정보처리방침 (2026-07-07 작성 + 배포 LIVE)** — [privacy.html](../tenk-backend/src/main/resources/static/privacy.html) 로 작성, Spring Boot static 서빙. ✅ **`https://tenk.hjson248.com/privacy.html` 배포 완료·브라우저 접속 확인** (SecurityConfig PERMIT_ALL 등록, 맥 이미지 재배포로 LIVE). 수집항목/이용목적/보관기간(탈퇴 후 1개월 — 2026-07-27 단축)/제3자(카카오)/파기/권한/문의처 포함. **Play Console 개인정보처리방침 URL 에 이 주소 입력.** 남은 것: ① ✅ **앱 내 링크 노출 + 필수 동의 플로우 완료 (2026-07-19)** — 아래 별도 항목 참고 ② ✅ **안전성 확보조치 항목 추가 (2026-08-06)** — 법 제30조 기재사항인데 통째로 빠져 있었다. **적힌 5가지는 전부 실제 조치**다(관리자 계정 분리·HTTPS·BCrypt/해시·접속기록 1년·파기 배치) ③ 문구는 실제 동작(음성 미수집, 자체 서버 저장, 1개월 보관 후 파기)과 일치시켜 작성했으니 정책 바꾸면 동시 갱신. **변호사 검수는 드롭됨**(§0 참고) — 대신 *문서 = 실제 동작* 을 유지 기준으로 삼는다.

- **필수 동의 플로우 (2026-07-19 구현 완료)** — "앱 내 링크 노출" 태스크를 출시 기준으로 확장. **이용약관([terms.html](../tenk-backend/src/main/resources/static/terms.html), 신규 작성) + 개인정보 수집·이용** 2개 필수 동의를 **동의 화면(ConsentGateScreen)** 에서 받고 `user.terms_agreed_dt`/`privacy_agreed_dt` 에 기록. **동의 화면과 닉네임 설정 화면은 분리** — 신규 가입은 동의(ConsentGateScreen) → 닉네임(NicknameSetupScreen) 2단계, 기존 미동의자는 동의 → 홈. 규칙·구조는 [../CLAUDE.md](../CLAUDE.md) "인증 — 필수 동의" 섹션이 진실의 원천. **⚠️ 라이브 DB 는 새 컬럼을 ALTER 로 추가해야 부팅됨**(ddl-auto=validate): `ALTER TABLE user ADD COLUMN terms_agreed_dt DATETIME NULL AFTER nickname_changed_dt, ADD COLUMN privacy_agreed_dt DATETIME NULL AFTER terms_agreed_dt;` (TEST enum 마이그레이션과 동일 패턴).
  - ✅ **prod 배포 + 에뮬 E2E 검증 완료 (2026-07-20)** — 이력·검증 상세는 [handoff-archive.md](handoff-archive.md) 참고.
  - ✅ **통합 테스트 작성 완료 (2026-07-20)** — [UserConsentIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserConsentIntegrationTest.java) 5건(MockMvc E2E): 신규 유저 `consentRequired=true` / 동의 POST 후 false + DB 스탬프 / 재호출 멱등(최초 시각 보존) / 미인증 401 / **TEST 계정 auto-consent 가드**. 스탬프 규칙 자체는 `UserServiceTest` 단위 5건이 담당.
  - **남은 것 없음** — terms.html 변호사 검수는 2026-08-06 사용자 결정으로 드롭됐다(§0 참고).
- **회원 탈퇴 hard delete (2026-07-07 구현 완료, 2026-07-27 유예 1개월로 단축)** — soft delete + 1개월 유예 후 물리 삭제. `User.withdraw()` 는 여전히 soft delete(`deleted_dt`) + RT 무효화, 새벽 1:30 배치 [UserRetentionScheduler](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java) → [WithdrawnUserPurgeService.purge](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 `deleted_dt` +1개월 지난 계정을 challenge/amount/media_file row + 디스크 `uploads/` 영상 + refresh_token 까지 FK 순서(디스크→media_file→challenge_badge→amount→challenge→refresh_token→user)로 삭제. 유저 1명 단위 트랜잭션, 파일은 best-effort(`deleteQuietly`). user 는 hard delete 라 provider/provider_user_id 재사용 가능. 보관기간 상수는 `WithdrawnUserPurgeService.RETENTION`. ✅ **통합 테스트 작성 완료 (2026-07-20)** — [WithdrawnUserPurgeIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeIntegrationTest.java) 5건: 탈퇴 직후·미탈퇴는 파기 대상 아님 / `deletedDt` reflection backdate 후 대상 포함 / purge 시 challenge·amount·media_file·challenge_badge·refresh_token row 전멸 + **디스크 mp4 실제 삭제**(`deleteQuietly` 가 조용히 실패해도 아무도 모르는 지점이라 이게 유일한 감시) / 타 계정 데이터 무손상. **해소됨(2026-07-27)**: 예전엔 "보관 기간 미도래 계정이 남아 있는데 UI 는 '영구히 삭제'라고 말하는" 불일치가 있었으나, 탈퇴 UX 재설계로 문구를 실제 동작에 맞추고 유예를 1개월로 줄이면서 정리됨.

### 5. 업적(achievement) 시스템 (우선순위 최후)
> 남은 일 중 **가장 후순위** — 핵심 흐름·배포·운영이 모두 정리된 뒤 착수 (2026-07-19 §1 에서 이관).

- 챌린지 경계를 가로지르는 누적 보상. 새 테이블(예: `user_achievement`) + 별도 컨트롤러/서비스 + 별도 Flutter 화면. 자산은 기존 `assets/badges/` 재활용 가능. 배지와 디자인 언어가 자연스럽게 이어지도록 설계.

---

## 알려진 주의사항 / 함정

### 백엔드
- **DDL과 엔티티가 어긋나면 부팅 실패** (`ddl-auto=validate`). 컬럼·인덱스 추가 시 `docs/schema.sql`도 같이 수정 후 DB에 적용.
- **`BadgeGrantService.consecutiveStreakEndingOn`은 "오늘 기록이 없으면 어제 기준"** 까지만 봐줌. 이틀 이상 비면 streak=0. 의도된 동작.
- **`@CurrentUserId`가 비인증 요청에서는 null**. `SecurityConfig.PERMIT_ALL`에 새 경로 추가하는데 그 경로에서 `@CurrentUserId`를 받으면 NPE. 인증 필요 경로면 PERMIT_ALL에 넣지 말 것.
- **`JwtAuthenticationFilter`에서 토큰 invalid/expired는 401을 직접 응답** (Bearer 헤더가 *있을 때만*). 헤더가 아예 없으면 그대로 통과 + `AuthenticationEntryPoint`가 401 처리.
- **AT는 stateless** — 로그아웃해도 AT 만료 시간까지 유효. 즉시 무효화 필요하면 RT만 revoke하면 다음 갱신 시 거부됨 (Swagger 시나리오 2로 확인됨).
- **JWT secret 노출 시 대응**: `openssl rand -base64 64`로 새 키 생성 → `application-prod.yaml`의 `tenk.auth.jwt.secret` 교체 → 재부팅. 서명 검증 실패로 기존 AT/RT 즉시 거부. 별도 블랙리스트/Redis 필요 없음.
- **`@TransactionalEventListener(AFTER_COMMIT)` 에서 DB 쓰기**: 리스너 메서드 자체에 **`@Transactional(propagation = REQUIRES_NEW)`** 필수. 안 박으면 `[Badge] granted` 로그는 찍히는데 INSERT 가 사라진다 (AFTER_COMMIT 콜백 시점에 원본 tx 동기화가 정리 중이라 단순 REQUIRED 가 새 tx 를 못 연다). [BadgeEventListener](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeEventListener.java) 참고.
- **"거부하면서 삭제"는 같은 트랜잭션에서 안 된다**: 연령 확인의 만 14세 미만 처리처럼 *데이터를 지우고 나서 예외를 던지는* 흐름은, 지우는 쪽이 같은 트랜잭션이면 그 예외의 롤백에 삭제까지 휩쓸려 계정이 되살아난다. [WithdrawnUserPurgeService.purgeImmediately](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 `@Transactional(REQUIRES_NEW)` 인 이유이고, 자기 호출(self-invocation)이면 프록시를 안 타 무력화되니 반드시 **다른 빈을 주입받아 호출**할 것. 회귀 가드는 [UserAgeVerificationIntegrationTest.underageIsRejectedAndPurged](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserAgeVerificationIntegrationTest.java).
- **테스트에서 amount 카테고리는 반드시 9종 코드(`"FOOD"` 등)로**: `Amount.spend`/`AmountCreateRequest` 가 `requireValidCode` 로 검증하므로 `"x"`·소문자 `"food"` 같은 더미 값을 쓰면 `AMOUNT_CATEGORY_INVALID` 로 깨진다 (2026-07-11 검증 도입 때 테스트 9건이 이 이유로 깨져 있었고 2026-07-20 수정됨). 단 [AmountTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/amount/AmountTest.java) 의 `"food"`/`"식비"` 는 **거부 검증용 의도된 값**이라 그대로 둘 것.
- **통합 테스트가 `tenk` 스키마 데이터를 비움**: [IntegrationTestBase](../tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) 의 `@BeforeEach` 가 user/challenge/amount/refresh_token 을 DELETE 한다 (badge·app_config 마스터는 유지). `./gradlew test` 후 Flutter 카카오 재로그인 필요. tenk_test 스키마 분리는 일부러 안 함 (다음 운영자가 원하면 그때).
- **관리자 계정은 "부팅한 마지막 컨텍스트" 가 이긴다 — 테스트 ID 를 실계정과 합치지 말 것** (2026-08-07 실측). [AdminAccountInitializer](../tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAccountInitializer.java) 는 부팅할 때마다 **설정된 이메일의 행을 찾아 비밀번호 해시를 yaml 값으로 맞춘다**. [AdminPanelIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/admin/AdminPanelIntegrationTest.java) 가 일부러 `admin@test` 라는 **전용 ID** 를 쓰는 이유가 이것 — 실계정 ID 로 "통일" 하면 `./gradlew test` 한 번에 **로컬 패널 비밀번호가 `test-admin-pw` 로 덮여** 백엔드를 재시작할 때까지 평소 비밀번호로 못 들어간다. 대가로 로컬 DB 에 안 쓰는 계정 행이 하나 남지만(이니셜라이저는 **이메일이 다른 행을 지우지 않는다**) 그쪽이 낫다는 판단. 같은 이유로 **운영 admin ID 를 교체할 땐 `DELETE FROM admin_user WHERE email='<옛 ID>';` 가 짝** — 안 지우면 옛 계정이 옛 비밀번호로 계속 유효하다.
- **`server.forward-headers-strategy=framework` 를 켜면 `X-Forwarded-For` 를 직접 읽을 수 없다** (2026-08-08 실측). Spring 의 `ForwardedHeaderFilter` 가 XFF 를 **적용한 뒤 헤더를 제거하고** 요청을 넘기므로 컨트롤러·컴포넌트에서 `request.getHeader("X-Forwarded-For")` 는 **항상 null** 이다. 대신 그 필터가 `getRemoteAddr()` 을 **XFF 첫 값으로 바꿔치기**해 주므로 **`getRemoteAddr()` 하나만 쓰는 게 정답**이다. XFF 를 먼저 읽고 폴백하는 코드를 새로 쓰지 말 것 — 앞 분기가 죽은 코드가 되어 *주석이 설명하는 동작과 실제가 어긋난다*([AdminAudit](../tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAudit.java) 가 실제로 그 상태였다, §1-F #28).
- **prod 에서는 클라이언트 IP 자체가 앱에 도달하지 못한다** (2026-08-08 확정). 맥+Colima 구조상 `맥 :443` → **Lima 유저스페이스 포트 포워더** → VM → docker-proxy 를 거치며 **VM 경계에서 원 source IP 가 소실**돼, Traefik 이 보는 클라이언트가 이미 `172.19.0.1`(도커 게이트웨이)이다. **Traefik 이전 단계라 앱·프록시 설정으로는 못 고친다.** IP 로 무언가를 판정하는 기능(대입 공격 탐지·지역 제한·rate limit)을 설계하기 전에 **§1-F #28 을 먼저 해결할 것** — 안 그러면 모든 요청이 같은 IP 로 보인다.
- **`app_config` 싱글턴 행을 건드리는 통합 테스트는 반드시 원복할 것**: [AppVersionIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/app/AppVersionIntegrationTest.java) 는 앱이 읽는 그 한 행(id=1)을 테스트용 더미(latest=1.2.0, `https://play/android`)로 덮어쓴다. `@AfterEach` 로 시드값(1.0.0/실 Play URL)으로 되돌리지 않으면, 테스트 실행 후 로컬 dev 앱이 가짜 "업데이트 있어요" 를 스토어 더미 주소로 띄운다 (2026-07-26 실제로 발생·수정). app_config 를 만지는 새 테스트도 같은 원복을 넣을 것.

### Flutter
- **✅ 해결됨 — 릴리스 APK 에서만 카카오 로그인 실패 = R8 이 카카오 Pigeon 클래스 제거 (2026-07-02, 삼성 실기기 확인)**. 증상: 릴리스 APK 에서 "카카오로 로그인" 탭 → `카카오 로그인 실패: Unable to establish connection on channel: "dev.flutter.pigeon.kakao_flutter_sdk_common.CommonHostApi.isKakaoTalkAvailable"`. 카카오 창이 아예 안 뜨고 즉시 실패. 진단: 최신 Flutter/AGP 가 `flutter build apk --release` 에서 **R8 축소를 기본 ON** 으로 도는데(gradle 에 `minifyEnabled` 명시 없어도 적용), `build/app/outputs/mapping/release/usage.txt` 에 `com.kakao.sdk.flutter.common.CommonHostApi.setUp(...)` 등 카카오 네이티브 58개 항목이 **제거됨**으로 찍혀 있었다 — 채널 핸들러를 등록하는 `setUp` 이 stripped 되어 채널이 안 열림. **키해시와 무관**(키해시 정상 등록돼도 이 에러). 해결: [build.gradle.kts](../tenk_app/android/app/build.gradle.kts) release 블록에 `isMinifyEnabled = false` + `isShrinkResources = false`. 이 앱은 kakao + ffmpeg_kit + camera fork 등 네이티브 플러그인이 무거워 keep 규칙 개별 관리보다 축소 OFF 가 안전(테스트 빌드 기준). **Play Store 정식 출시로 크기 최적화가 필요하면** R8 을 다시 켜고 `proguard-rules.pro` 에 플러그인별 keep 규칙(카카오/ffmpeg/camera) 추가할 것. 진단 명령: `grep -i kakao build/app/outputs/mapping/release/usage.txt`.
- **릴리스 APK 빌드 시 Kotlin 증분컴파일 스택트레이스는 무해**: `flutter build apk --release` 끝에 `Could not close incremental caches ... this and base files have different roots` 류의 긴 stacktrace 가 찍히는데, **pub 캐시가 `C:` 드라이브(`AppData\Local\Pub\Cache`)·프로젝트가 `D:` 드라이브라** Kotlin 이 상대경로 계산에 실패하는 것뿐이고 **빌드는 성공한다**. 판단 기준은 맨 끝의 `√ Built build\app\outputs\flutter-apk\app-release.apk` 줄. 없애려면 pub 캐시를 같은 드라이브로 옮기거나(`PUB_CACHE`) 무시. APK 산출물·서명엔 영향 없음.
- **목록/상세 화면의 비동기 데이터는 `AsyncStateMixin` + `AsyncStateView` 사용**, `FutureBuilder` 금지 ([presentation/common/async_state.dart](../tenk_app/lib/presentation/common/async_state.dart)). 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state.
- **Navigator push/pop의 generic은 양쪽 모두 명시.** `MaterialPageRoute<T>(builder: ...)`로 T를 박지 않으면 result가 null로 빠지는 경우. push 종료 시점에 무조건 refresh하는 패턴이 안전.
- **에뮬레이터에서 텍스트가 첫 프레임에 안 보이고 화면을 움직이면 나타나면** [[reference-flutter-android-impeller-text-glitch]] — Impeller 텍스트 atlas 버그. `flutter run --no-enable-impeller`로 검증.
- **매니페스트(`AndroidManifest.xml`) 변경은 hot reload로 반영 안 됨.** 콜드 부팅(`q` → `flutter run`) 또는 hot restart(`R`).
- **`main.dart` 최상단(`MaterialApp` 의 `builder`/`theme`/`locale`) 변경도 hot reload 로 안 실릴 수 있다.** 2026-07-28 에 `builder` 로 전역 키보드 닫기를 넣었는데 hot reload 후에도 동작하지 않아 코드를 의심했고, 에뮬에서 확인해보니 **코드는 정상이고 반영이 안 된 것**이었다. 최상단을 건드렸는데 동작이 그대로면 **먼저 `R`(hot restart)** 로 확인할 것.
- **`FittedBox` 는 폭 제약이 loose 면 `fit` 을 무엇으로 주든 자기 자신부터 자식 비율대로 줄인다** (2026-08-17 실측, #29). `RenderFittedBox.performLayout` 이 `constraints.constrainSizeAndAttemptToPreserveAspectRatio(child.size)` 로 **자기 크기**를 먼저 정하기 때문 — 480x864 카드를 360dp 폭 `Column`(기본 `crossAxisAlignment: center`) 안에 두면 FittedBox 자신이 **342.2dp** 로 줄고, `BoxFit.fitWidth` 는 그 342.2 를 채울 뿐이라 **`contain` 과 결과가 같아진다.** `fitWidth`/`fitHeight` 를 의도대로 쓰려면 그 축을 **tight** 로 만들 것(`crossAxisAlignment: stretch` 또는 `SizedBox(width: double.infinity)`). 진단은 추정 말고 `(element.renderObject as RenderBox).size` 를 찍어볼 것 — 격리 테스트에서는 정상이고 실제 트리에서만 틀리는 종류다.
- **카카오 키해시는 머신마다 다름.** 새 머신 [[reference-kakao-android-keyhash]] 절차로 재등록.
- **실기기에서 백엔드 도달 불가**: 기본 base URL 인 `10.0.2.2` 는 에뮬레이터 전용 호스트 루프백. 같은 Wi-Fi 의 실기기에서 PC 백엔드를 호출하려면 PC LAN IP 로 바꿔야 한다. 증상은 "카카오 동의 화면까지는 뜨는데 그 뒤 로그인이 안 됨" — 카카오 SDK 는 인터넷에 닿지만 백엔드 교환 콜이 끊긴다. 현재 머신 IP 와 셋업은 아래 "PC LAN IP" 참고.
- **Android `res/xml/*.xml` 주석에 이중 하이픈 금지**: `<!-- ... -->` 안에 `--` 두 글자가 들어가면 `mergeDebugResources` 가 `ParseError ... 주석에서는 "--" 문자열이 허용되지 않습니다` 로 빌드 실패. XML 1.0 §2.5 strict 적용이라 `--dart-define`, `--flag` 같은 CLI 옵션을 주석에 인용할 때 자주 걸린다. AndroidManifest.xml / network_security_config.xml / 그 외 `app/src/main/res/**.xml` 모두 동일. 해결은 단순히 하이픈을 빼거나 문구를 바꾸면 됨.
- **✅ 해결됨 — 영상 프리뷰 깜빡임 = Impeller 외부 텍스처 버그 (2026-06-19, 삼성 S24 실기기 재현·확정·수정)**. 증상: [export_result_screen](../tenk_app/lib/presentation/challenge/export/export_result_screen.dart) 의 미리보기 영상**만** 초당 10여 회 깜빡임 — 주변 UI(제목/저장/공유 버튼)는 멀쩡. 즉 화면 전체 리프레시 문제가 아니라 **영상 텍스처 합성 단계**의 문제. 진단: live logcat 결과 디코더(mpeg4)는 **단일 인스턴스가 에러 0 으로 정상 디코딩**(`BufferPoolAccessor2.0` 단일 풀, recycle/alloc 단조 증가, used 4~5 일정), 컨트롤러 dispose 도 정상 → 디코딩/컨트롤러 멀쩡, **그리는 단계만** 깜빡임. `flutter run` 에 no-enable-impeller 플래그를 줘서 실행하니 깜빡임 즉시 소멸 → **Impeller 백엔드의 외부 텍스처 렌더 버그로 확정**. 영구 수정: [AndroidManifest.xml](../tenk_app/android/app/src/main/AndroidManifest.xml) 의 `<application>` 에 `io.flutter.embedding.android.EnableImpeller=false` meta-data 추가(Skia 폴백). 매니페스트만으로 재빌드 후 깜빡임 없음 검증 완료. **2026-06-16 의 "삼성 적응형 120Hz thrashing / 양성 / 코드변경 없음" 결론은 오진이었다** — `requestGpisForSFSluggish` 는 노이즈였고 진짜 원인은 Impeller. 같은 프로젝트의 Impeller 텍스트 깨짐 이슈와 같은 계열. **함정 메모**: 그 meta-data 주석에 `--no-enable-impeller` 를 적었다가 XML 이중 하이픈 금지(위 Android res/xml 항목)로 manifest merge 가 깨졌음 — 하이픈 빼서 해결. Impeller 외부 텍스처 버그가 업스트림에서 고쳐지면 meta-data 제거 검토.

---

## 옮겨야 하는 비-git 자산

- **카카오 디벨로퍼스 계정 접근** — 새 머신에서 debug.keystore가 달라 새 키해시 등록 필요. 카카오 앱 ID 자체는 yaml에 박혀 git 추적되지만 콘솔에서 키해시 추가는 사람 작업.
- DB 비밀번호 (지금은 `application-local.yaml`에 박혀 git 추적 중)
- prod JWT secret (현재 `application-prod.yaml`에 박혀 있으나 실제 prod 배포 전 별도 키로 교체 필요)
- (선택) MariaDB 데이터 — 새 환경에서 `schema.sql` 다시 적용해도 무방하면 불필요
- (선택) `tenk-backend/uploads/` 디렉토리 — 이번 머신 영상이 필요 없으면 무시
- (참고) `~/.android/debug.keystore`는 머신별로 다른 게 정상 — Android Studio가 새로 만들어줌. 새 키스토어 → 새 키해시 → 카카오 디벨로퍼스에 추가 등록.
- **릴리스 keystore (`tenk_app/android/tenk-release.keystore`) + `key.properties`** 는 **git 추적**한다 (private 레포 방침 — yaml 자격증명과 동일). 즉 새 머신에서 클론하면 그대로 서명 가능, 별도 이송 불필요. **분실 시 같은 applicationId 로 앱 업데이트 배포 불가**하므로 레포 자체를 잃지 않는 게 곧 백업. (릴리스 keystore 의 키해시는 debug 와 다르므로 카카오 콘솔엔 debug/release 둘 다 등록해야 함.)

---

## PC LAN IP (실기기 테스트용)

현재 머신·현재 네트워크 기준 **`192.168.0.7`**. 두 곳에 같은 값이 박혀 있다 — IP 가 바뀌면 둘 다 갱신:
1. [.vscode/launch.json](../.vscode/launch.json) 의 `tenk_app (device)` 구성 `toolArgs` 안의 `--dart-define=API_BASE_URL=http://.../...`
2. [tenk_app/android/app/src/main/res/xml/network_security_config.xml](../tenk_app/android/app/src/main/res/xml/network_security_config.xml) 의 마지막 `<domain>`
3. 두 곳 바꾼 뒤 폰 브라우저로 `http://<IP>:8080/swagger-ui.html` 이 뜨는지 확인 (안 뜨면 PC Windows 방화벽 → inbound TCP 8080 허용)

IP 확인: PowerShell `ipconfig` → "이더넷 어댑터 Wi-Fi" 의 IPv4 주소. 공유기 DHCP lease 가 갱신되면 바뀔 수 있으니 잘 안 되면 가장 먼저 의심할 것.
