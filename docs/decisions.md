# 의사결정 회의록 — Tenk

> 주요 기능을 도입/변경할 때의 **의사결정 근거**(회의록). 영구 규칙은 [../CLAUDE.md](../CLAUDE.md), 현재 진행 상태는 [handoff.md](handoff.md)에 있고, 이 문서는 **"왜 이렇게 결정했나"**를 남긴다. **관련 코드를 건드릴 때만** 참고하면 됨.
>
> 수록: ① 기록 수정/촬영 분리 (2026-05-23) ② 결과 카드 (2026-05-26) ③ 영상 내보내기 (2026-05-21) ④ 연령 확인·선택 수집 (2026-07-21) ⑤ 테스터 로그인 (2026-07-25) ⑥ 앱 버전·업데이트 게이트 (2026-07-26) ⑦ 닉네임 쿨다운 안내 문구 (2026-07-26) ⑧ 탈퇴 UX (2026-07-27). 영상 export 관련 **함정(mpeg4 인코더 / drawtext 한글 회귀)**은 ③ 회의록의 "구현 시 주의사항"에 있다.

---

## 탈퇴 UX (2026-07-27)

> #1("탈퇴 철회 흐름")을 구현한 **직후** 붙은 논의. "탈퇴 후 3개월 보관이 괜찮은 건가"에서 시작해 보관 기간·목적·재가입·통계까지 다시 짰다. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증 — 탈퇴 후 유예 기간". 여기엔 왜 이렇게 골랐는지만.

### 배경 — 철회를 붙이자 보관의 목적이 바뀌었다

원래 3개월 보관의 명분은 처리방침에 적힌 **"부정 이용 방지 및 문의 대응"** 이었다. 그런데 따져보니 Tenk 에는 그 목적이 성립하지 않는다.

| 실무에서 보관하는 이유 | Tenk |
|---|---|
| 재가입 어뷰징 방지 (쿠폰·리워드·무료체험 재취득) | ❌ 결제·보상이 없어 유인 자체가 없음 |
| 분쟁·신고 대응 (커머스 클레임, UGC 신고) | ❌ 신고 체계가 아직 없음 (생기면 재검토) |
| **탈퇴 철회 / 실수 복구** | ✅ #1 로 방금 만든 그것 |

PIPA 원칙은 목적 달성 시 **지체 없이 파기**이고, 보관은 법령상 보존 의무나 별도 동의가 있을 때의 예외다. Tenk 은 결제·거래가 없어 전자상거래법 보존 대상도 아니다. 즉 **처리방침에 목적을 적는 것과 그 목적이 근거가 되는 것은 다르고**, 실질적 근거는 "철회 대응" 하나만 남았다. (법률 자문이 아니라 판단 — 검수는 §0 백로그.)

### 사용자가 제기한 두 문제

1. **"탈퇴 후 재가입이 바로 안 되는 UX 가 싫다"** — 유예 기간이 재가입 장벽이 되면 안 된다.
2. **"탈퇴 즉시 다 지우면 탈퇴 사유·통계 분석을 못 한다"** — 아쉽다.

그리고 이 둘과 철회가 서로 충돌하는 것처럼 보였다("철회를 보장하려고 데이터를 들고 있으면 재가입이 막힌다").

### 결정 사항

1. **유예 기간 3개월 → 1개월.** 재가입 장벽이 아니라 순수한 철회 유예가 되면 길게 잡을 이유가 없다. 실수를 깨닫는 데 걸리는 시간이 기준 (구글 20일·인스타 30일·디스코드 14일 등과 같은 범위).
2. **복귀 시 철회/재가입을 사용자가 고른다.** 돌아온 사람은 *기록을 되찾으러 온 사람* 과 *리셋하러 온 사람* 으로 갈린다. 후자에게 철회를 강요하는 것이 정확히 문제 ①이 지적한 UX다.
3. **"새로 시작하기" 는 옛 계정을 즉시 파기한다.** 그래야 유예를 기다리지 않고 곧바로 재가입된다. `(provider, provider_user_id)` unique 도 이걸로 자연히 풀린다.
4. **탈퇴 통계용 원본 보관은 기각.** raw 를 남기고 `user_id` 만 끊는 건 익명이 아니라 **가명처리**라 여전히 개인정보고, 안전조치·결합제한 의무가 붙어 "3개월 논쟁"이 이름만 바꿔 돌아온다. 게다가 **영상(얼굴이 곧 식별자)·자유 텍스트(내용·한 줄 평)는 익명화 자체가 불가능**하다.
5. **익명 집계 로그(`withdrawal_log`)도 두지 않는다.** 파기 직전 숫자 한 줄만 남기는 안(챌린지 수·이용 일수·마지막 활동 후 경과일·사유 코드)을 검토했고 PIPA 부담 없이 문제 ②를 풀 수 있었지만, **현 단계에 과하다는 사용자 판단으로 채택하지 않음**. 나중에 탈퇴 분석이 실제로 필요해지면 이 안을 꺼내 쓸 것 — 원본 보관으로 돌아가지 말고.
6. **보관 목적 문구를 "탈퇴 철회 대응" 으로 교체.** privacy.html §3 · delete-account.html 동시 갱신.

### 탈퇴 확인 다이얼로그는 철회를 안내하지 않는다

별도로 결정한 항목. 탈퇴를 결심한 사람에게 "되돌릴 수 있어요"는 결정을 흐리는 잡음이라, **철회는 실제로 돌아왔을 때 로그인 화면에서만** 알린다. 단 예전 문구 "영구히 삭제되고 복구할 수 없어요" 로도 되돌릴 수 없다 — 철회가 생긴 뒤로 거짓이 됐다. 그래서 참이면서 철회를 광고하지 않는 문장으로: *"탈퇴하면 모든 챌린지와 기록을 더 이상 볼 수 없고, 일정 기간이 지나면 완전히 삭제돼요."*

구성도 바꿨다 — **제목 없이 설명 → 질문("정말 탈퇴하시겠어요?")이 이어지는 한 문단**. 제목으로 먼저 물으면 사용자가 답을 정한 뒤에 근거를 읽게 되고, 설명이 결정에 반영되지 않는다. 질문을 굵게·크게 강조하는 안도 시도했다가 **뺐다** — 문장이 끊겨 보여서, 위계 없이 한 호흡으로 읽히는 쪽이 낫다는 판단(왼쪽 정렬 + 단일 `AppTypo.body`).

**UI 카피와 법적 고지는 기준이 다르다** — privacy.html·delete-account.html 은 보관 기간 중 처리 방식을 사실대로 적어야 하는 문서라 철회·재가입을 **명시**한다.

### 복귀 선택 다이얼로그는 버튼 라벨에 기대지 않는다

"이어서 쓰기" 만 보여주면 **탈퇴한 사람에게는 말이 안 된다** — *탈퇴했는데 뭘 이어서 쓴다는 거지?* 로 읽힌다. 그래서 본문 한 문단에서 두 선택지의 결과를 다 밝히고(철회 = 이전 기록 그대로 / 새로 시작 = 이전 기록 전부 삭제), 라벨도 `탈퇴 철회` 로 바꿨다. 버튼은 한 줄에 3개(`취소`/`새로 시작`/`탈퇴 철회`)이며 폭을 2:3:3 으로 고정한다 — 테마 기본 버튼 스타일로는 좁은 기기에서 Material 이 세로로 접는다.

재가입 2차 확인은 **만들었다가 제거**했다. 본문이 이미 삭제를 말하고 같은 다이얼로그에 취소가 있어 되돌릴 자리가 이미 한 번 있으므로, 확인을 한 겹 더 두는 건 마찰만 늘린다. 대신 `새로 시작` 을 danger 색으로 표시해 파괴적 선택임을 남긴다.

### 다루지 않은 것 (백로그 후보)

좋은 탈퇴 UX 의 나머지 요소로 정리만 해둔 것 — **탈퇴 시 잃는 것을 숫자로 보여주기**("챌린지 3개·기록 47건·영상 12개"), **탈퇴 전 영상 export 제안**(Tenk 에만 있는 기능이라 궁합이 좋다), **탈퇴 사유 1문항**(선택). 셋 다 이번 범위 밖.

---

## 닉네임 쿨다운 안내 문구 (2026-07-26)

> #11("닉네임 변경 안내 날짜 텍스트 삭제")에서 출발해 **제한 규칙 자체**와 **안내 문구 형식**까지 바뀐 건. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md) "닉네임". 여기엔 왜 이 형식인지만.

### 배경 — 안내와 규칙이 어긋나 있었다

앱 안내문은 "변경 후 **24시간** 동안은 다시 변경할 수 없어요" 인데, 실제 판정은 `today > 마지막변경일` = **다음 날 자정**이었다. 밤 11시에 바꾸면 **1시간 뒤** 다시 바뀌는 구멍. 안내를 규칙에 맞출지 규칙을 안내에 맞출지 골라야 했고, **규칙을 24시간으로** 통일하기로 했다 (사용자 결정) — 문구를 고치는 쪽은 구멍을 명문화하는 셈이라.

### 결정 사항

1. **상시 라벨 제거, 탭했을 때만 안내.** 닉네임 행에는 `lock_outline` 아이콘만. 평소 화면에 날짜가 박혀 있는 건 잡음이고, 바꾸려고 눌렀을 때 알려주면 충분하다.
2. **문구 = 규칙 먼저 + 가능 시점 짧게.** `닉네임은 24시간에 한 번만 바꿀 수 있어요. 내일 오후 10시 11분부터 가능해요.`
3. **날짜는 절대 표기 대신 now 기준 오늘/내일 라벨.** 쿨다운이 정확히 24시간이라 변경 직후엔 항상 '내일', 다음 날 열면 '오늘'로 바뀐다. 연도는 넣지 않는다.
4. **시각은 오전/오후 + 분** (정각이면 분 생략). 24시간제 `22:11` 보다 읽었을 때 자연스러운 쪽.

### 왜 이 형식인가 — 쿨다운 길이에 따라 표기법이 갈린다

한국 앱들의 일반적 관례를 정리하면:

| 쿨다운 | 표기 | 이유 |
|---|---|---|
| 초·분 (인증번호 재발송) | 카운트다운 숫자 (`59초 후 재전송`) | 줄어드는 게 보여야 기다릴 마음이 듦 |
| **시간 (우리 케이스)** | **상대 시간 또는 오늘/내일 + 시각** | 절대 시각만 주면 사용자가 뺄셈해야 함 |
| 일·월 (닉네임 30일 제한 등) | 절대 날짜 (`8월 25일부터`) | "30일 뒤"는 달력을 봐야 해서 오히려 불친절 |

상대 표현은 단위가 커질수록 계획을 못 세우게 되고, 절대 표현은 단위가 작아질수록 뺄셈을 강요한다. 24시간은 그 경계라 **오늘/내일 라벨 + 시각**이 둘의 장점을 취한다.

토스가 공개한 라이팅 원칙 중 직결되는 것 — **Weed cutting**(잡초 제거: 연도·"다시"·"이후에" 삭제), **Focus on key message**(방금 자기가 바꾼 걸 아는 사용자에게 이유를 재설명하지 않음), **Suggest over force**("변경할 수 없어요" 대신 "~부터 가능해요"), **Easy to speak**("14시 32분" 대신 "오후 2시 32분"). 다만 **시간·숫자 표기 세칙은 토스도 공개하지 않았다** — 위 표는 관례 정리이지 인용이 아니다.

### 회귀 방지

- 문구에 연도·"다시"·"이후에"를 다시 넣지 말 것 (잡초).
- 규칙을 날짜/자정 기준으로 되돌리지 말 것 — 위 구멍이 되살아나고 안내문과 다시 어긋난다.
- 쿨다운 상수는 `UserService.NICKNAME_CHANGE_COOLDOWN`(판정)과 `UserResponse.computeAvailableFrom`(안내 시각) **양쪽에 있다**. 하나만 바꾸면 "가능하다고 안내했는데 거부당함"이 된다.

**출처**: [토스의 8가지 라이팅 원칙들](https://toss.tech/article/8-writing-principles-of-toss) · [앱인토스 UX 라이팅 가이드](https://developers-apps-in-toss.toss.im/design/ux-writing.html)

---

## 앱 버전·업데이트 게이트 회의록 (2026-07-26)

> 메뉴에 "앱 버전 + 최신 여부"를 넣으려다 "최신 버전을 서버가 어떻게 아나"로 번져 #5(강제/권장 업데이트)까지 함께 설계한 회의. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md) "앱 버전 / 강제·권장 업데이트". 여기엔 **왜 이 방식을 골랐나 + 버린 대안**만.

### 배경 — 왜 서버가 필요한가

- 메뉴에 버전만 보여주는 건 `package_info_plus` 로 끝나지만, **"최신입니까?"** 를 판정하려면 *최신 버전이 뭔지* 를 어딘가에서 알아야 한다. 내 버전(1.0.0)만으로는 알 수 없다.
- 이 "최신 여부"는 본질적으로 #5(강제/권장 업데이트)와 **같은 데이터**(서버가 아는 최신/최소 버전)를 쓴다 → 둘을 한 번에 설계.

### 결정 사항

1. **판정은 서버가 진실의 원천.** 클라는 semver 비교를 하지 않고 상태(`LATEST`/`UPDATE_AVAILABLE`/`UPDATE_REQUIRED`)만 받는다. 이유: **강제 기준선(min)을 재배포·앱출시 없이 바꾸려면** 로직이 서버에 있어야 함. (닉네임·연령 검증과 같은 "서버가 원천" 원칙.)
2. **정책 저장 = `app_config` 단일 행 (DB, "B-sql" 방식).** `min_supported_version`/`latest_version`/`android_store_url`/`ios_store_url`. **값 갱신은 관리자 UI 없이 SQL** — TESTER 승격과 동일한 운영. `GET /api/app/version?platform&currentVersion`(PERMIT_ALL, 부팅 게이트).
3. **클라 게이트**: [SessionGate](../tenk_app/lib/app/session_gate.dart) 가 버전을 **가장 먼저** 판정(로그인·동의보다 상위 차단). 강제=풀스크린 차단, 권장=목적지 위 1회 안내. fail-open(서버·버전 이상 시 미적용 — 사용자를 잠그지 않는다).
4. **관리자 패널은 지금 짓지 않는다 — 백로그.** 현재 관리자 제어 대상은 TESTER 승격 + 버전 정책 2개뿐, 둘 다 저빈도 SQL 로 충분. 패널(ADMIN role+인증+웹 화면)은 **출시 후 UGC 모더레이션(신고)** 이 생겨 SQL 로 감당 안 될 때 착수. 그때 이 값들이 전부 "DB 행 편집" 이라 패널에 자연히 흡수.

### 검토했다 버린 대안

- **ⓐ 설정 파일(yaml/env)에 버전을 둔다(A안)**: 가장 단순(테이블 없음)하나 버전을 올릴 때마다 **백엔드 재배포(최소 컨테이너 재시작)** 가 필요. "재배포 없이 SQL 한 줄" 을 원해서 B-sql 채택. (env 로 빼면 재빌드까진 아니고 재시작이지만, 그것도 떼고 싶다는 요구.)
- **ⓑ 관리자 화면(B-admin)으로 버전 입력**: 재배포는 없지만 인증·화면·권한을 지금 세우는 건 값 2개에 과설계. TESTER 승격이 이미 SQL 운영이라 같은 방식(B-sql)이 일관.
- **ⓒ 코드 상수 하드코딩**: 코드 수정+재배포+앱 출시까지 묶여 최악. 폐기.
- **ⓓ Play In-App Update API(`in_app_update`)**: 백엔드 불필요하지만 **Play 설치본·안드로이드 한정**(직접 APK·iOS 미지원). 우리가 소유하는 서버 방식이 iOS 공통 커버라 우위.
- **ⓔ 클라가 semver 비교(서버는 값만 제공)**: 가능하나 정책(강제 기준)을 바꿀 때 **앱 재배포**가 필요해져 서버 판정의 이점이 사라짐. 서버 판정으로 결정.

---

## 테스터 로그인 회의록 (2026-07-25)

> Play 프로덕션 승격의 "앱 액세스 권한(App access)" 답안을 확정하려고 연 회의. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md) "테스트 지원 (devtools)", Play 폼 답안은 [play-console-app-content.md](play-console-app-content.md) §2. 여기엔 **왜 이 방식을 골랐나 + 검토했다 버린 대안**만.

### 배경 — 전제가 바뀌었다

- 심사자 로그인을 **이메일 전용 카카오계정**(전화·본인인증 없이 `accounts.kakao.com` 가입)으로 해결할 수 있음을 에뮬레이터에서 확인(2026-07-21). → 여분 번호·앱 내 우회 없이 데모 계정으로 App access 를 채울 수 있게 됨.
- 그전까지는 프로덕션 빌드에 **devtools 테스트 로그인**(카카오 우회 + 공유 키)을 남겨 심사자에게 안내하는 잠정안이 유력했다.

### 결정 사항

1. **App access = 데모 카카오 계정.** 심사자는 순정 앱에 데모 카카오 계정으로 로그인. 앱·서버에 우회 코드 0.
2. **앱 내 테스트 로그인 완전 제거** — 로그인 화면 버튼 + `AuthRepository.loginAsTest` + `AuthApi.testLogin` + `_TestSlotDialog` + `test_config.dart` 삭제.
3. **서버 테스트 로그인 엔드포인트 제거** — `POST /api/auth/test/login` + `TestSupportService.testLogin` + `TestLoginRequest` + `TestSupportProperties`(`tenk.test.*` yaml 포함) 삭제. `AuthProvider.TEST` 는 기존 로컬 데이터 호환용으로만 `@Deprecated` 로 잔존.
4. **시딩(테스트 데이터)은 유지하되 계정 단위 권한으로 재게이팅** — `provider==TEST` 게이트를 `user.role == TESTER` 로 교체. 새 `user.role`(`UserRole { USER, TESTER }`) 컬럼 + `role.canUseTestTools()`. 내부 테스터는 **실제 카카오 계정을 DB 에서 `role='TESTER'` 로 승격**(SQL). `UserResponse.role` 로 클라가 '내 정보' 시딩 버튼을 게이팅. **전역 킬스위치(`tenk.test.enabled`)는 제거** — 플래그 없는 계정 = 시딩 불가 = 그 자체가 킬스위치.

### 검토했다 버린 대안

- **ⓐ devtools 테스트 로그인을 프로덕션에 유지**(심사자에게 버튼 안내): 프로덕션 바이너리에 우회 경로가 남고 공유 키가 바이너리에서 추출 가능한 약점(키 새면 TEST 계정 양산 → 실계정 데이터엔 무접근이나 DB 오염). 데모 계정으로 대체 가능해지자 굳이 남길 이유가 없어 **폐기**.
- **"테스트 권한"을 boolean `test_enabled` 컬럼으로**: 동작은 같지만 나중에 `ADMIN` 등 운영 권한이 생기면 플래그가 늘어난다. **role 컬럼**이 확장 여지가 커서 채택.
- **"테스트 권한"을 yaml 허용목록(provider_user_id)으로**: 스키마 변경은 없지만 테스터 추가마다 재배포 필요 + "계정에 권한 부여"라는 멘탈 모델과 덜 맞음. **DB role 컬럼**으로 결정(SQL 로 즉시 승격, 재배포 불필요).
- **전역 킬스위치 유지**: role 게이트가 이미 충분한 잠금이라(승격 계정만 시딩, 그 계정 본인 데이터만 wipe) 이중 스위치는 불필요 → 제거해 단순화.

### iOS 심사 메모 (착수 시 안건 — 지금 결정 아님)

- 애플도 데모 계정 필요(App Store Connect → Sign-In Information). **같은 데모 카카오 계정 공용**.
- ⚠️ **가이드라인 4.8**: 제3자 소셜 로그인(카카오)만 제공하면 **Sign in with Apple** 병행이 심사 조건이 될 수 있음 → iOS 출시 전 `AppleTokenVerifier` + `/api/auth/apple/login` 추가 검토.
- ⚠️ 데모 계정 새 기기 인증(이메일 코드)을 심사자가 못 받으면 반려 위험 — 구글과 동일 리스크, 제출 전 재현.

---

## 연령 확인 · 선택 수집(성별) 회의록 (2026-07-21)

> Play 프로덕션 승격을 위한 "앱 콘텐츠" 마무리 과정에서 나온 결정들. 영구 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증 — 연령 확인 / 성별", Play 폼 답안은 [play-console-app-content.md](play-console-app-content.md). 여기엔 **왜 이 방식을 골랐나 + 검토했다 버린 대안**만.

### 배경

- Play 타겟 연령대에 **13~15세를 포함**하기로 함(이용약관이 만 14세 기준이라 18+만 고르면 약관과 숫자가 어긋남). 그 순간 **가족 정책(Families Policy)** 대상이 된다.

### 결정 사항

1. **연령 확인은 우리 앱 자체 화면으로** 받는다(카카오 위임 불가). → [AgeGateScreen](../tenk_app/lib/presentation/legal/age_gate_screen.dart)
2. **만 14세 미만 → 계정 즉시 하드 삭제 + 거부**(U0006). soft delete 아님. → [UserService.verifyAge](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserService.java)
3. **입력 방식은 생년월일**(생년만/나이 직접입력 아님).
4. **성별은 선택 수집** — 가입 흐름 밖('내 정보'), 목적 고지 + 언제든 철회. **필수/온보딩 아님.**

### 검토했다 버린 대안

- **"만 14세 이상입니다" 체크박스만** (사용자 최초 원안): **광고가 없는 지금은 이걸로도 정책상 충분**하다(중립적 연령 심사는 *인증 안 된 광고 SDK 를 쓰는* 혼합 타겟 앱에 걸리는 조항). 그럼에도 생년월일 화면을 유지한 이유 = ① 약관의 만 14세 기준을 실제로 강제하는 유일한 수단 ② 연령대 통계를 부수적으로 확보. **단, 나중에 광고를 붙이면 체크박스로는 부족** — 그땐 ⓐ 중립적 연령 심사 도입(지금 그것) 또는 ⓑ 전원을 아동/연령미상으로 취급해 인증 SDK 의 비맞춤 광고만 노출(구현 부담 0, eCPM 손해) 중 택1. 개인 앱엔 ⓑ 가 실용적.
- **카카오가 미성년자를 걸러주게 하기**: 불가. 로그인 단계 차단은 **카카오싱크(비즈앱 전환 + 채널 연결 + 검수, 사업자 정보 필요)** 기능이고, `birthyear` 동의항목도 별도 수집 권한 심사가 필요한 데다 **만 14세 판정·차단은 결국 우리 몫**이라 자체 화면을 피할 수 없다.
- **생년(4자리)만 받기**: UX·최소수집 측면에선 오히려 더 나은 안이었으나(자기신고라 정밀도 무의미, `birthyear` 가 업계 표준), 최종적으로 **생년월일 유지**로 결정.
- **나이 직접 입력**: 기각. 저장 순간부터 낡아 통계·정책 변경에 못 쓰고, 만 나이/세는 나이 혼동이 있다.
- **성별을 가입 시 필수/온보딩 수집**: 기각. 기능에 안 쓰이는 항목이라 **PIPA 최소수집 원칙 위반 소지** + 아동 포함 타겟이라 가족 정책상 더 민감 + 온보딩 마찰로 이탈. "가계부가 왜 성별을?" 인상도 비쌈.

### 함정·교훈

- **"거부하면서 삭제"는 같은 트랜잭션에서 안 된다.** 지우고 예외를 던지면 그 롤백에 삭제까지 휩쓸린다 → [purgeImmediately](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 를 `REQUIRES_NEW` 로 분리. 회귀 가드 [UserAgeVerificationIntegrationTest.underageIsRejectedAndPurged](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserAgeVerificationIntegrationTest.java).
- **AgeGateScreen 의 중립성 3원칙은 정책 요건**(컷오프 비노출 · 기본값 없음 · 이탈 차단) — 임의로 바꾸지 말 것.
- **Google 계정 삭제 정책은 앱 밖 삭제 요청 URL 을 요구** → [delete-account.html](../tenk-backend/src/main/resources/static/delete-account.html) 신설(앱 내 탈퇴만으론 부족).

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
