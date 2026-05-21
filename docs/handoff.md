# Handoff — Tenk

> 다른 컴퓨터/세션에서 이 작업을 이어받는 사람(또는 미래의 나)을 위한 인계 노트.
> 영구적인 규칙·결정은 [../CLAUDE.md](../CLAUDE.md)에 있고, 이 문서는 **현재 진행 상태와 다음 할 일**만 기록함.

마지막 갱신: 2026-05-21 (**무지출/배지 도메인 정합성 개선 + 챌린지 상세 화면 UX 강화** 완료. 무지출 일시 입력 불가·하루 1회·자동 삭제, NO_SPEND 정의 "연속 → 누적", 배지 회수(revoke) 로직 추가. 챌린지 상세는 amount 목록 날짜별 그룹화 + 오늘 상태 기반 동적 액션 패널 + 무지출 성취감 카드(누적 일수·다음 배지 게이지). 백엔드 테스트 **75 그린** (단위 55 + 통합 15 + WebMvc 4 + 컨텍스트 1). 다음 우선순위: 내보내기 구체화(회의 필요) → 배지 획득 애니메이션)

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
6. 백엔드 테스트: `cd tenk-backend && ./gradlew.bat test` (총 75개 그린 — 단위 55 + 통합 15 + WebMvc 4 + ContextLoads 1). ⚠️ **테스트 실행 시 로컬 `tenk` DB의 user/challenge/amount/challenge_badge/refresh_token 데이터가 비워진다** (badge 마스터는 유지). Flutter 재로그인으로 복구 가능
7. **Flutter 앱 셋업** (앱 작업까지 할 거면):
   - 새 머신의 `~/.android/debug.keystore`에서 키해시 추출:
     `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64` (Git Bash). PowerShell `Get-FileHash` 안 됨 — [[reference-kakao-android-keyhash]] 참고.
   - 출력값을 카카오 디벨로퍼스 → Tenk 앱 → 플랫폼 → Android의 키해시 목록에 **추가** 등록 (기존 머신 키해시는 그대로 두고 추가). 한 플랫폼에 여러 해시 등록 가능.
   - `cd tenk_app && flutter pub get && flutter run`. 에뮬레이터에서 글자가 안 보이면 [[reference-flutter-android-impeller-text-glitch]] 참고.
8. Claude 세션 시작: 리포 루트에서 `claude` (CLAUDE.md 자동 로딩됨). 첫 메시지로 *"docs/handoff.md 읽고 이어서 진행해줘"* 라고 말하면 컨텍스트 빠르게 복구.

---

## 완료된 것 (요약)

> 디테일은 git log/blame에 있음. 여기엔 "어디까지 왔는지" + "코드에 안 보이는 결정"만.

- ✅ **백엔드 골격**: 프로젝트 스캐폴딩, JPA 엔티티 7종 + Repository, 공통 응답/에러 처리, REST API(User/Challenge/Amount/Media/Badge), 영상 업로드(지출 필수/무지출 선택), Swagger UI, JPA Auditing.
- ✅ **인증**: 모바일 카카오 SDK + 자체 JWT(AT 1시간/RT 14일). `KakaoTokenVerifier`가 `access_token_info`로 `app_id` 매칭 검증. RT는 SHA-256 해시로 DB 저장, 회전 시 즉시 revoke. **Swagger 시나리오 1·2·3 통과 (2026-05-19, curl + DB 검증)**:
  - RT 회전 정상 — 한 번 쓴 RT는 401 + AU0003
  - logout 일괄 무효화 — DB의 그 user_id RT 전부 `is_revoked=1`
  - 만료 AT 401 + `AU0002`(EXPIRED) ≠ `AU0001`(INVALID) 코드 구분 확인
- ✅ **JWT secret 환경별 분리**: 공통 `application.yaml`에 secret 안 둠 (prod에 dev 키 누수 방지). `application-{local,prod}.yaml` 각각 별도 키. 키 노출 시 대응 → 아래 "알려진 주의사항" 참고.
- ✅ **배지 자동 지급**: 이벤트(`AmountRecordedEvent`/`ChallengeFinishedEvent` AFTER_COMMIT) + 매일 새벽 1시 배치 재평가. 단위 테스트로 정책 커버, **실제 이벤트 propagation E2E는 미검증** (아래 §1).
- ✅ **챌린지 결과 export**: `GET /api/challenges/{id}/export` — 일별/카테고리별 JSON 집계.
- ✅ **CORS 비활성화**: Flutter 네이티브 앱만 대상 (브라우저 preflight 없음). 추후 웹 도입 시 `CorsConfigurationSource` 빈 추가.
- ✅ **Spring Boot 4 + Jackson v3 마이그레이션**: `com.fasterxml.jackson.databind.ObjectMapper` → `tools.jackson.databind.ObjectMapper`. 어노테이션은 그대로.

- ✅ **Flutter 앱**: 카카오 로그인 + 챌린지 CRUD + 지출/무지출 기록 + 2초 영상 녹화·업로드(`camera` ResolutionPreset.low + enableAudio:false) + 일시 picker + 잔액 반영 + 삭제 + finalize. **에뮬레이터 E2E 통과 (2026-05-19)**. 구조는 `lib/app/`(셸) + `lib/data/`(api/repository) + `lib/presentation/`(화면) 3층. 컨벤션은 [../CLAUDE.md](../CLAUDE.md) "패키지 구조 (Flutter 앱)" + "코딩 컨벤션 — Flutter" 참고.

- ✅ **배지 도메인 모델 재편 — 유저 단위 → 챌린지 단위** (2026-05-21). 한 챌린지 안에서만 의미를 갖도록 재편. 같은 사용자가 챌린지 A 와 B 에서 똑같이 STREAK 7 을 얻으면 `challenge_badge` 행이 두 개. 챌린지 응답(`ChallengeResponse.badges`)에 인라인 노출. 전용 "배지 화면"·진입점·잠금 상태 UI 모두 제거. 유저 단위 누적(=업적)은 별도 시스템으로 추후 추가.
  - 백엔드: `user_badge` → `challenge_badge` (PK 변경, FK 가 user_id → challenge_id), `UserBadge` → [ChallengeBadge](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/ChallengeBadge.java), [BadgeGrantService](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeGrantService.java) 는 `evaluateForChallenge(challengeId)` / `grantChallengeSuccess(challengeId, result)` 로 시그니처 변경. streak 끝나는 기준일 = `min(today, challenge.endDate)`. amount 쿼리도 user 전체 lookback → 챌린지 내부만. `BadgeController` 와 `GET /api/badges/me` 삭제.
  - 챌린지 API: [ChallengeResponse.badges](../tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/dto/ChallengeResponse.java) 인라인 + [AcquiredBadgeResponse](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/dto/AcquiredBadgeResponse.java). [ChallengeService.toResponse](../tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeService.java) 가 badge JOIN FETCH (직전 운영 LazyInit 버그 패턴 재발 방지).
  - Flutter: `lib/data/badge/badge_api.dart` · `lib/presentation/badge/` 삭제, `BadgeScope` 삭제, AppBar 🏆 진입점 제거. [Challenge.badges](../tenk_app/lib/data/challenge/challenge.dart) 필드 + [ChallengeBadgesRow](../tenk_app/lib/presentation/challenge/widgets/challenge_badges.dart) 위젯 신설 — 챌린지 카드(작게 26px, max 5+N) / 상세(36px). 잠금 상태는 카탈로그 자체를 없앴으므로 노출 안 함. `assets/badges/` PNG 9장은 그대로 재활용 (업적 화면 도입 시도 재사용 가능).
  - 테스트: `BadgeControllerIntegrationTest` 삭제. `BadgeGrantServiceTest` · `BadgeEventIntegrationTest` · `BadgeSchedulerIntegrationTest` 모두 challenge_badge 기반으로 재작성. `BadgeEventIntegrationTest` 에 챌린지 격리 케이스 1개 추가 (`otherChallengeRecordsDoNotLeakIntoThisChallenge`).
  - DB 마이그레이션: `mysql -u tenk -p tenk < docs/schema.sql` 1회 적용 필요 (DROP & RECREATE). 기존 `user_badge` 행은 모두 폐기.
- ✅ **카카오 키 박힘**: 네이티브 앱 키 `589078d3c7daa590c71d9a6e77080b18` 3곳 (kakao_config.dart + Android build.gradle + iOS Info.plist), 백엔드 `tenk.auth.kakao.app-id = 1459747`. Android 키해시 `Dt3/ajH81vV0Ex78dS1ACaqelWc=` (이 머신 debug.keystore 기준). 새 머신은 [[reference-kakao-android-keyhash]] 절차로 재등록.

- ✅ **백엔드 단위 테스트 49개 그린** (2026-05-19, Mockito + AssertJ). `./gradlew.bat test` 통과. 6개 파일:
  - [ChallengeTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/challenge/ChallengeTest.java) (10) — 30일/시작일 과거/역순/null, isStarted·isFinished·containsDate 경계
  - [AmountTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/amount/AmountTest.java) (9) — spend invariant, noSpend, update 분기
  - [ChallengeServiceTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/challenge/ChallengeServiceTest.java) (7) — loadOwned, finalize SUCCESS/FAIL/이미확정/미종료
  - [AmountServiceTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/amount/AmountServiceTest.java) (6) — 종료/미시작 거부, 영상 필수, happy path
  - [BadgeGrantServiceTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeGrantServiceTest.java) (8) — STREAK 폴백·끊김, NO_SPEND 끊김, CHALLENGE_SUCCESS 분기
  - [AuthServiceTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/auth/AuthServiceTest.java) (9) — kakaoLogin/refresh/logout 전 분기
  - **결정 1 — invariant 우회**: `LocalDate.now()`가 정적이라 "종료된 챌린지" 상태는 `ReflectionTestUtils.setField(c, "endDate", today.minusDays(1))`로 사후 박음. 도메인 객체는 invariant를 거친 진짜 객체 유지.
  - **결정 2 — Mockito strictness**: Badge/Auth 테스트는 `@MockitoSettings(strictness = LENIENT)` (케이스별 stub 조합 다양). 나머지는 STRICT 유지.

- ✅ **배지 이벤트 propagation 통합 테스트 8개 그린** (2026-05-20). `@SpringBootTest` + 로컬 MariaDB. 2개 파일:
  - [BadgeEventIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeEventIntegrationTest.java) (6) — `grantChallengeSuccessDirectCall`(가설 검증), `noSpendThreeDaysGrantsBadge`, `multipleNoSpendOnSameDayCountAsOne`, `spendBreaksNoSpendStreak`, `challengeSuccessGrantsBadge`, `challengeFailDoesNotGrantBadge`. 모두 reflection 으로 startDate/endDate 를 backdate 한 챌린지 위에서 동작 (Challenge.validatePeriod 의 `startDate >= today` 제약을 우회).
  - [BadgeSchedulerIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeSchedulerIntegrationTest.java) (2) — `batchFinalizesAndGrantsChallengeSuccess` (배치가 미확정 챌린지 확정 + 배지 지급), `batchBackfillsMissedNoSpendBadge` (이벤트 우회로 박힌 amount 도 배치가 보강).
  - [IntegrationTestBase](../tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) + [application-test.yaml](../tenk-backend/src/test/resources/application-test.yaml): 로컬 `tenk` 스키마 그대로 사용. `@BeforeEach`에서 비-마스터 테이블 DELETE (badge 마스터는 유지). 트랜잭션 롤백 대신 명시적 정리를 쓰는 이유 = `@TransactionalEventListener(AFTER_COMMIT)` 가 실제 커밋 이후에만 발화하므로 테스트가 `@Transactional` 이면 AFTER_COMMIT 이 안 도는 함정.
  - **🚨 운영 버그 발견·수정**: 통합 테스트 첫 실행에서 `[Badge] granted` 로그는 찍히는데 `user_badge` INSERT 가 전혀 일어나지 않는 현상 발견. 원인은 `@TransactionalEventListener(AFTER_COMMIT)` 콜백 시점에 원본 tx 동기화가 정리 중이라 `BadgeGrantService` 의 단순 `@Transactional(REQUIRED)` 가 새 tx 를 못 열고 쓰기가 사라지는 패턴. 가설 검증으로 [`grantChallengeSuccessDirectCall`](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeEventIntegrationTest.java) (이벤트 우회 직접 호출 → 정상 저장) vs `challengeSuccessGrantsBadge` (이벤트 경유 → 미저장) 비교. 수정: [BadgeEventListener](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeEventListener.java) 리스너 메서드 자체에 `@Transactional(propagation = REQUIRES_NEW)` 추가.
  - **함정 1 — 챌린지 `validatePeriod`**: 도메인 invariant 가 `startDate >= today` 라서 NO_SPEND 3단계처럼 today-2 ~ today 의 spentDt 가 필요한 시나리오는 API 만으로 재현 불가. `createChallenge(userId, today-2, today+1, ...)` 처럼 invariant 통과 후 reflection 으로 startDate 를 사후에 박는 패턴 사용. BadgeGrantServiceTest 와 동일.
  - **함정 2 — 통합 테스트가 dev DB 데이터를 비움**: 위에 적은 대로 별도 `tenk_test` 스키마를 만들지 않고 `tenk` 스키마를 공유한다. 매 테스트 실행 시 user/challenge/amount/refresh_token 비워짐. Flutter 카카오 재로그인으로 복구. tenk_test 분리는 다음 머신 운영자가 원하면 그때 결정.

- ✅ **챌린지 상세 화면 UX 강화** (2026-05-21). 도메인 변경에 맞춰 화면도 정리.
  - **amount 목록 날짜별 그룹화** ([_buildGroupedAmounts](../tenk_app/lib/presentation/challenge/challenge_detail_screen.dart)): 최신 날짜 위, 같은 날 안에서도 시간 역순. 그룹 헤더에 "M월 D일 (요일)" + 그날 합계(지출 합산) 또는 "무지출" 라벨. helper 는 [_formatters.dart](../tenk_app/lib/presentation/challenge/_formatters.dart) 의 `formatDayHeader` / `dateOnly`.
  - **오늘 상태 기반 동적 액션 패널** ([_TodayActionPanel](../tenk_app/lib/presentation/challenge/challenge_detail_screen.dart)): 진행 중 챌린지에서 3분기.
    - 오늘 무지출 기록 있음 → 강조 카드만 (지출 버튼도 숨김). 사용자가 마음 바꾸려면 무지출 row 삭제 → 다시 두 버튼.
    - 오늘 지출 기록 있음 → "오늘 N원 지출했어요" 카드 + 지출 버튼만 (무지출은 의미 없음).
    - 오늘 기록 없음 → 기존대로 지출/무지출 두 버튼.
  - **무지출 성취감 카드** ([_NoSpendTodayCard](../tenk_app/lib/presentation/challenge/challenge_detail_screen.dart)): 트로피 아이콘 + "오늘은 무지출!" + 누적 일수 + NO_SPEND 사다리(3/7/14/30) 게이지 + "다음 배지까지 X일". 등록할 때마다 게이지가 한 칸씩 차는 시각적 진전. 30일 도달 시 "최고 단계 달성 🎉". 누적 정의는 `amounts.where(noSpend).map(day).toSet().length` 로 백엔드 `BadgeGrantService.daysWithOnlyNoSpend` 와 동일.
  - 카드 ladder `[3, 7, 14, 30]` 는 백엔드 `badge` 마스터의 NO_SPEND condition_value 와 1:1. 변경 시 [docs/schema.sql](schema.sql) 시드와 함께 갱신 (CLAUDE.md "배지 카탈로그 변경" 행 참고).
  - 백엔드 변경 없음 — 데이터는 기존 challenge + amounts 응답으로 충분.

- ✅ **무지출/배지 도메인 정합성 개선** (2026-05-21). 모델 모호성 제거 + 누적 정의 정착. 백엔드 테스트 **75 그린** (단위 55 + 통합 15 + WebMvc 4 + 컨텍스트 1).
  - 무지출 제약 강화: 일시 입력 불가(서버 `LocalDateTime.now()` 강제), 하루 1회(서비스 + DB `uk_amount_no_spend_day` 생성 컬럼 UNIQUE), 수정 불가(원래 수정 API 자체 미구현 — 자동 성립), 지출 등록 시 같은 날 무지출 row + 첨부 영상까지 자동 삭제. 사용자 통지는 [AmountRecordResult](../tenk-backend/src/main/java/com/hjson/tenk/domain/amount/dto/AmountRecordResult.java)의 `removedNoSpendCount` 로 → Flutter [challenge_detail_screen.dart](../tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) `_openRecord` 에서 SnackBar.
  - NO_SPEND 정의 변경: "연속 일수" → "챌린지 내 누적 일수". 무지출 5일 → 지출 → 무지출 5일이면 총 10일. STREAK 은 "연속" 유지 (꾸준함 vs 절약 총량 — 보상 의미가 달라서).
  - 배지 회수(revoke): [BadgeGrantService.applyLadder](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeGrantService.java) 가 grant/revoke 양방향을 단일 패스로 처리. 회수가 필요한 케이스(예: 무지출 자동 삭제로 누적이 줄어든 경우)에서도 별도 호출 없이 `evaluateForChallenge` 재평가만으로 정합. 검증은 [BadgeEventIntegrationTest.noSpendBadgeRevokedWhenSpendAddedSameDay](../tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeEventIntegrationTest.java).
  - 스키마: amount 에 `no_spend_day_key VARCHAR(64) GENERATED ALWAYS AS (CASE WHEN is_no_spend = 1 THEN CONCAT(challenge_id, '-', DATE(spent_dt)) ELSE NULL END) VIRTUAL` + `uk_amount_no_spend_day` UNIQUE 인덱스. MariaDB 는 partial index 미지원이라 생성 컬럼이 자연스러움. NULL 허용이라 지출 row 끼리는 충돌 안 함.
  - 이벤트 흐름: 지출 시 무지출 자동 삭제 → `AmountRecordedEvent` 발행 → `BadgeEventListener` 가 `evaluateForChallenge` 호출 → revoke 분기로 NO_SPEND 단계 정정. AFTER_COMMIT + REQUIRES_NEW 패턴은 직전 작업에서 정착된 그대로.
  - DB 마이그레이션: `mysql -u tenk -p tenk < docs/schema.sql` 1회 적용 필요 (DROP & RECREATE). 기존 amount row 는 모두 폐기되므로 Flutter 재로그인 후 새로 기록.
  - 추가 테스트: AmountServiceTest +3 (무지출 spentDt 무시·중복 차단·지출 시 자동 삭제), BadgeGrantServiceTest +3 (NO_SPEND 누적 정의·NO_SPEND revoke·STREAK revoke), BadgeEventIntegrationTest +1 (revoke E2E 시나리오). 기존 통합 케이스도 누적 정의에 맞춰 재작성.

- ✅ **통합 테스트 마무리 — Amount 쿼리 경계 + JWT 필터 WebMvc** (2026-05-20). 백엔드 테스트 총 67개 그린:
  - [AmountRepositoryIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/amount/AmountRepositoryIntegrationTest.java) (5) — `findUserAmountsBetween` 의 `[from, toExclusive)` 반열린 구간 검증. from 자정 포함·toExclusive 자정 제외, spentDt 정렬, 유저 필터, 빈 결과, 60일 lookback 패턴까지. `BadgeGrantService.evaluateForUser` 가 의존하는 쿼리라 단위 테스트로는 못 잡는 SQL/JPQL 영역을 메움. `IntegrationTestBase` 패턴 재사용 (다른 통합 테스트와 컨텍스트 공유돼 부팅 비용 0). 직접 native insert 로 amount 박는 이유 = `validateDateInChallenge` invariant + 영상 필수를 우회하기 위해.
  - [JwtAuthenticationFilterWebMvcTest](../tenk-backend/src/test/java/com/hjson/tenk/security/JwtAuthenticationFilterWebMvcTest.java) (4) — Swagger 시나리오 1·2·3 자동화: 헤더 없음 401+`C0003`(SecurityConfig EntryPoint), 정상 AT 200, 만료 AT 401+`AU0002`(필터가 직접 응답), 깨진 토큰 401+`AU0001`. `@WebMvcTest(UserController.class)` 슬라이스 + `@Import(SecurityConfig, JwtAuthenticationFilter, JwtTokenProvider)` + `@EnableConfigurationProperties(AuthProperties)` + `@TestPropertySource` 로 시크릿 주입. DB 없이 가볍게 (1.3초). 만료 토큰 생성은 `JwtTokenProvider` 가 TTL 기반이라 만들 수 없어 같은 시크릿 키로 `Jwts.builder()` 직접 호출, expiration 만 과거로 박는 헬퍼 사용.
  - [TenkApplicationTests](../tenk-backend/src/test/java/com/hjson/tenk/TenkApplicationTests.java) — `@ActiveProfiles("test")` 박아서 IntegrationTestBase 와 프로파일 일관화.
  - **🚧 Spring Boot 4 함정**: `WebMvcTest` 어노테이션 패키지가 이동했다. 기존 `org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest` 는 사라졌고 `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest` 가 정답. `spring-boot-starter-webmvc-test` → `spring-boot-webmvc-test` 모듈 안. (`spring-boot-test-autoconfigure` 자체는 SB4 에서 `json` 슬라이스만 남았다.) IDE 가 "WebMvcTest cannot be resolved" 라고 짖으면 이 import 부터 확인할 것.

---

## 남은 일 (우선순위 순)

> 백엔드 테스트(단위·통합·WebMvc)는 ✅ 완료. 자세한 건 "완료된 것 — 통합 테스트 마무리" 항목 참고.

### 1. 내보내기 구체화 (회의 필요)

> `GET /api/challenges/{id}/export` JSON은 이미 있지만 화면이 없음. 디자인 결정이 먼저.

**회의에서 정할 것**
- 시각화 형태: 일별 막대 / 카테고리 도넛 / 캘린더 히트맵 / 조합?
- 공유 기능: 결과 화면 이미지 저장? 외부 공유 링크? (영상 export는 CLAUDE.md 범위 밖 유지)
- 정보 우선순위: 총지출 vs 목표 / 무지출 일수 / 획득 배지 / 일별 추이 중 메인은?
- 결과 확정 전(진행 중) 챌린지에도 노출할지, 확정 후에만 보여줄지.
- export 가 결과 화면을 그대로 캡처하는 형태인지, 별도 포맷(PDF/이미지)으로 가공하는지.

회의 결과가 나오면 `presentation/challenge/export_screen.dart` 신설 + `ChallengeApi.fetchExport()` 추가.

### 2. 배지 획득 애니메이션

> 사용자 성취감/재미를 위해. 도메인 변경 없는 순수 클라이언트 UX.

- 트리거: 챌린지 응답의 `badges`가 직전 조회 대비 늘어난 시점 감지. `AsyncStateMixin.replaceData` 호출 전후 비교 또는 별도 캐시.
- 표현: Lottie 애니메이션 + confetti + 햅틱 1회. 패키지 `lottie`, `confetti`, `flutter/services`.
- MVP: 새 배지 발견 시 dialog로 1.5초 lottie 재생. 챌린지 상세에서만 트리거 (목록 화면은 시끄러워짐).
- 애셋: Lottie JSON 1~2개 정도. `assets/animations/badge_acquired.json` 같은 위치.

### 3. 앱 UX 다듬기 (나머지)
- **업적(achievement) 시스템** — 챌린지 경계를 가로지르는 누적 보상. 새 테이블(예: `user_achievement`) + 별도 컨트롤러/서비스 + 별도 Flutter 화면. 자산은 기존 `assets/badges/` 재활용 가능. 배지와 디자인 언어가 자연스럽게 이어지도록 설계.
- **녹화 영상 미리보기** — 현재는 체크 아이콘만. `video_player` 패키지 추가하면 미리보기 가능 (MVP 범위 밖).
- **실기기 테스트** — `--dart-define=API_BASE_URL=http://192.168.x.x:8080`로 같은 Wi-Fi의 PC IP 주입. 에뮬레이터와 카메라 동작이 미묘하게 다름.

### 4. 페이지네이션 / 정렬
- `/api/challenges`, `/api/challenges/{id}/amounts`가 전체 목록 반환 중. `Pageable` 도입 시점 결정 (지금은 사용자당 챌린지 수가 적어 무방).

### 5. Google / Naver 로그인 추가 (예정)
- 동일 패턴: `GoogleTokenVerifier` / `NaverTokenVerifier` + `AuthService`에 분기 + `POST /api/auth/google/login` / `/naver/login`. **브라우저 redirect 흐름은 사용하지 않음** (모바일 SDK 전제).

### 6. 운영 고려사항 (필요해지면)
- **영상 저장소 S3/MinIO 이전** — `LocalFileStorage`를 인터페이스로 추출 후 구현체 분리.
- **영상 워터마크** (날짜·잔액 오버레이) — 추후 FFmpeg 도입 시 별도 서비스.
- **AT 강제 무효화(블랙리스트)** — 필요 시 Redis. 현재는 AT 만료 시간(1시간)에 의존.
- **CI 도입** — 현재 통합 테스트가 로컬 `tenk` 스키마를 비우는 구조라 CI 에서 그대로 못 돈다. 도입 시 Testcontainers + 별도 `tenk_test` 스키마로 갈아탈 것.

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
- **통합 테스트가 `tenk` 스키마 데이터를 비움**: [IntegrationTestBase](../tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) 의 `@BeforeEach` 가 user/challenge/amount/refresh_token 을 DELETE 한다 (badge 마스터 9행은 유지). `./gradlew test` 후 Flutter 카카오 재로그인 필요. tenk_test 스키마 분리는 일부러 안 함 (다음 운영자가 원하면 그때).

### Flutter
- **목록/상세 화면의 비동기 데이터는 `AsyncStateMixin` + `AsyncStateView` 사용**, `FutureBuilder` 금지 ([presentation/common/async_state.dart](../tenk_app/lib/presentation/common/async_state.dart)). 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state.
- **Navigator push/pop의 generic은 양쪽 모두 명시.** `MaterialPageRoute<T>(builder: ...)`로 T를 박지 않으면 result가 null로 빠지는 경우. push 종료 시점에 무조건 refresh하는 패턴이 안전.
- **에뮬레이터에서 텍스트가 첫 프레임에 안 보이고 화면을 움직이면 나타나면** [[reference-flutter-android-impeller-text-glitch]] — Impeller 텍스트 atlas 버그. `flutter run --no-enable-impeller`로 검증.
- **매니페스트(`AndroidManifest.xml`) 변경은 hot reload로 반영 안 됨.** 콜드 부팅(`q` → `flutter run`) 또는 hot restart(`R`).
- **카카오 키해시는 머신마다 다름.** 새 머신 [[reference-kakao-android-keyhash]] 절차로 재등록.

---

## 옮겨야 하는 비-git 자산

- **카카오 디벨로퍼스 계정 접근** — 새 머신에서 debug.keystore가 달라 새 키해시 등록 필요. 카카오 앱 ID 자체는 yaml에 박혀 git 추적되지만 콘솔에서 키해시 추가는 사람 작업.
- DB 비밀번호 (지금은 `application-local.yaml`에 박혀 git 추적 중)
- prod JWT secret (현재 `application-prod.yaml`에 박혀 있으나 실제 prod 배포 전 별도 키로 교체 필요)
- (선택) MariaDB 데이터 — 새 환경에서 `schema.sql` 다시 적용해도 무방하면 불필요
- (선택) `tenk-backend/uploads/` 디렉토리 — 이번 머신 영상이 필요 없으면 무시
- (참고) `~/.android/debug.keystore`는 머신별로 다른 게 정상 — Android Studio가 새로 만들어줌. 새 키스토어 → 새 키해시 → 카카오 디벨로퍼스에 추가 등록.
