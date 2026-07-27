# Tenk — Claude 작업 가이드

이 문서는 새 세션이 시작될 때 Claude가 자동으로 읽는 프로젝트 컨텍스트야.
다른 컴퓨터에서 작업을 이어갈 때 가장 먼저 이 파일을 참고할 것.

> **이 문서를 갱신하는 규칙**: 다음 중 하나라도 발생하면 **같은 PR/커밋(또는 동일 대화 턴) 안에서 이 문서도 함께 갱신**할 것.
> - 코드/스키마/설정/도메인 규칙을 수정했고 이 문서와 어긋나거나 새로 적어둘 사항이 생긴 경우
> - **요구사항·기술 스택·아키텍처 결정이 추가·변경된 경우** (예: 클라이언트 프레임워크 결정, 새 외부 의존성 도입, 인증·저장소 방식 변경, 핵심 도메인 정책 변경)
> - 위 결정을 대화에서 합의했지만 아직 코드에 반영되지 않은 경우에도, 결정 자체는 이 문서에 먼저 박아둘 것
>
> **📂 문서는 용도별로 분리돼 있다 — 새 내용을 handoff 에 몰아 적지 말 것.** 어디에 쓸지는 아래 표로 판단:
>
> | 쓸 내용 | 어디에 |
> |---|---|
> | 영구적인 규칙·구조·아키텍처·도메인 정책 (진실의 원천) | **이 문서 (CLAUDE.md)** |
> | **현재** 진행 상태 · 남은 일(미착수) · 회귀 함정 · 시작 순서 | [docs/handoff.md](docs/handoff.md) |
> | **지난** 이력 — 시간순 변경 로그, 완료된 작업 상세, 검증 결과 | [docs/handoff-archive.md](docs/handoff-archive.md) |
> | 의사결정 **근거**(왜 이렇게 골랐나) · 대안 검토 · 회의록 | [docs/decisions.md](docs/decisions.md) |
> | 배포 **구조·런북·배포 함정** (배포하는 사람이 볼 것만) | [docs/docker-deployment.md](docs/docker-deployment.md) |
> | Play Console **앱 콘텐츠 폼 답안**(데이터 안전·콘텐츠 등급·타겟층) | [docs/play-console-app-content.md](docs/play-console-app-content.md) |
>
> 판단 기준: *"지금 알아야 하나(handoff) vs 나중에 왜 그런지 추적할 때만 보나(archive/decisions)"*.
> 작업을 완료하면 handoff 의 해당 항목은 **archive 로 옮기고 handoff 에선 지운다** (handoff 는 계속 짧게 유지).
> 배포 문서에는 **할 일·기능 이력을 적지 말 것** — 그건 handoff/archive 소관이다.

---

## 프로젝트 개요

- **서비스 컨셉**: "만원 챌린지" — 짧은 영상으로 지출/무지출을 기록하고, 챌린지 기간(시작일 오늘 이후, 최대 30일) 내 목표 금액 안에서 소비하기.
- **대상 클라이언트**: **Flutter 기반 모바일 앱(iOS/Android 단일 코드베이스)**. 브라우저 기반 흐름(서버 사이드 OAuth redirect, 세션 쿠키 등) 대신 모바일 친화적인 토큰 기반 흐름을 사용. 모든 백엔드 변경은 이 전제를 깔고 갈 것.
  - 카카오 로그인: 공식 `kakao_flutter_sdk`로 access token 발급 후 백엔드 `/api/auth/kakao/login`에 전달.
  - 영상 녹화: Flutter `camera` 패키지의 **`ResolutionPreset.medium` + 2초 타이머**로 처음부터 가볍게·짧게 촬영. ffmpeg 등 후처리 트랜스코딩은 사용하지 않음. export 파이프라인이 480x864 로 정규화하므로 medium 이상은 의미 없음 (파일만 커짐).
- **현재 단계**: 백엔드 REST API 골격 1차 구현 완료. 통합테스트는 미수행. Flutter 앱은 카카오 로그인 + 챌린지 CRUD + 지출/무지출 기록 + 영상 녹화·업로드 + 배지 화면 + **영상 합본 export(클라이언트 ffmpeg 합성)** 까지 완료.

## 리포 구조 (모노레포)

```
tenk/                       # 리포 루트 (CLAUDE.md/docs는 양쪽 공통)
├── CLAUDE.md, README.md
├── docs/                   # 핸드오프·스키마 등 (현재는 backend-only)
│   ├── handoff.md
│   └── schema.sql
├── tenk-backend/           # Spring Boot 백엔드 (Gradle 루트)
│   ├── src/main/java/com/hjson/tenk/...
│   ├── build.gradle, settings.gradle
│   ├── gradlew, gradlew.bat, gradle/
│   └── uploads/            # gitignored, 런타임 영상 저장 (`tenk.upload.base-dir` 기본값)
└── tenk_app/               # Flutter 모바일 앱 (iOS/Android 단일 코드베이스, Dart 패키지명 `tenk_app`)
```

- 백엔드 명령(`gradlew`, 빌드, 실행)은 모두 **`tenk-backend/`에서 실행**.
- Flutter 명령(`flutter pub get`, `flutter run`)은 모두 **`tenk_app/`에서 실행**.
- DB 스키마(`mysql ... < docs/schema.sql`)는 **리포 루트에서 실행** (docs는 루트에 있음).
- API 계약을 바꾸면 **백엔드와 앱을 같은 PR에서 함께 갱신**할 것 (모노레포 이점).

## 기술 스택

| 영역 | 선택 |
|---|---|
| 클라이언트(모바일) | **Flutter (Dart)** — `kakao_flutter_sdk`, `camera` |
| 언어/런타임 | Java 21 |
| 프레임워크 | Spring Boot 4.0.6 |
| 영속성 | Spring Data JPA + MariaDB |
| 보안 | Spring Security (stateless) + **자체 JWT (HS256, jjwt)** |
| 인증 방식 | **모바일 SDK가 카카오 access token 발급 → 백엔드가 검증·자체 JWT(AT+RT) 발급**. 세션·쿠키 없음 |
| 마이그레이션 | **JPA `ddl-auto=validate` + `docs/schema.sql` 수동 적용** (Flyway 등 미사용) |
| 파일 저장 | 로컬 파일 시스템 (`./uploads/`, gitignore) |
| API 문서 | springdoc-openapi (`/swagger-ui.html`) |
| 빌드 | Gradle Wrapper |
| 테스트(백엔드) | JUnit5 + Mockito + AssertJ. 총 **183개** (2026-07-28 실측): 단위 127 (기존 116 + 탈퇴 복귀(철회·재가입) 7 + **탈퇴 사유 4**) + `@SpringBootTest` 통합 51 (배지 이벤트 8 + 배치 2 + Amount 쿼리 경계 5 + Media JOIN FETCH 2 + devtools 시딩 3 + 필수 동의·선택 수집 E2E 5 + 탈퇴 계정 파기 5 + 연령 확인 E2E 6 + 앱 버전 게이트 E2E 4 + 탈퇴 복귀 E2E 7 + **탈퇴 사유 E2E 4**) + `@WebMvcTest` 인증 필터 슬라이스 4 + 컨텍스트 로드 1. **전원 통과**(2026-07-27 기준). ⚠️ **앱 버전 통합 테스트는 `app_config` 테이블이 있어야 돈다** — 로컬/CI 에 [schema.sql](docs/schema.sql) 의 app_config CREATE+INSERT 선적용 필요. (테스트 로그인 제거로 devtools 5→3 / 동의 6→5 / 연령 7→6, 총 151→147.) `@SpringBootTest` 통합은 **로컬 MariaDB의 `tenk` 스키마를 그대로 사용**하므로 매 테스트 실행 시 user/challenge/amount 등 dev 데이터가 함께 비워진다 (Flutter 재로그인으로 복구). 패턴은 [IntegrationTestBase](tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) 참고. WebMvc 슬라이스는 DB 없이 가볍게 돈다 ([JwtAuthenticationFilterWebMvcTest](tenk-backend/src/test/java/com/hjson/tenk/security/JwtAuthenticationFilterWebMvcTest.java)) |

## 도메인 규칙 (의사결정 합의)

### 인증
- **현재 활성 공급자**: `KAKAO`만. `GOOGLE`/`NAVER`는 enum/`AuthProvider`에는 남아 있으나 실 흐름·코드는 미구현 (추후 동일한 모바일 토큰 교환 방식으로 추가 예정).
- ID/비밀번호 자체 로그인 없음. `user.password` 컬럼은 **제거**, 대신 `provider`, `provider_user_id` 를 사용. `(provider, provider_user_id)`가 unique.
- **이메일은 수집하지 않는다** (2026-07-26 결정, `user.email` 컬럼도 DROP). 카카오 '카카오계정(이메일)' 동의항목은 **개인 개발자 일반 앱에서 '권한 없음'** 이라 실제로 늘 NULL 이었고, 확인해보니 이메일이 쓰이는 곳은 '계정 설정' 표시 한 곳뿐이었다. 비즈 앱 전환으로 받아올 수는 있으나 **기능에 안 쓰는 항목을 받는 건 최소수집 원칙 위반** — 성별을 선택 항목으로 둔 것과 같은 논리. [KakaoTokenVerifier.KakaoUser](tenk-backend/src/main/java/com/hjson/tenk/security/KakaoTokenVerifier.java) 는 `kakao_account.email` 을 **파싱조차 하지 않는다**. 되살리려면 파싱 + 엔티티 컬럼 + [schema.sql](docs/schema.sql) + [privacy.html](tenk-backend/src/main/resources/static/privacy.html) 수집표·제3자 제공표 + [play-console-app-content.md](docs/play-console-app-content.md) §6-2 를 **전부 함께** 되돌릴 것. '계정 설정'의 '연동 계정' 행은 이메일 대신 **공급자**를 표시한다.
- **로그인 흐름** (모바일 전용):
  1. 모바일 앱이 카카오 SDK로 access token 발급.
  2. `POST /api/auth/kakao/login { accessToken }` 호출.
  3. 백엔드가 `kapi.kakao.com/v1/user/access_token_info`로 **`app_id` 매칭 검증** (다른 앱 토큰 차단) → `/v2/user/me`로 사용자 정보 조회.
  4. 신규면 자동 프로비저닝 (카카오 닉네임 그대로), **기존이면 갱신하는 값이 없다** (닉네임은 사용자가 직접 변경한 값 보존 — 아래 닉네임 정책 참고. 이메일은 위 항목대로 미수집).
  5. 자체 JWT **AT(1시간, HS256)** + opaque **RT(랜덤 64자, SHA-256 해시로 DB 저장, 14일)** 발급. 응답에 `isNewUser` 플래그 — 신규 가입을 만든 호출이면 true (refresh 응답은 항상 false). 클라이언트는 true 일 때 NicknameSetupScreen 으로 분기.
- **카카오 키 두 종류** (같은 카카오 앱에서 발급되는 별개 값):
  - **앱 ID (숫자)**: 백엔드 `tenk.auth.kakao.app-id`. `access_token_info` 응답의 `app_id`와 매칭 검증용. REST API 키 아님.
  - **네이티브 앱 키 (영숫자)**: Flutter 측에서만 사용. **세 곳에 같은 값을 박는다**:
    1. [tenk_app/lib/config/kakao_config.dart](tenk_app/lib/config/kakao_config.dart) — `kakaoNativeAppKey` 상수 (KakaoSdk.init)
    2. [tenk_app/android/app/build.gradle.kts](tenk_app/android/app/build.gradle.kts) — `manifestPlaceholders["kakaoNativeAppKey"]` (URL scheme 주입)
    3. [tenk_app/ios/Runner/Info.plist](tenk_app/ios/Runner/Info.plist) — `CFBundleURLSchemes`의 `kakao{KEY}` (iOS URL scheme)
- **인증 요청**: 클라이언트가 `Authorization: Bearer <AT>` 헤더 부착. `JwtAuthenticationFilter`가 파싱 → `JwtPrincipal(userId)`를 `SecurityContext`에 주입.
- **토큰 갱신**: `POST /api/auth/refresh { refreshToken }`. 사용된 RT는 즉시 `revoked=true`로 회전(rotation) 후 새 AT/RT 발급.
- **로그아웃**: `POST /api/auth/logout` (AT 필요) → 해당 사용자의 모든 RT를 `revoked=true`. AT 자체는 만료 시까지 유효 (블랙리스트 없음). 회원 탈퇴 시에도 동일하게 RT 일괄 무효화.
- **CORS**: **비활성화** (`SecurityConfig`에서 `cors.disable()`). Flutter 네이티브 앱(iOS/Android)만 호출하므로 브라우저 preflight 자체가 없음. 추후 Flutter Web 등 브라우저 클라이언트를 도입하면 `CorsConfigurationSource` 빈으로 origin/method/header를 명시 설정할 것.
- **필수 동의 (이용약관 + 개인정보 수집·이용)**: 출시 기준 정석 동의 플로우. `user.terms_agreed_dt` / `privacy_agreed_dt` DATETIME NULL 두 컬럼에 최초 동의 시각 기록 ([User.agreeToRequiredConsents](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) — 미동의 항목만 스탬프, 이미 동의한 시각은 보존). `hasAgreedToRequiredConsents()` = 둘 다 non-null. **미동의면 `consentRequired=true`** 를 `UserResponse` + `AuthTokens`(로그인 응답) 양쪽에 노출 → 클라가 동의 화면으로 게이트.
  - **동의 기록 엔드포인트**: `POST /api/users/me/consent` ([UserController](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserController.java) → `UserService.agreeConsents`). 두 필수 항목을 모두 체크한 뒤 호출, 미동의 항목만 now() 스탬프. body 없음 — 필수성은 클라 버튼 비활성으로 강제.
  - **클라 게이트 3분기** (로그인 직후 [LoginScreen](tenk_app/lib/presentation/login/login_screen.dart) + 앱 시작 [SessionGate](tenk_app/lib/app/session_gate.dart)): 신규 가입(`isNewUser`) → [ConsentGateScreen](tenk_app/lib/presentation/legal/consent_gate_screen.dart)(동의) → **동의 후** [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart)(닉네임 설정) / 기존 미동의(`consentRequired`) → ConsentGateScreen → 홈 / 그 외 → 홈. **동의 화면과 닉네임 설정 화면은 분리** — ConsentGateScreen 의 `next` 파라미터가 다음 화면을 결정(신규=닉네임, 기존=홈 기본값). **저장된 세션도 동의 보장 없음**(동의 화면 이탈·기능 도입 전 가입자) → SessionGate 가 `/api/users/me` 로 1회 확인, 네트워크 실패 시 fail-open(홈 진입, 다음 실행 재확인).
  - ConsentGateScreen 이 공용 위젯 [ConsentSection](tenk_app/lib/presentation/legal/consent_section.dart) (전체 동의 + 이용약관/개인정보 필수 2항목 + 각 [보기]) 으로 동의를 수집한다(back/swipe 차단, 동의 or 로그아웃만). Tenk 은 마케팅·푸시가 없어 **선택 동의 항목은 두지 않음**.
  - **문서 2종**: [privacy.html](tenk-backend/src/main/resources/static/privacy.html) + [terms.html](tenk-backend/src/main/resources/static/terms.html) 을 백엔드 static 서빙(SecurityConfig PERMIT_ALL). 클라는 `url_launcher` 로 외부 브라우저 오픈 ([legal_config.dart](tenk_app/lib/config/legal_config.dart) 의 `termsUrl`/`privacyPolicyUrl` = `https://tenk.hjson248.com/{terms,privacy}.html`). **노출 3지점** (상시 접근 = PIPA 고지 의무): ① 로그인 화면 하단 푸터(로그인 전) ② 동의 화면 [보기](가입·동의 순간) ③ '내 정보' → 법적 고지([LegalNoticeScreen](tenk_app/lib/presentation/legal/legal_notice_screen.dart))(로그인 후 상시). 셋 다 `openLegalDoc` 헬퍼 공유 — 새 링크 지점도 이걸 쓸 것.
  - **내부 테스터(TESTER)도 일반 카카오 계정이라 동의 게이트를 정상적으로 탄다** — 예전 테스트 로그인의 auto-consent 는 제거됐다(테스트 로그인 자체가 사라짐). TESTER 승격은 동의·연령까지 마친 실계정을 DB 에서 올리는 것이라 게이트 우회가 아니다.
  - **약관 본문은 법률 검수 권장** (privacy.html 과 동일 방침). terms.html 은 초안.
- **연령 확인 (중립적 연령 심사)**: **만 14세 미만은 이용 불가** — terms.html 과 같은 기준. `user.birth_date DATE NULL` 에 생년월일을 기록하고, NULL 이면 `ageVerificationRequired=true` 를 `UserResponse` + `AuthTokens` 양쪽에 노출해 클라가 게이트한다. 판정은 **서버가 진실의 원천** ([UserService.verifyAge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserService.java) — `MINIMUM_AGE=14`, 하한 1900-01-01, 미래 거부).
  - **엔드포인트**: `POST /api/users/me/birth-date { birthDate: "yyyy-MM-dd" }`.
  - **만 14세 미만 → 계정 즉시 파기 + `USER_UNDER_MINIMUM_AGE`(U0006, 403)**. 거부만 하면 카카오 로그인 때 이미 만들어진 이메일·닉네임이 서버에 남기 때문. 파기는 [WithdrawnUserPurgeService.purgeImmediately](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) — **`REQUIRES_NEW` 필수**. 호출자가 곧바로 예외를 던져 자기 트랜잭션을 롤백하므로 같은 트랜잭션에서 지우면 계정이 되살아난다.
  - **게이트 순서는 연령 → 동의 → (신규)닉네임 → 홈.** 게이트를 안쪽부터 감싸는 방식으로 배선한다 ([LoginScreen](tenk_app/lib/presentation/login/login_screen.dart) / [SessionGate](tenk_app/lib/app/session_gate.dart) 동일 패턴). 연령·동의·닉네임은 **각각 별도 화면** — 하나에 몰아넣지 말 것.
  - **[AgeGateScreen](tenk_app/lib/presentation/legal/age_gate_screen.dart) 의 중립성 설계는 정책 요건이라 바꾸지 말 것**: ① 입력 **전에 컷오프(만 14세)를 알려주지 않는다**(역산 입력 유도가 됨) ② 기본값·초기 선택값 없음(DatePicker 대신 빈 입력칸 3개) ③ back/swipe 차단, 확인 또는 로그아웃만.
  - **왜 필요한가**: Play 타겟 연령대에 13~15세가 포함되어 **가족 정책(Families Policy)** 대상이기 때문. 카카오는 이 역할을 대신해줄 수 없다 — 로그인 단계 미성년 차단은 **카카오싱크(비즈앱+검수)** 기능이고, `birthyear` 동의항목도 별도 심사가 필요한 데다 판정은 결국 우리 몫. 근거·대안 검토는 [docs/play-console-app-content.md](docs/play-console-app-content.md) §5.
  - 내부 테스터(TESTER)도 일반 카카오 계정이라 연령 게이트를 정상적으로 탄다(예전 테스트 로그인의 auto-verify 는 제거됨).
- **성별 (선택 수집)**: `user.gender VARCHAR(10) NULL` (`MALE`/`FEMALE`/`OTHER`, [Gender](tenk-backend/src/main/java/com/hjson/tenk/domain/user/Gender.java)). **NULL(미입력)이 정상 상태이고 서비스 기능은 이 값을 전혀 쓰지 않는다** — 수집 목적은 이용자 통계뿐. `PATCH /api/users/me/gender { gender }`, **`gender: null` 이면 미입력으로 되돌린다(수집 철회 — 이 경로를 막지 말 것)**.
  - **가입 흐름에 넣지 말 것.** '내 정보' 화면([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart))에서 사용자가 원할 때만 입력한다. 다이얼로그는 ① 수집 목적을 그 자리에서 고지하고 ② '입력 안 함' 을 동등한 선택지로 노출한다. **필수로 바꾸거나 온보딩으로 옮기면 개인정보 최소수집 원칙(PIPA)에 걸린다** — 기능에 안 쓰이는 항목이라 필수 수집을 정당화할 근거가 없다.
  - 연령대 통계는 `birth_date` 로 이미 산출 가능하므로 통계 목적으로 항목을 더 늘리지 말 것.
  - Play 데이터 안전에서 이 항목만 목적이 **'분석'** 이다(나머지는 '앱 기능'). [play-console-app-content.md](docs/play-console-app-content.md) §6-2 참고.
- **탈퇴 사유 (선택 수집, 익명)**: 사유 1문항을 **선택으로** 받아 [withdrawal_feedback](docs/schema.sql) 에 기록한다 (`DELETE /api/users/me { reason?, detail? }` — body 를 생략해도 탈퇴된다).
  - **순서: 계정 설정 → 확인 다이얼로그(의사 확정) → [WithdrawScreen](tenk_app/lib/presentation/profile/withdraw_screen.dart)(사유) → 탈퇴 처리.** 확인을 먼저 받는 게 핵심이다 — 아직 마음을 못 정한 사람에게 설문부터 들이밀면 설문이 만류 장치처럼 읽히고 답도 부정확해진다(업계 통례도 "취소 의사 확정 후 마이크로 설문"). **순서를 뒤집지 말 것.** 확인은 다이얼로그 한 번뿐이고 사유 화면에서 또 묻지 않는다.
  - 사유 화면은 경고를 반복하지 않고 **감사 + 아쉬움 + 부탁** 으로 연다(이미 확정한 사람이라). '계속 이용하기' 같은 **만류 버튼을 나란히 두지 말 것** — 두 버튼이 경쟁하면 어느 쪽이 진행인지 헷갈린다(국내 앱들의 대표적 실패 사례). 되돌리려면 뒤로 가면 된다.
  - **`user_id` 를 두지 않는 게 이 테이블의 핵심이다.** 계정과 연결하지 않으면 개인정보가 아니라 **익명정보**라서 ① privacy.html 수집표에 항목을 안 늘려도 되고 ② 보관 기간 논쟁 없이 계속 보존하며 ③ **계정 파기 후에도 통계가 남는다**. **여기에 user 참조·식별 가능한 값을 추가하지 말 것** — 그 순간 셋 다 무너진다. 계정 파기 배치의 삭제 대상도 아니다.
  - **사유를 필수로 만들지 말 것.** 탈퇴가 가입보다 어려워지면 안 된다. 그래서 '건너뛰기' 버튼도 따로 두지 않는다 — 아무것도 안 고르고 '탈퇴하기' 를 누르는 게 곧 건너뛰기고, 버튼을 하나 더 두면 무엇을 눌러야 넘어가는지가 되레 헷갈린다.
  - 사유 코드는 **서버 enum [WithdrawalReason](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawalReason.java) 이 진실의 원천**, 표시 문구는 클라 `_reasons` 목록 (지출 카테고리와 같은 방식). 항목을 바꾸면 양쪽을 같은 코드로 동시에 갱신하고, **이미 쌓인 상수는 지우거나 이름을 바꾸지 말 것**.
  - 자유 서술(`detail`)은 **'기타' 를 고른 경우에만** 저장한다(엔티티가 다른 사유면 버린다). 200자 제한이고 초과분은 잘라 담는다 — 탈퇴 자체가 길이 때문에 실패하면 안 되므로.
  - **화면 문구 구성은 [감사] → [사유 요청 + 개선 약속] → [선택지]** (국내 앱 7종 조사 결과, 근거는 [decisions.md](docs/decisions.md) "탈퇴 UX 회의"). 해요체 + 겸양(감사드려요 / 알려주시면 / 보답할게요)으로 정중함을 올리고, **"답하지 않으셔도 괜찮아요" 한 문장이 선택임을 알리는 유일한 장치**다 — 라벨의 `(선택)` 표기나 별도 건너뛰기 버튼 대신 쓰는 것이라 지우지 말 것.
  - **선택지 라벨은 해요체 문장으로 어미까지 통일**('기타'만 관례대로 명사). 명사형과 문장형이 섞이면 훑어보기 어려워진다. 현재 7종 = 사용 불편 / 기능 없음 / 흥미 없음 / 오류 / 목표 달성 / 다른 앱 사용 / 기타. **늘릴 땐 뺄 것을 같이 정할 것** — 선택지가 많을수록 고르는 시간이 늘고, 9개는 과하다는 게 사례들의 공통 결론이다.
  - **`GOAL_ACHIEVED`(목표를 이뤘어요)는 부정적 이탈이 아니라 '졸업'** 이다. 지표를 볼 때 다른 사유와 같이 세면 이탈률이 왜곡되니 따로 분리할 것.
  - 회귀 가드는 [WithdrawalFeedbackIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawalFeedbackIntegrationTest.java) 4건 — 특히 **컬럼 목록 검사(익명성)** 와 **계정 파기 후 생존**.
- **탈퇴 후 유예 기간(1개월) 안에 돌아오면 — 철회 / 재가입을 사용자가 고른다**: 탈퇴 계정으로 카카오 로그인하면 막지 않고 **무엇을 원하는지 묻는다**. 돌아온 사람은 *기록을 되찾으러 온 사람* 과 *리셋하러 온 사람* 으로 갈리고, 어느 한쪽을 강요하면 나머지 절반에게는 서비스가 방해가 된다.
  - **유예 기간이 끝날 때까지 재가입을 막는 흐름은 만들지 말 것 (핵심 원칙).** "새로 시작하기" 는 옛 계정을 **그 자리에서 파기**하고 곧바로 새 계정을 만든다 — 기다리게 하지 않는다. 회귀 가드는 [AuthWithdrawalReturnIntegrationTest.loginAfterRejoinUsesTheNewAccount](tenk-backend/src/test/java/com/hjson/tenk/domain/auth/AuthWithdrawalReturnIntegrationTest.java).
  - **판정 기준은 계정 row 의 생존 하나뿐** — 유예 1개월이 지났어도 새벽 파기 배치가 아직 안 돌았으면 두 갈래 다 허용한다 ([AuthService](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java)). 배치 타이밍에 따라 경험이 갈리지 않게 하려는 것이고 어긋나는 폭은 최대 하루다. **여기에 보관 기간 체크를 다시 넣지 말 것.**
  - **흐름**: `POST /api/auth/kakao/login` 이 `USER_WITHDRAWAL_RESTORABLE`(U0007) 로 거부 → 클라가 선택 다이얼로그 → 두 엔드포인트 중 하나 (둘 다 PERMIT_ALL, **카카오 토큰 재검증**):
    - **철회** `POST /api/auth/kakao/restore` → `User.restoreFromWithdrawal()` 로 `is_deleted`/`deleted_dt` 해제 후 그대로 토큰 발급. `isNewUser=false` + 보존된 동의·연령 플래그라 이미 마친 게이트를 다시 타지 않는다.
    - **재가입** `POST /api/auth/kakao/rejoin` → `purgeImmediately(옛 userId)`(**`REQUIRES_NEW` — 파기가 먼저 커밋돼야 같은 `(provider, provider_user_id)` unique 로 새 계정 insert 가 된다**) → 신규 프로비저닝 → `isNewUser=true` 라 연령→동의→닉네임 온보딩을 전부 다시 탄다.
  - **철회는 데이터를 한 톨도 건드리지 않고, 재가입은 한 톨도 남기지 않는다** — 각각 `restore` 에 초기화 로직, `rejoin` 에 데이터 이관 로직을 넣지 말 것. 중간 상태가 가장 헷갈린다.
  - **선택 다이얼로그 문구는 버튼 라벨에 기대지 말 것.** 탈퇴한 사람에게 "이어서 쓰기" 만 보여주면 *탈퇴했는데 뭘 이어서 쓴다는 거지?* 로 읽힌다. 본문 한 문단에서 **철회 = 이전 기록 그대로 / 새로 시작 = 이전 기록 전부 삭제** 를 둘 다 밝힌다.
  - **버튼은 한 줄에 3개** (`취소` / `새로 시작` / `탈퇴 철회`). 테마 기본 버튼 스타일(15px w800 + 좌우 패딩 20)로는 좁은 기기에서 폭이 모자라 Material 이 세로로 접으므로, `Row` + `Expanded` **2:3:3** 에 `_dialogActionStyle`(14px + 패딩 6)을 씌워 고정한다. 라벨을 길게 바꾸면 다시 접히니 주의.
  - **재가입에 2차 확인을 두지 않는다** (한 번 넣었다가 뺐다). 본문이 이미 "이전 기록을 모두 삭제한 뒤" 라고 말하고 같은 다이얼로그에 취소가 있어 오탭을 되돌릴 자리가 이미 있다. 대신 **`새로 시작` 은 danger 색**으로 파괴적 선택임을 표시한다. 철회는 잃는 게 없어 확인 없이 바로.
  - `USER_ALREADY_WITHDRAWN`(U0002) 은 **`refresh` 경로 전용**으로 남았다 (RT 로 들어오는 요청은 선택 UI 를 띄울 맥락이 아님). 클라 트리거는 U0007 하나.
  - **탈퇴 진입점은 [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart) 의 일반 `ListTile` 이고, danger 색을 쓰지 않는다.** 빨간 아이콘 + 빨간 텍스트는 상시 노출되는 목록에서 가장 눈에 띄어 로그아웃보다 도드라졌다 — **경고색은 확인 다이얼로그의 '탈퇴' 버튼에만.** 반대로 **위치를 더 깊게 넣거나 링크로 축소하거나 확인 단계를 늘리지 말 것** — Play 데이터 삭제 정책이 앱 내 삭제 경로를 쉽게 찾을 수 있어야 한다고 요구하고, 탈퇴가 가입보다 어려우면 안 된다(현재 홈에서 3탭이 한계선). 작은 밑줄 링크로 바꿔봤다가 **목록 안에서 형태만 튀어 되돌렸다** — 색을 빼는 것으로 충분하다.
  - **탈퇴 확인 다이얼로그에는 철회 가능성을 적지 않는다 (의도)** — 탈퇴를 결심한 사람에게 "되돌릴 수 있어요" 는 결정을 흐리는 잡음이다. 실제로 돌아왔을 때 로그인 화면에서 안내하면 충분. 단 **"영구히 삭제되고 복구할 수 없어요" 로도 되돌리지 말 것** — 철회 흐름이 생긴 뒤로는 사실이 아니다. 현재 문구는 "더 이상 볼 수 없고, 일정 기간이 지나면 완전히 삭제돼요"(참이면서 철회를 광고하지 않음). **구성은 제목 없이 설명 → 질문("정말 탈퇴하시겠어요?")이 이어지는 한 문단** — 제목으로 먼저 물으면 답을 정한 뒤에 근거를 읽게 된다. 순서를 뒤집거나 질문에 크기·굵기·색으로 강조를 주지 말 것(문장이 끊겨 보인다). 왼쪽 정렬 + `AppTypo.body` 단일 스타일.
  - **법적 고지 문서 2곳은 반대로 두 갈래를 명시한다** — [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §3 / [delete-account.html](tenk-backend/src/main/resources/static/delete-account.html). 보관 기간 중 처리 방식을 사실대로 적어야 하는 문서라 UI 카피와 기준이 다르다 (여기서 철회·재가입 문단을 빼지 말 것).
  - **보관 목적은 "탈퇴 철회 대응" 하나로 적는다.** 예전의 "부정 이용 방지 및 문의 대응" 으로 되돌리지 말 것 — Tenk 은 결제·보상이 없어 어뷰징 유인이 없고, 그 목적이면 개인정보 최소보유 원칙상 근거가 약하다. **탈퇴 통계를 위해 원본을 남기는 방안도 기각**했다(가명정보라 여전히 개인정보 + 영상·자유 텍스트는 익명화 불가). 근거는 [decisions.md](docs/decisions.md) "탈퇴 UX 회의".
- **계정·데이터 삭제 안내 페이지**: [delete-account.html](tenk-backend/src/main/resources/static/delete-account.html) → `https://tenk.hjson248.com/delete-account.html` (SecurityConfig PERMIT_ALL). **Google 계정 삭제 정책이 "앱 밖에서도 삭제를 요청할 수 있는 URL"을 요구**하므로 앱 내 탈퇴만으로는 부족하다. 보관 기간(1개월)은 privacy.html §3 · `WithdrawnUserPurgeService.RETENTION` 과 항상 같은 값이어야 한다.

### 닉네임
- **신규 가입 시 닉네임 설정 화면 필수**. 카카오 첫 로그인 응답의 `isNewUser=true` 면 클라이언트는 [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 으로 분기. 카카오 닉네임 pre-fill, 그대로 두든 수정하든 '시작하기' 눌러야 ChallengeListScreen 진입. **back/swipe 차단** (`PopScope canPop=false`). 사유: 카카오 로그인이 끝나면 user 는 이미 백엔드에 만들어진 상태고, 닉네임만 확정하면 본 화면 진입 가능 — 뒤로 보낼 곳이 없다.
- **카카오 재로그인 시 닉네임 갱신하지 않음**. [AuthService.provisionUser](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java) 의 기존 사용자 분기는 `updateEmail` 만 호출, `changeNickname` 호출 안 함. 사용자가 '내 정보' 에서 변경한 닉네임이 다음 카카오 재로그인 한 번에 카카오 프로필 닉네임으로 덮어쓰이는 회귀를 막는다. 신규 사용자 생성 시에만 `User.create` 가 카카오 닉네임을 박는다.
- **24시간 1회 변경 제한** (2026-07-26: "다음 날 자정" → 정확히 24시간으로 변경). `User.nickname_changed_dt DATETIME NULL` 컬럼에 마지막 직접 변경 시각 기록. null = 한 번도 변경 안 함 → 무조건 통과. non-null 이면 `now >= nickname_changed_dt + 24h` 일 때만 통과 (`UserService.NICKNAME_CHANGE_COOLDOWN`). 위반 시 `USER_NICKNAME_CHANGE_TOO_FREQUENT`. **날짜/자정 기준으로 되돌리지 말 것** — 앱 안내문("변경 후 24시간 동안은 다시 변경할 수 없어요")과 어긋나고, 밤 11시에 바꾸면 1시간 뒤 다시 바뀌던 구멍이 생긴다. **신규 가입 화면의 닉네임 확정도 1회로 카운트.** 단, **값이 기존과 같으면 멱등 no-op** 처리 → 가입 화면에서 카카오 닉네임 그대로 두고 '확인' 누른 경우 nickname_changed_dt 박지 않음 → 곧바로 1회 자유 변경 가능. `UserResponse.nicknameChangeAvailableFrom` = `nickname_changed_dt + 24h` (null = 즉시 가능) — **`UserService` 와 `UserResponse` 양쪽에 같은 24h 상수가 있으니 바꿀 땐 둘 다.**
  - **안내 노출 지점은 "잠긴 상태에서 탭했을 때" 하나뿐** ([MyInfoScreen](tenk_app/lib/presentation/profile/my_info_screen.dart) 의 SnackBar → `nextNicknameChangeMessage`). 닉네임 행에는 `lock_outline` 아이콘만 두고 **날짜 안내 라벨을 상시 노출하지 않는다** (2026-07-26 결정 — 평소엔 잡음이고 필요한 순간에만 알려주면 충분).
  - **문구 형식: `닉네임은 24시간에 한 번만 바꿀 수 있어요. 내일 오후 10시 11분부터 가능해요.`** — ① 규칙 먼저 ② 가능 시점은 짧게 ③ 날짜는 절대 표기 대신 **now 기준 오늘/내일 라벨**(쿨다운이 정확히 24h 라 변경 직후엔 늘 '내일', 다음 날 열면 '오늘') ④ 시각은 오전/오후 + 분(정각이면 분 생략). **연도·"다시"·"이후에" 같은 잡초를 다시 넣지 말 것** — 사용자가 뺄셈하지 않게 하는 게 목적이고, 근거는 [decisions.md](docs/decisions.md) "닉네임 쿨다운 안내 문구" 참고.
- **닉네임 보안 검증** (서버가 진실의 원천). `UserService.updateNickname` 에서 trim 후:
  - 길이: 1~50자. 초과/blank 시 `USER_NICKNAME_INVALID`
  - 거부 문자: `\p{Cc}` (제어 문자 — null byte, 줄바꿈, 백스페이스 등) + `\p{Cf}` (형식 문자 — zero-width space/joiner, BiDi override, BOM, word joiner 등). 표시 위장·로그 인젝션·방향 뒤집기 차단. 일반 이모지/한글/특수문자는 통과
  - SQL 인젝션은 JPA prepared statement 로 자동 방어, XSS 는 Flutter Text 위젯이 raw 렌더링하므로 위험 없음
  - 클라이언트도 같은 패턴 `RegExp(r'[\p{Cc}\p{Cf}]', unicode: true)` 으로 1차 검증 (즉시 피드백 — [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) / [my_info_screen.dart](tenk_app/lib/presentation/profile/my_info_screen.dart) 의 `_NicknameEditDialog`). 진실의 원천은 서버
- **메뉴 화면** ([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart)) — 챌린지 리스트 AppBar 의 `account_circle_outlined` 버튼에서 진입. **자체 콘텐츠 없이 하위 화면으로만 분기하는 순수 메뉴**: **내 정보**(→ [MyInfoScreen](tenk_app/lib/presentation/profile/my_info_screen.dart): 닉네임·성별) → **계정 설정**(→ [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart): 연동 계정·로그아웃·회원 탈퇴) → **법적 고지**(→ [LegalNoticeScreen](tenk_app/lib/presentation/legal/legal_notice_screen.dart): 이용약관·개인정보처리방침) → 테스트 재생성(dev). **전부 별도 하위 화면으로 push**(섹션 아님). 로그아웃·회원 탈퇴 로직은 AccountSettingsScreen 소유(연동 계정 = 공급자 표시. 메뉴가 로드한 User 를 넘겨 재fetch 없음).
  - **경계**: '내 정보' = **사용자 본인에 대한 정보**(닉네임·성별), '계정 설정' = **계정 자체**(연동·로그인·탈퇴). 새 항목은 이 기준으로 배치할 것.
  - **메뉴는 `/api/users/me` 를 기다리지 않고 즉시 렌더한다** (2026-07-26). 순수 내비게이션 허브라 user 없이도 그릴 수 있고, `user` 는 **TESTER 타일 노출 판정 + 계정 설정에 넘길 값**에만 쓰인다. 그래서 `AsyncStateMixin`/`AsyncStateView` 로 감싸지 않고 `User? _user` 를 직접 든다(컨벤션의 "두 종류 이상의 비동기 자원" 케이스 — 앱 버전 타일이 이미 두 번째 자원). **`/me` 실패해도 ErrorView 로 덮지 말 것** — 오프라인에서 법적 고지·앱 버전조차 못 여는 게 로딩보다 나쁘다. 같은 이유로 [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart) 의 `user` 는 **nullable** 이고 null 이면 스스로 읽는다(메뉴가 아직 못 받았을 수 있으므로). 메뉴가 값을 갖고 있으면 그대로 넘겨 재fetch 없음.
  - MyInfoScreen 의 닉네임 행은 변경 불가 상태면 **`lock_outline` 아이콘만** 노출하고, 다시 가능해지는 시각은 **탭했을 때 SnackBar 로만** 알려준다 (상시 라벨 없음 — 위 닉네임 정책 참고). 메뉴로 돌아오면 `reload()` 로 갱신(닉네임 변경분이 '계정 설정'에 넘길 User 에도 반영되게).
  - **메뉴 화면 제목 = '메뉴', 진입 아이콘 = `Icons.menu`(햄버거) 로 확정 (2026-07-25).** 이 허브는 설정(preference) 모음이 아니라 내 정보·계정·법적 고지·앱 정보 등 **이질적 항목을 모아 분기하는 메뉴**라서 '설정'이 아니다. **소리·진동 같은 설정성 항목이 생기면 최상위에 토글을 두지 말고 '알림/효과 설정' 하위 화면을 새로 추가**할 것 (설정은 최상위 이름이 아니라 필요 시 하위 화면 이름으로 들어온다).
- **회원 탈퇴 = soft delete 후 1개월 유예 → hard delete**. 탈퇴 즉시 [User.withdraw](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) 로 `is_deleted=true` + `deleted_dt` 기록 + 모든 RT 무효화. 이후 매일 새벽 1:30 배치 [UserRetentionScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java) 가 `deleted_dt` 로부터 **1개월(`WithdrawnUserPurgeService.RETENTION`) 지난 계정**을 물리 삭제 — challenge/amount/media_file row + **디스크 영상 파일** + refresh_token 까지 cascade ([WithdrawnUserPurgeService.purge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java), FK 안전 순서: 디스크→media_file→challenge_badge→amount→challenge→refresh_token→user). 유저 1명 단위 트랜잭션 — 스케줄러가 유저별로 외부 호출해 `@Transactional` 프록시를 살린다(self-invocation 금지). 보관 기간(1개월)은 개인정보처리방침 §3 과 일치시킬 것. **개인정보처리방침**은 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) → `https://tenk.hjson248.com/privacy.html` 로 서빙 (SecurityConfig PERMIT_ALL 등록). Play Console 개인정보처리방침 URL·앱 내 링크가 이 주소를 가리킨다.

### 영상
- 짧은 2초 영상은 **클라이언트가 처음부터 짧게·가볍게 녹화**하는 방식 (사후 변환·트랜스코딩 아님). Flutter 기준 `camera` 패키지의 `ResolutionPreset.medium` + 2초 타이머로 처리. 백엔드는 업로드받은 파일을 그대로 저장. export 가 480x864 로 정규화하므로 medium 위로 올릴 이유 없음 (파일만 커짐).
- **영상은 지출/무지출 양쪽 모두 선택**. 백엔드는 영상 part 가 없거나 빈 multipart 면 그대로 통과 (`AmountService.record`/`update`). 영상이 첨부된 경우에만 `MediaFile` 행을 만든다.
- **촬영 화면은 별도** ([AmountCameraScreen](tenk_app/lib/presentation/amount/amount_camera_screen.dart)). 기록 화면(record/edit)은 [VideoAttachmentSection](tenk_app/lib/presentation/amount/widgets/video_attachment_section.dart) 으로 영상 첨부 상태만 보여주고, 실제 카메라 프리뷰·녹화는 카메라 화면에서만 한다. 사유: 카메라 초기화가 실패해도 폼 입력은 진행 가능해야 하고, 화면 한 곳에 너무 많은 것을 띄우지 않기 위해.
- **카메라 컨트롤**: 플래시(`FlashMode.torch` — 영상이라 지속 점등, `auto`/`always` 는 정지 사진용이라 무의미) / 셀카 전환 / 핀치 줌 / 탭 초점 모두 **녹화 시작 전에만 조정 가능, 녹화 중엔 전부 잠금** (탭 초점 포함). 사유: 2초 영상이라 녹화 중 조작이 결과에 노이즈만 됨 — 시작 전 셋업하고 그대로 찍는 흐름이 깔끔. 핀치 줌은 1손가락 팬이 탭 초점과 충돌하므로 `details.pointerCount >= 2` 일 때만 적용. 플래시 버튼은 후면 카메라일 때만 노출 (전면은 보통 플래시 미지원). 카메라 전환 시 `_flashMode` 는 off 로 reset.
- **줌 preset 버튼 (iOS 카메라 스타일)**: 프리뷰 하단 중앙에 배율 preset row (1x 기본, 디바이스가 ultra-wide 지원하면 minZoom 을 앞에, maxZoom≥2 면 2x, maxZoom≥5 면 5x). 사유: 핀치 줌만 있으면 발견성이 낮아 사용자가 줌 기능이 있는지도 모름. preset 버튼은 익숙한 패턴이라 즉시 인지됨. 현재 zoom 과 ±0.15x 이내인 preset 이 active (흰 원 + 검은 글씨) 강조. 핀치로 preset 사이 값에 멈추면 어느 것도 active 가 아니고 row 위에 작은 chip 으로 실제 값(`1.5x`) 표시. preset 이 1개(=1x) 뿐인 디바이스는 row 자체를 안 그림. 녹화 중·준비 중엔 숨김.
- **프리뷰 종횡비 처리**: `CameraPreview` 를 그냥 Stack 자식으로 두면 `StackFit.expand` 가 내부 AspectRatio 를 무시하고 강제로 늘려서 세로로 길어 보임 (센서 landscape 를 portrait 박스에 stretch). cover-crop 패턴으로 감싸 종횡비 유지 + 박스 채움 — `FittedBox(BoxFit.cover) + SizedBox(width: previewSize.height, height: previewSize.width, child: CameraPreview)` (previewSize 는 센서 기준이라 portrait 표시용으로 width/height swap). 녹화 후 미리보기·서버 영상 미리보기도 같은 패턴 사용. `GestureDetector` 는 `Positioned.fill` 로 분리해 위에 얹어 탭 초점·핀치 줌은 그대로.
- **녹화 시작 흐름 (3단계)**: ① 화면 진입 직후 카메라 init → 곧바로 background 에서 dummy `startVideoRecording`→150ms→`stopVideoRecording`→파일 삭제로 MediaCodec/MediaMuxer 워밍업 (`_warmupEncoder`). 워밍업 중엔 시작 버튼 비활성화 (idle 모습 그대로 disabled). ② 사용자 탭 → `_starting=true` → **탭 즉시 효과음** (`AudioPlayer.resume()` 으로 `assets/sounds/record_start.mp3`, royalty-free) → `_startMorph.forward()` 단방향 0→1 morph 가 즉시 시작 → `await camera.startVideoRecording()` → **추가로 `_encoderStartLag`(1초) 더 대기**. 이 구간 UX = **transitional morph**: idle UI(큰 빨간 원 56px) → recording UI(작은 둥근 사각형 28px) 로 안쪽 모양이 부드럽게 변형 (0~12% anticipation 살짝 작아짐, 12~85% 본 morph, 85~100% snap = scale 1→1.15→1 sine bump). 프리뷰 자체는 vendor fork 패치로 freeze 안 됨. ③ `_recording=true` 전환 직전 듀얼 시그널: `HapticFeedback.heavyImpact()` + morph 의 snap 구간. 효과음은 ② 의 탭 즉시로 분리 — 사유: 효과음을 녹화 시작 시점에 두면 사용자 멘탈 모델로는 "녹화 중에 소리가 났다" 로 읽혀 어색 (enableAudio:false 라 영상 트랙엔 안 들어가지만 인지 모델이 그렇게 잡힘). 탭 즉시 효과음 = "버튼 인식" 신호, 햅틱+snap = "지금부터 녹화 시작" 신호로 역할 분리. 이후 progress arc + 2초 정지 타이머 시작. **사유**: CameraX 의 `startVideoRecording` future 가 실제 인코더 첫 프레임보다 먼저 resolve 되는 경우가 있어, future resolve 직후 바로 2초 타이머를 걸면 실제 캡처가 ~1초로 잘려나가는 회귀가 있었다 (Android 실기기 실측). `_encoderStartLag` 만큼 더 기다린 뒤 게이지를 시작해 캡처 길이를 안정적으로 2초에 맞춤. **트레이드오프**: 사용자가 탭한 순간은 캡처에 포함되지 않음 — 스피너 끝난 뒤 2초가 잡힘. 정확한 탭 순간 캡처가 필요하면 pre-roll + ffmpeg trim 방식이 필요한데 (대화에서 검토 후) 배터리·발열·후처리 비용 때문에 sync wait 로 결정.
- **프리뷰 freeze 제거 (camera 패키지 fork, Android)**: 업스트림은 VideoCapture UseCase 를 `startVideoCapturing` 시점에 lazy bind 하는데 이때 Camera2 capture session 이 재구성되며 프리뷰가 잠깐 freeze 됨. [vendor fork](tenk_app/vendor/camera_patched/camera_android_camerax/lib/src/android_camera_camerax.dart) 의 `initializeCamera` 에서 `ImageAnalysis` 자리에 `VideoCapture` 를 넣어 eager bind, `stopVideoRecording` 의 unbind 도 제거 — 두 군데 `[tenk fork patch]` 주석. Tenk 는 image stream 을 안 쓰므로 ImageAnalysis 는 첫 호출 시 lazy bind 되어도 무해. CameraX UseCase 조합 표 기준 P+IC+VC 는 LIMITED 이상에서 지원 (4-way 는 LEVEL_3 한정이라 회피). `pubspec.yaml` `dependency_overrides` 로 주입. 업스트림 버전 올릴 때 같은 두 지점에 재적용 필요.
- **시작 transition 의 UX 원칙**: 대기 구간엔 oscillating effect (라디오 링·글로우·pulse) 가 아니라 **idle UI 와 recording UI 를 잇는 단방향 모양 변화** 만 둠. 라디오 링·preview 빨간 글로우·심박 펄스는 한 번 시도했다가 제거 — "지금 뭐가 일어나고 있는지" 가 시각적으로 안 전달되고 정지 효과로 읽혔기 때문. 회귀하지 말 것 (`_RecordButton._morphShape` 의 3구간 piecewise + `Curves.easeInOutCubic` 가 정답). 사운드는 `SystemSound`/`HapticFeedback` 으로 우회하다가 실기기에서 안 들려서 `audioplayers` + royalty-free MP3 자산으로 정착.
- **촬영 직후 미리보기** (카메라 화면): 2초 녹화가 끝나면 같은 화면에서 `video_player` 로 영상을 자동 loop 재생 (탭으로 일시정지). "사용" 으로 확정하기 전에 결과 확인. 체크 아이콘 등 placeholder 가 아니라 실제 영상. 초기화 실패 시 체크 아이콘 + "미리보기를 불러올 수 없어요" 로 폴백 (저장 자체는 가능).
- **기존 영상 확인** (수정 화면): 영상이 있을 때 섹션은 collapsed — 메시지 + "영상 보기" 버튼만. 탭하면 [AmountVideoPreviewScreen](tenk_app/lib/presentation/amount/amount_video_preview_screen.dart) 이 새 화면으로 떠 영상 + "다시 촬영" / "삭제" 버튼. 액션은 `VideoPreviewAction` enum 으로 부모에게 반환되고 부모(edit 화면)가 실제 카메라 호출·REMOVE 마킹 처리. 사유: edit 진입 시점에는 사용자가 영상을 못 봤기 때문에 확인 단계가 필요한데, 폼 안 인라인 player 는 화면을 무겁게 만들고 retake/delete 를 영상과 함께 묶어 보여주기에는 별도 화면이 자연스러움. record 화면은 카메라 직후 이미 확인했으므로 기존 즉시 모드 유지 (`expandable: false`).
- **서버 영상 lazy 다운로드** (수정 화면 KEEP 상태): "영상 보기" 첫 탭에 `MediaApi.downloadToFile` 로 `{tmp}/tenk_edit_preview/{fileId}.mp4` 에 저장. 같은 세션에서 재탭 시 캐시 재사용, 화면 dispose 시 파일 삭제. 다운로드 전 같은 경로의 잔재 선삭제 + 다운로드 직후 `exists` + `size > 0` 검증으로 깨진 캐시(이전 호출의 partial write / 다른 핸들 점유) 차단 — 둘 다 `video_player` init 실패로 이어지는 케이스이고 진단이 어려워 사전에 막는 게 싸다.
- **Impeller 비활성화 (앱 전역, Android)**: [AndroidManifest.xml](tenk_app/android/app/src/main/AndroidManifest.xml) `<application>` 에 `io.flutter.embedding.android.EnableImpeller=false` meta-data 로 Skia 렌더 백엔드 강제. 사유: 삼성 실기기에서 `video_player` 외부 텍스처가 초당 10여 회 깜빡이는 Impeller 렌더 버그(디코더/컨트롤러는 정상, 텍스처 합성 단계만 깜빡임 — `flutter run` no-enable-impeller 플래그로 원인 확정). 같은 프로젝트의 Impeller 텍스트 깨짐 이슈와 같은 계열. **다시 켜지 말 것** — 업스트림에서 외부 텍스처 버그가 고쳐지면 제거 검토. 진단·함정 경로는 [docs/handoff.md](docs/handoff.md) "알려진 주의사항 — Flutter" 의 깜빡임 항목. (그 meta-data 주석에 `--` 이중 하이픈 넣지 말 것 — manifest merge 깨짐.)
- 저장소는 로컬 파일 시스템 (`tenk.upload.base-dir`, 기본 `./uploads`). `.gitignore`에 등록됨.
- **녹화 시 음성은 꺼둠** (`CameraController(enableAudio: false)`). 사유: `RECORD_AUDIO` 런타임 권한 프롬프트를 한 단계 줄이기 위해. 추후 음성이 필요해지면 매니페스트 `RECORD_AUDIO`는 이미 선언돼 있으니 코드에서 `enableAudio: true`로만 바꾸면 됨.
- **업로드 형식**: multipart/form-data로 `request`(application/json) + `video`(video/mp4) 2개 part. dio의 `MediaType`은 dio v5.7+에서 `DioMediaType`으로 재익스포트됨 — 따로 `http_parser`를 의존성에 추가하지 말 것.
- **영상 합본 내보내기 (구현 완료)**: 챌린지 확정 후 기록 영상들을 시간순으로 합쳐 1개 MP4 로 만드는 기능. 결정 사항·함정 모음은 [docs/decisions.md](docs/decisions.md) "영상 내보내기 회의록"(구현 시 주의사항에 인코더·drawtext 한글 함정 포함) 참고. 합성은 **클라이언트 측 `ffmpeg_kit_flutter_new_video`** (LGPL 'video' 변종) 로 처리 — 서버 부담 0. 자막 디폴트는 `amount.memo` → 없으면 지출="내용 금액원" / 무지출="무지출" 순으로 폴백. **인코더는 sw `mpeg4` 만 사용** — `h264_mediacodec` 은 silent fail, `libx264` 는 GPL 이라 빌드에 없음, `libkvazaar` 는 native crash. 자세한 경로 [video_composer.dart](tenk_app/lib/data/export/video_composer.dart) `_videoEncoder` 주석 참고.

### 챌린지
- 한 사용자가 **여러 챌린지 동시 진행 가능**.
- **이름(`name`, VARCHAR 100, NOT NULL)**: 목록에서 챌린지를 구분하는 사용자 정의 이름. **필수 — 비울 수 없다.** 생성 화면 진입 시 **클라이언트가 `챌린지 N` 기본값을 미리 채워**(N = 목록 개수 + 1, 삭제분 제외 — 서버 목록이 삭제분을 빼므로 `data.length + 1`, [challenge_list_screen `_openCreate`](tenk_app/lib/presentation/challenge/challenge_list_screen.dart)) 사용자가 그대로 쓰거나 수정한다. 삭제 후 재생성 시 N 중복 가능하나 자유 편집하는 기본값이라 허용. 서버는 빈값을 거부한다 (`ChallengeCreateRequest.name` `@NotBlank`, 2차 방어는 엔티티). 검증은 엔티티가 진실의 원천 (`Challenge.validateAndNormalizeName`): trim 후 1~100자, 제어/형식 문자(`\p{Cc}\p{Cf}`) 거부 — 닉네임과 동일 정책. 클라도 같은 패턴 + 빈값 거부로 1차 검증. **결과 확정 전(`result == null`)까지 변경 가능** — `PATCH /api/challenges/{id}` ([ChallengeService.rename](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeService.java), 확정 후엔 `CHALLENGE_ALREADY_FINISHED`). 결과 카드 헤더에도 이름이 출력된다 (아래 "결과 카드" 참고).
- 기간 표현: `start_date` / `end_date` **DATE (양끝 포함)**. 시각 정보 없음. (`Challenge.startDate` / `endDate`)
- 검증 (`Challenge.validatePeriod`): ① `startDate >= today` (오늘 이후만 시작) ② `endDate >= startDate` ③ inclusive 일수 ≤ `MAX_DURATION_DAYS = 30`.
- 상태:
  - **시작 전**: `today < startDate` — 기록 불가
  - **진행 중**: `startDate <= today <= endDate` and `result == null` — 기록 가능
  - **결과 확정 대기**: `today > endDate` and `result == null` — `finalize` 호출 가능. **이 상태에서도 기존 기록 수정은 가능** (아래 amount "수정" 참고) — 마지막 날 밤늦게 남긴 기록의 영상/내용을 확정 전까지 보완할 수 있게.
  - **성공/실패**: `result` 설정됨
- 상태 판별 메서드: `isStarted(today)`, `isFinished(today)`, `containsDate(date)`. `ChallengeResponse`는 `started`/`finished` 둘 다 노출.
- 종료 시점에 `result` 컬럼 확정: `SUCCESS`(총지출 ≤ target_amount) / `FAIL`. `NULL`이면 진행 중.
- **확정 트리거는 사용자 수동 호출(`POST /api/challenges/{id}/finalize`) 단 하나.** 자동 확정 배치는 두지 않는다 — 종료 후 확정 전까지 기록을 보완할 수 있어야 하고, 확정은 사용자에게 페이오프 모먼트(배지 → 결과 카드)라 본인이 누르는 게 자연스럽다. 새벽 1시 배치(`BadgeScheduler.dailyReconciliation`)는 **배지 재평가(`evaluateAllActive`)만** 하고 확정은 하지 않는다.

### 지출(amount)
- **지출 기록**: `category`, `content` NOT BLANK, `amount > 0`, **영상 선택**. `spent_dt`는 클라이언트가 챌린지 기간 안의 임의 일시를 보낼 수 있다.
- **카테고리(`category`)**: **고정 9종 중 택1** (자유 텍스트 아님). "만원 챌린지 = 가볍고 잦은 소비" 주제에 맞춘 목록. `amount.category` 컬럼(VARCHAR)에는 **안정적인 코드**(`FOOD` 등 enum name)를 저장하고, **표시는 한글 라벨·Material 벡터 아이콘**으로 클라가 매핑한다 (라벨을 바꿔도 DB 마이그레이션 불필요). 아이콘은 색이 박히지 않은 `IconData` — 렌더 시점에 테마 색으로 칠하므로 추후 챌린지별 색 부여에도 자유롭게 대응.
  - 9종: `FOOD` 식비 / `TRANSPORT` 교통비 / `SHOPPING` 쇼핑 / `LEISURE` 여가 / `HEALTH` 건강 / `EDUCATION` 교육 / `EVENT` 경조사 / `LIVING` 생활비 / `ETC` 기타.
  - **진실의 원천 = 서버 enum** [SpendCategory](tenk-backend/src/main/java/com/hjson/tenk/domain/amount/SpendCategory.java) (코드+한글 label). `Amount.spend()/update()` 지출 분기가 `requireValidCode` 로 검증 → 9종 밖이면 `AMOUNT_CATEGORY_INVALID`(A0008). **엔티티 컬럼은 `@Enumerated` 가 아니라 String** — 검증 도입 이전에 저장된 자유 텍스트 row 를 읽을 때 enum 매핑 크래시가 안 나게(쓰기는 엄격, 읽기는 관대). 그래서 **schema.sql 변경 불필요**.
  - 클라 매핑은 [spend_category.dart](tenk_app/lib/presentation/amount/spend_category.dart) `kSpendCategories` (code/label/icon) + `spendCategoryForCode()`(미매칭→기타 폴백)가 진실의 원천. 입력은 기록/수정 화면의 **`DropdownButtonFormField` 셀렉박스**(항목마다 아이콘+라벨, value=code. 폼 필드라 validator 로 미선택 검증), 표시는 상세 타일 leading 아이콘·타이틀 라벨 + export 목록 라벨. **카테고리 목록을 바꾸면 서버 enum + 클라 `kSpendCategories` 를 같은 코드로 동시 갱신** (아이콘도 함께). export JSON 통계의 `CategorySummary.category` 는 코드 그대로(외부 연동 안정 키).
  - **마이그레이션 주의**: 검증 이전 자유 텍스트 카테고리(예: "카페")로 저장된 기록은 표시상 '기타' 아이콘으로 폴백되고, 수정 저장 시 9종 중 재선택이 강제된다. `/dev/seed` 재시딩하면 전부 정상.
- **메모(`memo`, VARCHAR 500, NULL 허용)**: 지출/무지출 양쪽 모두 선택 입력. 사용자가 그 기록에 남기는 자유 텍스트. **UI 노출 라벨은 "한 줄 평"** (필드명·코드·이 문서의 도메인 규칙은 `memo` 로 유지 — 라벨만 사용자용). **빈 문자열/공백은 엔티티에서 null 로 정규화** (DTO 분기를 깔끔하게). 용도는 영상 export 자막 디폴트 오버라이드 — 메모 있으면 그 값, 없으면 지출="내용 금액원" / 무지출="무지출" 폴백.
- **무지출 기록**: `is_no_spend = true`, `amount = 0`, `category/content` NULL 허용, **영상 선택**. **제약 (도메인 정합성)**:
  - **일시 입력 불가** — 클라이언트가 보낸 `dateTime`은 서비스에서 무시되고 서버가 `LocalDateTime.now()`(분초까지)를 박는다. "오늘 하루 지출이 없다"는 행위만 의미 있으므로 과거/미래 무지출은 성립하지 않는다.
  - **하루 1회** — 같은 챌린지 + 같은 날에 두 번째 무지출 등록은 `AMOUNT_NO_SPEND_ALREADY_EXISTS`로 거부. 1차 방어선은 서비스 검증, 2차는 DB `uk_amount_no_spend_day` 생성 컬럼 UNIQUE 인덱스 ([docs/schema.sql](docs/schema.sql) `no_spend_day_key`).
  - **지출 등록 시 자동 삭제** — 같은 날 이미 무지출이 있는 상태에서 그 날에 지출이 등록되면, 무지출 row + 첨부 영상 파일까지 자동 삭제하고 `AmountRecordResult.removedNoSpendCount`로 클라이언트에 통지 (Flutter는 SnackBar로 "오늘 무지출 기록이 취소되었어요" 표기). 그 다음 `AmountRecordedEvent`가 발행돼 배지가 재평가된다.
- **수정** (`PUT /api/challenges/{cid}/amounts/{aid}`): **결과 확정 전(`result == null`)이면 가능** — 진행 중은 물론, 종료됐지만 아직 확정 안 한 "결과 확정 대기" 상태에서도 수정할 수 있다 (확정되면 `CHALLENGE_ALREADY_FINISHED`). 게이트는 `isFinished` 가 아니라 `challenge.getResult() != null` ([AmountService.update](tenk-backend/src/main/java/com/hjson/tenk/domain/amount/AmountService.java)). 카드 탭 → 수정 화면 진입. 영상은 `videoAction` 으로 KEEP/REMOVE/REPLACE 중 하나 (REPLACE 면 새 video part 필수).
  - **지출**: 카테고리/내용/금액/메모/**시간만** 변경 가능. **날짜는 고정** — 서버는 클라이언트 `time` (HH:mm:ss) 만 받아서 기존 spentDt 의 LocalDate 와 결합한다. 날짜를 바꾸고 싶으면 삭제 후 재등록.
  - **무지출**: memo + 영상만. 카테고리/내용/금액/시간은 서버가 무시.
  - 배지 재평가는 안 한다. 날짜·noSpend 여부가 그대로라 STREAK/NO_SPEND 가 바뀔 일이 없음. (영상만 바꾸는 케이스도 동일.)
- **일시 의미**:
  - `spent_dt` (DATETIME, NOT NULL): 지출일 때만 사용자가 고른 "지출이 발생한 일시". **날짜 부분**이 챌린지 기간(`startDate`~`endDate`, 양끝 포함) 안에 있어야 함 (`AMOUNT_DATE_OUT_OF_RANGE`). 기본값은 지금. 배지·집계는 `spentDt.toLocalDate()`를 기준으로 잡는다. 무지출은 위 제약대로 서버 now() 강제.
  - `created_dt` (DATETIME, JPA Auditing): 서버가 자동으로 박는 row 생성 시각. 감사용. 도메인 로직에서 직접 쓰지 않는다.
- **응답 형태**: `POST /api/challenges/{cid}/amounts` 는 `AmountRecordResult { amount, removedNoSpendCount }`. `PUT` 은 갱신된 `AmountResponse` 단일. list/delete 는 기존대로 `AmountResponse` 직접.
- **신규 기록**(`record`)은 챌린지가 시작 전(`CHALLENGE_NOT_STARTED`)이거나 종료된 상태(`today > endDate` → `CHALLENGE_ALREADY_FINISHED`)에서는 불가. **수정**(`update`)은 위 "수정" 항목대로 확정 전이면 종료 후에도 가능 — record 와 update 의 종료 판정 기준이 다르다(record=`isFinished`, update=`result != null`).

### 배지 (챌린지 단위)
배지는 **챌린지 1개에 귀속**된다. 같은 사용자가 챌린지 A 와 B 에서 똑같이 STREAK 7 을 얻으면
`challenge_badge` 행이 두 개 생긴다. 챌린지 응답(`ChallengeResponse.badges`)에 인라인으로 노출되며
별도 "내 배지" 화면은 없다. **유저 단위 누적(=업적, achievement) 시스템은 추후 별도 테이블로 추가 예정**
(현재 범위 밖).

- 단계: `condition_value` = **3 / 7 / 14 / 30** (CHALLENGE_SUCCESS 만 1).
- `STREAK`: **그 챌린지 안에서** 매일(지출 또는 무지출 무관) 기록한 **연속** 일수. 끊기면 의미가 퇴색되는 "꾸준함" 보상이라 연속 정의 유지.
- `NO_SPEND`: **그 챌린지 안에서** 기록이 무지출만 있는 날의 **누적** 일수. 끊겼다가 다시 무지출해도 합산된다 (절약 총량 보상). 같은 날 지출이 끼면 그 날은 카운트에서 빠진다. 챌린지 최대 30일이라 NO_SPEND 30 단계는 챌린지 모든 날이 무지출인 경우.
- `CHALLENGE_SUCCESS`: 챌린지가 성공으로 확정될 때 1회 지급.
- STREAK 끝나는 기준일: `min(today, challenge.endDate)`. 진행 중이면 today, 종료 후엔 endDate.
- **회수(revoke) 정책**: 재평가 시 현재 값이 조건 미달이면 이미 지급된 `challenge_badge` 도 DELETE. 예: 무지출 3일로 NO_SPEND 3 받은 뒤 그 중 하루에 지출이 추가돼 무지출 row 가 자동 삭제되면 → 누적 2일 → NO_SPEND 3 회수. `BadgeGrantService.applyLadder` 가 grant/revoke 양방향을 단일 패스로 처리.
- **지급 트리거 2종**:
  - 이벤트: `AmountRecordedEvent`(지출/무지출 기록 후 → 해당 챌린지 재평가), `ChallengeFinishedEvent`(챌린지 확정 후 → CHALLENGE_SUCCESS 지급 + 재평가) — `BadgeEventListener`가 `@TransactionalEventListener(AFTER_COMMIT)` + `@Transactional(REQUIRES_NEW)` 조합으로 처리. **REQUIRES_NEW가 필수**: AFTER_COMMIT 콜백 시점에는 원본 tx의 동기화가 정리 중이라 단순 REQUIRED 호출은 새 tx를 못 열고 쓰기가 조용히 사라진다 ([BadgeEventListener](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeEventListener.java) 주석 + [BadgeEventIntegrationTest.grantChallengeSuccessDirectCall vs challengeSuccessGrantsBadge](tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeEventIntegrationTest.java)).
  - 배치: 매일 새벽 1시 활성 챌린지 전체 재평가 (`evaluateAllActive`, 이벤트 누락 대비).
- 데이터 모델: [challenge_badge](docs/schema.sql) `(challenge_id, badge_id)` UNIQUE. 한 챌린지 안에서 같은 배지는 1번만.

### 내보내기
- **JSON 통계 export** (`GET /api/challenges/{id}/export`): 일별·카테고리별 집계 + 전체 item 목록. 통계·외부 연동용으로 유지. 화면 구성은 클라이언트 몫.
- **영상 합본 export (구현 완료)**: 챌린지 확정 후 기록 영상을 시간순으로 합쳐 1개 MP4 로 내보내는 기능. 클라이언트 측 `ffmpeg_kit_flutter_new_video` 로 처리. 진입은 챌린지 상세 화면의 "영상 만들기" 카드 (확정 후에만 노출). 파이프라인은 ① 원본 영상 prefetch → ② 클립 단위 정규화(480x864 세로, 2초, 자막 PNG overlay 합성, mpeg4) → ③ 0.3초 xfade 로 concat → ④ 갤러리 저장(`gal`) + OS 공유(`share_plus`). **자막은 Flutter `TextPainter` 로 투명 PNG 를 그려 ffmpeg `overlay` 필터로 합성** — ffmpeg 8.0 drawtext 가 multi-codepoint 한글에서 첫 글리프만 그리고 뒤를 silent drop 시키는 회귀가 있어 (`text=`/`textfile=`/`text_shaping=0`/폰트 교체 모두 무효) drawtext 자체를 우회. 자세한 결정·범위·진단 경로는 [docs/decisions.md](docs/decisions.md) "영상 내보내기 회의록" 및 "함정 — drawtext 한글 회귀". **결과 카드는 별도 도메인** — 아래 "결과 카드" 섹션 참고. export 화면 체크박스(기본 ON)로 영상 끝에 3초 정지 화면으로 합성 가능.
  - **export 흐름은 2화면**: ① [export_screen.dart](tenk_app/lib/presentation/challenge/export/export_screen.dart) 클립 선택 + 자막 편집 → "다음" ② [export_settings_screen.dart](tenk_app/lib/presentation/challenge/export/export_settings_screen.dart) 합성 설정(자막 위치/배경/결과 카드 포함) → "영상 만들기" 가 prefetch→compose→result 흐름 시작. 설정은 모두 **영상 전체 단위**(클립별 아님), 세션 한정.
  - **자막 위치·배경 설정** (설정 화면): 위치 SegmentedButton **중단/하단**(기본 하단 — 상단은 대시보드 Day N+잔여와 겹쳐 의도적 제외) + 배경 Switch. 배경 ON=반투명 박스(black@0.55)+흰 글자(외곽선 X, 기존 스타일), 배경 OFF=흰 글자+검은 외곽선(stroke 4px)+drop shadow(박스 X). [video_composer.dart](tenk_app/lib/data/export/video_composer.dart) `SubtitlePosition` enum + `_drawTextBlock(withBox/withOutline, centerY)`. 상단 대시보드는 항상 박스 유지(`withBox:true`) — 자막만 영향. 흐름은 `includeResultCard` 와 함께 `ExportSettingsScreen` state → `ExportComposeScreen` 생성자 → `compose()` 로 thread.

### 결과 카드 (구현 완료)
- **챌린지 결과를 1장 카드로** — 480x864 (9:16) 세로 PNG. 영상 export 와 무관하게 챌린지 확정 후 항상 표시. 진입점 **2개**: ① finalize 직후 자동 풀스크린 push (배지 모달 큐가 끝난 뒤) ② 챌린지 상세의 "결과 카드" 카드 (확정 후에만 노출). 영상 export 마지막에 **3초 정지 화면**으로도 포함 가능 (export 화면 체크박스, 기본 ON).
- **모달 충돌 정책**: finalize 직후엔 **배지 모달 → 결과 카드 풀스크린** 순차. 결과 카드 안에 획득 배지 row 가 있지만 배지 모달도 그대로 진행해 페이오프 계단을 만든다.
- **닉네임 노출**: "○○님의 만원 챌린지" — `/api/users/me` 로 fetch ([UserApi](tenk_app/lib/data/user/user_api.dart) / [UserScope](tenk_app/lib/app/scopes.dart)). fetch 실패하거나 미완 상태에서 캡처되면 헤더만 "만원 챌린지" 로 fallback. **영상 export 마지막 카드는 닉네임을 fetch 하지 않는다** — compose 시작 지연 회피 + 결과 카드 화면이 닉네임 표시 메인 진입점.
- **성공/실패 색 분기 (드라마틱 대비)**: 성공 = 따뜻한 노랑 그라데이션 + 보라 accent + 🎉. 실패 = 그레이 그라데이션 + 다크 그레이 accent + 💪. 색은 **위젯에 hardcode** ([ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) `_bgTop`/`_bgBottom`/`_accent`/`_muted`) — 캡처 시 ThemeData 변동 영향 안 받아야.
- **콘텐츠**: 헤더(닉네임 한 줄 "○○님의 만원 챌린지" + **챌린지 이름** 크게/볼드 + 기간) / 결과 라벨 + 부제 (절약/초과 금액) / 통계 카드 (목표/사용/절약(또는 초과)/무지출 — 무지출 0일이면 라인 생략) / 배지 row (없으면 통째 생략, 최대 6 + N) / Tenk 워터마크. **카테고리 분포는 의도적으로 제외** (자리 빡빡 + 숫자/배지로 충분). 챌린지 이름은 `challenge.name` 을 그대로 쓰므로 별도 fetch 불필요.
- **PNG 캡처 패턴** ([ResultCardCapture](tenk_app/lib/data/export/result_card_capture.dart)): Overlay 에 `Positioned(left: -2*width)` 로 화면 밖 좌표에 RepaintBoundary 로 감싸진 ResultCardWidget 을 잠시 띄움 → 배지 자산 `precacheImage` → 2 frame 대기 → `boundary.toImage(pixelRatio)` → PNG bytes → 파일. 사유: 위치는 안 보여도 layout/paint 는 정상 수행되고 RepaintBoundary 가 layer 를 그대로 캡처. 갤러리/공유용은 `pixelRatio: 2.0` (960x1728 HiDPI), 영상 export 용은 `1.0` (480x864 영상 해상도와 1:1). **배지 precache 가 필수** — Image.asset 의 첫 프레임 placeholder 가 캡처되는 회귀 방지.
- **영상 마지막 카드 클립** ([VideoComposer.compose](tenk_app/lib/data/export/video_composer.dart) `resultCardPngPath` 옵션): PNG 가 480x864 라 scale/pad noop, `-loop 1 -t 3.0` 으로 3초 정지 mpeg4 클립 생성 → 기존 normalize 출력들 뒤에 추가 → concat 에 포함. `_concatWithXfade` 는 클립별 가변 duration 지원 (`durations: List<double>`) — 마지막 3초 + 앞 클립들 2초가 섞여도 xfade offset 누적이 정확. xfade 길이는 동일하게 0.3초. 카드 정지 시간 결정은 [docs/decisions.md](docs/decisions.md) "결과 카드 회의록" 참고.

### 앱 버전 / 강제·권장 업데이트 (구현 완료)
- **판정은 서버가 진실의 원천.** 클라가 semver 를 자체 비교하지 않는다 — 강제 기준선(min)을 **재배포 없이 SQL 로** 바꾸기 위함. 클라는 상태(`LATEST`/`UPDATE_AVAILABLE`/`UPDATE_REQUIRED`)만 받아 화면을 분기.
- **정책 저장 = `app_config` 단일 행 (B-sql 방식).** `min_supported_version`(미만이면 강제) / `latest_version`(미만이면 권장) / `android_store_url` / `ios_store_url`. **값 갱신은 관리자 UI 없이 SQL** — TESTER 승격과 동일한 운영 방식:
  - `UPDATE app_config SET latest_version='1.1.0', min_supported_version='1.0.0' WHERE app_config_id=1;`
  - **라이브 DB 는 이 테이블을 CREATE + INSERT 로 추가**해야 부팅됨(ddl-auto=validate) — [schema.sql](docs/schema.sql) 의 `app_config` 블록 참고. 새 앱을 릴리스해 "최신 버전"을 올릴 때마다 이 행을 갱신한다(재배포 불필요, SQL 한 줄).
- **엔드포인트**: `GET /api/app/version?platform={android|ios}&currentVersion={x.y.z}` — **PERMIT_ALL(인증 불필요, 로그인 전 부팅 시점 호출)**. 응답 `{ status, latestVersion, minSupportedVersion, storeUrl }`. 판정·비교는 [AppVersionService](tenk-backend/src/main/java/com/hjson/tenk/domain/app/AppVersionService.java) + [SemanticVersion](tenk-backend/src/main/java/com/hjson/tenk/domain/app/SemanticVersion.java)(빌드/프리릴리스 접미사 무시, 숫자 비교). storeUrl 은 platform 으로 서버가 선택.
- **fail-open 원칙**: 설정 행이 없거나, currentVersion 이 없거나·이상하면 서버는 `LATEST` 를 준다. 클라도 네트워크 실패 시 [AppVersionInfo.unknown](tenk_app/lib/data/app/app_version.dart)(게이트 미적용). **서버가 안 붙는다고 앱을 잠그지 않는다** — 연령·동의 게이트의 fail-open 과 같은 원칙.
- **클라 게이트 배선**: [SessionGate](tenk_app/lib/app/session_gate.dart) 가 **버전 게이트를 가장 먼저** 판정(로그인·동의보다 상위 차단). 강제 → [ForceUpdateScreen](tenk_app/lib/presentation/update/update_gate.dart)(back/swipe 차단, 스토어로만), 권장 → 정상 목적지를 [RecommendedUpdateHost](tenk_app/lib/presentation/update/update_gate.dart) 로 감싸 첫 프레임에 1회 안내(‘나중에’로 계속 사용, 다음 콜드 스타트에 재안내). 순서: **강제 업데이트 → 연령 → 동의 → (신규)닉네임 → 홈.**
- **버전 표시**: 메뉴([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart))의 '앱 버전' 행이 `package_info_plus` 로 현재 버전(`v1.0.0`)을 읽어 표시 + 최신 여부(최신/업데이트 있어요). 업데이트 있으면 탭 시 스토어로.
- **버전 문자열의 진실의 원천 = pubspec `version`** (예 `1.0.0+3`). 릴리스할 때 이 값을 올리고, 스토어 게시가 끝나면 `app_config.latest_version` 을 그 값으로 SQL 갱신(둘을 일치시킬 것).

### 테스트 지원 (devtools — 상태별 시딩. **테스트 로그인은 제거됨**)
- **왜 있나**: 날짜 기반 앱이라 "완료(성공/실패)·확정 대기" 같은 챌린지 상태는 **현실 날짜가 지나야만** 자연 발생한다. 실기기/에뮬레이터에서 각 상태를 즉시 만들어 테스트하려고 둔 **테스트 전용** 시딩 경로. 백엔드는 [com.hjson.tenk.devtools](tenk-backend/src/main/java/com/hjson/tenk/devtools/TestSupportService.java) 패키지.
- **⚠️ 카카오 우회 테스트 로그인은 제거됐다 (2026-07-25 테스터 로그인 회의, [decisions.md](docs/decisions.md)).** `POST /api/auth/test/login` · `TestLoginRequest` · `TestSupportProperties`(`tenk.test.*` yaml 포함) · Flutter 로그인 버튼/`loginAsTest`/`test_config.dart` 전부 삭제. Play 심사·데모는 **데모 카카오 계정**으로, 내부 테스터는 **실제 카카오 계정을 TESTER 로 승격**해 쓴다. `AuthProvider.TEST` 는 기존 로컬 데이터 호환용으로만 `@Deprecated` 잔존(새로 안 생김). **다시 추가하지 말 것.**
- **게이팅 = 계정 role.** [UserRole](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRole.java) `{ USER, TESTER }` (`user.role` 컬럼, 기본 USER). 시딩은 `user.getRole().canUseTestTools()`(=TESTER)일 때만 허용, 아니면 `TEST_ONLY_OPERATION`(T0001). **테스터 승격은 DB 에서 직접** — 앱엔 부여 경로가 없다: `UPDATE user SET role='TESTER' WHERE provider='KAKAO' AND provider_user_id='<카카오회원번호>';`. **심사자 데모 계정은 절대 승격 금지**(승격하면 '내 정보'에 시딩 버튼 노출). 전역 킬스위치(`tenk.test.enabled`) 없음 — 플래그 없는 계정 = 시딩 불가 = 그 자체가 킬스위치.
- **데이터 시딩** (`POST /api/dev/seed`, **인증 필요**): 호출자가 TESTER 가 아니면 거부. 통과 시 그 유저 데이터를 wipe([WithdrawnUserPurgeService.purge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 와 같은 FK 순서, user/refresh_token 만 유지) 후 **5종 상태** 챌린지 시딩: 시작 전 / 진행 중(STREAK·NO_SPEND 배지) / 확정 대기(finalize→SUCCESS 페이오프 테스트용) / 완료-성공(CHALLENGE_SUCCESS 배지) / 완료-실패. **wipe 는 호출자 본인 데이터를 지운다** — 그래서 TESTER 는 소모용 계정이어야 한다(승격한 실계정의 진짜 기록도 날아감).
- **날짜 우회 방식**: 챌린지는 `Challenge.create` 로 today 로 만든 뒤 `startDate`/`endDate` 만 **reflection(`ReflectionUtils`) 으로 backdate** — `validatePeriod` 가 미래 시작만 허용하므로 우회 필요(통합 테스트의 backdate 패턴과 동일). **금액·배지는 우회 불필요** — `Amount.spend/noSpend` 는 오늘이 아니라 *챌린지 기간* 으로 검증하고, 배지는 `BadgeGrantService.evaluateForChallenge`/`grantChallengeSuccess` 를 그대로 호출해 현실적 데이터가 나온다.
- **Flutter 진입**: '내 정보'→메뉴 화면([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart))의 "테스트 데이터 재생성"(`user.isTester` = `role=='TESTER'` 일 때만 노출, confirm→seed→목록 reload). 시딩=`ChallengeApi.seedTestData`(ChallengeScope). `UserResponse.role` 을 Flutter `User.role` 로 파싱해 버튼 노출 판정.

## 패키지 구조 (백엔드)

루트: `tenk-backend/src/main/java/com/hjson/tenk/`

```
com.hjson.tenk
├── TenkApplication.java          # @EnableScheduling, @ConfigurationPropertiesScan
├── common
│   ├── api/ApiResponse.java        # 공통 응답 포맷 {success, data, error}
│   ├── config/                     # JpaAuditing, OpenApi, *Properties
│   └── exception/                  # ErrorCode, BusinessException, GlobalExceptionHandler
├── security/                       # SecurityConfig (STATELESS) + JwtTokenProvider/JwtAuthenticationFilter
│                                   # + JwtPrincipal + KakaoTokenVerifier + @CurrentUserId
├── devtools/                       # 테스트 전용. TestSupportController/Service — 상태별 챌린지 시딩(/api/dev/seed)
│                                   # TESTER 권한 계정만 (user.role). 테스트 로그인은 제거됨
└── domain
    ├── auth/        (AuthController, AuthService, RefreshToken, RefreshTokenRepository, AuthTokens, dto/)
    ├── user/        (entity, repo, service, controller, dto/, AuthProvider — TEST 포함)
    ├── challenge/   (+ ChallengeExportService, event/ChallengeFinishedEvent)
    ├── amount/      (+ event/AmountRecordedEvent)
    ├── media/       (MediaFile, LocalFileStorage, MediaController)
    ├── badge/       (Badge, ChallengeBadge, BadgeGrantService, BadgeEventListener, BadgeScheduler, dto/AcquiredBadgeResponse)
    │                <!-- 챌린지 단위. 응답은 ChallengeResponse.badges 에 인라인 — 별도 컨트롤러 없음 -->
    └── app/         (AppConfig, AppConfigRepository, AppVersionService, SemanticVersion, AppVersionController, dto/AppVersionResponse)
                     <!-- 앱 버전 정책 단일 행(app_config). GET /api/app/version — PERMIT_ALL 부팅 게이트 -->

```

## 패키지 구조 (Flutter 앱)

루트: `tenk_app/lib/`

```
lib/
├── main.dart                   # composition root만. 의존성 조립 + Scope 주입 + MaterialApp
├── app/                        # 앱 셸: 라우팅 진입점, 전역 DI, 네비게이터 키
│   ├── navigator_key.dart        # 위젯 트리 밖(예: dio interceptor)에서 라우터 접근용
│   ├── scopes.dart               # AuthScope / ChallengeScope / ... (InheritedWidget DI)
│   └── session_gate.dart         # 토큰 유무에 따라 홈/로그인 분기
├── config/                     # 컴파일 타임 상수 (API base URL, 카카오 키)
├── design/                     # 디자인 시스템 (색·타이포·여백·라운드·테마) — 아래 "디자인 시스템" 참고
│   ├── tokens.dart               # AppColors / AppSpacing / AppRadius / AppTypo (단일 진실)
│   └── app_theme.dart            # buildTenkTheme(): 토큰 → ThemeData (main.dart 에서 배선)
├── data/                       # 모든 외부 통신·영속성. 화면에서 직접 import 금지 — Scope를 거쳐서만
│   ├── api/                      # 전송 계층 공용
│   │   ├── dio_client.dart         # rawDio(인증X) + authDio(401 회전 인터셉터 부착)
│   │   ├── auth_interceptor.dart   # single-flight refresh + 1회 재시도
│   │   ├── api_response.dart       # 백엔드 envelope `{success,data,error}` 헬퍼
│   │   ├── api_error.dart          # 서버 에러 → ApiException 변환
│   │   └── auth_api.dart           # /api/auth/* HTTP 호출만
│   ├── auth/                     # 도메인 폴더: 모델 + (필요시) repository + storage
│   │   ├── auth_tokens.dart, token_storage.dart, auth_repository.dart
│   ├── challenge/                # 도메인 폴더: 모델 + api (지금은 repo 불필요)
│   │   ├── challenge.dart, challenge_api.dart
│   ├── amount/                   # 지출/무지출 기록 + multipart 영상 업로드
│   │   ├── amount.dart, amount_api.dart
│   ├── badge/                    # 챌린지 응답에 인라인되는 AcquiredBadge 모델만 (API 없음)
│   │   └── badge.dart
│   ├── media/                    # 영상 다운로드 (export prefetch 용)
│   │   └── media_api.dart
│   ├── user/                     # 사용자 정보 — 결과 카드 헤더, '내 정보' 화면, 닉네임 변경, 회원 탈퇴
│   │   ├── user.dart, user_api.dart  # User 모델에 nicknameChangeAvailableFrom. updateNickname/withdraw 호출
│   ├── app/                      # 앱 버전 게이트 (rawDio, 인증X). 판정은 서버
│   │   ├── app_version.dart        # AppVersionStatus enum + AppVersionInfo(+unknown fail-open)
│   │   └── app_api.dart            # currentVersion(package_info) + checkVersion(GET /api/app/version)
│   └── export/                   # ffmpeg 영상 합본 합성 + 결과 카드 PNG 캡처 (외부 통신 X, 로컬 처리)
│       ├── video_composer.dart     # 정규화→concat 2-pass. mpeg4 sw 인코더 고정. resultCardPngPath 옵션
│       └── result_card_capture.dart  # Overlay off-screen + RepaintBoundary → PNG. video/gallery 두 해상도
└── presentation/               # 화면. data 레이어를 Scope로만 호출
    ├── common/                   # 도메인 무관 공용 위젯·헬퍼
    │   ├── async_state.dart        # AsyncStateMixin + AsyncStateView (필수 — 아래 컨벤션 참고)
    │   └── error_view.dart
    ├── login/login_screen.dart
    ├── challenge/
    │   ├── _formatters.dart        # 도메인 내부 공유 (외부 노출 X — 언더스코어 prefix). formatNumber/formatWon/formatDday/formatStartsOn/formatShortPeriod
    │   ├── challenge_list_screen.dart # 상태 탭(진행 중/완료) + 그룹핑·정렬 — 아래 "챌린지 목록 IA" 참고
    │   ├── widgets/                # 도메인 전용 공용 위젯
    │   │   ├── challenge_status.dart  # ChallengeStatusStyle.of(c) = 라벨+색+틴트 (칩/배너/마커 공유)
    │   │   ├── challenge_card.dart    # 목록 카드 1장 (상태 무관 동일 구조·높이, 우상단 마커에만 상태색, 배지 없음)
    │   │   ├── progress_bar.dart      # ChallengeProgressBar — 예산 진행률 바 (목록 카드·상세 요약 카드 공유, 초과=코랄)
    │   │   ├── challenge_badges.dart  # 챌린지에 귀속된 배지 아이콘만 작게 (잠금 노출 X)
    │   │   └── badge_celebration_dialog.dart  # 신규 배지 획득 시 풀스크린 축하 모달 + 큐 헬퍼
    │   ├── export/                 # 영상 합본 export 흐름 (확정 후에만 진입)
    │   │   ├── export_plan.dart      # 세션 한정 모델 (선택 + 자막 오버라이드)
    │   │   ├── export_screen.dart    # 1단계: 클립 선택 + 자막 편집 → "다음"
    │   │   ├── export_settings_screen.dart  # 2단계: 자막 위치/배경 + 결과 카드 포함 → "영상 만들기" (compose 흐름 시작)
    │   │   ├── export_prefetch_screen.dart  # 원본 영상 다운로드
    │   │   ├── export_compose_screen.dart   # ffmpeg 합성 진행률 + 캔슬 (결과 카드 PNG 캡처도 여기)
    │   │   └── export_result_screen.dart    # 미리보기 + 갤러리 저장 + 공유
    │   ├── result_card/            # 챌린지 결과 1장 카드 (영상 export 와 독립 도메인)
    │   │   ├── result_card_widget.dart  # 480x864 고정 위젯. 캡처 시 RepaintBoundary 로 감쌈
    │   │   └── result_card_screen.dart  # 풀스크린 라우트 + 갤러리 저장 + 공유. 닉네임 fetch
    │   └── *_screen.dart           # 카드·상세 양쪽에서 ChallengeBadgesRow 사용
    ├── amount/                       # 기록 추가/수정 + 촬영 + 미리보기
    │   ├── amount_record_screen.dart    # 폼 (지출/무지출 토글). 카메라 인라인 없음 — VideoAttachmentSection 만 (즉시 모드)
    │   ├── amount_edit_screen.dart      # 카드 탭 → 진입. 시간/내용/메모/영상 수정 + 삭제. 서버 영상 lazy 다운로드 캐시 (`_serverVideoLocalPath`)
    │   ├── amount_camera_screen.dart    # 2초 녹화 + 녹화 후 video_player 자동 재생(loop). "사용" pop<String>(path)
    │   ├── amount_video_preview_screen.dart  # 기존/새 영상 전용 미리보기 화면. pop<VideoPreviewAction>(retake/delete)
    │   └── widgets/
    │       ├── video_attachment_section.dart  # 영상 첨부 상태 위젯. `expandable=false` (record) 즉시 모드 / `expandable=true` (edit) "영상 보기" 버튼만
    │       └── budget_hint_row.dart  # 지출 금액칸 하단 보조: 좌 입력 에코(실시간)/우 "잔액 ○원"(포커스 아웃 커밋, 초과 시 error색). record/edit 공유
    ├── profile/                      # 신규 가입 닉네임 설정 + '내 정보'
    │   ├── nickname_setup_screen.dart   # 신규 가입자 전용 (LoginScreen 이 isNewUser=true 면 분기). PopScope canPop=false 로 회피 차단. 카카오 닉네임 pre-fill. 동의 화면과 분리(닉네임만)
    │   ├── profile_screen.dart          # AppBar 햄버거(Icons.menu) 진입점 = 순수 메뉴(제목 '메뉴' 확정). 내 정보(→) + 계정 설정(→) + 법적 고지(→) + 앱 버전(+최신여부) + 테스트 재생성(dev)
    │   ├── my_info_screen.dart           # '내 정보' 하위 화면. 닉네임(변경 다이얼로그) + 성별(선택, '입력 안 함' 포함)
    │   ├── account_settings_screen.dart # '계정 설정' 하위 화면. 연동 계정 표시 / 로그아웃 / 회원 탈퇴(→ WithdrawScreen push). 메뉴가 넘긴 User 사용, null 이면 자체 로드
    │   └── withdraw_screen.dart          # 탈퇴 사유 화면. 확인 다이얼로그를 통과한 뒤 열린다 — 사유 칩(선택, '기타'면 자유 입력) → withdraw → 로그아웃
    ├── legal/                        # 연령 확인·약관 동의·고지 (openLegalDoc 헬퍼 공유)
    │   ├── age_gate_screen.dart          # 중립적 연령 심사. 생년월일 3칸(기본값 없음), 컷오프 비노출, back 차단. 14세 미만이면 계정 파기 안내 후 로그아웃
    │   ├── consent_section.dart         # 전체 동의 + 이용약관/개인정보 필수 2항목 + [보기] 공용 위젯 + openLegalDoc(url_launcher)
    │   ├── consent_gate_screen.dart     # 필수 동의 화면. next 파라미터로 다음 화면 분기(신규=닉네임, 기존=홈). back 차단, 동의 or 로그아웃
    │   └── legal_notice_screen.dart     # '법적 고지' 하위 화면. 이용약관/개인정보처리방침 링크 + 오픈소스 라이선스(showLicensePage)
    └── update/                       # 앱 버전 게이트 UI (판정은 서버, 여기선 화면만)
        └── update_gate.dart             # ForceUpdateScreen(강제, back차단) + RecommendedUpdateHost(권장 1회 안내) + openStorePage 헬퍼
```

자산: `tenk_app/assets/fonts/Korean.ttf` (현재 미사용 — 영상 export 자막은 Flutter `TextPainter` + 시스템 폰트 폴백으로 처리. 자막 폰트를 명시 지정하고 싶으면 [tenk_app/assets/fonts/README.md](tenk_app/assets/fonts/README.md) 참고).

배지 자산: `tenk_app/assets/badges/` (pubspec.yaml `flutter.assets`에 등록). 파일명은 서버 `badge.icon_path`와 1:1 매칭 (`streak_3.png` 등 9개). 새 배지 추가 시 schema.sql · 자산 디렉토리 동시 갱신.

Lottie 자산: `tenk_app/assets/lottie/` — 현재 `confetti.json` (배지 축하 모달 컨페티) 1개. 파일이 없으면 컨페티만 조용히 생략되고 배지 줌·바운스는 그대로. 추가/교체 시 라이선스 확인 ([assets/lottie/README.md](tenk_app/assets/lottie/README.md)).

배지 UI 원칙:
- **챌린지에 귀속된 획득 배지만 노출** — 잠금 상태/미획득은 챌린지 단위 모델에서 의미 없으므로 보이지 않는다. 전용 "배지 화면"이나 진입점도 없다.
- 챌린지 응답(`Challenge.badges`)을 카드·상세에서 그대로 [ChallengeBadgesRow](tenk_app/lib/presentation/challenge/widgets/challenge_badges.dart) 로 렌더.
- **신규 배지 획득 알림은 [ChallengeDetailScreen](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 의 reload diff 로만**. `_knownBadgeIds` (challengeBadgeId 기반) 와 새 응답을 비교해 신규 항목만 [showBadgeCelebrations](tenk_app/lib/presentation/challenge/widgets/badge_celebration_dialog.dart) 로 큐잉. 첫 로드는 `_baselineSet` 으로 막아 baseline 만 채움 — 과거 배지를 다시 축하하지 않는다. 메인/홈 등 다른 진입점에서도 알리고 싶으면 global `BadgeNotifier` 로 승격 (현재 범위 밖).
- 유저 단위 누적(=업적) 화면은 추후 추가 예정 — 그때 별도 `presentation/achievement/` + 별도 Scope/API 신설.

### 디자인 시스템 (색·타이포·테마)
- **방향: "절제된 베이스 + 리워드만 화려".** 평소 화면(목록·기록·상세)은 흰 배경 + 뉴트럴 잉크 텍스트 + 민트 accent 로 인지부하를 낮추고, **배지 획득·finalize·결과카드** 같은 페이오프 순간에만 컬러·모션을 몰아준다. 토스 공식 UX 가이드 + 카뱅 26주적금/챌린저스/뱅크샐러드 레퍼런스에서 도출 (레퍼런스 이미지·팔레트 근거는 `references/` 폴더).
- **진실의 원천 = [design/tokens.dart](tenk_app/lib/design/tokens.dart).** 색은 `AppColors`, 타이포는 `AppTypo`, 여백/라운드는 `AppSpacing`/`AppRadius`. **화면·위젯에서 hex(`Color(0x...)`)·매직넘버를 직접 박지 말고 토큰을 가져다 쓸 것.**
  - **팔레트**: Primary=민트 `#1FBE9C`(+틴트 `#E3F6F0`), 베이스=**화이트 `#FFFFFF`**(bg·surface 동일 → 카드는 **보더 `#EAECEF`로 구분**)/입력칸 채움 쿨그레이 `#F1F3F6`/잉크 쿨차콜 `#1C1D21`. Semantic=success `#12B886`/danger `#FF6B6B`/warn `#E0951B`. 상태색(시작전 그레이/진행중 민트/확정대기 앰버/성공 에메랄드/실패 코랄뮤트)은 각 틴트 포함. Reward(성공 골드 그라데이션+보라 / 실패 그레이)는 페이오프 전용. **뉴트럴은 쿨 그레이 계열** — 초기의 웜 크림(#FAF9F6)은 민트와 톤 충돌해 폐기(2026-07-15 리모델).
  - **예외 — 결과 카드**: [ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) 등 **오프스크린 캡처(PNG)** 되는 위젯은 ThemeData 영향을 받으면 안 되므로 색을 위젯에 hardcode 한다 (기존 규칙 유지). **`AppColors.reward*` 토큰 값은 이 카드의 hardcode 색과 정합**시켜 뒀으니(Wave 4), 카드 색을 바꾸면 토큰도 같이 맞출 것 — 둘이 어긋나면 리워드 색 언어가 갈라진다. 어두운 배경 위 페이오프 글로우는 `AppColors.rewardGlow`(골드).
- **전역 테마 = [design/app_theme.dart](tenk_app/lib/design/app_theme.dart) `buildTenkTheme()`.** [main.dart](tenk_app/lib/main.dart) 에서 `theme:` 로 배선. colorScheme/textTheme/scaffold 배경(화이트)/Card(elevation 0, radius 20, **보더 line**)/FilledButton·Elevated·Outlined/Input/AppBar(화이트·elevation 0)/SnackBar/TabBar 를 모두 토큰으로 정의. **이 한 곳이 룩의 절반 이상을 좌우** — 새 화면은 대부분 손 안 대도 새 룩이 자동 전파된다. 컴포넌트 기본 스타일을 바꾸려면 개별 화면이 아니라 여기서.
- **하이브리드 롤아웃 (Wave 0~5 완료)**: 토큰/테마(Wave 0)를 먼저 깔고, 화면 폴리시를 우선순위 웨이브로 적용. **Wave 0(토큰·테마) → 1(목록) → 2(상세) → 3(폼·필수 별표) → 4(리워드: 배지 모달 골드 글로우 + 리워드 토큰↔결과카드 정합) → 5(통계: 상세에 카테고리별 지출 카드).** 기능은 안 건드리고 보이는 층만.
  - **Wave 5 통계**: 챌린지 상세에 `_CategoryBreakdown`(뱅크샐러드식 가로 바 — 카테고리 아이콘/라벨/금액/% + 민트 진행바). `amounts` 에서 **클라 계산**(백엔드 무관), 지출>0 일 때만 노출, 금액 큰 순. 카테고리는 코드로 그룹핑하므로 검증 이전 자유텍스트 데이터는 '기타'로 폴백되어 합쳐 보일 수 있음(정상 — 9종 셀렉박스로 재저장하면 구분됨). 상세는 목록과 같은 언어(상태 pill + 남은 금액 히어로 + `ChallengeProgressBar`)의 요약 카드로 정합화했고, 확정 대기는 앰버 틴트 카드 + 전폭 확정 버튼, 진입 카드(결과카드/영상)는 공용 `_EntryCard` 로 통일.
- **리모델 (2026-07-15, Wave 0~5 이후)**: ① 카드 **좌측 상태색 스트라이프 제거** — 탭+섹션이 이미 상태로 분류하므로 중복. 상태색은 우상단 마커/칩에만 남김. ② **목록 카드 높이 통일** — 상태 무관 동일 구조(이름+마커 / 남은금액(또는 목표) / 진행바 / 캡션 한 줄), 배지는 카드에서 제외(상세에만 노출)해 높이 변동 제거. ③ **베이스 크림→화이트** + 쿨 그레이 뉴트럴(위 팔레트).
- **폼 규칙 (Wave 3)**: 필수/선택 표기는 [common/field_label.dart](tenk_app/lib/presentation/common/field_label.dart) `FieldLabel(text, required:/optional:)` 하나로 통일 — 필수=빨간 `*`, 선택=회색 `(선택)`. **폼 라벨은 전부 `FieldLabel` 로**([[feedback-consistency-over-pinpoint]] — record/edit/create/nickname_setup 전수 적용됨). 입력칸은 **`InputDecoration` 에 `border` 를 직접 박지 말 것** — app_theme 의 `inputDecorationTheme`(채움 surfaceAlt + 라운드 + 무보더, 포커스 시 민트)를 상속받는다. 날짜/시간 등 탭 필드는 `Material(surfaceAlt)+InkWell` 채움 패턴으로 통일.

### 챌린지 목록 IA (상태 탭)
- **문제였던 것**: 목록이 상태·시간 구분 없이 한 리스트에 전부 노출돼, 완료본이 쌓이거나 동시 진행이 많아지면 원하는 챌린지를 못 찾음.
- **해결**: [challenge_list_screen.dart](tenk_app/lib/presentation/challenge/challenge_list_screen.dart) 를 **상태 탭 2개**로 분리 (`DefaultTabController`). 정렬·그룹핑·필터는 전부 **클라이언트에서** (지금 챌린지 수가 적어 백엔드 무변경 — 수백 개 되면 그때 페이지네이션).
  - **진행 중 탭**(기본): 확정 대기 → 진행 중 → 시작 전 순으로 섹션 그룹. 확정 대기·진행 중은 **마감 임박순**(endDate↑), 시작 전은 시작 임박순(startDate↑). 진행 중 탭 라벨에 **확정 대기 개수 amber 뱃지**(놓치지 않게).
  - **완료 탭**: 성공/실패 함께 **종료일 최신순**(히스토리라 시간순 하나면 충분, 그룹 안 나눔). 완료가 쌓여도 진행 중 탭은 안 건드림.
  - **빈 상태**: 챌린지 0개면 진행 중 탭에 온보딩 CTA("새 챌린지 시작"), 그 외엔 탭별 안내 문구.
- **카드 글랜스어빌리티** ([challenge_card.dart](tenk_app/lib/presentation/challenge/widgets/challenge_card.dart)): **모든 상태가 동일 구조**(이름 + 우상단 마커 / "남은 금액"(시작 전은 "목표") 히어로 / 진행률 바 / 캡션 한 줄) → **높이 일관**. 우상단 마커가 **상태색을 담는 유일한 곳**(진행중=D-day 민트 / 시작전="M/D 시작" 그레이 / 확정대기="확정하기" 앰버 / 성공="성공" 그린 / 실패="실패" 코랄). 진행률 바 예산 초과면 코랄, 완료 캡션은 "N원 아꼈어요/초과했어요"(성공 그린/실패 코랄). **완료 카드는 톤다운**(그림자 없이 보더 — 단 **이름 색은 진행 중과 동일한 잉크**, 뮤트하지 말 것). 배지는 카드에 안 넣음(상세에만). 상태→색은 `ChallengeStatusStyle.of(challenge)` 공유(칩/배너/마커).

### 레이어 규칙 (반드시 지킬 것)
- **`presentation/`에서 `data/api/*Api`를 직접 import 금지.** 항상 `Scope.of(context)`를 거쳐서만 접근. composition root(`main.dart`)에서 주입된 인스턴스만 화면이 본다.
- **`data/`에서 `presentation/` import 금지.** 단방향 의존성.
- **Repository 패턴은 강제하지 않음**: 하나의 도메인이 *여러 출처*(예: 외부 SDK + 백엔드 + storage)를 합쳐야 할 때만 `*_repository.dart`를 만든다. 단일 백엔드 호출만 하는 도메인은 `*_api.dart`만으로 충분. (예: [auth_repository.dart](tenk_app/lib/data/auth/auth_repository.dart)는 카카오 SDK + AuthApi + TokenStorage 3개를 합치므로 가치 있음. challenge는 아직 api만으로 충분.)
- **Scope는 도메인별로 하나씩** `app/scopes.dart`에 추가. Scope 개수가 5개를 넘기는 시점에 Riverpod/Provider 도입을 재검토 (지금은 boilerplate가 그만한 비용을 정당화하지 못함).
- **새 화면 코드가 `import '../../main.dart'` 하면 잘못된 방향.** Scope·SessionGate·navigatorKey는 모두 `app/`에 있다.

## 코딩 컨벤션 — 백엔드

- **컨트롤러는 얇게**, 비즈니스 로직은 서비스에. 엔티티는 정적 팩토리 메서드로 생성하고 invariant 검증.
- **에러는 `BusinessException(ErrorCode.XXX)`로 던지기.** 새 케이스는 `ErrorCode` enum에 추가. 메시지는 한국어.
- **DTO는 record로**. 요청 DTO는 Bean Validation 어노테이션 사용.
- **트랜잭션**: 서비스 클래스는 기본 `@Transactional(readOnly = true)`, 쓰기 메서드만 `@Transactional`.
- **사용자 ID 주입**: 컨트롤러 파라미터에 `@CurrentUserId Long userId` 사용. (내부적으로 `@AuthenticationPrincipal(expression="userId")`)
- **댓글은 최소화.** "왜"가 비자명할 때만 작성. JavaDoc은 정책 문서 역할일 때만 (예: `BadgeGrantService` 상단).
- **새 API를 만들 때**: `@Tag`, `@Operation` 어노테이션을 빠뜨리지 말 것 (Swagger).
- **LAZY 연관 매핑된 엔티티를 응답 DTO로 변환할 때**: 컨트롤러가 트랜잭션 밖에서 매핑하면 `LazyInitializationException`. **컨트롤러에 `@Transactional` 붙이지 말고, repository 쿼리에서 `JOIN FETCH`로 같이 끌어와라.** N+1도 피한다. 회귀 가드는 `@SpringBootTest` 통합 테스트로 — 단위/`@DataJpaTest`는 못 잡는다 ([UserBadgeRepository.findByUserOrderByCreatedDtDesc](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/UserBadgeRepository.java) + [BadgeControllerIntegrationTest.returnsAcquiredBadgesWithBadgeFieldsResolved](tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeControllerIntegrationTest.java) 패턴 참고).

## 코딩 컨벤션 — Flutter

- **화면의 비동기 로딩은 `AsyncStateMixin` + `AsyncStateView` 사용**. `FutureBuilder` 금지. 이유: `FutureBuilder`가 새 future로 교체돼도 stale snapshot으로 그리는 케이스가 있어 챌린지 생성/삭제 후 갱신이 누락된 적이 있음. mixin은 `_loading/_data/_error/_loadGen` 4-tuple과 stale-response 가드를 한 곳에 캡슐화한다. 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state를 들 것. ([presentation/common/async_state.dart](tenk_app/lib/presentation/common/async_state.dart))
- **`Scope.of(context)` 등 InheritedWidget 의존 호출을 `initState()` 안에서(또는 initState 가 동기적으로 부르는 메서드의 첫 await 이전에) 하지 말 것.** `dependOnInheritedWidgetOfExactType` 는 initState 완료 전엔 `... called before initState() completed` 로 크래시한다. `AsyncStateMixin` 의 `fetch()` 는 `didChangeDependencies` 단계라 안전하고, mixin 을 안 쓰는 화면은 `WidgetsBinding.instance.addPostFrameCallback((_) => ...)` 으로 첫 프레임 이후에 접근할 것 ([result_card_screen](tenk_app/lib/presentation/challenge/result_card/result_card_screen.dart) / [export_prefetch_screen](tenk_app/lib/presentation/challenge/export/export_prefetch_screen.dart) 패턴). 버튼 콜백·build 안에서의 `Scope.of` 는 build phase 이후라 무관. 실제 [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 이 이 규칙 위반으로 신규 가입 직후 크래시한 적 있음 (2026-06-16 수정).
- **HTTP 응답은 항상 `unwrapData` / `unwrapList` 통과**. 백엔드 envelope 풀이 로직을 도메인마다 복붙하지 말 것. ([data/api/api_response.dart](tenk_app/lib/data/api/api_response.dart))
- **에러는 SnackBar로 노출 시 `toApiException(e).message` 사용**. dio 에러·서버 에러·기타 예외를 일관된 한국어 메시지로 변환.
- **모델은 immutable + `fromJson` 팩토리**. `@immutable` 어노테이션 + `final` 필드. JSON 키는 백엔드 응답 그대로 (snake/camel 변환 X).
- **Navigator push/pop의 generic은 양쪽 모두 명시** (`push<T>(MaterialPageRoute<T>(...))`). push 결과에 의존하지 말고 push 종료 시점에 무조건 새로고침 — 결과 누락 케이스가 있음 ([docs/handoff.md](docs/handoff.md) "함정 — Flutter" 참고).
- **위젯 중복은 즉시 추출**: 두 화면이 같은 위젯을 쓰면 도메인 위젯은 `presentation/<domain>/widgets/`, 도메인 무관 공용 위젯은 `presentation/common/`에. 화면 파일 안에 `_PrivateView` 클래스로 두는 건 그 화면에서만 쓸 때.
- **Scaffold body 는 항상 `SafeArea(top: false, child: ...)` 로 감싼다** (AppBar 가 있는 화면 기준). 안드로이드 제스처 내비/3-버튼 바가 본문 하단 액션 버튼을 가리는 기기가 있어 일관 적용한다. AppBar 가 없는 화면(login 처럼)만 `SafeArea(child: ...)` 전체 방향. **bottomNavigationBar 슬롯은 Flutter 가 inset 자동 처리하므로 별도 SafeArea 불필요** (export_screen 의 기존 패턴은 historical — 새 화면에서 따라할 필요 없음). 화면별로 SafeArea 가 있는 곳·없는 곳이 섞이면 디바이스 따라 가림이 들쭉날쭉해진다.
- **빈 곳 탭 시 키보드 닫기는 전역 처리** — [main.dart](tenk_app/lib/main.dart) 의 `MaterialApp.builder` 가 `GestureDetector(translucent, onTap: unfocus)` 로 전 화면에 적용한다. **화면마다 GestureDetector 를 새로 달지 말 것** (입력칸 있는 화면이 계속 늘어나는데 화면별로 붙이면 빠지는 곳이 생긴다 — 실제로 전 화면에 아예 없던 상태였다). 하위 위젯의 탭·핀치는 제스처 아레나에서 안쪽 recognizer 가 이기므로 카메라 탭 초점·휠 picker 등은 영향 없다.
- **폼 키보드 이동 규칙 (전 화면 공통)**: 입력칸이 2개 이상인 폼은 **다음 칸이 있으면 `textInputAction: next` + `onFieldSubmitted`(TextField 는 `onSubmitted`)에서 다음 `FocusNode` 를 직접 `requestFocus()`**, **마지막 칸이면 `done` + 제출**. 다음 대상을 traversal 자동 계산에 맡기지 말 것 — 중간에 탭 필드(날짜 picker 등 `InkWell`)가 끼면 포커스가 그쪽으로 샌다 ([challenge_create_screen](tenk_app/lib/presentation/challenge/challenge_create_screen.dart) 의 이름→목표금액이 실제 사례). **자릿수 고정 숫자 칸**(생년월일 년/월/일)은 숫자 키보드에 액션 키가 없으므로 **`maxLength` 를 채우면 자동 이동**하고, 짝으로 **빈 칸 백스페이스 시 이전 칸 복귀**를 같이 둔다(자동 이동만 있으면 오타 수정이 막힌다) — 구현은 [age_gate_screen](tenk_app/lib/presentation/legal/age_gate_screen.dart) `_BirthField` 가 레퍼런스. **autofocus 는 "빈 칸을 반드시 채워야 하는 단일 목적 화면·다이얼로그"에만** — 값이 pre-fill 된 화면([NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 은 카카오 닉네임이 채워져 있어 대부분 그대로 확정)에 걸면 키보드가 액션 버튼을 밀어올려 손해다.
- **날짜·시간 선택은 공용 헬퍼만 쓴다 — `showDatePicker`/`showTimePicker` 직접 호출 금지.** [common/date_time_picker.dart](tenk_app/lib/presentation/common/date_time_picker.dart) 의 `pickTenkDate` / `pickTenkTime` 을 경유할 것. 호출부가 4곳(챌린지 생성 시작/종료일, 기록 날짜·시간, 수정 시간)으로 흩어져 각자 옵션을 박으면 화면마다 다른 picker 가 뜬다.
  - **날짜는 Material 달력 picker**(`pickTenkDate`) 유지. 범위 밖 `initial` 은 헬퍼가 클램프하므로 호출부에서 미리 보정하지 말 것.
  - **시각은 Material `showTimePicker` 를 쓰지 않는다** — 아날로그 시계(dial)가 분을 맞추기 불편해서 **휠(드럼) 방식 자체 위젯**([common/wheel_time_picker.dart](tenk_app/lib/presentation/common/wheel_time_picker.dart))으로 대체했다. 규격: 오전·오후(2항, 순환 X) / 시 1~12(**무한 순환**) / 분 00~59(**무한 순환**), 가운데 숫자 탭 → 그 열만 직접 입력, 스크롤마다 `HapticFeedback.selectionClick`. **dial 로 되돌리지 말 것.**
  - **휠은 평면이다 — 3D 드럼으로 되돌리지 말 것.** `ListWheelScrollView` 기본값은 항목을 원통에 배치해 위아래가 기울고 작아지는데, `diameterRatio` 를 크게(`_flatDiameterRatio`) + `perspective` 를 거의 0 으로 + `useMagnifier: false` + `squeeze: 1` 로 곡률을 없애 **모든 항목이 같은 크기**다. 선택 여부는 **크기가 아니라 색으로만** 구분한다.
  - **선택 밴드는 민트 채움 + 흰 글자**(`primary` / `onPrimary`) — 날짜 picker 의 선택된 날(민트 원 + 흰 글자)·`FilledButton` 과 같은 언어. 콜론도 밴드 안이라 흰색이고, 직접 입력 오버레이도 같은 민트·같은 라운드라야 밴드가 이어져 보인다. **`surfaceAlt` 를 쓰지 말 것** — 다이얼로그 표면이 이미 옅은 틴트라 밴드가 오히려 더 밝아져 흰 알약처럼 보이고 "선택됨" 으로 안 읽힌다.
  - **시 휠이 경계를 넘으면 오전/오후가 자동 전환된다. 경계는 "11시↔12시" — 12시↔1시가 아니다.** 실제 시계가 오전 11시 다음 오후 12시(정오)로 넘어가므로 이렇게 해야 휠을 굴리는 게 24시간 타임라인을 그대로 걷는다. 12↔1 로 바꾸면 정오가 `오전 12시`(자정)로 잡혀 중간 한 칸이 12시간 틀어진다. 판정은 `_amPmBoundariesUpTo`(경계 개수 차가 홀수면 뒤집기). **분은 시로 carry 하지 않는다**(의도).
  - **12/24시간제는 기기 설정(`alwaysUse24HourFormat`)을 따르고 강제하지 않는다** — 단 이건 **표기**(`formatTimeOfDay`)에만 적용되고, 휠 입력은 항상 오전·오후 + 1~12 다.
- **기록/수정 화면의 `일시` 는 `날짜 | 시간` 2칸** ([amount/widgets/date_time_fields.dart](tenk_app/lib/presentation/amount/widgets/date_time_fields.dart) `DateTimeFields`). `onDateTap == null` 이면 날짜 칸이 읽기 전용 — **수정 화면은 도메인 규칙상 날짜를 바꿀 수 없다**(삭제 후 재등록). **한 칸에 합쳐 날짜→시간 다이얼로그를 연달아 띄우지 말 것** — 시간만 고치려는데 날짜를 매번 통과해야 했던 게 2칸으로 나눈 이유다.
- **화면에 보이는 시각 표기도 같은 헬퍼로** — `formatTimeOfDay(context, time)` / `formatDateWithTime(context, dt)`. 기기 설정에 따라 `오후 10:11` 또는 `22:11` 로 자동 분기한다. `_formatters.dart` 에 24시간제 고정 포맷을 **다시 만들지 말 것** (예전 `formatDateTime` 이 그래서 제거됨 — 폼은 `10:11 PM`, 목록은 `22:11` 로 갈라져 있었다). 노출 4지점: 기록 화면 일시 칸 / 수정 화면 시간 칸 / 챌린지 상세 amount 타일 / export 클립 목록.
- **Material 기본 UI 의 한국어는 `MaterialApp` 로케일 고정에서 온다** — [main.dart](tenk_app/lib/main.dart) 의 `locale: Locale('ko')` + `supportedLocales: [Locale('ko')]` + `flutter_localizations` delegate 3종. 앱 문자열이 전부 한국어 하드코딩이라 **시스템 로케일을 따라가게 두지 말 것** (영어 기기에서 picker·라이선스 화면만 영어로 튄다). `flutter_localizations` 가 `intl` 을 transitive 로 끌어오지만 **직접 import 하지 않는다** — 숫자·날짜 포맷은 계속 [_formatters.dart](tenk_app/lib/presentation/challenge/_formatters.dart) 자체 구현.
- **백엔드의 LocalDateTime 전송은 `Z` 없는 ISO-8601 직접 포맷**. `DateTime.toIso8601String()`은 UTC 변환 시 `Z`가 붙어 백엔드 LocalDateTime 파서를 깨뜨림 ([challenge_api.dart](tenk_app/lib/data/challenge/challenge_api.dart) `_formatLocal` 참고).
- **댓글은 최소화.** "왜"가 비자명할 때만 (예: dio 2개 인스턴스 이유, `_loadGen` 세대 카운터 이유, hide 키워드로 카카오 SDK `AuthApi` 가리기).

## 환경 설정 / 프로파일

- **서버 타임존 = `Asia/Seoul` 고정.** `LocalDate.now()`/`LocalDateTime.now()` 는 JVM 기본 타임존을 따르는데 Docker 컨테이너 기본이 UTC 라, 그대로 두면 **한국 자정~오전 9시(UTC 가 다음 날로 넘어가기 전) 사이 날짜가 하루 밀린다** — "오늘 시작" 챌린지가 그 시간대에 "시작 전" 으로 보이고, 무지출/spent_dt 날짜 판정도 어긋난다. **두 겹으로 고정**: ① 앱 코드 [TenkApplication.main](tenk-backend/src/main/java/com/hjson/tenk/TenkApplication.java) `TimeZone.setDefault("Asia/Seoul")` (배포 환경 무관 보장) ② [deploy/docker-compose.yml](deploy/docker-compose.yml) backend `TZ: Asia/Seoul` env (컨테이너 레벨, 재빌드 없이 재시작만으로 적용). JDBC URL 의 `serverTimezone=Asia/Seoul` 은 드라이버 타임스탬프 변환용이라 `LocalDate.now()` 엔 영향 없음 — 별개다. **둘 다 유지할 것.** 새 `now()` 호출부에서 타임존을 다시 신경 쓸 필요는 없다 (기본이 이미 KST).
- **프로파일 분리**: `application.yaml`(공통) + `application-local.yaml`(로컬 DB 자격증명) + `application-prod.yaml`(prod placeholder).
- **기본 active 프로파일은 `local`** — `application.yaml`의 `spring.profiles.active: local` 기본값. prod 실행은 `--spring.profiles.active=prod`.
- **자격증명은 환경변수 대신 yaml에 직접 박는다.** private 레포 전제. `.gitignore`에서 `application-*.yaml` 라인을 제거해 둘 다 git 추적함.
- **`tenk.auth.jwt`** (secret, accessTokenTtl, refreshTokenTtl, issuer) / **`tenk.auth.kakao.app-id`** — `AuthProperties` 레코드로 바인딩. `secret`은 Base64 인코딩된 HS256 키.
- **`tenk.auth.jwt.secret`은 환경별 profile에서만 정의한다.** 공통 `application.yaml`에는 **의도적으로 비워둠** — fallback이 있으면 prod에 dev 키가 새어나갈 위험. `application-local.yaml`엔 의미 있는 평문(`tenk-local-jwt-secret-key-for-development-12345678`)을 Base64로 인코딩한 dev 키, `application-prod.yaml`엔 `openssl rand -base64 64`로 생성한 512bit 랜덤 키. 두 키는 서로 다른 값이어야 한다 — local 키는 코드/문서에 등장해도 무해하지만 prod 키는 절대 노출 금지. 노출 시 yaml에서 새 키로 교체하면 기존 AT/RT가 모두 즉시 무효화된다.
- 카카오 REST API 키(=`app-id`, 숫자)는 `tenk.auth.kakao.app-id`에 실제 값 박을 예정. 모바일 SDK가 토큰 발급을 담당하므로 server-side `client-secret`은 사실상 불필요.

## 로컬 실행 방법

### 백엔드

```powershell
# 1. DB 준비 (MariaDB) — 리포 루트에서
mysql -u root -p
> CREATE DATABASE tenk DEFAULT CHARACTER SET utf8mb4;
> CREATE USER 'tenk'@'localhost' IDENTIFIED BY '<your-pw>';
> GRANT ALL ON tenk.* TO 'tenk'@'localhost';

# 2. 스키마 적용 (ddl-auto=validate 이므로 필수) — 리포 루트에서
mysql -u tenk -p tenk < docs/schema.sql

# 3. tenk-backend/src/main/resources/application-local.yaml의 datasource.username/password 본인 계정으로 수정

# 4. 실행 (기본 active=local) — tenk-backend/ 디렉토리에서
cd tenk-backend
./gradlew.bat bootRun
# 브라우저: http://localhost:8080/swagger-ui.html
```

### Flutter 앱

```powershell
cd tenk_app
flutter pub get
flutter run    # 연결된 디바이스/에뮬레이터에서 실행 (기본 base URL = http://10.0.2.2:8080, 에뮬레이터 전용)
```

**백엔드 base URL은 `lib/config/api_config.dart` 의 `API_BASE_URL` dart-define 으로 주입**. 기본값은 안드로이드 에뮬레이터용 `http://10.0.2.2:8080`. 다른 타깃은 빌드 시 명시:
- iOS 시뮬레이터: `--dart-define=API_BASE_URL=http://localhost:8080`
- 안드로이드 실기기(기본): 배포된 HTTPS 도메인 `--dart-define=API_BASE_URL=https://tenk.hjson248.com`. cleartext 예외·LAN IP 불필요 — 어디서든(LTE 포함) 붙는다.
- (선택) 로컬 백엔드를 실기기로 테스트: 같은 Wi-Fi 에서 `--dart-define=API_BASE_URL=http://<PC LAN IP>:8080`. 이때만 두 군데 손볼 것 — ① [network_security_config.xml](tenk_app/android/app/src/main/res/xml/network_security_config.xml) 의 `<domain>` 목록에 해당 IP 추가 (cleartext HTTP 허용), ② PC Windows 방화벽에서 inbound TCP 8080 허용. **IP가 바뀌면 두 파일 + run config 모두 같이 갱신**.

**VS Code Launch Configurations** ([.vscode/launch.json](.vscode/launch.json), git 추적 — 워크스페이스는 리포 루트 `tenk/` 에서 열림. `cwd: tenk_app` 으로 Flutter 프로젝트 잡음): Run/Debug 드롭다운에서 골라 F5. **백엔드는 IntelliJ 에서 `bootRun` 한 번 띄워두면 충분** — Spring Boot 가 `0.0.0.0:8080` 에서 듣고 있어 에뮬레이터/실기기 양쪽이 같은 프로세스로 들어간다.
- `tenk_app (emulator)` — `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
- `tenk_app (device)` — `--dart-define=API_BASE_URL=https://tenk.hjson248.com` (배포된 prod HTTPS). 실기기가 외부 어디서든 붙는다. 로컬 백엔드를 실기기로 붙일 때만 이 값을 임시로 `http://<PC LAN IP>:8080` 으로 바꾸고 network_security_config 에 IP 추가 (위 실기기 항목 참고)
- **테스트 데이터 시딩 UI** 는 이제 빌드 dart-define 이 아니라 **계정 role 로 노출**된다 — 시딩을 쓰려면 그 카카오 계정을 DB 에서 `role='TESTER'` 로 승격(위 "테스트 지원 (devtools)" 참고). 즉 dev 빌드든 릴리스든 빌드 플래그는 필요 없다.

## 릴리스 빌드 / 배포

> 개발용 `flutter run` 과 별개로 **테스트 배포용 서명 빌드**를 만드는 규칙. 진행 상태·체크리스트는 [docs/handoff.md](docs/handoff.md) "남은 일 §0".

- **브랜드 표기 = `TenK`** (2026-07-28 확정, 이전 표기 `Tenk` 전면 교체). **사용자에게 보이는 문자열은 전부 `TenK`** — 앱 내 문구(로그인 로고·결과 카드 워터마크·동의/닉네임/업데이트 안내·라이선스 화면·`MaterialApp.title`), Android `android:label`([AndroidManifest.xml](tenk_app/android/app/src/main/AndroidManifest.xml)), iOS `CFBundleDisplayName`([Info.plist](tenk_app/ios/Runner/Info.plist)), 법적 문서 3종(privacy/terms/delete-account).
  - **바꾸지 않는 것**: `applicationId`/`CFBundleName` = `tenk_app`(내부 식별자 — 바꾸면 카카오 URL scheme·서명이 깨진다), 코드 식별자(`TenkApp`/`buildTenkTheme`/`pickTenkDate` 등), 도메인 `tenk.hjson248.com`, **갤러리 앨범명 `Tenk`**(바꾸면 기존 저장물과 앨범이 갈라진다 — 표기 통일보다 사용자 자산의 연속성이 우선).
  - **Play Console 스토어 등록명은 콘솔에서만 바뀐다** (코드로 안 바뀜). 현재 `TenK` 로 등록돼 있어 앱 표시 이름과 일치 — 표기를 또 바꾸면 양쪽을 같이 맞출 것.
- **base URL 은 릴리스 빌드 시 반드시 명시 주입**: `--dart-define=API_BASE_URL=https://tenk.hjson248.com`. 안 주면 기본값 `10.0.2.2`(에뮬레이터 전용)로 나가 실기기에서 백엔드 못 붙는다.
- **Android 서명 (직접 APK 공유 방침)**:
  - 릴리스 keystore = `tenk_app/android/tenk-release.keystore` (PKCS12), 자격증명은 `tenk_app/android/key.properties`. **둘 다 git 추적** — private 레포 방침(yaml 자격증명과 동일). Flutter 기본 `.gitignore` 가 `key.properties`/`*.keystore` 를 무시하므로 두 `.gitignore`(루트 + `android/`)에서 해당 라인을 제거해 추적한다.
  - [build.gradle.kts](tenk_app/android/app/build.gradle.kts) 가 `key.properties` 를 읽어 `release` signingConfig 구성. 파일이 없으면 debug 서명으로 폴백(로컬 `flutter run --release` 용).
  - 빌드: `flutter build apk --release --dart-define=API_BASE_URL=https://tenk.hjson248.com` → `build/app/outputs/flutter-apk/app-release.apk` (fat APK, 직접 공유용). Play Console 로 갈 땐 `appbundle`(AAB).
  - **R8 축소 OFF** ([build.gradle.kts](tenk_app/android/app/build.gradle.kts) release 블록 `isMinifyEnabled=false`/`isShrinkResources=false`). 최신 Flutter/AGP 는 R8 을 기본 ON 으로 도는데, 카카오 SDK Pigeon 클래스를 제거해 릴리스에서만 카카오 로그인이 `Unable to establish connection on channel ... isKakaoTalkAvailable` 로 깨졌다(2026-07-02, docs/handoff.md 함정 참고). **다시 켜지 말 것** — Play Store 출시로 크기 최적화가 필요할 때만 R8 재활성화 + `proguard-rules.pro` 에 kakao/ffmpeg/camera keep 규칙 추가.
  - ⚠️ **카카오 릴리스 키해시 필수**: 릴리스 keystore 는 debug 와 **키해시가 달라서**, 카카오 콘솔에 릴리스 키해시를 추가 등록 안 하면 릴리스 빌드에서 로그인만 실패한다(다른 증상은 정상). 추출법은 [[reference-kakao-android-keyhash]] — `keytool -exportcert ... | openssl sha1 -binary | openssl base64`. debug/release 둘 다 등록해 둘 것.
- **iOS — 이 Windows 머신에서 불가, 전부 macOS + Xcode 필수**. **빌드·실행은 무료**(시뮬레이터=계정 불필요, 본인 아이폰=무료 Apple ID 개인팀, 7일 서명), **TestFlight/앱스토어 배포만 Apple Developer Program($99/년)**. 사전: `flutter pub get` + `cd ios && pod install`(ffmpeg_kit/camera 때문에 `Podfile` 의 `platform :ios` 를 14.0 정도로 올려야 할 수 있음). 카카오 URL scheme·권한은 Info.plist 에 이미 있고 iOS 는 키해시 개념 없음 — 단 **카카오 콘솔에 iOS 플랫폼(번들 ID) 추가 등록 필요**(현재 Android 만). SSH 원격빌드: 컴파일·`xcrun simctl`(시뮬레이터)은 SSH OK지만 코드서명 키체인·개인팀 자동 프로비저닝·실기기 신뢰는 GUI 한 번 필요(화면공유 권장). 상세·명령은 [docs/handoff.md](docs/handoff.md) 남은 일 §0.

## 위치별 책임 (요약)

| 변경 위치 | 동시에 챙겨야 할 곳 |
|---|---|
| 엔티티 컬럼 추가 | `docs/schema.sql` 수동 동기화 (validate 모드라 안 맞으면 부팅 실패) |
| 새 도메인 추가 | 패키지 분리 (`domain/<name>/`), `ErrorCode`에 도메인 prefix 코드 추가 |
| 새 이벤트 추가 | `*Event` record는 도메인의 `event/` 하위에, 리스너는 소비자 도메인에 |
| 로그인 공급자 추가 | 공급자별 토큰 검증기(현 `KakaoTokenVerifier` 패턴) + `AuthService`에 분기 + `AuthProvider` enum 추가 + 신규 엔드포인트 `POST /api/auth/<provider>/login`. **브라우저 OAuth redirect 흐름은 사용하지 않음** (모바일 SDK + 토큰 교환 전제) |
| 파일 업로드 | 항상 `LocalFileStorage.store(file, subdir)`을 거치기. 경로를 직접 조립하지 말 것. **호출 전에 null/empty 분기는 도메인에서 하기** — `store()` 는 빈 파일이 들어오면 프로그래머 오류로 `INVALID_INPUT` 을 던진다 |
| amount 기록 수정 | `PUT /api/challenges/{cid}/amounts/{aid}` ([AmountController.update](tenk-backend/src/main/java/com/hjson/tenk/domain/amount/AmountController.java)). 지출은 시간만, 무지출은 memo + 영상만 갱신. 영상은 `videoAction` (KEEP/REMOVE/REPLACE) 로 분기. Flutter 진입은 챌린지 상세의 [_AmountTile.onTap](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) → [AmountEditScreen](tenk_app/lib/presentation/amount/amount_edit_screen.dart). 영상 섹션은 record 와 같은 [VideoAttachmentSection](tenk_app/lib/presentation/amount/widgets/video_attachment_section.dart) 을 공유하지만 `expandable: true` 로 collapsed 노출 — "영상 보기" 탭 시 [AmountVideoPreviewScreen](tenk_app/lib/presentation/amount/amount_video_preview_screen.dart) 푸시 후 `VideoPreviewAction` 으로 retake/delete 반환 |
| 환경별로 다른 값 추가 | 공통은 `application.yaml`, 환경별 override는 `application-{local,prod}.yaml`. prod placeholder는 TODO 주석 유지 |
| 릴리스 빌드/서명/앱이름 변경 | 위 "릴리스 빌드 / 배포" 섹션이 진실의 원천. Android 서명은 `key.properties`+`tenk-release.keystore`(git 추적), 앱 이름은 `Tenk`(android:label + iOS CFBundleDisplayName 두 곳 동시), base URL 은 릴리스 시 `--dart-define=API_BASE_URL=https://tenk.hjson248.com` 필수. **릴리스 keystore 바꾸거나 새로 만들면 카카오 콘솔에 새 키해시 등록** 안 하면 로그인만 실패. iOS 는 맥+Apple 계정 필요 |
| 보호된 신규 엔드포인트 추가 | 기본적으로 인증 필요 (`SecurityConfig.PERMIT_ALL`에 없으면 자동 보호). 컨트롤러는 `@CurrentUserId Long userId`로 사용자 식별 |
| 백엔드 도메인/서비스 추가 | `src/test/java/com/hjson/tenk/domain/<name>/` 아래에 단위 테스트도 같이. 패턴은 기존 6개 테스트 (`ChallengeTest`, `ChallengeServiceTest`, `AmountServiceTest`, ...) 참고. 의존 repository는 Mockito `@Mock` + `@InjectMocks`, 도메인 entity는 정적 팩토리로 만들고 id 등 사후 박을 필드는 `ReflectionTestUtils.setField`. `LocalDate.now()` 모킹 불가 — "종료된 챌린지" 같은 상태는 invariant 통과 후 reflection으로 endDate 사후 박는 패턴 (`ChallengeServiceTest.finishedChallenge` 참고) |
| 새 이벤트 리스너 추가 | `@TransactionalEventListener(AFTER_COMMIT)`로 DB 쓰기를 한다면 리스너 메서드에 **반드시 `@Transactional(propagation = Propagation.REQUIRES_NEW)`** 같이 박을 것. 안 박으면 쓰기가 조용히 사라짐 ([BadgeEventListener](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeEventListener.java) 참고). 검증은 `@SpringBootTest` 통합 테스트로 — 단위 테스트는 못 잡는다 |
| 백엔드 통합 테스트 추가 | [IntegrationTestBase](tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) 상속. `@SpringBootTest` + `@ActiveProfiles("test")` + 트랜잭션 롤백 대신 `@BeforeEach`로 비-마스터 테이블 DELETE. **테스트 메서드 자체는 `@Transactional` 금지** — AFTER_COMMIT이 안 도는 함정 ([handoff.md §1·§2 검증 메모](docs/handoff.md)). 트랜잭션이 필요하면 `tx.execute(status -> ...)`로 명시 |
| 인증/필터 슬라이스 테스트 추가 | [JwtAuthenticationFilterWebMvcTest](tenk-backend/src/test/java/com/hjson/tenk/security/JwtAuthenticationFilterWebMvcTest.java) 패턴. `@WebMvcTest(SomeController.class)` + `@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtTokenProvider.class})` + `@EnableConfigurationProperties(AuthProperties.class)` + `@TestPropertySource`로 jwt secret 주입. 컨트롤러 협력자는 `@MockitoBean`. **Spring Boot 4 함정**: `WebMvcTest` import 가 `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest` 로 이동했다 (구 `...test.autoconfigure.web.servlet.WebMvcTest` 아님). 만료 토큰은 TTL 기반 `JwtTokenProvider`로 못 만드니까 같은 시크릿으로 `Jwts.builder()` 직접 호출해 expiration 만 과거로 박는다 |
| Flutter 새 도메인 추가 | ① 데이터: `lib/data/<feature>/<feature>.dart`(모델, `@immutable` + `fromJson`) + `<feature>_api.dart`(authDio 주입, `unwrapData`/`unwrapList` 사용). 여러 출처를 합쳐야 하면 `<feature>_repository.dart`도. ② DI: `lib/app/scopes.dart`에 `<Feature>Scope` 추가 + `main.dart`에서 인스턴스 생성·주입. ③ 화면: `lib/presentation/<feature>/<feature>_screen.dart`. 데이터 호출은 `<Feature>Scope.of(context)`로만 |
| Flutter 새 자산(이미지/폰트) 추가 | `tenk_app/assets/<feature>/` 아래에 두고 `tenk_app/pubspec.yaml`의 `flutter.assets`에 디렉토리(끝에 `/`) 등록. 디렉토리 등록은 그 안의 파일이 추가될 때 자동 인식. **새 자산은 hot reload 안 됨** — `R`(hot restart)로 반영. 자산이 없을 수도 있는 개발 중에는 `Image.asset(... errorBuilder:)`로 폴백 위젯을 두면 화면이 안 깨짐 ([badge_list_screen.dart](tenk_app/lib/presentation/badge/badge_list_screen.dart) `_IconFallback` 참고) |
| 배지 카탈로그 변경 | 서버는 `badge` 테이블의 9행(STREAK 3/7/14/30, NO_SPEND 3/7/14/30, CHALLENGE_SUCCESS 1)으로 고정. 새 단계/타입 추가 시 **네 곳을 동시에 갱신**: ① [docs/schema.sql](docs/schema.sql)의 INSERT (+ DB에 수동 적용) ② [tenk_app/lib/data/badge/badge.dart](tenk_app/lib/data/badge/badge.dart)의 `BadgeType` enum (label 매핑까지) ③ [tenk_app/assets/badges/](tenk_app/assets/badges/)에 아이콘 파일 ④ [_NoSpendTodayCard._ladder](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 의 NO_SPEND 단계 배열 (성취감 카드 게이지가 사다리로 사용). **챌린지 단위라 클라에 카탈로그 전체를 두지 않는다** — 획득한 것만 챌린지 응답에 인라인되므로 미획득 노출 위젯이 없음 |
| 배지를 부여하는 로직 변경 | [BadgeGrantService](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeGrantService.java) 는 항상 **챌린지 단위**로 평가. `evaluateForChallenge(challengeId)` / `grantChallengeSuccess(challengeId, result)`. 유저 단위 누적이 필요하면 새 서비스(추후 achievement 시스템)로 분리할 것 — 여기에 user 파라미터를 다시 끼우지 말 것. amount 쿼리는 `findByChallengeOrderBySpentDtAscCreatedDtAsc(challenge)` 사용. **STREAK는 연속, NO_SPEND는 누적** (서로 다른 행동에 대한 보상이라 정의가 다름). 단일 패스 `applyLadder` 가 grant/revoke 양방향을 처리 — 회수가 필요한 변경(예: 무지출 자동 삭제)에서도 별도 호출 없이 재평가만 하면 정합. |
| Flutter 새 화면의 비동기 로딩 | `AsyncStateMixin<W, T>` + `AsyncStateView<T>` 사용 ([presentation/common/async_state.dart](tenk_app/lib/presentation/common/async_state.dart)). `FutureBuilder` 금지. `fetch()` 오버라이드 + `didChangeDependencies`에서 `ensureLoaded()`. 외부 동작 결과를 즉시 반영하려면 `replaceData(next)`, 그 외 갱신은 `reload()`. 에러는 `toApiException(e).message`로 SnackBar 노출 |
| Flutter 새 공용 위젯 | 두 화면 이상이 같은 위젯을 쓰면 즉시 추출. 도메인 전용은 `presentation/<domain>/widgets/`, 도메인 무관은 `presentation/common/` |
| 날짜·시간 선택 / 시각 표기 추가·변경 | 진실의 원천은 [common/date_time_picker.dart](tenk_app/lib/presentation/common/date_time_picker.dart) — `pickTenkDate`/`pickTenkTime`(선택) + `formatTimeOfDay`/`formatDateWithTime`(표기). **화면에서 `showDatePicker`/`showTimePicker` 를 직접 부르거나 24시간제 고정 포맷을 새로 만들지 말 것** (위 "코딩 컨벤션 — Flutter" 참고). 한국어 라벨은 [main.dart](tenk_app/lib/main.dart) 의 `locale: Locale('ko')` 고정에서 오므로 **로케일을 시스템 추종으로 바꾸면 picker 만 영어로 튄다**. 시각 picker 본체는 자체 휠 위젯 [wheel_time_picker.dart](tenk_app/lib/presentation/common/wheel_time_picker.dart) — 무한 순환·직접 입력·**오전/오후 자동 전환 경계는 11↔12**(12↔1 아님)가 모두 UX 결정이라 유지. 폼의 `날짜 \| 시간` 2칸은 [DateTimeFields](tenk_app/lib/presentation/amount/widgets/date_time_fields.dart) 공유 (수정 화면은 날짜 읽기 전용) |
| 색·타이포·여백·컴포넌트 기본 스타일 변경 | 진실의 원천은 [design/tokens.dart](tenk_app/lib/design/tokens.dart)(`AppColors`/`AppTypo`/`AppSpacing`/`AppRadius`) + [design/app_theme.dart](tenk_app/lib/design/app_theme.dart)(`buildTenkTheme`). **화면에 hex·매직넘버 직접 박지 말 것** — 토큰을 가져다 쓰거나 토큰을 고쳐라. 컴포넌트(버튼/카드/입력 등) 기본 룩은 개별 화면이 아니라 app_theme 에서. 방향("절제+리워드")·팔레트(민트+화이트) 근거는 위 "디자인 시스템" + `references/`. **예외**: 오프스크린 캡처되는 결과 카드는 색 hardcode 유지 |
| 챌린지 목록 화면/상태 표시 변경 | [challenge_list_screen.dart](tenk_app/lib/presentation/challenge/challenge_list_screen.dart)(상태 탭·그룹핑·정렬) + [challenge_card.dart](tenk_app/lib/presentation/challenge/widgets/challenge_card.dart)(카드) + [challenge_status.dart](tenk_app/lib/presentation/challenge/widgets/challenge_status.dart)(`ChallengeStatusStyle` = 라벨·색·틴트 단일 매핑). 정렬/필터는 클라이언트 처리(백엔드 무변경). 위 "챌린지 목록 IA" 가 규칙의 진실의 원천 |
| camera 패키지 fork 갱신 | [tenk_app/vendor/camera_patched/camera_android_camerax](tenk_app/vendor/camera_patched/camera_android_camerax) 가 업스트림 `camera_android_camerax` 의 fork. `pubspec.yaml` `dependency_overrides` 로 주입. **패치 두 군데**: `initializeCamera` 의 `bindToLifecycle` 리스트 (`imageAnalysis` 자리에 `videoCapture` 를 넣음) + `stopVideoRecording` 의 `_unbindUseCaseFromLifecycle(videoCapture!)` 제거. 둘 다 `[tenk fork patch]` 주석으로 표시. **사유**: 업스트림은 VideoCapture 를 lazy bind 라 매 녹화 시작마다 Camera2 capture session 이 재구성돼 preview freeze. eager bind 로 전환해 freeze 자체 제거. Tenk 가 image stream 을 안 써서 ImageAnalysis 를 lazy 로 미뤄도 무해. **업스트림 버전 올릴 때**: pub cache 에서 신버전 디렉토리 통째로 vendor 에 덮어쓰고 두 지점 재적용. CameraX UseCase 조합 표 ([공식 문서](https://developer.android.com/media/camera/camerax/architecture#combine-use-cases)) 기준 P+IC+VC 는 LIMITED 이상 지원 — 4-way 는 LEVEL_3 한정이므로 ImageAnalysis 를 같이 추가하지 말 것 |
| 영상 export 합성 파이프라인 변경 | [VideoComposer](tenk_app/lib/data/export/video_composer.dart) 에서 ffmpeg 명령 구성. **인코더는 sw `mpeg4` 고정 — 바꾸지 말 것**. `h264_mediacodec`(hw silent fail) / `libx264`(GPL · 빌드 미포함) / `libkvazaar`(native crash) 모두 실격됐고 경로는 `_videoEncoder` 주석 + [decisions.md "함정 — H.264/HEVC sw 인코더 다 막힘"](docs/decisions.md) 에 박혀 있다. **자막은 ffmpeg drawtext 대신 Flutter `TextPainter` 로 PNG 그려 `overlay` 필터로 합성 — drawtext 로 회귀하지 말 것** (ffmpeg 8.0 의 multi-codepoint 한글 silent drop 회귀, [decisions.md "함정 — drawtext 한글 회귀"](docs/decisions.md) 참고). 자막 좌표/폰트크기/박스 스타일은 `_drawTextBlock` 안에서 조절. **자막 위치(중단/하단)·배경(박스 vs 외곽선)은 사용자가 export 설정 화면([ExportSettingsScreen](tenk_app/lib/presentation/challenge/export/export_settings_screen.dart))에서 영상 전체 단위로 고름** — `SubtitlePosition` enum + `compose(subtitlePosition, subtitleBackground)` → `_renderTextOverlayPng` → `_drawTextBlock(withBox/withOutline, centerY)`. 상단은 대시보드와 겹쳐 제외했고 대시보드 자체는 항상 `withBox:true` 유지(자막만 영향). 흐름은 `includeResultCard` 와 동일하게 ExportSettingsScreen state → ExportComposeScreen 생성자 → compose 로 thread. 합성 파라미터(해상도/비트레이트/xfade 길이 등)는 모두 클래스 상단 상수. **결과 카드 마지막 클립**은 `resultCardPngPath` 옵션으로 합성 — `_normalizeStaticImageClip` 가 `-loop 1 -t 3.0` 으로 3초 정지 클립 만들고 `_concatWithXfade` 가 가변 duration 으로 xfade offset 누적 |
| 결과 카드 도메인 변경 | [ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) 가 480x864 고정 사이즈로 모든 콘텐츠를 그린다 — 좌표/폰트 크기는 영상 export 해상도와 1:1. **색은 ThemeData 안 쓰고 hardcode** (캡처 시 컨텍스트 영향 회피). 빈 슬롯 (배지 0개 / 무지출 0일) 은 라인 통째 생략 — 자리 흔들리지 않게. 캡처는 [ResultCardCapture](tenk_app/lib/data/export/result_card_capture.dart) 가 Overlay off-screen + RepaintBoundary 패턴으로 처리 (배지 자산 `precacheImage` + 2 frame 대기 필수). 진입점은 ① [ChallengeDetailScreen._finalize](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 의 finalize 직후 자동 push (배지 큐 뒤) ② [_ResultCardEntryCard](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) (확정 후에만 노출) ③ 영상 export 마지막 클립 (체크박스 기본 ON). 영상용은 `pixelRatio: 1.0` (480x864), 갤러리/공유는 `2.0` (HiDPI). 배지 카탈로그를 바꾸면 결과 카드 안의 `_BadgeRow` (최대 6 + N) 도 같이 검토 |
| 닉네임 정책 변경 | 진실의 원천은 [UserService.updateNickname](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserService.java) — trim 후 NICKNAME_FORBIDDEN_CHARS (`\p{Cc}\p{Cf}`) / NICKNAME_MAX_LENGTH (50) / enforceChangeCooldown(24h) 3단 검증. **쿨다운 상수 `NICKNAME_CHANGE_COOLDOWN` 은 `UserService`(판정)와 [UserResponse.computeAvailableFrom](tenk-backend/src/main/java/com/hjson/tenk/domain/user/dto/UserResponse.java)(안내 시각) 양쪽에 있으니 바꿀 땐 둘 다 + 앱 안내 문구(`_NicknameEditDialog` / [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 의 "24시간" 문구) 까지 같이.** 거부 패턴/길이를 바꾸려면 클라 측 1차 검증 [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) `_forbiddenChars` + [my_info_screen.dart](tenk_app/lib/presentation/profile/my_info_screen.dart) `_NicknameEditDialog._forbiddenChars` 도 동일하게. 같은 값 PATCH 는 `User.changeNickname` 에서 멱등 no-op — 이걸 깨면 가입 화면 흐름이 1회 제한에 걸린다. 카카오 재로그인 시 닉네임 동기화는 절대 다시 추가하지 말 것 — [AuthService.provisionUser](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java) 의 기존 사용자 분기는 `updateEmail` 만 호출. `isNewUser` 가 가입 화면 분기의 trigger 라 응답에서 누락되면 신규 사용자가 카카오 닉네임으로 자동 가입되어 설정 화면을 못 본다 |
| 챌린지 이름 정책 변경 | 진실의 원천은 [Challenge.validateAndNormalizeName](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/Challenge.java) — trim 후 1~100자(`NAME_MAX_LENGTH`) + `NAME_FORBIDDEN_CHARS` (`\p{Cc}\p{Cf}`). **이름은 필수 — 비울 수 없다.** 서버는 빈값 거부 (`ChallengeCreateRequest.name` `@NotBlank` 1차, 엔티티 2차). 기본값 `챌린지 N` 은 **클라이언트가 생성**해 미리 채운다 ([challenge_list_screen `_openCreate`](tenk_app/lib/presentation/challenge/challenge_list_screen.dart), N = `data.length + 1`) — 서버엔 더 이상 default-fill 로직 없음(`resolveName` 제거됨). 이름 변경은 `PATCH /api/challenges/{id}` ([ChallengeService.rename](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeService.java)) — 게이트는 `result != null` (확정 후 차단, amount 수정과 동일 기준). 거부 패턴/길이를 바꾸면 클라 1차 검증도 같이: [challenge_create_screen.dart](tenk_app/lib/presentation/challenge/challenge_create_screen.dart) `_forbiddenChars`(+빈값 거부) + [challenge_detail_screen.dart](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) `_RenameDialogState._forbiddenChars`. 노출 위치 3곳: 목록 카드 / 상세 AppBar 타이틀(+result==null 일 때만 연필 아이콘) / 결과 카드 헤더. `ChallengeResponse.name` 누락되면 Flutter `Challenge.fromJson` 이 깨짐 (non-null) |
| 메뉴 / '내 정보' / 회원 탈퇴 흐름 변경 | 진입점은 [ChallengeListScreen](tenk_app/lib/presentation/challenge/challenge_list_screen.dart) AppBar 의 `Icons.menu`(햄버거) IconButton → [ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart)(순수 메뉴) push. 메뉴는 내 정보(→ [MyInfoScreen](tenk_app/lib/presentation/profile/my_info_screen.dart): 닉네임·성별) + 계정 설정(→ [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart)) + 법적 고지(→ [LegalNoticeScreen](tenk_app/lib/presentation/legal/legal_notice_screen.dart): 약관·개인정보·**오픈소스 라이선스**(showLicensePage)) + **앱 버전 행**(`_AppVersionTile` — 현재 버전+최신여부, 업데이트 있으면 스토어로) 으로 분기한다. **새 항목은 "본인 정보 → 내 정보 / 계정 자체 → 계정 설정 / 설정성(소리·진동 등) → 새 '알림/효과 설정' 하위 화면" 기준으로 배치** (최상위에 토글 두지 말 것). **로그아웃은 AccountSettingsScreen 소유. 회원 탈퇴는 계정 설정이 confirm 다이얼로그로 의사만 확인하고, 실제 처리는 [WithdrawScreen](tenk_app/lib/presentation/profile/withdraw_screen.dart) 소유** — 사유(선택) 입력 후 `UserScope.withdraw(reason, detail)` → `AuthScope.logout()` (storage clear) → LoginScreen 으로 `pushAndRemoveUntil`. **확인 → 사유 순서를 뒤집지 말 것** (위 "탈퇴 사유" 규칙). 백엔드는 [User.withdraw](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) 로 soft delete(`deleted_dt` 기록) + RT 무효화 후, 새벽 배치 [UserRetentionScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java)/[WithdrawnUserPurgeService](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 **탈퇴 1개월 후 challenge/amount/media_file row + 디스크 영상 + refresh_token 까지 물리 삭제**. 보관 기간 상수(`RETENTION`)를 바꾸면 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §3 + [delete-account.html](tenk-backend/src/main/resources/static/delete-account.html) 도 같이 갱신 (진실의 원천 = 개인정보처리방침과 코드 일치). **탈퇴 확인 다이얼로그는 철회를 안내하지 않는다 (의도)** — 위 "탈퇴 철회" 규칙 참고. 파기 삭제 순서는 FK 자식→부모 (디스크→media_file→challenge_badge→amount→challenge→refresh_token→user) — 새 자식 테이블 추가 시 순서 앞쪽에 끼울 것. **회귀 가드는 [WithdrawnUserPurgeIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeIntegrationTest.java)** (보관기간 경계 + 디스크 파일 삭제 + 타 계정 격리) — 자식 테이블을 추가하면 이 테스트의 시딩·`Counts` 에도 같이 넣을 것 |
| 탈퇴 사유 항목 추가·변경 | 위 "인증 — 탈퇴 사유" 규칙이 진실의 원천. **서버 [WithdrawalReason](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawalReason.java) enum 과 [withdraw_screen.dart](tenk_app/lib/presentation/profile/withdraw_screen.dart) 의 `_reasons` 를 같은 코드로 동시 갱신** (서버는 코드만, 표시 문구는 클라). 이미 저장된 상수는 지우거나 이름을 바꾸지 말 것 — 과거 데이터가 매핑을 잃는다. 저장은 [WithdrawalFeedback](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawalFeedback.java)(익명, `user_id` 없음) + [schema.sql](docs/schema.sql) `withdrawal_feedback`. **컬럼을 늘릴 땐 식별 가능성부터 따질 것** — user 참조가 들어가는 순간 개인정보가 되어 privacy.html 수집표·보관 기간 규칙이 따라붙는다. 회귀 가드는 [WithdrawalFeedbackIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawalFeedbackIntegrationTest.java) 4건(선택성·익명성·미지 코드 거부·파기 후 생존) |
| 탈퇴 후 복귀(철회/재가입) 흐름 변경 | 위 "인증 — 탈퇴 후 유예 기간" 규칙이 진실의 원천. 백엔드는 [AuthService](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java) 의 `restoreWithdrawnAccount`/`rejoinAfterWithdrawal` + `POST /api/auth/kakao/{restore,rejoin}`(SecurityConfig PERMIT_ALL) + [User.restoreFromWithdrawal](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) + 재가입 시 [WithdrawnUserPurgeService.purgeImmediately](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java)(**`REQUIRES_NEW` 유지 필수** — 파기가 먼저 커밋돼야 unique 키가 풀린다). 클라는 [AuthRepository](tenk_app/lib/data/auth/auth_repository.dart) 의 `WithdrawnAccountException`(→ `restoreWithdrawnAccount` / `rejoinAfterWithdrawal` / `abandonRestore`) + [LoginScreen._offerWithdrawnChoice](tenk_app/lib/presentation/login/login_screen.dart). **이 경로에서만 카카오 세션을 즉시 폐기하지 않는다** — 폐기하면 사용자가 카카오 로그인을 처음부터 다시 타야 해서, 그 토큰을 `restoreTicket` 으로 넘겨 재사용하고 확정·취소 시점에 정리한다. 로그인 후 라우팅은 `_enterApp` 하나를 로그인·철회·재가입이 공유(게이트 순서가 갈라지지 않게). 회귀 가드는 [AuthWithdrawalReturnIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/auth/AuthWithdrawalReturnIntegrationTest.java) 7건 + `AuthServiceTest` 단위 7건 |
| 필수 동의 정책/문서/화면 변경 | 진실의 원천은 [User.agreeToRequiredConsents](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java)(`terms_agreed_dt`/`privacy_agreed_dt` 스탬프, 미동의 항목만) + `hasAgreedToRequiredConsents`. 컬럼 추가라 [schema.sql](docs/schema.sql) 동기화 + **라이브 DB 는 ALTER 수동 적용**(schema.sql 주석 참고). `consentRequired` 는 [UserResponse](tenk-backend/src/main/java/com/hjson/tenk/domain/user/dto/UserResponse.java) + [AuthTokens](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthTokens.java) 양쪽에서 계산. 클라 게이트는 [LoginScreen](tenk_app/lib/presentation/login/login_screen.dart)(로그인 직후 3분기) + [SessionGate](tenk_app/lib/app/session_gate.dart)(앱 시작 `/me` 확인, fail-open). 동의 화면은 [ConsentGateScreen](tenk_app/lib/presentation/legal/consent_gate_screen.dart)(공용 [ConsentSection](tenk_app/lib/presentation/legal/consent_section.dart) 사용) 하나로 통일하고 `next` 파라미터로 다음 화면 분기(신규=[NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart), 기존=홈). **동의 화면과 닉네임 설정 화면은 분리 — 닉네임 화면에 동의를 다시 임베드하지 말 것.** **문서를 추가/변경**하면 백엔드 static(privacy.html/terms.html) + SecurityConfig PERMIT_ALL + [legal_config.dart](tenk_app/lib/config/legal_config.dart) URL 동시 갱신. 내부 테스터(TESTER)도 일반 카카오 계정이라 동의 게이트를 정상적으로 탄다(예전 테스트 로그인 auto-consent 는 제거됨). 선택 동의(마케팅)는 현재 없음. **회귀 가드는 [UserConsentIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserConsentIntegrationTest.java)**(엔드포인트 계약) + `UserServiceTest`(스탬프 멱등 규칙) |
| 연령 확인 정책/화면 변경 | 진실의 원천은 [UserService.verifyAge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserService.java) (`MINIMUM_AGE`) + [User.verifyAge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java). **최소 연령을 바꾸면 [terms.html](tenk-backend/src/main/resources/static/terms.html) · [privacy.html](tenk-backend/src/main/resources/static/privacy.html) · Play Console 타겟 연령대([docs/play-console-app-content.md](docs/play-console-app-content.md) §5) 를 전부 같이** 갱신 (숫자가 어긋나면 심사에서 걸린다). 컬럼 추가라 [schema.sql](docs/schema.sql) 동기화 + 라이브 DB `ALTER` 수동 적용. 클라 게이트는 [LoginScreen](tenk_app/lib/presentation/login/login_screen.dart) + [SessionGate](tenk_app/lib/app/session_gate.dart) 의 "안쪽부터 감싸기" 배선(연령→동의→닉네임→홈). [AgeGateScreen](tenk_app/lib/presentation/legal/age_gate_screen.dart) 의 중립성 3원칙(컷오프 비노출·기본값 없음·이탈 차단)은 정책 요건이라 유지. 미만 판정 시 `purgeImmediately` 의 **`REQUIRES_NEW` 를 빼지 말 것**. 회귀 가드는 [UserAgeVerificationIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserAgeVerificationIntegrationTest.java) 6건 + `UserServiceTest` 단위 5건 |
| 선택 수집 항목(성별 등) 추가·변경 | 진실의 원천은 위 "성별 (선택 수집)" 규칙. **선택 항목은 ① 가입 흐름 밖(내 정보)에서 ② 목적 고지와 함께 ③ 언제든 되돌릴 수 있게** 받는다. 새 선택 항목을 추가하면 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) 수집표(선택 표기)·이용목적 + [play-console-app-content.md](docs/play-console-app-content.md) §6-2 데이터 안전표(목적 '분석', 선택)를 같은 커밋에서 갱신. **기능에 안 쓰이는 항목을 필수로 받지 말 것** |
| Play Console 앱 콘텐츠(데이터 안전·콘텐츠 등급·타겟층) 입력 | [docs/play-console-app-content.md](docs/play-console-app-content.md) 가 답안지이자 진실의 원천. **수집 항목·권한·SDK·연령 정책을 바꾸면 이 문서 + privacy.html + Play Console 폼 3곳을 같은 커밋에서** 갱신할 것 — 셋이 어긋나면 심사에서 불일치로 걸린다. 광고 SDK 를 도입하면 §3(광고)뿐 아니라 §5(가족 정책 인증 SDK 요건)도 함께 재검토 |
| 앱 버전 정책 / 강제·권장 업데이트 변경 | 위 "앱 버전 / 강제·권장 업데이트" 도메인 규칙이 진실의 원천. **최신/최소 버전 값은 코드가 아니라 `app_config` 행** — 재배포 없이 `UPDATE app_config SET latest_version=..., min_supported_version=... WHERE app_config_id=1;` 로 바꾼다(관리자 UI 없음, TESTER 승격과 동일 운영). 라이브 DB 는 [schema.sql](docs/schema.sql) `app_config` CREATE+INSERT 를 수동 적용해야 부팅됨. 판정 로직은 [AppVersionService](tenk-backend/src/main/java/com/hjson/tenk/domain/app/AppVersionService.java)/[SemanticVersion](tenk-backend/src/main/java/com/hjson/tenk/domain/app/SemanticVersion.java)(**서버가 진실의 원천 — 클라는 semver 비교 안 함**), 엔드포인트 `GET /api/app/version`(PERMIT_ALL). 클라 게이트는 [SessionGate](tenk_app/lib/app/session_gate.dart)(버전 게이트를 **가장 먼저**) + [update_gate.dart](tenk_app/lib/presentation/update/update_gate.dart)(ForceUpdateScreen/RecommendedUpdateHost). **fail-open 원칙 유지**(서버·버전 이상 시 게이트 미적용 — 앱을 잠그지 않는다). 릴리스 시 pubspec `version` 을 올리고 스토어 게시 후 `latest_version` 을 SQL 로 맞출 것. 회귀 가드는 [AppVersionServiceTest](tenk-backend/src/test/java/com/hjson/tenk/domain/app/AppVersionServiceTest.java)/[SemanticVersionTest](tenk-backend/src/test/java/com/hjson/tenk/domain/app/SemanticVersionTest.java)/[AppVersionIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/app/AppVersionIntegrationTest.java) |
| 테스트 시딩(devtools) 변경 | 위 "테스트 지원 (devtools)" 도메인 규칙이 진실의 원천. 백엔드 [TestSupportService](tenk-backend/src/main/java/com/hjson/tenk/devtools/TestSupportService.java) + [TestSupportController](tenk-backend/src/main/java/com/hjson/tenk/devtools/TestSupportController.java). **시딩 상태를 추가/변경**하면 `seedAll` 만 손대면 됨(챌린지는 reflection backdate, 금액·배지는 정상 팩토리/서비스 재사용). **게이팅 = 계정 role** — seed 는 `role=TESTER` 계정만 허용([UserRole.canUseTestTools](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRole.java)), 이 가드를 풀지 말 것(호출자 본인 데이터 wipe 위험). 클라 버튼은 `user.isTester`(=`role=='TESTER'`)로 노출. **테스트 로그인(카카오 우회)은 회의 결정으로 제거됨 — 다시 추가하지 말 것**([decisions.md](docs/decisions.md) "테스터 로그인 회의"). 회귀 가드는 [TestSupportServiceIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/devtools/TestSupportServiceIntegrationTest.java) 3건(시딩 5종 + wipe 멱등 + 비-TESTER 거부) |

## 미해결/다음 단계

진행 상태와 남은 작업은 [docs/handoff.md](docs/handoff.md) 참고.
