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
| 테스트(백엔드) | JUnit5 + Mockito + AssertJ. 총 **254개** (2026-08-06 실측, 전원 통과). 구성은 단위(엔티티·서비스 Mockito) + `@SpringBootTest` 통합 E2E + `@WebMvcTest` 인증 필터 슬라이스 4 + 컨텍스트 로드 1. 최근 증분: 문의하기 239 → **관리자 패널 15**(E2E — 인증 격리·CSRF·처리·승격 + **앱 체인 무회귀 2** + **접속기록 5**) 추가로 254. ⚠️ **`app_config`·`withdrawal_feedback`·`feedback`·`inquiry`·`admin_user` 테이블이 있어야 돈다** — 로컬/CI 에 [schema.sql](docs/schema.sql) 의 해당 CREATE(+app_config INSERT) 선적용 필요. `@SpringBootTest` 통합은 **로컬 MariaDB의 `tenk` 스키마를 그대로 사용**하므로 매 테스트 실행 시 user/challenge/amount 등 dev 데이터가 함께 비워진다 (Flutter 재로그인으로 복구). 패턴은 [IntegrationTestBase](tenk-backend/src/test/java/com/hjson/tenk/support/IntegrationTestBase.java) 참고. WebMvc 슬라이스는 DB 없이 가볍게 돈다 ([JwtAuthenticationFilterWebMvcTest](tenk-backend/src/test/java/com/hjson/tenk/security/JwtAuthenticationFilterWebMvcTest.java)) |

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
- **성별 (선택 수집)**: `user.gender VARCHAR(10) NULL` (`MALE`/`FEMALE` **2종 — '기타'는 없다**, [Gender](tenk-backend/src/main/java/com/hjson/tenk/domain/user/Gender.java)). **NULL(미입력)이 정상 상태이고 서비스 기능은 이 값을 전혀 쓰지 않는다** — 수집 목적은 이용자 통계뿐. `PATCH /api/users/me/gender { gender }`, **`gender: null` 이면 미입력으로 되돌린다(수집 철회 — 이 경로를 막지 말 것)**.
  - **입력 UI 는 [GenderEditScreen](tenk_app/lib/presentation/profile/gender_edit_screen.dart) 의 `SegmentedButton` 3칸 — 남성 / 입력 안 함 / 여성** (2026-07-29, `OTHER` 제거와 같은 건). **'입력 안 함' 이 가운데**인 건 좌우가 값이 되는 대칭 배치라서고, 값들과 **동등한 칸**이어야 한다는 정책 요건(수집 철회의 동등 노출)도 이걸로 충족한다.
  - ⚠️ **`Gender` 상수를 지울 때는 `UPDATE user SET gender=NULL WHERE gender='<지운 값>';` 를 반드시 짝으로 칠 것.** `@Enumerated(EnumType.STRING)` 이라 enum 에 없는 문자열이 DB 에 남아 있으면 **그 유저 조회가 예외로 죽는다.**
  - **가입 흐름에 넣지 말 것.** '내 정보' 화면([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart))에서 사용자가 원할 때만 입력한다. 다이얼로그는 ① 수집 목적을 그 자리에서 고지하고 ② '입력 안 함' 을 동등한 선택지로 노출한다. **필수로 바꾸거나 온보딩으로 옮기면 개인정보 최소수집 원칙(PIPA)에 걸린다** — 기능에 안 쓰이는 항목이라 필수 수집을 정당화할 근거가 없다.
  - 연령대 통계는 `birth_date` 로 이미 산출 가능하므로 통계 목적으로 항목을 더 늘리지 말 것.
  - **변경을 제한하지 않는 게 의도된 설계다 (2026-07-29 확정).** 쿨다운·1회 확정 같은 마찰을 넣지 말 것 — ① 우리가 여는 건 '성별 변경'이 아니라 **'입력값 정정'** 이고, 편집을 막으면 오탭이 **영구 고착**돼 데이터 품질이 오히려 나빠진다(노이즈는 편집이 아니라 최초 입력에서 들어온다) ② 정정·삭제·철회는 법상 권리라 앱에서 막아도 **문의 창구로 수작업 처리할 의무만 남고**, 정확성·최신성 보장 원칙에도 어긋난다 ③ privacy.html §1 이 "언제든 되돌려 삭제할 수 있다" 고 **이미 공개 약속**했다. 잠그는 서비스는 실명인증 기반이거나 성별이 혜택과 연동된 경우뿐인데 TenK 은 둘 다 아니다. 근거는 [decisions.md](docs/decisions.md) "성별 수집·변경".
  - **변경 이력·변경 시각을 저장하지 말 것.** 성별 변경 이력은 **아웃팅 위험이 있는 정보**라 통계 정확도와 바꿀 수 있는 게 아니다. 지금 이력이 안 남는 것은 우연이 아니라 규칙이다 — "감사 목적" 으로도 컬럼을 붙이지 말 것.
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
- **메뉴 화면** ([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart)) — 챌린지 리스트 AppBar 의 `account_circle_outlined` 버튼에서 진입. **자체 콘텐츠 없이 하위 화면으로만 분기하는 순수 메뉴**: **내 정보**(→ [MyInfoScreen](tenk_app/lib/presentation/profile/my_info_screen.dart): 닉네임·성별) → **계정 정보**(→ [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart): 연동 계정·로그아웃·회원 탈퇴) → **설정**(→ [SettingsScreen](tenk_app/lib/presentation/settings/settings_screen.dart): 효과음·진동) → **의견 보내기**(→ [FeedbackScreen](tenk_app/lib/presentation/feedback/feedback_screen.dart)) → **설정** → **고객센터**(→ [CustomerSupportScreen](tenk_app/lib/presentation/support/customer_support_screen.dart): 문의하기) → **법적 고지**(→ [LegalNoticeScreen](tenk_app/lib/presentation/legal/legal_notice_screen.dart): 이용약관·개인정보처리방침·오픈소스 라이선스) → 테스트 재생성(dev). **전부 별도 하위 화면으로 push**(섹션 아님). 로그아웃·회원 탈퇴 로직은 AccountSettingsScreen 소유(연동 계정 = 공급자 표시. 메뉴가 로드한 User 를 넘겨 재fetch 없음).
  - **경계**: '내 정보' = **사용자 본인에 대한 정보**(닉네임·성별), '계정 정보' = **계정 자체**(연동·로그인·탈퇴), '설정' = **앱 동작 환경**(효과음·진동, 추후 알림), '의견 보내기' = **익명으로 가볍게 남기는 제품 의견**(그래서 최상위), '고객센터' = **답변이 필요한 문의**(계정 연결), '법적 고지' = **고지 문서 전용**. 새 항목은 이 기준으로 배치할 것. '의견 보내기'·'고객센터'는 정적 문서인 법적 고지보다 **위**에 둔다 — 사용자가 능동적으로 하는 행동이라서.
  - **'계정 설정' → '계정 정보' 로 개명 (2026-08-01).** 바로 아래에 '설정' 이 생겨 그대로 뒀으면 **"설정이 두 개"** 로 읽혔다. **표시 라벨만 바꾸고 클래스·파일명(`AccountSettings*`)은 유지** — 브랜드를 TenK 로 통일할 때 내부 식별자를 안 건드린 것과 같은 논리다. 되돌리지 말 것.
  - **메뉴는 `/api/users/me` 를 기다리지 않고 즉시 렌더한다** (2026-07-26). 순수 내비게이션 허브라 user 없이도 그릴 수 있고, `user` 는 **TESTER 타일 노출 판정 + 계정 설정에 넘길 값**에만 쓰인다. 그래서 `AsyncStateMixin`/`AsyncStateView` 로 감싸지 않고 `User? _user` 를 직접 든다(컨벤션의 "두 종류 이상의 비동기 자원" 케이스 — 앱 버전 타일이 이미 두 번째 자원). **`/me` 실패해도 ErrorView 로 덮지 말 것** — 오프라인에서 법적 고지·앱 버전조차 못 여는 게 로딩보다 나쁘다. 같은 이유로 [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart) 의 `user` 는 **nullable** 이고 null 이면 스스로 읽는다(메뉴가 아직 못 받았을 수 있으므로). 메뉴가 값을 갖고 있으면 그대로 넘겨 재fetch 없음.
    - **'앱 버전' 행도 네트워크를 안 탄다 (2026-07-28)** — 부팅 때 SessionGate 가 이미 판정해둔 `AppApi.lastKnownVersion` 을 첫 프레임에 동기로 읽어 그린다(아래 "앱 버전" 규칙). 확인 실패로 캐시가 비었을 때만 여기서 한 번 더 부른다.
    - **반대로 '내 정보'(MyInfoScreen) 의 진입 로딩은 정상이고 없애지 말 것 (2026-07-28 결정).** 메뉴와 달리 닉네임·성별이 **화면 콘텐츠 그 자체**라 값 없이 그릴 게 없고, 캐시를 끼우면 로그아웃·탈퇴 후 재로그인 때 이전 계정 값이 한 프레임 비친다. 닉네임 쿨다운(`nicknameChangeAvailableFrom`)도 stale 하면 잠금 안내가 틀린다. 근거는 [decisions.md](docs/decisions.md) "메뉴 앱 버전 행 회의".
  - MyInfoScreen 의 닉네임 행은 변경 불가 상태면 **`lock_outline` 아이콘만** 노출하고, 다시 가능해지는 시각은 **탭했을 때 SnackBar 로만** 알려준다 (상시 라벨 없음 — 위 닉네임 정책 참고). 메뉴로 돌아오면 `reload()` 로 갱신(닉네임 변경분이 '계정 설정'에 넘길 User 에도 반영되게).
  - **메뉴 화면 제목 = '메뉴', 진입 아이콘 = `Icons.menu`(햄버거) 로 확정 (2026-07-25).** 이 허브는 설정(preference) 모음이 아니라 내 정보·계정·법적 고지·앱 정보 등 **이질적 항목을 모아 분기하는 메뉴**라서 '설정'이 아니다. 예고대로 **설정성 항목은 최상위 토글이 아니라 하위 '설정' 화면**으로 들어갔다(2026-08-01 신설) — 새 설정도 최상위에 토글로 붙이지 말고 그 화면에 넣을 것.
- **회원 탈퇴 = soft delete 후 1개월 유예 → hard delete**. 탈퇴 즉시 [User.withdraw](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) 로 `is_deleted=true` + `deleted_dt` 기록 + 모든 RT 무효화. 이후 매일 새벽 1:30 배치 [UserRetentionScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java) 가 `deleted_dt` 로부터 **1개월(`WithdrawnUserPurgeService.RETENTION`) 지난 계정**을 물리 삭제 — challenge/amount/media_file row + **디스크 영상 파일** + refresh_token 까지 cascade ([WithdrawnUserPurgeService.purge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java), FK 안전 순서: 디스크→media_file→challenge_badge→amount→challenge→refresh_token→inquiry→user). 유저 1명 단위 트랜잭션 — 스케줄러가 유저별로 외부 호출해 `@Transactional` 프록시를 살린다(self-invocation 금지). 보관 기간(1개월)은 개인정보처리방침 §3 과 일치시킬 것. **개인정보처리방침**은 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) → `https://tenk.hjson248.com/privacy.html` 로 서빙 (SecurityConfig PERMIT_ALL 등록). Play Console 개인정보처리방침 URL·앱 내 링크가 이 주소를 가리킨다.
  - ⚠️ **법적 문서 2종(privacy·terms)의 유지 기준 = "문서 = 실제 동작" 이다** (2026-08-06 확정 — 변호사 검수를 백로그에서 뺀 대신 이 원칙을 남겼다). **모든 문장은 코드·배치·설정에 대응하는 사실이어야 하고, 하지 않는 것을 적지 말 것** — 지키지 못할 약속이 되고 사고 시 오히려 불리해진다. 대응 관계가 비자명한 곳(§8 안전성 확보조치)은 **문서 안에 HTML 주석으로 대응 코드를 적어뒀다.** 정책·조치를 바꾸면 같은 커밋에서 문서도 고칠 것.
  - 법률 자문이 필요해지는 트리거: **결제 도입 · 광고 SDK · 제3자 제공 · 해외 이전** — 문서가 사실 서술을 넘어 법적 판단을 요구하게 될 때.

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
  - **진실의 원천 = 서버 enum** [SpendCategory](tenk-backend/src/main/java/com/hjson/tenk/domain/amount/SpendCategory.java) (코드+한글 label). 엔티티 필드는 **`SpendCategory` + `@Enumerated(EnumType.STRING)`**(컬럼 `VARCHAR(20)`, 2026-07-30 전환 — 그 전엔 raw String 이었다).
    - **외부 입력(String) → enum 변환은 `SpendCategory.from(String)` 한 곳에서만** 하고, 호출은 **엔티티 정적 팩토리 안**(`Amount.spend()`/`update()` 의 지출 분기)에서만 한다. 9종 밖이면 `AMOUNT_CATEGORY_INVALID`(A0008).
    - ⚠️ **`from` 은 null·공백에 예외를 던지지 않고 null 을 돌려준다 — 이 계약을 깨지 말 것.** "카테고리를 안 보냄"은 `AMOUNT_CATEGORY_CONTENT_REQUIRED`(A0005)이고 "이상한 값을 보냄"이 A0008 이라, 미입력 판정은 호출자(엔티티)가 먼저 한다. `from` 이 공백에 던지면 두 에러가 하나로 뭉개진다. 회귀 가드는 [SpendCategoryTest](tenk-backend/src/test/java/com/hjson/tenk/domain/amount/SpendCategoryTest.java).
    - **요청/응답 DTO 필드는 계속 `String`** — 요청은 Jackson 이 먼저 파싱에 실패하면 A0008(한국어 메시지) 대신 범용 400 이 나가고, 응답은 클라가 코드를 받아 라벨·아이콘으로 매핑하는 계약이라 wire format 을 유지해야 한다. `AmountResponse` 는 `.name()` 으로 내보낸다. 회귀 가드는 `AmountTest.response_emits_category_as_code_string`.
    - **네이티브 SQL 로 amount 를 넣는 테스트 헬퍼는 반드시 유효 코드를 쓸 것** — 엔티티 검증을 우회하므로 `'x'` 같은 값을 넣으면 *읽을 때* enum 매핑이 깨진다 (실제로 통합 테스트 5건이 이 이유로 깨졌다).
  - 클라 매핑은 [spend_category.dart](tenk_app/lib/presentation/amount/spend_category.dart) `kSpendCategories` (code/label/icon) + `spendCategoryForCode()`(미매칭→기타 폴백)가 진실의 원천. 입력은 기록/수정 화면의 **`DropdownButtonFormField` 셀렉박스**(항목마다 아이콘+라벨, value=code. 폼 필드라 validator 로 미선택 검증), 표시는 상세 타일 leading 아이콘·타이틀 라벨 + export 목록 라벨. **카테고리 목록을 바꾸면 서버 enum + 클라 `kSpendCategories` 를 같은 코드로 동시 갱신** (아이콘도 함께). export JSON 통계의 `CategorySummary.category` 는 코드 그대로(외부 연동 안정 키).
  - **마이그레이션 주의**: 검증 도입(2026-07-11) 이전의 자유 텍스트 카테고리(예: "카페")는 **enum 전환과 함께 `ETC` 로 접었다** — 클라가 이미 미매칭 코드를 '기타'로 폴백해 그리고 있어 화면상 변화는 없다. 라이브 반영은 **`UPDATE` 먼저, 이미지 재배포 나중**([schema.sql](docs/schema.sql) `amount.category` 주석에 SQL 이 그대로 있음). 순서를 뒤집으면 `Gender.OTHER` 때와 같은 함정 — 남은 값이 있는 row 조회가 예외로 죽는다.
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
  - ⚠️ **finalize 응답에는 `CHALLENGE_SUCCESS` 배지가 없다.** 지급이 `AFTER_COMMIT` 리스너에서 일어나는데 응답 DTO 는 그 커밋 **전에** 이미 만들어지기 때문이다. 그래서 [_finalize](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 는 응답으로 낙관적 반영(`replaceData`)을 하면 안 되고 **반드시 `reload()` 로 재조회**해야 한다 — 안 그러면 **트로피 축하가 통째로 누락되고 결과 카드로 직행한다**(2026-08-01 실제 발생). 리스너는 같은 요청 스레드에서 동기로 끝나므로 재조회 시점엔 이미 지급돼 있다.
- **닉네임 노출**: "○○님의 만원 챌린지" — `/api/users/me` 로 fetch ([UserApi](tenk_app/lib/data/user/user_api.dart) / [UserScope](tenk_app/lib/app/scopes.dart)). fetch 실패하거나 미완 상태에서 캡처되면 헤더만 "만원 챌린지" 로 fallback. **영상 export 마지막 카드는 닉네임을 fetch 하지 않는다** — compose 시작 지연 회피 + 결과 카드 화면이 닉네임 표시 메인 진입점.
- **디자인 = 화이트 + 브랜드 민트 (2026-08-01 재설계, #18).** 이전의 "성공=노랑 그라데이션+보라 / 실패=그레이"(+🎉/💪)를 뒤집었고, 중간에 **다크로 갔다가 되돌아온 것**이라 두 방향 다 되돌리지 말 것. 근거는 [decisions.md](docs/decisions.md) "결과 카드 디자인".
  - **리워드의 특별함을 '표면색'으로 만들지 말 것.** 다크 시안이 실패한 이유가 이것이다 — 프리미엄해 보이는 대신 앱과 너무 따로 놀았다. **표면은 앱과 같아야 하고**(화이트), 특별함은 표면 위에 **얹히는 것**(컨페티 · 상단 민트 틴트 · 진입 연출)이 담당한다.
  - accent 는 앱과 같은 **민트(성공) / 코랄(실패)** 를 그대로 쓴다. **리워드 전용 accent 토큰을 새로 만들지 말 것** — "앱과 이어진다" 가 이 디자인의 핵심이다.
  - ⚠️ **배경색을 커밋할 것 — 옅은 틴트로 되돌리지 말 것.** 상단 블록을 명도 94% 민트 틴트로 뒀더니 **썸네일·피드에서 그냥 흰 카드로 읽혔다.** Spotify Wrapped·Strava·카뱅이 공통으로 하는 일이 배경을 색으로 완전히 커밋하는 것이고, 그게 **스크롤 중에 눈에 걸리는 유일한 장치**다. 지금은 **브랜드 민트를 꽉 채우고 글자를 흰색**으로 얹는다(앱 `FilledButton` 과 같은 색이라 언어도 이어진다).
  - **성공/실패 대비의 수단**: 블록 채움색(성공=민트 `#1FBE9C` / 실패=**앱 `danger` 와 같은 `#FF6B6B`**) + **컨페티 유무**(실패엔 축하 장식을 붙이지 말 것) + **데이터의 빨강**(아래 게이지·그리드).
    - **실패 레드를 더 어둡게 눌러 새 값을 만들지 말 것.** 딥 레드(`#D94F4F`)로 눌렀던 안은 카드가 **경고창처럼 무거워졌다**. 앱 `danger` 를 그대로 쓰면 실패를 말하는 색이 앱 안에서 하나로 유지된다 — 대비는 알파를 낮추지 않는 것으로 확보한다(블록 위 텍스트는 불투명 흰색이 기본).
  - ⚠️ **블록 색을 바꾸면 `AppColors.rewardSuccessTop`/`rewardFailTop` 도 반드시 같이** — 화면이 **상태바 뒤를 덮는 띠**에 그 토큰을 쓴다. 카드만 레드로 바꾸고 토큰을 그레이로 두면 **상태바 띠만 다른 색으로 남는다**(2026-08-01 실제 발생).
  - 블록 위 텍스트는 **흰색이 기본**이고 보조 정보만 알파로 살짝 낮춘다(닉네임 .82 / 기간 .86 / 히어로 보조 .88·.90). **알파로 대비를 깎지 말 것** — 채움색이 진해 흰색 그대로가 가장 잘 읽힌다.
  - 색은 **위젯에 hardcode** ([ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) `_block`/`_white`/`_onBlock`/`_confetti`/`_slotBorder`/`_inkSub`/`_inkMuted`) — 캡처 시 ThemeData 변동 영향 안 받아야. `AppColors.reward*` 와 정합 유지.
- **이모지를 쓰지 않는다 (🎉/💪 제거됨).** 시스템 이모지는 OS·폰트마다 다른 글리프로 그려져 **같은 챌린지의 카드가 기기별로 달라진다** — 저장본과 영상 클립이 갈라지는 자리다. 장식은 [result_card_painters.dart](tenk_app/lib/presentation/challenge/result_card/result_card_painters.dart) 로 직접 그린다. 결과 pill 에도 아이콘을 붙이지 말 것(성공만 체크를 달면 실패와 비대칭).
  - **컨페티 좌표는 고정 목록**(난수 금지 — 캡처마다 그림이 달라지면 저장본과 영상 클립이 갈라진다)이고, ⚠️ **콘텐츠 열(좌우 패딩 36 안쪽)을 침범하지 않는다.** 카드 안쪽은 챌린지마다 높이가 달라(카테고리 1~4줄, 배지 유무) 가운데에 조각을 두면 어떤 조합에선 **글자 옆에 붙어 오타처럼 보인다**(제목 2줄 카드에서 실제로 그랬다). 최상단 띠 + 좌우 여백 + 바닥만 쓸 것.
- ⚠️ **히어로 = "기간 안에서 목표를 지켰다" 한 문장.** `N일 동안 / {목표액} / 챌린지 성공`(실패는 `챌린지 실패`).
  - **절약액(목표 − 사용)을 주인공으로 두지 말 것.** 10,000원 목표에서 3,000원만 썼다고 *"7,000원 아꼈다"* 가 성취인 게 아니다 — **주어진 기간 안에서 목표를 지킨 것**이 성취고, 덜 쓴 정도는 자랑거리가 아니라 부산물이다. 절약액 계산은 카드에서 아예 제거했다(2026-08-01, 사용자 지적).
  - 실제 사용액은 예산 바 위에 `6,800원 썼어요` **한 줄로만**. 목표액은 히어로가 이미 말했으므로 바 라벨에 또 적지 않는다.
  - **마지막 줄은 `안에서 지켰어요` 가 아니라 `챌린지 성공` 이다** — 앞 두 줄이 이미 "N일 동안 / 10,000원" 이라 서술형으로 이어붙이면 문장이 길어지고, 카드가 말할 결론은 성공/실패 두 글자다.
  - 결과 pill(`성공`/`실패`)은 **없앴다** — 히어로 문장이 이미 결과를 말하고, 블록 색이 한 번 더 말한다.
- **그래프는 척도를 보여줘야 한다 — 도넛/링을 쓰지 말 것.** 한때 링 게이지를 히어로로 뒀다가 걷어냈다: **도넛은 비율만 인코딩하고 척도(최대값·현재값)를 못 나른다.** 결국 정보를 나르는 건 링 밑의 작은 캡션이었고 링은 자리만 제일 많이 먹는 장식이었다.
  - **예산 바 (성공)**: 트랙 흰색 .28 + 쓴 만큼 불투명 흰색. 금액은 바로 위 `6,800원 썼어요` 한 줄이 맡는다.
  - **예산 바 (실패)**: 막대 전체가 실사용액이고 **목표 지점에 흰 눈금**(블록색 링을 둘러 흐린 구간 위에서도 끊겨 보이게)을 세운다. **목표까지는 흐린 흰색(.42), 넘긴 만큼만 불투명 흰색** — 빨강 위에서 **제일 밝은 게 초과분**이 되도록 밝기를 뒤집은 것이라 되돌리지 말 것. 초과 구간을 딥레드(`#A32E33`)로 눌렀던 안은 빨강 위 어두운 빨강이라 **빈 칸으로 읽혔다**. 초과액은 사용액 옆 **흰 칩 + 블록색 글씨**(`2,000원 초과`).
  - ⚠️ **막대 아래에 라벨 줄을 두지 말 것.** 초과액은 위 칩이, 목표액은 히어로가 이미 말한다. 줄을 하나라도 붙이면 그만큼 **빨강 면이 성공(민트)보다 아래로 내려와 두 카드의 블록 높이가 어긋난다**. 같은 이유로 사용액 줄은 `SizedBox(height: 26)` 로 높이를 고정한다(칩이 있는 실패 카드와 글자만 있는 성공 카드의 높이를 맞추는 장치).
  - **일자 그리드**(`N일간의 기록`): 챌린지 N일을 N칸으로 그리고 무지출/지출/미기록을 색으로 (카카오뱅크 26주적금 방식). 칸 수가 곧 기간이라 척도가 보이고, "다 채웠다" 가 그림으로 읽혀 자랑거리가 된다.
    - ⚠️ **열 수는 기간에 따라 접는다** (`_columnsFor`): ~4일 한 줄 / 5~20일 **2줄** / 21일+ 10열 3줄. 짧은 챌린지를 한 줄로 늘어놓으면 칸이 폭에 눌려 **카드 하단이 텅 빈다**. 21일+ 를 2줄로 하면 세로가 넘친다.
    - **범례에 일수를 같이 적는다**(`무지출 4일 · 지출 4일`) — 범례가 곧 요약이 되게. 안 나온 상태는 빼서 '기록 없음 0일' 같은 잡음을 없앤다.
    - **무지출은 성공/실패와 무관하게 늘 민트** — 기록한 날은 결과와 상관없이 잘한 것이다. 반대로 **지출한 날은 실패 카드에서만 빨강**(성공 카드는 옅은 민트) — 색면뿐 아니라 **데이터에서도** 어디가 문제였는지 보이게 하는 장치다. 실패 카드를 통째로 빨강으로 칠하지는 말 것(무지출까지 빨강이면 우울해진다).
  - ⚠️ **카테고리 분포를 카드에 다시 넣지 말 것.** 한 번 넣었다가 걷어냈다 — **자랑거리가 아니라 정산서**라 공유 카드의 40%를 쓸 가치가 없고, 막대가 전부 같은 accent 라 구분도 안 됐다. 카테고리는 **상세 화면에 그대로 있다**(`_CategoryBreakdown`). 2026-05-26 회의의 "카테고리 분포 제외" 결정이 결과적으로 유지된 셈.
- **축하는 두 겹 (성공 전용)**: ① **카드 안 정적 컨페티** — 캡처에 포함돼 저장·공유 PNG 와 영상 마지막 클립에도 남는다 ② **진입 연출** ([ResultCardConfettiOverlay](tenk_app/lib/presentation/challenge/result_card/result_card_painters.dart)) — 화면 위 오버레이라 **캡처엔 안 들어간다**. ⚠️ **진입 연출은 확정 직후에만**(`ResultCardScreen.celebrate`, [_finalize](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 만 true) — 상세의 진입 카드로 다시 열 때마다 터지면 축하가 아니라 **지연**으로 느껴진다.
  - ⚠️ **진입 연출은 끝난 뒤 흔적을 남기지 않는다.** 오버레이가 카드 위에 얹히므로 조각이 하나라도 멈춰 서면 그 자리의 일자 그리드·범례를 **영구히 가린다** — 낙하 중에 스쳐 지나가는 건 연출이지만 멈춰 있는 건 결함이다(2026-08-03 실기기: `delay + fallSpan > 1` 인 조각 15개가 화면 62~94% 지점에 얼어붙었고, **저장 PNG 는 멀쩡해서** 화면에서만 보였다). 장치는 두 겹 — `fallSpan` 을 `1 - delay` 로 **클램프**(모든 조각이 fade 0 까지 도달) + **완료 시 오버레이를 트리에서 제거**. 회귀 가드는 [test/result_card_confetti_test.dart](tenk_app/test/result_card_confetti_test.dart) 3건.
  - **오버레이에는 '콘텐츠 열 회피' 규칙을 적용하지 않는다 (의도).** 그 규칙은 정적 컨페티가 **캡처에 영원히 박히기 때문에** 있는 것이고, 낙하 연출은 지나가면 그만이다. 화면 좌표계로 뿌리는 것도 그대로 둔다 — 카드에 정렬하면 조각이 카드 아래 버튼 영역에서 잘려 낙하가 도중에 끊겨 보인다.
- **구조 = 2블록** (카뱅 26주적금 레퍼런스). 흰 배경 하나에 요소를 8개 나열하던 안은 위계가 없어 **폼(form)처럼** 읽혔다. 레퍼런스 3종의 공통 문법이 **요소 3~5개 / 타이포 대비 극단적 / 배경이 컬러 블록** 이다.
  - **상단 컬러 블록**: 헤더(닉네임 + **챌린지 이름** + 날짜 범위) + **히어로 문장** + 예산 바. **카드의 절반 이상**을 차지하게 여백을 넉넉히 준다 — 기간이 짧아 그리드가 작을 때 하단이 비어 보이는 걸 막는 장치이기도 하다.
  - ⚠️ **헤더에 "만원 챌린지" 라고 쓰지 말 것** — 목표 금액은 챌린지마다 다르다(30만원짜리도 있다). '만원 챌린지' 는 서비스 컨셉 이름이지 이 카드가 말할 사실이 아니다. 지금은 `○○님의 챌린지`.
  - ⚠️ **보조 텍스트를 작게 깔지 말 것.** 강조하지 않는 글자까지 12~14px 로 두면 카드가 통째로 밍밍해진다. 현재 스케일: 닉네임 17 / 이름 27 / **날짜 19** / 히어로 보조 22·24 / 사용액 17 / 그리드 타이틀 17 / 범례 14. **일정은 부가 정보가 아니라 성취의 조건**이라 특히 작게 두지 않는다(일수는 히어로 문장 `N일 동안` 이 맡는다).
  - ⚠️ **컬러 블록과 화이트의 경계는 선명하게 끊는다 — 그라데이션으로 흐리지 말 것.** 하단 12%를 투명으로 페이드시켜본 적이 있는데("두 장을 붙인 것처럼 보인다" 는 우려 때문), 실물에선 색이 바래며 끝나 **블록이 덜 칠해진 것처럼** 보였다. 컬러 블록이 하는 일이 **대비를 만드는 것**이라 그 끝은 또렷해야 한다.
  - **하단 화이트**: **배지 3칸 → 일자 그리드** → TenK 워터마크. **순서를 뒤집지 말 것** — 성취(배지)가 블록 바로 아래 붙고 그 근거(기록)가 따라와야 카드 위쪽이 "결과" 로 뭉친다.
  - ⚠️ **하단 간격은 최악 케이스(이름 2줄 + 30일 그리드 + 배지)에서 864 를 넘지 않도록 맞춰진 값**이다(블록→배지 18 / 배지→그리드 16 / 그리드 내부 14·14, 배지 62·76). 이름이 2줄이면 블록이 32px 자라 하단이 그만큼 밀린다 — 늘리려면 **30일 카드로 오버플로우부터 확인할 것**(실제로 7.2px 넘쳤다).
- **배지는 3칸 고정 — `[연속 기록] [챌린지 성공] [무지출 누적]`** (2026-08-01 규칙화). 단순 나열로 되돌리지 말 것.
  - **타입별로 최상위 등급 하나만.** 3·7·14 를 다 늘어놓으면 같은 성취가 세 번 나오는 셈이고, 14 를 땄다는 건 3·7 을 지났다는 뜻이라 정보가 중복이다.
  - **챌린지 성공이 가운데**, 좌우가 연속/무지출. 자리가 고정이라 카드끼리 비교가 된다.
  - **획득/미획득 **양쪽 다 흰 원 + 테두리**(`#DFE5EC` 2px)**이고 안에 배지 자산이 들어가느냐만 다르다. **미획득만 회색으로 채우지 말 것** — 빈 칸이 얼룩처럼 읽힌다. 빈 칸을 남기는 것 자체는 유지(3칸 대칭 + "여긴 다음에"). 실패 카드는 가운데가 비는 게 정상.
  - 3개뿐이라 **크게** 그릴 수 있다(원 지름 가운데 76 / 좌우 62, 자산은 그 70%). 배지가 하나도 없으면 row 통째 생략.
  - ⚠️ **콘텐츠는 블록 바로 아래 붙이고 남는 공백은 아래로 몬다**(`Spacer` 는 그리드 뒤 하나). 가운데에 띄우면(`Expanded`+`Center`) 기간이 짧을 때 **카드 하단 절반이 통째로 빈다**.
  - 푸터의 '만원 챌린지' 부제는 헤더와 중복이라 **삭제됨** — 되살리지 말 것.
- **화면은 풀블리드** ([ResultCardScreen](tenk_app/lib/presentation/challenge/result_card/result_card_screen.dart)): AppBar 없이 카드를 화면 폭에 꽉 맞춘다(AppBar+카드+버튼 3층이면 카드가 화면의 60%만 쓴다). 닫기는 **우상단 X** — 헤더가 가운데 정렬이라 그 자리가 비어 있고 좌상단은 긴 이름과 겹친다(카드 상단 패딩 52 가 이 자리를 비워둔 것).
  - ⚠️ **상태바 뒤를 카드 상단 블록과 같은 색으로 덮는다** — 안 그러면 카드가 상태바 밑으로 파고들어 닉네임 줄이 시계와 겹친다. 화면 전용이고 캡처물엔 상태바가 없다.
  - **카드에 테두리·라운드를 주지 말 것** — 공유 PNG 는 full-bleed 여야 하고, 화면에서도 액자처럼 보이면 카드가 작아 보인다. 카드 하단이 화이트라 아래 버튼 영역과 seamless 하게 이어진다.
- **PNG 캡처 패턴** ([ResultCardCapture](tenk_app/lib/data/export/result_card_capture.dart)): Overlay 에 `Positioned(left: -2*width)` 로 화면 밖 좌표에 RepaintBoundary 로 감싸진 ResultCardWidget 을 잠시 띄움 → 배지 자산 `precacheImage` → 2 frame 대기 → `boundary.toImage(pixelRatio)` → PNG bytes → 파일. 사유: 위치는 안 보여도 layout/paint 는 정상 수행되고 RepaintBoundary 가 layer 를 그대로 캡처. 갤러리/공유용은 `pixelRatio: 2.0` (960x1728 HiDPI), 영상 export 용은 `1.0` (480x864 영상 해상도와 1:1). **배지 precache 가 필수** — Image.asset 의 첫 프레임 placeholder 가 캡처되는 회귀 방지.
- **영상 마지막 카드 클립** ([VideoComposer.compose](tenk_app/lib/data/export/video_composer.dart) `resultCardPngPath` 옵션): PNG 가 480x864 라 scale/pad noop, `-loop 1 -t 3.0` 으로 3초 정지 mpeg4 클립 생성 → 기존 normalize 출력들 뒤에 추가 → concat 에 포함. `_concatWithXfade` 는 클립별 가변 duration 지원 (`durations: List<double>`) — 마지막 3초 + 앞 클립들 2초가 섞여도 xfade offset 누적이 정확. xfade 길이는 동일하게 0.3초. 카드 정지 시간 결정은 [docs/decisions.md](docs/decisions.md) "결과 카드 회의록" 참고.

### 앱 버전 / 강제·권장 업데이트 (구현 완료)
- **판정은 서버가 진실의 원천.** 클라가 semver 를 자체 비교하지 않는다 — 강제 기준선(min)을 **재배포 없이** 바꾸기 위함. 클라는 상태(`LATEST`/`UPDATE_AVAILABLE`/`UPDATE_REQUIRED`)만 받아 화면을 분기.
- **정책 저장 = `app_config` 단일 행.** `min_supported_version`(미만이면 강제) / `latest_version`(미만이면 권장) / `android_store_url` / `ios_store_url`. **값 갱신은 [관리자 패널](#관리자-패널-구현-완료) → '앱 버전'** (2026-08-06 이전에는 `UPDATE app_config ...` 를 직접 쳤다. 패널이 안 뜰 때의 폴백으로 SQL 은 여전히 유효).
  - **라이브 DB 는 이 테이블을 CREATE + INSERT 로 추가**해야 부팅됨(ddl-auto=validate) — [schema.sql](docs/schema.sql) 의 `app_config` 블록 참고. 새 앱을 릴리스해 "최신 버전"을 올릴 때마다 이 행을 갱신한다(재배포 불필요).
  - ⚠️ **`min` 을 올릴 땐 스토어 게시 반영을 먼저 확인할 것** — 스토어에 그 버전이 없으면 사용자가 강제 업데이트 화면에서 나갈 길이 없다. 패널 화면에도 같은 경고가 떠 있다.
- **엔드포인트**: `GET /api/app/version?platform={android|ios}&currentVersion={x.y.z}` — **PERMIT_ALL(인증 불필요, 로그인 전 부팅 시점 호출)**. 응답 `{ status, latestVersion, minSupportedVersion, storeUrl }`. 판정·비교는 [AppVersionService](tenk-backend/src/main/java/com/hjson/tenk/domain/app/AppVersionService.java) + [SemanticVersion](tenk-backend/src/main/java/com/hjson/tenk/domain/app/SemanticVersion.java)(빌드/프리릴리스 접미사 무시, 숫자 비교). storeUrl 은 platform 으로 서버가 선택.
- **fail-open 원칙**: 설정 행이 없거나, currentVersion 이 없거나·이상하면 서버는 `LATEST` 를 준다. 클라도 네트워크 실패 시 [AppVersionInfo.unknown](tenk_app/lib/data/app/app_version.dart)(게이트 미적용). **서버가 안 붙는다고 앱을 잠그지 않는다** — 연령·동의 게이트의 fail-open 과 같은 원칙.
- **클라 게이트 배선**: [SessionGate](tenk_app/lib/app/session_gate.dart) 가 **버전 게이트를 가장 먼저** 판정(로그인·동의보다 상위 차단). 강제 → [ForceUpdateScreen](tenk_app/lib/presentation/update/update_gate.dart)(back/swipe 차단, 스토어로만), 권장 → 정상 목적지를 [RecommendedUpdateHost](tenk_app/lib/presentation/update/update_gate.dart) 로 감싸 첫 프레임에 1회 안내(‘나중에’로 계속 사용, 다음 콜드 스타트에 재안내). 순서: **강제 업데이트 → 연령 → 동의 → (신규)닉네임 → 홈.**
- **버전 표시**: 메뉴([ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart))의 '앱 버전' 행이 `package_info_plus` 로 현재 버전(`v1.0.0`)을 읽어 표시.
  - **상태 라벨은 상시 노출한다** — 최신이면 `최신 버전이에요`(inkMuted), 업데이트가 있으면 `업데이트가 있어요`(primary) + chevron. 확인 전·실패(unknown)일 때만 라벨 없이 버전만.
  - **아이콘·버전(·chevron)은 두 줄의 가운데가 아니라 첫째 줄에 맞춘다 (2026-07-28).** 가운데 정렬이면 둘째 줄이 제목과 동등한 무게로 읽히는데, 상태 라벨은 제목에 딸린 **부가 줄**이라 그렇게 보이면 안 된다.
    - 구현은 **ListTile 의 `leading`/`trailing` 슬롯을 쓰지 않고 첫째 줄 요소를 전부 `title` 의 `Row` 에 담는 것**이다. 두 슬롯은 `titleAlignment` 를 뭘로 줘도 *두 줄 전체* 를 기준으로 놓여 제목 줄과 미묘하게 어긋난다 — **`ListTileTitleAlignment.top` 으로는 해결되지 않는다**(실제로 시도했다가 아이콘·버전이 제목보다 위로 떠서 되돌렸다). 가로 위치는 ListTile 기본 치수(`_iconSize` 24 + `_leadingGap` 16)를 그대로 재현해 다른 항목과 맞추고, `subtitle` 은 같은 값(40)만큼 들여쓴다. **이 수치를 바꾸면 이 행만 어긋난다.**
  - 버전 숫자가 이 행의 주인공이라 **`AppTypo.body` + `inkSub`**(제목과 같은 크기, 색만 낮춤)로 둔다. ListTile trailing 기본 크기로 되돌리지 말 것 — 작아서 안 읽힌다.
  - **판정을 다시 묻지 않는다 — 부팅 결과를 재사용한다 (2026-07-28).** SessionGate 가 강제 업데이트 게이트를 위해 이미 `checkVersion()` 을 부르고, [AppApi](tenk_app/lib/data/app/app_api.dart) 가 **성공한 판정만** `lastKnownVersion`(+`cachedVersion`) 에 남긴다. 메뉴 타일은 `didChangeDependencies` 에서 이 둘을 **동기로** 읽어 첫 프레임을 완성하므로 정상 경로의 네트워크 호출이 **0회**고 `'확인 중…'` 플래시도 없다. 실패(unknown)는 **일부러 캐시하지 않아** getter 가 null 로 남고, 그 null 이 곧 "재확인 대상" 표시다(별도 플래그를 만들지 말 것). 버전 정책은 릴리스 때만 바뀌므로 한 세션 stale 은 무해하고, 콜드 스타트마다 다시 확인한다.
  - **'탭하면 확인' 방식으로 바꾸지 말 것** — 이 행의 일은 물어보면 알려주는 게 아니라 **업데이트가 있을 때 먼저 알리는 것**이다. 눌러야만 알 수 있으면 정작 알려야 할 순간에 아무도 누르지 않는다(push > pull). 근거는 [decisions.md](docs/decisions.md) "메뉴 앱 버전 행 회의".
  - **탭 3분기**: 업데이트 있음 → 스토어 / 최신 → SnackBar("최신 버전을 이용 중이에요.") / 확인 실패 → 재확인. 최신일 때도 눌리게 두는 건 **반응 없는 행이 고장처럼 보이기 때문**이라 `onTap: null` 로 되돌리지 말 것.
    - **문구에 "이미" 를 넣지 말 것** — *업데이트하러 눌렀다*고 전제하는 말인데, 그냥 버전을 확인하러 누르는 경우가 더 많다. 상태만 담백하게 알린다(앱 전체가 해요체이므로 "…입니다" 도 쓰지 않는다).
- **버전 문자열의 진실의 원천 = pubspec `version`** (예 `1.0.0+3`). 릴리스할 때 이 값을 올리고, 스토어 게시가 끝나면 `app_config.latest_version` 을 그 값으로 SQL 갱신(둘을 일치시킬 것).

### 의견 보내기 (피드백) — 구현 완료
- **'문의(고객센터)'와 '피드백'은 다른 기능이다.** 문의는 *답을 기다리는 긴급한 요청*(내 돈·내 시간이 걸린 문제), 피드백은 *답이 전제되지 않는 제품 개선 의견*이다. 국내 표준([KRDS 사용자 피드백 패턴](https://www.krds.go.kr/html/site/global/global_05.html))도 둘을 병존시키되 역할을 나눈다. **TenK 은 받는 사람이 한 명이라 화면 하나로 합쳤다** — 대형 앱이 나누는 건 CS 팀과 제품 팀이 서로 다른 큐를 보기 때문이라 우리에겐 해당하지 않는다. 근거·리서치는 [decisions.md](docs/decisions.md) "의견 보내기 회의".
- **"답변이 필요한가"의 판정은 회신용 이메일을 적었는지 하나로 한다. 유형으로 판정하지 말 것** — 같은 '불편/오류'라도 답을 원하는 사람과 그냥 알려주는 사람이 갈린다. 그래서 이메일 칸 아래에서 **"답변이 필요할 경우에만 적어주시면 돼요"** 로 그 자리에서 밝힌다. **이 문장을 지우지 말 것** — 답변 여부가 그 칸에 달렸다는 걸 알리는 유일한 장치이고, 답을 기다리게 해놓고 안 주는 건 창구가 아예 없는 것보다 나쁘다.
- **저장은 익명** ([Feedback](tenk-backend/src/main/java/com/hjson/tenk/domain/feedback/Feedback.java) — `user_id` 없음). `withdrawal_feedback` 과 같은 논리라 계정 파기 배치의 대상이 아니고 privacy.html 수집표에도 의견 **내용**은 없다. **여기에 user 참조를 추가하지 말 것.**
  - **단 `reply_email` 만은 개인정보다** — 그래서 privacy.html §1 수집표에 '의견 보내기 (선택) — 답변받을 이메일 주소' 한 줄, §3 에 **답변 후 파기 / 미회신 시 최대 1년**이 들어가 있다. 이 상한은 문서만의 약속이 아니라 [FeedbackRetentionScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/feedback/FeedbackRetentionScheduler.java)(매일 01:40)가 강제한다 — **기간을 바꾸면 `FeedbackService.REPLY_EMAIL_RETENTION` 과 privacy.html 을 같이** 고칠 것. 이메일만 지우고 본문은 남긴다.
- **엔드포인트**: `POST /api/feedback` — **인증 필요**(SecurityConfig PERMIT_ALL 에 넣지 말 것). 토큰은 스팸을 막는 통과 조건일 뿐이라 컨트롤러가 `@CurrentUserId` 를 받지 않는 게 의도다. **rate limit 은 두지 않았다**(인증 + 길이 제한으로 충분, 지금 규모에 과설계).
- 유형 코드는 **서버 enum [FeedbackType](tenk-backend/src/main/java/com/hjson/tenk/domain/feedback/FeedbackType.java) 이 진실의 원천**, **사용자에게 보이는 선택지 문구는 클라 `_types` 목록** (지출 카테고리·탈퇴 사유와 같은 방식). 현재 4종 = 불편/오류 · 기능 제안 · 좋았던 점 · 기타.
  - ⚠️ **enum 의 `label` 은 관리자 패널 전용이고 앱 문구와 일부러 다르다** (2026-08-07 신설). 앱은 고르는 화면이라 해요체 문장(`불편하거나 오류가 있어요`)이지만 패널은 목록 한 칸이라 짧은 분류명(`불편·오류`)이 맞다. **둘을 같은 값으로 맞추려 들지 말 것** — 쓰이는 자리가 다르다. 문의 유형은 앱 쪽도 짧은 명사라 지금은 두 값이 같지만 규칙은 동일하다. 입력은 **지출 카테고리와 같은 `DropdownButtonFormField` 셀렉박스**(항목마다 아이콘+라벨, value=code) — 칩으로 되돌리지 말 것(선택 UI 언어를 앱 전체에서 하나로 유지한다). **이미 쌓인 상수는 지우거나 이름을 바꾸지 말 것.**
- **내용 검증은 줄바꿈만 예외로 허용**한다 (`[\p{Cc}\p{Cf}&&[^\n]]`). 닉네임·챌린지 이름은 한 줄이라 줄바꿈까지 막지만, 의견은 여러 줄로 쓰는 게 자연스러워 그대로 막으면 정상 입력이 거부된다. 진단 정보(앱 버전·플랫폼·OS)는 **틀려도 거부하지 않고 잘라 담는다** — 부가 정보 때문에 의견 전송이 실패하면 안 된다.
- **화면 문구 구성은 [감사 인사] → [유형] → [내용] → [이메일 + 안내]**. 감사는 **상단 인트로가 전담**하고 **완료 스낵바는 "의견이 성공적으로 보내졌어요." 한 문장으로 통일**한다 — 한때 이메일 유무로 갈라 안내했지만(적었으면 "답변은 이메일로", 아니면 "잘 읽고 반영할게요") 상단에서 이미 인사한 뒤라 **두 번 인사하면 오히려 옅어져서** 합쳤다. 되살리려면 앞 문장은 그대로 두고 이메일을 적은 경우에만 뒷문장을 덧붙이는 형태로 할 것(문구 자체를 다시 둘로 가르지 말 것).
- **읽는 방법은 [관리자 패널](#관리자-패널-구현-완료) → '의견'** (2026-08-06 이전에는 `SELECT * FROM feedback ORDER BY created_dt DESC;` 였다). **처리 상태·필터는 없고 최신순 한 줄기뿐인 게 의도다** — 즉시 처리해야 하는 큐가 아니라 모아서 보는 데이터라는 성격은 패널이 생겨도 그대로다. 남길 수 있는 건 `handler_note`(처리 메모) 하나이고 그게 "봤다"의 표시다.
  - ⚠️ **처리 메모에 개인정보를 적지 말 것** — 이 테이블은 익명이라 privacy.html 수집표에 없다. 신원이나 답변 전문을 적으면 그 전제가 깨진다(화면에도 같은 안내가 떠 있다). 회귀 가드는 `FeedbackIntegrationTest` 의 **컬럼 목록 검사**.
- **답변이 필요한 문의는 별도 창구다** — 아래 "문의하기" 참고. 합치지 말 것.

### 문의하기 (구현 완료)
> 2026-08-05 (#23, 2026-08-06 조정). **메뉴 → 고객센터 → '문의하기'**. 회의록은 [decisions.md](docs/decisions.md) "문의 창구 정리".

- **의견 보내기와 계약이 정반대인 창구다.** 표로 고정한다 — **이 대비를 흐리지 말 것**:

  | | 의견 보내기 | 문의하기 |
  |---|---|---|
  | 진입 | **메뉴 최상위**(설정 위) | 메뉴 → **고객센터** 안 |
  | 신원 | **익명** (`user_id` 없음) | **`user_id` 저장** |
  | 회신 이메일 | 선택 | **필수** |
  | 답변 | 전제되지 않음 | 전제됨 (10일 내 조치 원칙) |
  | 테이블 | `feedback` | [`inquiry`](docs/schema.sql) |
  | 계정 파기 시 | 남는다 | **함께 지워진다** |
  | 보관 | 본문 영구(이메일만 1년) | **회원 탈퇴 시까지** |

- **왜 합치지 않았나**: privacy.html §4 가 *"'의견 보내기'로 보낸 내용은 계정과 연결하지 않아 누가 보냈는지 알 수 없다"* 고 **공개 약속**해 뒀다. 같은 화면의 어떤 유형만 계정과 연결되면 그 약속이 흐려진다. **각 화면이 각자의 계약을 갖는 게 이 설계의 핵심** — `feedback` 에 user 참조를 넣는 방식으로 통합하지 말 것.
- **`user_id` 를 저장하는 게 이 테이블의 존재 이유다.** 열람·정정·삭제 요구는 "누구의 데이터인가"가 특정돼야 처리된다. 그 대가로 이 테이블은 익명정보가 아니라 **개인정보**라서 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §1 수집표·§3 보관기간·[play-console-app-content.md](docs/play-console-app-content.md) §6-2 의 대상이고, 계정 파기 배치의 삭제 대상이다.
- ⚠️ **문의 본문을 `feedback` 에 익명 사본으로 남기지 말 것** (2026-08-06 검토 후 기각). `withdrawal_feedback`·`feedback` 이 익명으로 성립하는 건 본문에 신원이 안 들어가기 때문인데, **문의 본문에는 이름·연락처가 적힐 가능성이 높다** — `user_id` 만 떼도 익명이 아니고, 그러면 feedback 이 "익명이라 수집표에 안 들어간다"는 성질이 무너진다. 삭제 요구를 받으면서 그 요구서를 파기 후에도 보관하는 모양새이기도 하다. **알림 메일에 본문이 통째로 들어가 메일함이 이미 아카이브다.** 통계가 필요해지면 본문 없이 `유형 + 접수일 + 처리 소요일`만 남길 것.
- **가르는 기준은 유형이 아니라 "답변을 원하는가" 하나다.** 오류 문의가 의견의 '불편/오류'와 겹쳐 보여도 문제가 아니다 — 답을 원하면 문의, 그냥 알려주는 거면 의견이다.
- ⚠️ **'의견 보내기'를 고객센터 안에 넣지 말 것** (2026-08-06). 한 번 넣었다가 뺐다 — 익명으로 **가볍게** 남기는 창구라 고객센터 안에 있으면 *문의할 일이 있어야 여는 곳*으로 읽혀 문턱이 올라간다. 최상위, **설정보다 위**에 둔다.
- **[고객센터](tenk_app/lib/presentation/support/customer_support_screen.dart)는 항목이 '문의하기' 하나뿐이어도 허브로 유지한다** — FAQ·공지사항이 들어올 자리다. **두 화면 모두 subtitle 을 두지 않는다**(제목이 이미 말한다).
- **유형은 굵게 잡은 4종**(계정·로그인 / 서비스 이용 / 개인정보 / 기타). 서버 enum [InquiryType](tenk-backend/src/main/java/com/hjson/tenk/domain/inquiry/InquiryType.java) 이 진실의 원천, 사용자에게 보이는 선택지 문구는 클라 `_types` (enum 의 `label` 은 관리자 패널 표시용 — 위 "의견 보내기" 의 ⚠️ 참고). 국내 고객센터 표준이 **계정/결제/오류/기타**인데 TenK 은 결제가 없어 그 자리를 개인정보가 대신한다. ⚠️ **'오류'를 따로 두지 말 것** — 결제가 없어 서비스 이용 문의의 대부분이 곧 오류고, 순수 버그 제보는 의견 보내기가 받는다. 세분화하면 고르는 시간만 늘고 분류도 부정확해진다(권리 4종으로 쪼갰다가 되돌린 이력이 있다). **이미 쌓인 상수는 지우거나 이름을 바꾸지 말 것.**
- **처리는 [관리자 패널](#관리자-패널-구현-완료) → '문의'** 에서 한다 (2026-08-06 이전에는 `UPDATE inquiry SET status='DONE' ...` 를 직접 쳤다). 안 바꾸면 **매일 오전 9시 리마인드가 계속 온다.** 되돌리기(`미처리로 되돌리기`)도 있고, 되돌려도 **처리 메모는 남는다**(무엇을 했었는지가 사라지면 안 되므로).
  - **답변은 패널에서 보내지 않는다 (의도).** 회신 이메일을 눌러 메일 클라이언트로 답장하고, 패널에는 `handler_note` 로 *"무엇을 어떻게 답했나"* 한 줄만 남긴다. ⚠️ **답변 전문을 옮겨 담지 말 것** — 보관 대상 개인정보가 늘어 privacy.html §1·§3 과 Play §6-2 가 따라온다. **메일 스레드가 이미 아카이브다**(문의 본문의 익명 사본을 기각한 것과 같은 논리).
- **보관은 회원 탈퇴 시까지**이고 계정 파기 때 함께 지워진다 (2026-08-06 변경 — 그 전엔 "답변 후 3개월" 배치가 있었다). ⚠️ **답변 여부로 지우는 배치를 다시 만들지 말 것**: 3개월은 법이 요구한 값이 아니었고(전자상거래법의 3년은 **통신판매업자** 대상이라 TenK 은 해당 없음), 계정 데이터 전체가 어차피 탈퇴 시까지 남아 문의만 짧게 둘 실익이 없다. `status` 는 **리마인드를 멈추는 용도일 뿐 파기 기준이 아니다.**
- **화면 상단은 "무엇을 도와드릴까요?"** — 고객센터의 표준 오프닝이다. ⚠️ **"궁금하신가요?" 로 되돌리지 말 것**: 이 창구에 오는 사람은 대부분 *문제가 생겨서* 오지 궁금해서 오지 않는다. **하단 안내(계정 정보 전송·보관 기간)는 사용자 결정으로 없앴다** — 수집·보관 사실은 privacy.html §1·§3 이 고지한다.
- **⚠️ 앱 안 폼이 생겼다고 고지된 메일 주소를 지우지 말 것.** 폼은 로그인해야 쓸 수 있어 **탈퇴자·로그인 불가·설치 전 사용자에게 닿지 않는다.** 그 사람들의 유일한 창구가 문서에 적힌 주소이고, Play 가 `delete-account.html` 을 앱 밖 URL 로 요구하는 것과 같은 논리다. 전송 실패 시 스낵바가 `메일로 보내기` 로 그 경로를 안내하는 것도 같은 이유 ([openSupportEmail](tenk_app/lib/presentation/legal/support_contact.dart) 유지).
- ⚠️ **서비스 전용 주소가 3개고 역할이 전부 다르다. 합치지 말 것** (모두 **개발자 개인 메일 아님**):

  | 주소 | 역할 | 설정 위치 | 사용자에게 보이나 |
  |---|---|---|---|
  | `system.tenk@` | 알림 **발신 전용** (SMTP 인증·From) | `spring.mail.username` | ❌ |
  | `support.tenk@` | 알림 **수신함 + 고지된 문의처** | `tenk.notify.mail.to` = [legal_config.dart](tenk_app/lib/config/legal_config.dart) `supportEmail` | ✅ **유일하게 노출** |
  | `admin.tenk@` | 관리자 패널 **로그인 ID** | `tenk.admin.account.email` | ❌ |

  사용자에게 보이는 주소(`support.tenk@`)는 privacy·terms·delete-account 에 고지한 값과 **항상 같아야 한다**. ⚠️ Android 11+ 는 `AndroidManifest.xml <queries>` 에 `mailto` 선언이 없으면 메일 앱 열기가 조용히 실패한다.
  - ⚠️ **패널 로그인 ID 를 개인 메일로 두지 말 것** — 로그인 폼이 공개 인터넷에 있어 **ID 를 추측당하면 비밀번호 하나만 남는다**. 실패 로그의 `actor=` 에도 그대로 쌓인다. 형식 검증이 없으므로 메일 주소일 필요조차 없다.

### 관리자 알림 (문의·의견 도착 / 미처리 리마인드)
- **받는 사람이 개발자 한 명이라 "도착했다는 걸 아는 것" 자체가 기능이다.** 의견은 원래 DB 에만 쌓여 `SELECT` 를 치기 전엔 도착 사실도 몰랐다.
- **두 갈래로 보낸다 — 메일(SMTP) + 텔레그램** ([AdminNotifier](tenk-backend/src/main/java/com/hjson/tenk/common/notify/AdminNotifier.java)). 한쪽을 놓쳐도 다른 쪽이 남는다. 붙는 곳은 **문의 등록 · 의견 등록 · 미처리 리마인드** 3곳.
- ⚠️ **best-effort — 발송이 실패해도 저장은 성공해야 한다.** 모든 예외를 삼키고 로그만 남긴다. 알림이 안 가는 것보다 사용자의 문의가 유실되는 게 훨씬 나쁘다. **여기서 예외를 다시 던지지 말 것.**
- **`@Async` 필수** (`TenkApplication` 의 `@EnableAsync`). SMTP·텔레그램은 외부 호출이라 그 지연이 사용자 응답에 붙으면 안 된다. ⚠️ **같은 빈 안에서 부르면 프록시를 안 타 동기 실행**되니 반드시 다른 빈에서 주입받아 호출할 것.
- ⚠️ **알림 메일은 Gmail 스팸함으로 간다 — 수신 계정에 필터를 걸어둘 것.** 2026-08-06 실측: SMTP·배달은 정상인데 수신측이 걸렀다(발신 계정이 새것이라 평판 이력이 없고, 짧은 본문 + 자동화 제목이라 의심받는다). 해결은 **`support.tenk@` 에서 `from:system.tenk@gmail.com` → "스팸으로 보내지 않기" 필터** + 스팸함의 기존 메일을 '스팸이 아님' 으로 학습시키기. **코드로 고칠 문제가 아니다** — 표시 이름·본문을 손봐도 수신측 판정은 바뀌지 않는다. ⭐ 이 사고가 **텔레그램 2겹의 가치를 실증했다**(메일 하나였으면 그대로 놓쳤다).
- ⚠️ **발신 주소(From)를 반드시 채운다.** `spring.mail.username` 은 **인증용일 뿐 From 헤더가 되지 않아**, 안 채우면 JavaMail 이 `can't determine local email address` 로 **조용히 실패한다**(best-effort라 로그만 남고 아무도 모른다 — 2026-08-06 에뮬 검증에서 실제로 걸렸다). `AdminNotifier.resolveFrom` 이 `tenk.notify.mail.from` → `JavaMailSenderImpl.getUsername()` 순으로 폴백하니 **이 폴백을 지우지 말 것.**
- **설정이 없으면 조용히 넘어간다** (`tenk.notify.*.enabled`, [NotifyProperties](tenk-backend/src/main/java/com/hjson/tenk/common/config/NotifyProperties.java)). **local/test 는 false** 라 테스트를 돌려도 실제 발송이 없고, 자격증명은 jwt secret 과 같은 원칙으로 **prod 프로파일에만** 둔다(공통 yaml 에 fallback 금지).
- **도착 알림만으로는 부족하다 — 미처리 리마인드가 본체다.** 도착 알림은 그 순간 한 번뿐이라 자는 사이에 오면 놓친다. [InquiryScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/inquiry/InquiryScheduler.java) 가 매일 **오전 9시**(새벽이 아니라 *사람이 볼 시간*)에 `PENDING` 이 있으면 다시 알린다. **0건이면 아무것도 보내지 않는다** — 매일 오는 "0건" 은 곧 무시되고 그러면 진짜 알림도 같이 묻힌다.
- **의견에는 리마인드가 없다** (도착 알림만). 의견에는 "처리 완료" 라는 상태가 없고, 즉시 처리해야 하는 큐가 아니라 모아서 보는 데이터라서.
- **FCM 을 도입하지 말 것** — 이건 사용자 알림이 아니라 **개발자 한 명에게 가는 운영 알림**이라 앱과 무관하다. 알림 도메인의 "로컬 알림만" 규칙과는 별개 축이다.
- **알림 본문 끝에 패널 링크가 붙는다** (`tenk.admin.base-url` + 경로). ⚠️ **주소 설정이 없으면 링크 줄만 빠지고 알림은 정상 발송된다** — 링크 때문에 알림이 실패하면 안 된다. 서버는 자기 공개 주소를 모르고 알림은 스케줄러(요청 밖)에서도 나가서 설정으로 받는다.

### 관리자 패널 (구현 완료)
> 2026-08-06 (#27). **`https://tenk.hjson248.com/admin`**. 회의록은 [decisions.md](docs/decisions.md) "관리자 패널".

- **존재 이유 = SSH + `docker compose exec db mariadb` + SQL 의례를 없애는 것.** 흡수한 것 4가지: **문의 처리** · **의견 열람** · **TESTER 승격** · **앱 버전 정책**. [앱 버전 회의](docs/decisions.md)가 *"그때 이 값들이 전부 DB 행 편집이라 패널에 자연히 흡수"* 라고 예고한 자리가 여기다.
- ⚠️ **화면이 아니라 인증이 이 기능의 몸통이었다.** 앱 로그인은 카카오 모바일 SDK 전용이라 **브라우저에는 진입로가 없었고**, `formLogin`/`httpBasic`/`csrf`/세션이 전부 꺼져 있었다.
- **보안 체인을 2개로 쪼갠다 — 앱 인증은 한 줄도 안 건드린다.** [AdminSecurityConfig](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminSecurityConfig.java) 가 `@Order(1)` + `securityMatcher("/admin/**")` 로 먼저 받고, 나머지는 [SecurityConfig](tenk-backend/src/main/java/com/hjson/tenk/security/SecurityConfig.java)(`@Order(2)`)가 **지금 그대로** 처리한다.
  - **절대 한 체인으로 합치지 말 것.** 세션·CSRF·폼 로그인은 브라우저에 필요한 것이고, 전역으로 켜면 앱이 401 JSON 대신 **로그인 화면으로 리다이렉트**되고 POST 마다 CSRF 토큰을 요구하게 된다. 회귀 가드는 [AdminPanelIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/admin/AdminPanelIntegrationTest.java) 의 **마지막 2건**(앱 API 가 여전히 401 `C0003` / CSRF 없이 POST 통과) — **단위 테스트로는 확인할 수 없는 지점**이다.
- **관리자 계정은 `user` 가 아니라 [admin_user](docs/schema.sql) 별도 테이블** ([AdminUser](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminUser.java)). **운영자 자격증명과 이용자 계정은 생명주기가 다르다** — 이용자는 가입→동의→연령→탈퇴→파기 파이프라인을 타지만 운영자는 그중 아무것도 안 탄다.
  - ⚠️ **`user` 에 넣지 말 것**: `(provider, provider_user_id)` NOT NULL UNIQUE 라 **가짜 공급자 값**이 필요해지고(`AuthProvider.TEST` 가 남긴 실수와 같은 모양), 그 행이 **동의 미완·연령 미확인 상태로 파기 배치 스캔과 사용자 통계에 섞인다**. `user.email` 은 2026-07-26 에 수집을 접으며 DROP 한 컬럼이라 운영자용으로 되살리면 그 결정이 흐려진다.
  - **나중에 이용자용 자체 계정(이메일+비밀번호)이 생기면 그때 `user` 에 컬럼을 추가한다** — 그 시점엔 privacy.html 수집표·Play 갱신이 어차피 따라오므로 미리 넣어도 면제되지 않는다. **중복이 아니라 성격이 다른 것.**
  - ⚠️ **`admin_user.email` 은 운영자 연락처라 개인정보 수집표(privacy.html §1)의 대상이 아니다.**
- **자격증명은 yaml 이 진실의 원천** (`tenk.admin.account`, jwt secret 과 같은 원칙). 부팅할 때마다 계정을 만들거나 해시를 다시 맞춘다 ([AdminAccountInitializer](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAccountInitializer.java), BCrypt). **그래서 패널에 비밀번호 변경 화면이 없다** — 뒀다면 다음 재부팅에 yaml 값으로 되돌아가 "바꿨는데 안 바뀐다" 가 된다. 바꾸려면 yaml 을 고치고 재시작.
  - **local 과 prod 는 로그인 ID 만 같고 비밀번호는 따로 둔다** (2026-08-07 결정 — 그 전엔 local 이 `admin@local`/`local-admin` 로 통째로 달랐다).
    - **ID 를 맞추는 이유**: 로컬에서 확인한 로그인이 곧 운영에서 쓸 로그인이라 *"로컬에선 되는데"* 가 생기지 않는다. **prod ID 를 바꾸면 [application-local.yaml](tenk-backend/src/main/resources/application-local.yaml) 도 같이 고칠 것.**
    - ⚠️ **비밀번호까지 맞추지 않는 이유**: 로컬 백엔드는 `0.0.0.0:8080` 에 열려 **같은 Wi-Fi 의 누구나 그 로그인 폼에 닿는다.** 값을 공유하면 공용망에 운영 자격증명을 들고 나가는 셈이라, 로컬 값은 외우기 쉬운 전용 비밀번호로 둔다.
    - ⚠️ **이니셜라이저는 이메일이 다른 행을 지우지 않는다** — ID 를 바꾸면 옛 계정이 옛 비밀번호 그대로 **유효한 로그인으로 남는다.** ID 를 교체할 땐 `DELETE FROM admin_user WHERE email='<옛 ID>';` 를 짝으로 칠 것.
  - **로그인 ID(`email`)는 순수 ID 다** — 메일이 오가지 않고 형식 검증도 없다. ⚠️ **개인 메일로 두지 말 것**: 공개 로그인 폼에서 ID 를 추측당하면 비밀번호 하나만 남고, 실패 로그의 `actor=` 에도 쌓인다. 현재 값은 서비스 전용 `admin.tenk@`(위 "관리자 알림" 의 주소 3종 표 참고).
- **`tenk.admin.enabled=false`(기본)면 보안 체인·컨트롤러가 등록되지 않아** `/admin/**` 이 앱 체인의 `anyRequest().authenticated()` 에 걸려 **401** 로 끊긴다. local·prod 는 켜져 있고, test 는 해당 테스트에서만 켠다.
- ⚠️ **범위를 늘리지 말 것 — 안 만들기로 한 것들**: 이용자 데이터 **편집·삭제**(삭제의 진실의 원천은 앱 탈퇴 흐름 + 파기 배치다. 패널이 우회로가 되면 그 계약이 무너진다) · 챌린지/기록/영상 조회 · 통계 대시보드 · **답변 발송**(SMTP 를 붙이면 스팸 이슈까지 여기로 끌려온다) · 비밀번호 변경.
- **알림 2겹은 그대로 유지한다.** 패널은 **'처리'** 를 맡고 알림은 **'인지'** 를 맡는다 — 도착 사실을 아는 건 여전히 알림의 일이라 패널이 생겼다고 뺄 수 없다.
- **접속기록 = [AdminAudit](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAudit.java)** (전용 로거 `TENK_ADMIN_AUDIT`). 「개인정보의 안전성 확보조치 기준」이 요구하는 항목에 맞춰 **계정 · 일시 · 접속지 IP · 수행업무**를 남기고, [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §8 에 **1년 이상 보관**으로 고지돼 있다. **SQL 로 직접 치던 시절엔 아무 흔적도 안 남았다** — 패널로 옮기며 오히려 좋아진 부분이다.
  - **변경뿐 아니라 열람도 남긴다** — 고시의 '수행업무'에 조회가 포함되고 **유출은 변경이 아니라 열람에서 난다**. 거는 곳은 개인정보가 *화면에 실제로 보이는* 3곳(문의 목록·상세 / 의견 목록 / 사용자 목록)이고, 대시보드(집계)·앱 버전(정책 값)은 개인정보가 아니라 제외했다.
  - **로그인 성공·실패도 남긴다** ([AdminLoginAuditor](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminLoginAuditor.java), Spring Security 인증 이벤트). **실패가 특히 중요하다** — 로그인 폼이 공개 인터넷에 있어 대입 공격의 유일한 탐지 수단이다. 성공 시 `admin_user.last_login_dt` 도 갱신.
  - ⚠️ **로그에 담지 말 것 3가지**: **본문·이메일**(로그가 또 하나의 개인정보 보관소가 된다) · **입력된 비밀번호**(오타는 대개 진짜 비밀번호의 변형이라 그 자체가 자격증명 유출) · **검색어**(닉네임으로 검색하면 그게 곧 개인정보 — `keyword=given/none` 만 남긴다). 회귀 가드는 `AdminPanelIntegrationTest` 의 접속기록 5건.
  - **prod 는 Traefik 뒤라 IP 는 `X-Forwarded-For` 의 첫 값**을 쓴다(`getRemoteAddr()` 은 프록시 IP).
  - ⚠️ **보관은 파일 + 볼륨 2겹으로 성립한다** — [logback-spring.xml](tenk-backend/src/main/resources/logback-spring.xml) 이 전용 파일에 월 단위 13개월 롤링(`additivity=false` 로 앱 로그와 분리)하고, [docker-compose.yml](deploy/docker-compose.yml) 의 **`admin-audit` 볼륨**이 재배포·컨테이너 교체에도 살아남게 한다. **둘 중 하나만 빠져도 "1년 보관" 고지가 거짓이 된다.** DB 클린 재생성(§5.7) 때 **이 볼륨은 지우지 말 것** — 계정 데이터와 무관하다.
  - **기록 없이 바꾸는 경로를 만들지 말 것.**
- **`handler_note`(처리 메모)는 문의·의견 양쪽에 있다.** ⚠️ **답변 전문을 옮겨 담는 칸이 아니다** — 각 도메인 규칙의 경고 참고.
- **Thymeleaf 서버사이드 렌더링**([templates/admin/](tenk-backend/src/main/resources/templates/admin/)). CSS 는 `layout.html` 에 인라인 — **정적 리소스 경로를 열면 permitAll 예외가 하나 더 생기고** 화면이 다섯 개뿐이라 그 비용이 이득보다 크다.

### 테스트 지원 (devtools — 상태별 시딩. **테스트 로그인은 제거됨**)
- **왜 있나**: 날짜 기반 앱이라 "완료(성공/실패)·확정 대기" 같은 챌린지 상태는 **현실 날짜가 지나야만** 자연 발생한다. 실기기/에뮬레이터에서 각 상태를 즉시 만들어 테스트하려고 둔 **테스트 전용** 시딩 경로. 백엔드는 [com.hjson.tenk.devtools](tenk-backend/src/main/java/com/hjson/tenk/devtools/TestSupportService.java) 패키지.
- **⚠️ 카카오 우회 테스트 로그인은 제거됐다 (2026-07-25 테스터 로그인 회의, [decisions.md](docs/decisions.md)).** `POST /api/auth/test/login` · `TestLoginRequest` · `TestSupportProperties`(`tenk.test.*` yaml 포함) · Flutter 로그인 버튼/`loginAsTest`/`test_config.dart` 전부 삭제. Play 심사·데모는 **데모 카카오 계정**으로, 내부 테스터는 **실제 카카오 계정을 TESTER 로 승격**해 쓴다. `AuthProvider.TEST` 는 기존 로컬 데이터 호환용으로만 `@Deprecated` 잔존(새로 안 생김). **다시 추가하지 말 것.**
- **게이팅 = 계정 role.** [UserRole](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRole.java) `{ USER, TESTER, ADMIN }` (`user.role` 컬럼, 기본 USER). 시딩은 `user.getRole().canUseTestTools()`(=TESTER·ADMIN)일 때만 허용, 아니면 `TEST_ONLY_OPERATION`(T0001). **승격은 [관리자 패널](#관리자-패널-구현-완료) → '사용자'** 에서 하고 **앱엔 부여 경로가 없다**(2026-08-06 이전에는 `UPDATE user SET role='TESTER' ...` 를 직접 쳤다). 카카오 회원번호로 검색하는 게 실제 경로다 — 닉네임은 중복될 수 있다. **심사자 데모 계정은 절대 승격 금지**(승격하면 '내 정보'에 시딩 버튼 노출). 전역 킬스위치(`tenk.test.enabled`) 없음 — 플래그 없는 계정 = 시딩 불가 = 그 자체가 킬스위치.
  - ⚠️ **패널에서 `ADMIN` 으로는 올릴 수 없다** ([AdminService.changeUserRole](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminService.java) 가 거부). `UserRole.ADMIN` 은 *이용자* 계정에 관리 권한을 줄 때의 자리이고 패널 로그인은 `admin_user` 가 담당하는 **별개 축**이다 — 둘을 섞으면 권한 상승 경로가 생긴다.
- **데이터 시딩** (`POST /api/dev/seed`, **인증 필요**): 호출자가 TESTER 가 아니면 거부. 통과 시 그 유저 데이터를 wipe([WithdrawnUserPurgeService.purge](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 와 같은 FK 순서, user/refresh_token 만 유지) 후 **5종 상태** 챌린지 시딩: 시작 전 / 진행 중(STREAK·NO_SPEND 배지) / 확정 대기(finalize→SUCCESS 페이오프 테스트용) / 완료-성공(CHALLENGE_SUCCESS 배지) / 완료-실패. **wipe 는 호출자 본인 데이터를 지운다** — 그래서 TESTER 는 소모용 계정이어야 한다(승격한 실계정의 진짜 기록도 날아감).
- **날짜 우회 방식**: 챌린지는 `Challenge.create` 로 today 로 만든 뒤 `startDate`/`endDate` 만 **reflection(`ReflectionUtils`) 으로 backdate** — `validatePeriod` 가 미래 시작만 허용하므로 우회 필요(통합 테스트의 backdate 패턴과 동일). **금액·배지는 우회 불필요** — `Amount.spend/noSpend` 는 오늘이 아니라 *챌린지 기간* 으로 검증하고, 배지는 `BadgeGrantService.evaluateForChallenge`/`grantChallengeSuccess` 를 그대로 호출해 현실적 데이터가 나온다.
- **수동 시드 SQL 2종** (devtools 와 별개 — 특정 기능을 손으로 볼 때만): [seed-badge-demo.sql](docs/seed-badge-demo.sql)(배지 획득 연출 6종 — 색 사다리·체인·폴백·확정 트로피를 한 번씩) / [seed-export-test.sql](docs/seed-export-test.sql)(영상 합본 export). 둘 다 **로그인된 계정을 자동으로 잡고 반복 실행 가능**하다. ⚠️ 아래 '테스트 데이터 재생성' 버튼을 누르면 이 시드가 **전부 wipe** 된다 (그쪽은 호출자 데이터를 통째로 지운다).
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
│   └── notify/AdminNotifier.java   # 개발자에게 가는 운영 알림 (메일 SMTP + 텔레그램 2겹, @Async, best-effort)
├── security/                       # SecurityConfig (@Order(2), 앱 전용 STATELESS) + JwtTokenProvider/
│                                   # JwtAuthenticationFilter + JwtPrincipal + KakaoTokenVerifier + @CurrentUserId
├── admin/                          # 관리자 패널 (/admin/**). 앱 인증과 완전히 분리된 두 번째 보안 체인
│                                   # AdminSecurityConfig(@Order(1), 세션+폼+CSRF) · AdminUser/Repository
│                                   # AdminUserDetailsService · AdminAccountInitializer(yaml→BCrypt 동기화)
│                                   # AdminProperties · AdminController · AdminService · AdminAudit
│                                   # 화면은 templates/admin/*.html (Thymeleaf)
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
    ├── feedback/    (Feedback, FeedbackType, FeedbackRepository, FeedbackService, FeedbackController,
    │                 FeedbackRetentionScheduler, dto/FeedbackCreateRequest)
    │                <!-- 익명(user_id 없음). reply_email 만 개인정보 → 1년 상한 배치로 삭제 -->
    ├── inquiry/     (Inquiry, InquiryType, InquiryStatus, InquiryRepository, InquiryService,
    │                 InquiryController, InquiryScheduler, dto/InquiryCreateRequest)
    │                <!-- feedback 과 정반대: user_id 저장(개인정보) · 회신 이메일 필수 ·
    │                     계정 파기 대상(= 탈퇴 시까지 보관) · 미처리는 매일 09:00 리마인드 -->
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
│   ├── app_theme.dart            # buildTenkTheme(): 토큰 → ThemeData (main.dart 에서 배선)
│   └── tenk_logo.dart            # 로고 마크(CustomPainter) + 워드마크 조합 — 런처 아이콘과 같은 형상
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
│   │   └── badge.dart              # + kBadgeLadder(3/7/14/30) — 사다리 상수의 클라 단일 출처
│   ├── settings/                 # 효과음·진동·알림 설정 (shared_preferences). 외부 통신 X
│   │   └── app_settings.dart       # 재생 직전에 동기로 읽는다(구독 없음) + 햅틱 헬퍼 + NotificationPrefs 저장
│   ├── notification/             # 로컬 알림 (FCM 아님). 예약은 기기가 하고 서버는 관여 안 함
│   │   ├── notification_kind.dart    # 발신 채널 3종 + Android 채널 id/이름 + ScheduledNotification
│   │   ├── notification_prefs.dart   # 설정 스냅샷(마스터+종류별 3+리마인더 시각) + 기본값 상수
│   │   ├── notification_plan.dart    # **순수 함수** buildNotificationPlan — 문구 우선순위·병합·건너뛰기
│   │   ├── notification_scheduler.dart # 재예약 유일 진입점(rescheduleAll). 전량 취소 후 다시 걸기
│   │   └── notification_service.dart   # flutter_local_notifications 래퍼(권한·채널·zonedSchedule)
│   ├── media/                    # 영상 다운로드 (export prefetch 용)
│   │   └── media_api.dart
│   ├── user/                     # 사용자 정보 — 결과 카드 헤더, '내 정보' 화면, 닉네임 변경, 회원 탈퇴
│   │   ├── user.dart, user_api.dart  # User 모델에 nicknameChangeAvailableFrom. updateNickname/withdraw 호출
│   ├── app/                      # 앱 버전 게이트 (rawDio, 인증X). 판정은 서버
│   │   ├── app_version.dart        # AppVersionStatus enum + AppVersionInfo(+unknown fail-open)
│   │   └── app_api.dart            # currentVersion(package_info) + checkVersion(GET /api/app/version)
│   ├── feedback/                 # 의견 보내기 (authDio). 서버엔 익명 저장 — 모델 없이 api 만
│   │   └── feedback_api.dart       # submit(type/content/replyEmail) + 진단 정보(버전·플랫폼·OS) 자동 첨부
│   ├── inquiry/                  # 문의하기 (authDio). 서버가 **계정과 연결해** 저장 — 모델 없이 api 만
│   │   └── inquiry_api.dart        # submit(type/content/replyEmail 필수). 진단 정보는 일부러 안 붙인다
│   └── export/                   # ffmpeg 영상 합본 합성 + 결과 카드 PNG 캡처 (외부 통신 X, 로컬 처리)
│       ├── video_composer.dart     # 정규화→concat 2-pass. mpeg4 sw 인코더 고정. resultCardPngPath 옵션
│       └── result_card_capture.dart  # Overlay off-screen + RepaintBoundary → PNG. video/gallery 두 해상도
└── presentation/               # 화면. data 레이어를 Scope로만 호출
    ├── common/                   # 도메인 무관 공용 위젯·헬퍼
    │   ├── async_state.dart        # AsyncStateMixin + AsyncStateView (필수 — 아래 컨벤션 참고)
    │   ├── selection_sheet.dart    # showSelectionSheet — 목록 택1 바텀시트 ("모달 사용 기준")
    │   ├── selection_field.dart    # SelectionField — 탭하면 선택 시트가 뜨는 **폼 필드**(FormField 라 validator 유지). Dropdown 대체
    │   ├── text_input_sheet.dart   # showTextInputSheet — 텍스트 한 값 편집 바텀시트 (챌린지 이름 · export 자막)
    │   ├── tap_field_box.dart      # TapFieldBox — 탭 필드 공용 룩(surfaceAlt 채움). 날짜·시간·선택 칸이 공유
    │   ├── date_time_picker.dart   # pickTenkDate / pickTenkTime + formatTimeOfDay (직접 showDatePicker 금지)
    │   ├── field_label.dart        # FieldLabel(required:/optional:) — 폼 라벨은 전부 이걸로
    │   ├── bottom_action_scroll_view.dart  # BottomActionScrollView — 본문+하단 액션 한 스크롤.
    │   │                             # 게이트/온보딩 3화면 공유 (키보드에 입력칸이 잘리는 걸 막는다)
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
    │   │   ├── badge_celebration_dialog.dart  # 획득 축하 모달(3막 연출 + CustomPainter 컨페티) + 큐 헬퍼
    │   │   ├── badge_style.dart       # 단계별 색 매핑(5개) — 글로우·파티클·광택 강도
    │   │   └── badge_next_goal.dart   # '다음 목표' 한 줄. 도달 가능할 때만 사다리, 아니면 완주 폴백
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
    │   ├── profile_screen.dart          # AppBar 햄버거(Icons.menu) 진입점 = 순수 메뉴(제목 '메뉴' 확정). 내 정보(→) + 계정 정보(→) + 설정(→) + 의견 보내기(→) + 법적 고지(→) + 앱 버전(+최신여부) + 테스트 재생성(dev)
    │   ├── my_info_screen.dart           # '내 정보' 하위 화면. 닉네임 · 성별 — 둘 다 **별도 화면으로 push**(다이얼로그 아님, "모달 사용 기준" 참고)
    │   ├── nickname_edit_screen.dart     # 닉네임 변경 화면. 신규 가입용 nickname_setup_screen 과 별개 (저쪽은 back 차단 온보딩)
    │   ├── gender_edit_screen.dart       # 성별 화면. SegmentedButton 3칸(남성/입력 안 함/여성) + 목적 고지. GenderChoice 로 pop(취소와 '입력 안 함' 구분)
    │   ├── account_settings_screen.dart # **표시명 '계정 정보'**(클래스·파일명은 유지). 연동 계정 표시 / 로그아웃 / 회원 탈퇴(→ WithdrawScreen push). 메뉴가 넘긴 User 사용, null 이면 자체 로드
    │   └── withdraw_screen.dart          # 탈퇴 사유 화면. 확인 다이얼로그를 통과한 뒤 열린다 — 사유 칩(선택, '기타'면 자유 입력) → withdraw → 로그아웃
    ├── legal/                        # 연령 확인·약관 동의·고지 (openLegalDoc 헬퍼 공유)
    │   ├── age_gate_screen.dart          # 중립적 연령 심사. 생년월일 3칸(기본값 없음), 컷오프 비노출, back 차단. 14세 미만이면 계정 파기 안내 후 로그아웃
    │   ├── consent_section.dart         # 전체 동의 + 이용약관/개인정보 필수 2항목 + [보기] 공용 위젯 + openLegalDoc(url_launcher)
    │   ├── consent_gate_screen.dart     # 필수 동의 화면. next 파라미터로 다음 화면 분기(신규=닉네임, 기존=홈). back 차단, 동의 or 로그아웃
    │   ├── legal_notice_screen.dart     # '법적 고지' 하위 화면. 이용약관/개인정보처리방침 링크 + 오픈소스 라이선스(showLicensePage). **고지 문서만** — 문의 행을 다시 두지 말 것
    │   └── support_contact.dart         # openSupportEmail — 고지한 문의처 메일 앱 열기. 실패 시 주소 클립보드 복사
    │                                    # (앱 밖 창구 + 문의 폼 전송 실패 시 탈출구. 폼이 생겨도 지우지 말 것)
    ├── support/                      # 고객센터 허브 — 두 창구를 나란히 두는 게 존재 이유
    │   └── customer_support_screen.dart  # 문의하기 1줄 (FAQ·공지가 들어올 자리라 허브 유지)
    ├── feedback/                     # 의견 보내기 — **익명**. 답변 여부는 '회신 이메일' 유무로만 갈린다
    │   └── feedback_screen.dart         # 유형(필수) + 내용(필수) + 회신 이메일(선택) → POST /api/feedback
    ├── inquiry/                      # 문의하기 — **계정과 연결**·**탈퇴 시까지 보관**. feedback 과 계약이 정반대다
    │   └── inquiry_screen.dart          # 유형(필수) + 내용(필수) + 회신 이메일(**필수**) + 계정 전송 고지 → POST /api/inquiry
    ├── settings/                     # 앱 동작 환경
    │   └── settings_screen.dart         # 효과음·진동 + 알림(마스터 1 + 종류별 3 + 리마인더 시각).
    │                                    # 알림 토글은 저장 후 곧바로 재예약(updatePrefs)
    ├── notification/                 # 알림 권유 (판정·예약은 data 층, 여기선 UI 만)
    │   └── notification_priming_sheet.dart   # **첫 챌린지 생성 직후** 권유 시트. 게이트 아님(back=나중에), 한 번만
    └── update/                       # 앱 버전 게이트 UI (판정은 서버, 여기선 화면만)
        └── update_gate.dart             # ForceUpdateScreen(강제, back차단) + RecommendedUpdateHost(권장 1회 안내) + openStorePage 헬퍼
```

로고·아이콘 자산: **번들 자산이 없다** — 마크는 코드로 그리고([design/tenk_logo.dart](tenk_app/lib/design/tenk_logo.dart)), 런처 아이콘 PNG 는 Android `res/`·iOS `Assets.xcassets` 로 직접 생성된다. 생성기·원본은 [tenk_app/assets_src/icon/](tenk_app/assets_src/icon/) (번들 제외). 위 "로고 / 앱 아이콘" 참고.

자산: `tenk_app/assets/fonts/Korean.ttf` (현재 미사용 — 영상 export 자막은 Flutter `TextPainter` + 시스템 폰트 폴백으로 처리. 자막 폰트를 명시 지정하고 싶으면 [tenk_app/assets/fonts/README.md](tenk_app/assets/fonts/README.md) 참고).

배지 자산: **번들은 `tenk_app/assets/badges/` (384px, 9개)**, **1024px 원본은 번들 밖 [assets_src/badges/](tenk_app/assets_src/badges/)**. 파일명은 서버 `badge.icon_path`와 1:1 매칭 (`streak_3.png` 등). 화면 최대 표시가 180px 인데 원본이 1024px(합계 6.7MB)이라 디코딩·메모리·번들이 모두 손해였다 — **리사이즈 스크립트는 `assets_src/badges/README.md`** 에 있고, 원본을 고치면 다시 돌려 번들본을 갱신할 것. 새 배지 추가 시 schema.sql · 두 디렉토리 동시 갱신.

사운드 자산: `tenk_app/assets/sounds/` — `record_start.mp3`(녹화 시작) · `badge_acquired.mp3`(배지 획득). **재생 전에 반드시 효과음 토글을 확인할 것** (아래 "설정" 참고). 합성음은 3번 반려된 전례가 있어 **royalty-free 다운로드로만** 채운다 ([assets/sounds/README.md](tenk_app/assets/sounds/README.md)).

> **Lottie 는 제거됐다 (2026-08-01).** 컨페티를 `CustomPainter` 로 직접 그리면서 `lottie` 의존성과 `assets/lottie/` 를 통째로 뺐다 — 되살리지 말 것. 사유는 아래 연출 규칙.

배지 UI 원칙:
- **챌린지에 귀속된 획득 배지만 노출** — 잠금 상태/미획득은 챌린지 단위 모델에서 의미 없으므로 보이지 않는다. 전용 "배지 화면"이나 진입점도 없다.
- 챌린지 응답(`Challenge.badges`)을 카드·상세에서 그대로 [ChallengeBadgesRow](tenk_app/lib/presentation/challenge/widgets/challenge_badges.dart) 로 렌더.
- **신규 배지 획득 알림은 [ChallengeDetailScreen](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 의 reload diff 로만**. `_knownBadgeIds` (challengeBadgeId 기반) 와 새 응답을 비교해 신규 항목만 [showBadgeCelebrations](tenk_app/lib/presentation/challenge/widgets/badge_celebration_dialog.dart) 로 큐잉. 첫 로드는 `_baselineSet` 으로 막아 baseline 만 채움 — 과거 배지를 다시 축하하지 않는다. 메인/홈 등 다른 진입점에서도 알리고 싶으면 global `BadgeNotifier` 로 승격 (현재 범위 밖).
- 유저 단위 누적(=업적) 화면은 추후 추가 예정 — 그때 별도 `presentation/achievement/` + 별도 Scope/API 신설.

#### 배지 획득 연출 (2026-08-01 재설계)
> 레퍼런스는 **듀오링고 + 챌린저스**(+ 토스 리워드). 회의록은 [decisions.md](docs/decisions.md) "배지 획득 연출".

- **모달 유지 — 화면으로 빼지 말 것.** 토스·챌린저스는 화면이지만 그건 *리워드 수령*이라 그렇고, 우리 배지는 기록하다 **부수적으로** 얻는 성취다. finalize 경로에선 배지 N개 + 결과 카드가 전부 풀스크린 푸시가 돼 버린다.
- **9종 전부 동일한 최대 연출. 등급별로 연출을 갈라 30일만 화려하게 만들지 말 것** — 위계는 연출이 아니라 **자산의 색**이 만든다(브론즈 3 → 실버 7 → 골드 14 → 주얼골드 30, 성공=금 트로피).
- **색은 타입이 아니라 단계로 갈린다** (`streak_3` 과 `no_spend_3` 이 같은 구리색) → 매핑은 9개가 아니라 **5개**. [badge_style.dart](tenk_app/lib/presentation/challenge/widgets/badge_style.dart) 가 진실의 원천이고 토큰은 `AppColors.badge*`. **자산 색을 바꾸면 여기도 같이.**
- **타임라인 3막**(총 1400ms): 무대(radial 글로우) → **임팩트 180~520ms** → 여운(wobble·글로우 호흡·광택 sweep 1회). **임팩트는 한 점에 몰아줄 것** — 소리·햅틱·파티클·오버슈트가 흩어지면 "쿵"이 사라진다(예전엔 900ms 에 완만히 퍼져 절정이 없었다). 텍스트는 60ms 간격 순차.
- **컨페티는 `CustomPainter`. Lottie 로 되돌리지 말 것** — 색·수량·방향이 JSON 에 박혀 있어 **배지 단계색과 연동이 안 된다.** 30·성공만 파티클을 다색(자산의 보석과 호응)으로, 반대로 **광택 sweep 은 약하게**(그 자산들은 반짝임이 이미 그려져 있어 겹치면 지저분해진다).
- **닫기는 명시적 CTA 버튼.** "탭하여 닫기" 힌트로 되돌리지 말 것. 배지가 2개 이상이면 **`다음 (1/2)` 로 체인의 길이를 밝힌다** — 남은 개수를 알면 반복이 지루함이 아니라 수확으로 읽힌다(듀오링고 패턴). 전부 동일 연출이라 피로는 강도가 아니라 **페이싱**으로 푼다.
- **'다음 목표' 는 사다리를 그대로 읽으면 거짓말이 된다.** 챌린지에 기간이 있어 5일짜리는 7/14/30 을 처음부터 못 따고, 남은 기간이 모자라도 마찬가지다. 판정은 **`현재값 + 남은 일수 >= 다음 칸`** ([badge_next_goal.dart](tenk_app/lib/presentation/challenge/widgets/badge_next_goal.dart)). 도달 불가면 **챌린지 완주로 폴백** — 이건 위로가 아니라 사다리가 막혀도 살아 있는 실제 다음 배지(`CHALLENGE_SUCCESS`)다. **분모 표기("3개 중 2번째")를 쓰지 말 것** — 사다리가 막히면 못 딸 배지를 딸 수 있는 것처럼 보인다.
- 현재값은 **방금 받은 배지의 `conditionValue`** 로 본다(배지는 칸을 넘는 순간 지급되므로 동일). 연속/누적 집계를 클라에서 다시 구현하지 말 것 — 서버가 진실의 원천.
- 사다리 상수는 **[kBadgeLadder](tenk_app/lib/data/badge/badge.dart) 하나**가 출처(무지출 성취감 카드 게이지도 공유). 사본을 만들지 말 것.
- 모달 진입 전 **`precacheImage` 필수** — 첫 프레임 디코딩이 걸리면 임팩트가 시작부터 끊긴다.
- **칭호(예: "꾸준함의 증명")는 도입하지 않는다** — 자산이 이미 숫자를 크게 박고 있어 이름과 숫자가 경쟁한다.

### 설정 (효과음·진동)
- **메뉴 → '설정'** ([SettingsScreen](tenk_app/lib/presentation/settings/settings_screen.dart)) 에 효과음 on/off · 진동 on/off 2개. 값은 [AppSettings](tenk_app/lib/data/settings/app_settings.dart)(`shared_preferences`)가 들고 `SettingsScope` 로 주입. **기본값은 둘 다 켜짐** — 축하 연출이 앱의 페이오프라 기본이 무음이면 대부분이 존재를 모른 채 지나간다.
- **토글은 앱 전체에 적용한다.** 효과음 = 배지 획득 + 녹화 시작, 진동 = 배지 + 녹화 시작 + 시간 휠. "효과음 끔"인데 촬영할 때만 소리가 나면 토글이 고장 난 것으로 보인다.
- **`HapticFeedback` 을 직접 부르지 말고 `AppSettings` 헬퍼(`selectionClick`/`mediumImpact`/`heavyImpact`)를 경유할 것.** 호출부마다 `if (enabled)` 를 복붙하면 새 호출부에서 빠진다. 새 효과음도 재생 전 `soundEnabled` 확인.
- **화면 이름을 '알림/효과 설정' 이나 '소리 및 진동' 으로 바꾸지 말 것** — 전자는 알림을 이 화면 밖에서 찾게 만들고, 후자는 알림이 들어갈 자리가 없다. 실제로 **알림(#17)이 이 화면에 들어왔고**, 앞으로 늘어날 설정도 여기로 온다.
- ⚠️ **설명 문구를 다시 늘리지 말 것 (2026-08-04, #21).** 이 화면의 부가 설명은 세 종류를 지웠고 되살리면 안 된다: ① **토글 이름이 이미 말하는 것**(효과음/진동의 "언제 울리는지" subtitle — 켜보면 안다) ② **앱 밖 상식**("무음·방해 금지 모드면 소리가 안 나요") ③ **구현 디테일**("알림은 기기에서 직접 예약해요" — 로컬 알림인지는 개발자만 알면 된다). 꺼짐 상태 설명(`지금은 알림을 보내지 않아요`)도 **스위치가 이미 말하는 것**이라 뺐다 — 마스터 subtitle 은 **켜졌을 때만** 있다.
  - 남은 subtitle 3개는 전부 **"언제 오는지"** 를 말한다(시각 / 마지막 날 / 확정 안 했을 때). 새 알림을 추가하면 같은 결로 쓸 것.
  - **미발신 조건 안내**(`진행 중인 챌린지가 없거나 그날 이미 기록했다면…`)도 **사용자 결정으로 함께 삭제**했다. 조용한 미발신이 고장으로 읽힐 여지는 남지만, 설정 화면을 설명서로 만들지 않는 쪽을 택한 것이다 — 문의가 실제로 들어오면 그때 되살릴 것.
- **구독(리스너)을 붙이지 말 것.** 값은 재생 직전에 읽고, 리빌드가 필요한 건 설정 화면 자신뿐이라 로컬 state 로 충분하다 — 그래서 이 Scope 는 "화면 간 공유 상태"(Riverpod 도입 트리거)에 해당하지 않는다. 리스너를 붙이는 순간 그 판단이 뒤집힌다.

### 알림 (구현 완료)
> 설계·근거는 [decisions.md](docs/decisions.md) "알림 기능"(2026-08-02 회의). 코드는 `data/notification/` + `presentation/notification/`.

- **진실의 원천 3개**: 예약 계획은 [notification_plan.dart](tenk_app/lib/data/notification/notification_plan.dart) `buildNotificationPlan`(**부수효과 없는 순수 함수** — 문구·병합·건너뛰기 규칙이 전부 여기 있다), 재예약 진입점은 [notification_scheduler.dart](tenk_app/lib/data/notification/notification_scheduler.dart) `rescheduleAll` **하나뿐**, 플랫폼 호출은 [notification_service.dart](tenk_app/lib/data/notification/notification_service.dart).
- **로컬 알림만 쓴다 (`flutter_local_notifications`). FCM/Firebase 를 도입하지 말 것.** ① 알림 후보가 전부 **기기가 이미 아는 정보**로 예약된다(소셜 기능이 없어 서버 발신이 필요한 알림이 0개) ② **iOS 푸시는 Apple Developer Program 없이 불가능**(APNs 키)이라 FCM 을 고르면 iOS 는 알림 없는 앱이 된다 ③ Firebase 를 넣으면 installation ID 때문에 [play-console-app-content.md](docs/play-console-app-content.md) §0 의 "SDK 0개 / 기기 ID 미수집" 답안을 다시 짜야 한다. 서버 발신이 필요한 알림이 실제로 생기면 그때 재검토.
- **발신 채널은 3종** — ① 매일 기록 리마인더 ② 챌린지 종료 임박 ③ 확정 대기. **배지 근접은 별도 채널이 아니라 리마인더의 문구 승격**이다 — 둘은 같은 시각에 같은 말("오늘 기록해")을 해서 나눠 두면 근접일에 두 번 울린다.
- **같은 시각에 겹치면 발신 1개로 합치고 문구만 가장 급한 걸로 쓴다**: `마지막 날 > 배지 근접 > 평소`. **토글 3개는 그대로** — 합치는 건 *발신*이지 *채널*이 아니다(종료 임박만 켠 사람은 마지막 날에만 받는다). 같은 종류가 여러 챌린지에 걸릴 때도 **묶어서 1개**("확정을 기다리는 챌린지 3개가 있어요").
- **챌린지별 리마인더를 만들지 말 것** — 동시 진행이 되는 구조라 3개면 하루 3번이다. **앱 전체 하루 1회.**
- **시각·횟수**: 리마인더 **기본 오후 9시**(사용자 변경 가능 — [wheel_time_picker](tenk_app/lib/presentation/common/wheel_time_picker.dart) 재사용) / 종료 임박은 **마지막 날**(D-1 은 아직 급하지 않아 행동을 안 바꾼다) / 확정 대기는 **종료 다음 날 + 3일 뒤 총 2회, 오전 10시**(저녁 리마인더와 시간대를 갈라야 하루 두 번이 덜 피곤하고, "결과를 보러 오세요" 는 "기록하세요" 와 성격이 다르다).
- **안 보내는 조건도 설계의 일부다**: 진행 중 챌린지가 **0개면 리마인더를 예약조차 안 한다** / **오늘 이미 기록했으면 오늘 것 취소**. 후자는 앱을 열 때 전량 재예약하는 것만으로 자연히 정확해진다 — **앱을 안 열었다는 건 기록도 안 했다는 뜻**이라서(기록은 앱 안에서만 한다).
- ⚠️ **정확한 알람을 쓰지 말 것.** `USE_EXACT_ALARM` 은 알람시계·캘린더 앱 전용의 highly restricted 권한이라 TenK 은 자격이 없고 `SCHEDULE_EXACT_ALARM` 도 Android 13+ 에선 기본 거부다. **inexact 예약**으로 간다(분 단위가 중요한 알림이 아니다).
- **권한은 첫 챌린지를 만든 직후 + 설정 양쪽에서 요청하되 게이트가 아니다.** 기본값은 **권한 승인 = 마스터 ON + 종류별 3개 ON**.
  - ⚠️ **권유를 온보딩(연령→동의→닉네임) 뒤로 되돌리지 말 것 (2026-08-05, #22).** 원래 거기 있었는데 **그 시점엔 챌린지가 0개라 승인해도 예약되는 알림이 0건**이다 — `buildNotificationPlan` 이 리마인더·종료 임박을 `active.isEmpty` 로 건너뛰고 확정 대기도 챌린지가 있어야 생기기 때문. 승인한 사람이 첫 챌린지를 만들기 전까지 알림을 한 개도 못 받아 "켰는데 안 오네" 가 된다. **챌린지가 생긴 순간이 승인이 곧 실제 예약으로 이어지는 첫 순간**이라 거기로 옮겼다. 근거는 [decisions.md](docs/decisions.md) "알림 권유 화면".
  - **형태는 바텀시트** ([notification_priming_sheet.dart](tenk_app/lib/presentation/notification/notification_priming_sheet.dart) `showNotificationPriming`). **바깥 탭·드래그로는 닫지 않는다**(`isDismissible: false` + `enableDrag: false`) — 권유 기회가 유한한데 실수로 닫히면 아래 '한 번만' 플래그만 소진된다. 단 **시스템 back 은 막지 않는다**(= '나중에' 와 같은 결과) — 게이트가 아니고, 모달에서 back 을 막는 건 플랫폼과 싸우는 것이다.
  - **트리거는 [challenge_list_screen](tenk_app/lib/presentation/challenge/challenge_list_screen.dart) `_openCreate` 한 곳**이고 조건 3개 AND: ① **목록 길이가 늘었다**(같은 자리 주석대로 pop result 는 못 믿는다) ② 아직 안 물었다 ③ 마스터가 꺼져 있다. **플래그(`AppSettings.notificationPrimingShown`)는 띄우는 순간 세운다** — 승인·나중에·back 어느 쪽으로 닫혔든 시스템 다이얼로그 기회를 한 번 쓴 것으로 본다.
  - **플래그는 계정이 아니라 기기 단위다 — 재가입·재로그인해도 다시 묻지 않는다 (의도).** 시스템 권한 요청 기회 자체가 기기 단위라 계정을 새로 만들었다고 기회가 늘지 않기 때문이다. 새 계정에서 알림을 켜려면 설정 화면으로 간다. **계정별로 다시 묻게 만들지 말 것** — 같은 기기에서 탈퇴·재가입을 반복해 권한 다이얼로그를 여러 번 띄우려는 시도가 되고, 그 기회는 어차피 OS 가 2회(iOS 1회)로 막는다.
  - **시트 높이는 실기 기준 화면의 약 63%** 로, 뒤에 **방금 만든 챌린지 카드가 한 장 온전히 보인다**(360×640 에뮬 실측). ⚠️ 시안 단계에선 "대부분을 덮어 탭바까지만 보인다" 고 예측했는데 **실물이 더 낮았다** — 추정 높이로 판단하지 말 것. 더 줄이고 싶으면 아이콘 상자(72)를 빼는 안이 회의록에 남아 있다.
- ⚠️ **재요청 횟수는 앱이 정할 수 없다 — 재시도 루프를 만들지 말 것.** **Android 11+ 는 거부 2번, iOS 는 1번**이면 시스템 다이얼로그가 다시 뜨지 않고 요청이 **즉시 false 로** 돌아온다. 반복 호출을 넣으면 "버튼을 눌러도 아무 일이 없다" 가 되어 더 나쁘다. 프라이밍 시트가 존재하는 이유가 이것 — **그 귀한 1~2번을 맥락 없이 태우지 않으려는 것**이다.
  - 거부당하면 유일한 탈출구가 기기 설정이므로 **말만 하지 말고 데려다준다** — 설정 화면의 스낵바에 **`설정 열기` 액션**을 달아 `app_settings` 패키지로 **앱의 알림 설정 페이지에 바로** 꽂는다(`AppSettingsType.notification`, Android·iOS 16+ 지원). 직접 찾아가면 4~5단계다. `url_launcher` 로는 안 된다(Android 의 Activity action 은 URI 가 아니다).
  - 반대로 **프라이밍 시트의 거부 경로에는 이 안내를 붙이지 말 것** — 거기서 붙잡으면 게이트가 된다. 그냥 넘어가고 나중에 설정에서 켜게 한다.
- **알림 탭은 앱만 연다 (v1).** 딥링크는 부팅 게이트(버전→연령→동의→닉네임) 뒤에 배선해야 해 복잡도가 붙고, 목록에 이미 앰버 '확정하기' 마커가 있어 2탭이면 닿는다.
- **서버가 `currentStreak` 을 준다** — 배지 근접 문구에 현재 연속 일수가 필요한데 `ChallengeResponse` 에 그 값이 없다(클라가 아는 건 *획득한 배지*뿐). **연속 집계를 클라에서 재구현하지 말 것** — `consecutiveStreakEndingOn` 의 "오늘 기록이 없으면 어제 기준" 같은 규칙 때문에 서버와 어긋난다. NO_SPEND 는 DISTINCT 날짜라 예외적으로 클라가 이미 센다. **즉 이 기능은 백엔드 변경·재배포가 딸려온다.**
- **Android 알림 채널은 종류별 3개** — 시스템 설정과 앱 설정이 1:1 로 맞는다. 하나로 뭉치면 사용자가 시스템에서 종류별로 못 끈다.
- **설정값이 바뀌면 그 자리에서 재예약**한다(`NotificationScheduler.updatePrefs`). `AppSettings` 에 **구독(리스너)을 붙이지 말 것**(위 "설정" 규칙과 동일 — 붙는 순간 Riverpod 착수 트리거에 걸린다). `AppSettings` 는 챌린지 데이터를 모르므로 재예약은 setter 가 아니라 **스케줄러가 소유**한다.
- **재예약은 전량 취소 후 다시 걸기**(`cancelAll` → 계획 → 예약). 부분 갱신을 하면 취소·중복의 경우의 수가 폭발한다. 트리거 3곳: **앱 포그라운드 복귀**([main.dart](tenk_app/lib/main.dart) 의 `_TenkAppState` 가 관찰 — 복귀 시 어떤 화면일지 몰라 셸에 둔다) / **챌린지 목록 로드 성공**(방금 받은 응답을 넘겨 조회를 아낀다) / **기록 저장 직후**(`onRecordSaved`).
  - **inexact 배달 창과 겹치면 그날 알림 1회가 사라질 수 있다 — 알고도 그대로 두기로 한 동작이다** (2026-08-02 종결, 검증 기록은 [handoff-archive.md](docs/handoff-archive.md) #17). 그 순간 사용자는 이미 앱 안에 있어 손실이 없고, **부분 취소로 고치려 들면 경우의 수가 폭발한다.**
- **"오늘 이미 기록했는가" 는 로컬에 남긴 `lastRecordedDate` 로 판정한다** — 기록은 앱 안에서만 일어나므로 이게 곧 사실이고, 챌린지마다 상세를 다시 부르는 것보다 싸다.
  - **로컬 플래그라 기록을 지우거나 재설치하면 하루치가 어긋난다 — 알고도 그대로 두기로 한 동작이다** (2026-08-02 종결, 검증 기록은 [handoff-archive.md](docs/handoff-archive.md) #17). 다음 날 자동 회복되고, 정확히 맞히려 들면 로컬에서 세야 할 경우의 수가 는다.
  - **정확도를 올려야 할 일이 생기면 로컬 플래그를 다듬지 말고 서버 필드로 갈 것** — `ChallengeStatsCalculator` 가 이미 `daysWithAnyRecord` 를 들고 있어 `recordedToday` 를 **추가 쿼리 없이** 내려줄 수 있고, 그러면 삭제·재설치·다중 기기가 한 번에 정확해진다.
- **매일 반복 알림(`DateTimeComponents.time`)을 쓰지 말 것** — 날마다 문구가 다르고(마지막 날·배지 근접) "오늘만 건너뛰기" 가 필요한데 반복 알림은 하루만 뺄 수 없다. 대신 **날짜별로 따로 걸고**(기본 14일치, `kReminderHorizonDays`) 앱을 열 때마다 전량 다시 건다. 14일인 건 **iOS 대기 알림 64건 상한** 때문.
- **배지 근접 문구는 오늘 것만 계산한다** — 내일 이후는 오늘 기록 여부에 따라 값이 달라져 추측이 된다. 앱을 열면 어차피 다시 계산되므로 미래 날짜는 평소 문구.
- `POST_NOTIFICATIONS` 를 매니페스트에 추가하면 [play-console-app-content.md](docs/play-console-app-content.md) **§0 권한 목록을 같은 커밋에서 갱신**할 것. **데이터 안전 폼·privacy.html 은 변경 없음** — 로컬 알림은 수집이 아니다.

### 디자인 시스템 (색·타이포·테마)
- **방향: "절제된 베이스 + 리워드만 화려".** 평소 화면(목록·기록·상세)은 흰 배경 + 뉴트럴 잉크 텍스트 + 민트 accent 로 인지부하를 낮추고, **배지 획득·finalize·결과카드** 같은 페이오프 순간에만 컬러·모션을 몰아준다. 토스 공식 UX 가이드 + 카뱅 26주적금/챌린저스/뱅크샐러드 레퍼런스에서 도출 (레퍼런스 이미지·팔레트 근거는 `references/` 폴더).
- **진실의 원천 = [design/tokens.dart](tenk_app/lib/design/tokens.dart).** 색은 `AppColors`, 타이포는 `AppTypo`, 여백/라운드는 `AppSpacing`/`AppRadius`. **화면·위젯에서 hex(`Color(0x...)`)·매직넘버를 직접 박지 말고 토큰을 가져다 쓸 것.**
  - **팔레트**: Primary=민트 `#1FBE9C`(+틴트 `#E3F6F0`), 베이스=**화이트 `#FFFFFF`**(bg·surface 동일 → 카드는 **보더 `#EAECEF`로 구분**)/입력칸 채움 쿨그레이 `#F1F3F6`/잉크 쿨차콜 `#1C1D21`. Semantic=success `#12B886`/danger `#FF6B6B`/warn `#E0951B`. 상태색(시작전 그레이/진행중 민트/확정대기 앰버/성공 에메랄드/실패 코랄뮤트)은 각 틴트 포함. Reward(성공 골드 그라데이션+보라 / 실패 그레이)는 페이오프 전용. **뉴트럴은 쿨 그레이 계열** — 초기의 웜 크림(#FAF9F6)은 민트와 톤 충돌해 폐기(2026-07-15 리모델).
  - **예외 — 결과 카드**: [ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) 등 **오프스크린 캡처(PNG)** 되는 위젯은 ThemeData 영향을 받으면 안 되므로 색을 위젯에 hardcode 한다 (기존 규칙 유지). **`AppColors.reward*` 토큰 값은 이 카드의 hardcode 색과 정합**시켜 뒀으니 카드 색을 바꾸면 토큰도 같이 맞출 것 — 둘이 어긋나면 리워드 색 언어가 갈라진다. 어두운 배경 위 페이오프 글로우(배지 모달)는 `AppColors.rewardGlow`(골드).
    - **결과 카드는 상단 컬러 블록 + 하단 화이트다** (2026-08-01, #18): `rewardSuccessTop`(민트 채움 = `primary`)/`rewardFailTop`(**= `danger`**) + `rewardBottom`(화이트) + `rewardOnBlock`(블록 위 흰 텍스트) + `rewardSpendMark`(실패 그리드의 지출일 = `danger`) + `rewardSlotBorder`(배지 슬롯 테두리) + `rewardConfetti`(3색 — **민트 블록 위에서 보이는 색**이라 민트 계열은 못 쓴다). **성공 블록이 곧 브랜드색, 실패 블록이 곧 `danger`** 라 리워드 전용 accent 를 따로 만들지 말 것 — "앱과 이어진다" 가 이 디자인의 핵심이다. **다크 표면**(앱과 따로 논다)·**옅은 틴트**(썸네일에서 흰 카드로 보인다)·**딥 레드**(경고창처럼 무겁다) 전부 시도했다가 폐기했다.
    - ⚠️ **`rewardTint`/`rewardTintInk` 는 용도가 다르다** — 표면색이 아니라 **목록 사이에서 '리워드로 가는 입구'만 눈에 띄게** 하는 골드 틴트(챌린지 상세의 결과 카드 진입 카드). 둘을 섞어 쓰지 말 것.
- **전역 테마 = [design/app_theme.dart](tenk_app/lib/design/app_theme.dart) `buildTenkTheme()`.** [main.dart](tenk_app/lib/main.dart) 에서 `theme:` 로 배선. colorScheme/textTheme/scaffold 배경(화이트)/Card(elevation 0, radius 20, **보더 line**)/FilledButton·Elevated·Outlined/Input/AppBar(화이트·elevation 0)/SnackBar/TabBar 를 모두 토큰으로 정의. **이 한 곳이 룩의 절반 이상을 좌우** — 새 화면은 대부분 손 안 대도 새 룩이 자동 전파된다. 컴포넌트 기본 스타일을 바꾸려면 개별 화면이 아니라 여기서.
- **하이브리드 롤아웃 (Wave 0~5 완료)**: 토큰/테마(Wave 0)를 먼저 깔고, 화면 폴리시를 우선순위 웨이브로 적용. **Wave 0(토큰·테마) → 1(목록) → 2(상세) → 3(폼·필수 별표) → 4(리워드: 배지 모달 골드 글로우 + 리워드 토큰↔결과카드 정합) → 5(통계: 상세에 카테고리별 지출 카드).** 기능은 안 건드리고 보이는 층만.
  - **Wave 5 통계**: 챌린지 상세에 `_CategoryBreakdown`(뱅크샐러드식 가로 바 — 카테고리 아이콘/라벨/금액/% + 민트 진행바). `amounts` 에서 **클라 계산**(백엔드 무관), 지출>0 일 때만 노출, 금액 큰 순. 카테고리는 코드로 그룹핑하므로 검증 이전 자유텍스트 데이터는 '기타'로 폴백되어 합쳐 보일 수 있음(정상 — 9종 셀렉박스로 재저장하면 구분됨). 상세는 목록과 같은 언어(상태 pill + 남은 금액 히어로 + `ChallengeProgressBar`)의 요약 카드로 정합화했고, 확정 대기는 앰버 틴트 카드 + 전폭 확정 버튼, 진입 카드(결과카드/영상)는 공용 `_EntryCard` 로 통일.
- **리모델 (2026-07-15, Wave 0~5 이후)**: ① 카드 **좌측 상태색 스트라이프 제거** — 탭+섹션이 이미 상태로 분류하므로 중복. 상태색은 우상단 마커/칩에만 남김. ② **목록 카드 높이 통일** — 상태 무관 동일 구조(이름+마커 / 남은금액(또는 목표) / 진행바 / 캡션 한 줄), 배지는 카드에서 제외(상세에만 노출)해 높이 변동 제거. ③ **베이스 크림→화이트** + 쿨 그레이 뉴트럴(위 팔레트).
### 로고 / 앱 아이콘
> 2026-08-02 확정 (#6). 형상의 진실의 원천은 **[assets_src/icon/generate_icons.py](tenk_app/assets_src/icon/generate_icons.py)**, 사용법·함정은 같은 폴더의 [README.md](tenk_app/assets_src/icon/README.md), 후보 비교·탈락 사유는 [decisions.md](docs/decisions.md) "로고·앱 아이콘".

- **마크 = `10`.** 세로획+깃발이 `1`, 오른쪽 링이 `0` 이면서 **예산 게이지**다. 흰 바탕 + 민트 마크(`AppColors.primary`) + 옅은 트랙(`AppColors.logoTrack`).
  - **워드마크가 `TenK` 를 담당하므로 마크는 `10` 만 진다** — 세 글자를 두 글자로 줄여 48px(mdpi 런처)에서 형태가 남는다. 아이콘은 "예쁜가" 가 아니라 **"48px 에서 형태가 남는가"** 로 고른 것이라, 되돌릴 땐 이 기준을 먼저 확인할 것.
  - ⚠️ **트랙은 '완전한 원' 이어야 한다.** 갭만 열어둔 안은 작은 크기에서 `0` 이 **`C` 로 읽혔다**(`1C`). 트랙이 갭을 메워야 `10` 으로 읽힌다 — **트랙을 지우거나 `primaryTint` 처럼 더 옅은 색으로 바꾸지 말 것.** 결과 카드 워터마크가 뮤트 톤이면서도 트랙을 남기는 이유가 이것이다.
  - 함께 검토한 안: `T`(가로획을 게이지로 — 워드마크 `TenK` 의 첫 글자와 겹쳐 `T TenK` 로 읽힘), `10K`/`KK`(세 글자라 48px 에서 획이 가늘어짐), `K`(`10` 을 변형 — 잘 읽히나 숫자 의미가 사라짐), 링 게이지 단독으로 K 만들기(**닫힌 곡선은 K 의 '팔' 로 안 읽힌다** — 실측 확인).
- **마크는 자산 PNG 가 아니라 코드로 그린다 — 양쪽에 하나씩.** 파이썬(런처 아이콘 PNG 생성) + Dart [design/tenk_logo.dart](tenk_app/lib/design/tenk_logo.dart) `TenkLogoPainter`(앱 안 렌더). ⚠️ **비율 상수를 바꾸면 두 파일을 같이 고칠 것** — 한쪽만 고치면 런처 아이콘과 앱 안 로고가 갈라진다. Dart 가 쓰는 잉크 bbox 는 `python generate_icons.py --ink` 로 다시 뽑는다.
  - ⚠️ **단 `MARK_EXTENT`(마크가 아이콘 캔버스에서 차지하는 비율, 현재 **0.70**)는 예외 — 파이썬에만 있고 Dart 엔 대응 상수가 없다.** 형상이 아니라 **캔버스 안의 여백**을 정하는 값이고, `TenkLogoPainter` 는 주어진 박스를 꽉 채워 그려서(`unit = shortestSide / max(inkW, inkH)`) 여백 개념 자체가 없기 때문. 이 값만 바꿀 땐 **Dart 무변경이 정상**이고 잉크 bbox 도 안 변한다(2026-08-05 #25 에서 0.56→0.70 으로 키우며 확인).
  - Dart 쪽을 `Image.asset` 으로 되돌리지 말 것 — 색을 호출부가 정해야 민트/흰색/뮤트 반전을 자산 여러 벌 없이 처리하고, **결과 카드 캡처 경로에서 `precacheImage` 가 필요 없다**(배지 PNG 와 다른 점).
- **`flutter_launcher_icons` 를 도입하지 말 것.** 그 도구도 원본 PNG 는 손으로 만들어야 해서 얻는 게 없고, 생성기가 둘이 되면 산출물이 갈라진다. 밀도·플랫폼 전부 위 스크립트 한 번(`python generate_icons.py`, 41개)으로 나온다.
- **산출물을 손으로 갈아끼우지 말 것.** Android legacy·원형·adaptive 전경·themed 모노크롬 5밀도 + `mipmap-anydpi-v26/*.xml` + `values/colors.xml`(`ic_launcher_background`) + iOS `AppIcon.appiconset` 전 크기 + Play 업로드용 512 가 전부 스크립트 산출물이다.
  - ⚠️ **iOS 아이콘에 알파 채널이 있으면 App Store 업로드가 거부된다**(스크립트가 RGB 로 평탄화하는 이유). ⚠️ **adaptive 는 108dp 중 가운데 72dp 만 보인다** — 전경 배율(`ADAPTIVE_SAFE`)을 빼면 원형 런처에서 획이 잘린다. ⚠️ `Contents.json` 은 스크립트가 **읽기만** 한다(슬롯을 늘리려면 Xcode 로 먼저 갱신).
- **로고 노출 지점 3곳**: ① 로그인 화면 [TenkLogoLockup](tenk_app/lib/design/tenk_logo.dart)(마크 + `TenK` + '만원 챌린지') ② 결과 카드 워터마크(마크 + `TenK` 가로 조합, 뮤트 톤 + 트랙 유지) ③ 런처 아이콘. **워드마크 표기는 항상 `TenK`** (아래 "릴리스 빌드 / 배포" 의 브랜드 규칙).
- **스플래시(`launch_background.xml`)에는 로고를 넣지 않았다 (의도).** 스플래시·로그인 화면이 둘 다 흰 배경이라 지금은 이음매가 안 보이는데, 스플래시에만 로고를 넣으면 로그인 화면 로고와 위치·크기가 어긋나며 점프가 생긴다. 넣으려면 두 화면의 좌표를 함께 맞출 것.

### 모달 사용 기준 (다이얼로그 / 바텀시트 / 화면)
> 2026-07-29 확정. **새 UI 를 만들 때 이 표로 형태를 먼저 정할 것** — 같은 성격의 상호작용이 화면마다 다른 형태로 뜨면 앱이 산만해진다.

| 성격 | 형태 | 예 |
|---|---|---|
| **파괴적 행동 직전의 확인** ("정말?") | **`AlertDialog`** | 챌린지·기록 삭제, 회원 탈퇴, 테스트 재생성 |
| **흐름을 막고 알리는 것** | **`AlertDialog`** | 만 14세 미만 안내, 권장 업데이트, 탈퇴 계정 복귀 선택 |
| **'내 정보' 의 내 속성 편집** | **화면(push)** | 닉네임([NicknameEditScreen](tenk_app/lib/presentation/profile/nickname_edit_screen.dart)), 성별([GenderEditScreen](tenk_app/lib/presentation/profile/gender_edit_screen.dart)) |
| **폼·목록 안에서 값 하나 고르기/고쳐쓰기** | **바텀시트** | 카테고리, 의견 유형, 챌린지 이름, export 자막 |
| **권유 — 지금 이 맥락에서만 물을 수 있는 것** | **바텀시트**(바깥 탭·드래그로 안 닫힘) | 알림 권유([showNotificationPriming](tenk_app/lib/presentation/notification/notification_priming_sheet.dart)) |
| 축하·연출 | 풀스크린 모달 | 배지 획득 |

- 갈림길은 **"원래 화면의 맥락을 유지해야 하나"** 하나다. 설정형 드릴다운('내 정보')은 떠나도 되니 화면, 입력 중인 폼·진행 중인 챌린지·클립 목록 위에서 값만 고치는 건 맥락이 보여야 하니 바텀시트.
- **확인 다이얼로그를 화면으로 빼지 말 것** — 되돌릴 자리가 멀어져 오히려 위험해진다.
- **'권유' 는 시트지만 바깥 탭·드래그로 닫히지 않는다** (2026-08-05 신설). 일반 선택 시트와 달리 **다시 물어볼 수 없는 것**(시스템 권한처럼 요청 기회가 유한한 것)을 묻기 때문에, 실수로 닫히면 되돌릴 길이 설정 화면밖에 없다. 시트를 고른 건 **뒤 맥락(방금 만든 챌린지)이 보여야 하기 때문**이고, 그래도 **시스템 back 은 막지 않는다**(게이트가 아니다).
- 공용 위젯 4종이 이 기준의 구현체다. **새로 만들지 말고 이걸 쓸 것**:
  [selection_sheet.dart](tenk_app/lib/presentation/common/selection_sheet.dart) `showSelectionSheet`(목록 택1) / [text_input_sheet.dart](tenk_app/lib/presentation/common/text_input_sheet.dart) `showTextInputSheet`(텍스트 한 값) / [selection_field.dart](tenk_app/lib/presentation/common/selection_field.dart) `SelectionField`(**폼 필드** — 탭하면 선택 시트) / [tap_field_box.dart](tenk_app/lib/presentation/common/tap_field_box.dart) `TapFieldBox`(탭 필드 공용 룩 — 날짜·시간·선택 칸이 공유).
- **`DropdownButtonFormField` 를 쓰지 말 것 (2026-07-29 전환 완료).** 카테고리·의견 유형이 쓰던 드롭다운은 전부 `SelectionField` 로 갈아탔다. `SelectionField` 는 **`FormField` 로 감싸 `validator` 를 유지**하므로 기존 `Form.validate()` 검증 흐름이 그대로 돈다 — 드롭다운으로 되돌리면 선택 UI 언어가 다시 갈라진다.
- **`showSelectionSheet`/`showTextInputSheet` 의 반환 `null` 은 '취소'** 다. '선택 안 함' 같은 빈 값을 선택지로 두려면 sentinel 을 쓸 것 (null 을 값으로 쓰면 취소와 구분되지 않는다 — `GenderEditScreen._none` 이 그 패턴).

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
- **Scope는 도메인별로 하나씩** `app/scopes.dart`에 추가. 개수 임계는 **10개** — 넘으면 Riverpod/Provider 도입을 재검토한다 (2026-07-29 회의에서 5→10 상향).
  - **단 개수는 보조 지표일 뿐이고, 진짜 착수 트리거는 "화면 간 공유 상태가 생길 때"다.** Scope 에 담기는 건 앱 생애 내내 값이 안 바뀌는 **stateless API 객체**뿐이라 `updateShouldNotify` 가 사실상 항상 false — 개수가 늘어도 리빌드·정합성 비용이 0 이다. 실제 비용은 [main.dart](tenk_app/lib/main.dart) 의 중첩 한 겹 + 조립 보일러플레이트(생성·필드·중첩 3곳)뿐. **공유 상태가 없는 한 개수만 보고 도입하지 말 것** — 상태 관리 라이브러리를 DI 용도로만 끌고 오는 건 과설계다.
  - 상태는 화면별 로컬(`AsyncStateMixin`)로 들고, 화면 간에는 명시적으로 넘긴다(예: 메뉴 → 계정 설정에 `User` 전달). 이 방식이 깨지는 순간(예: 배지 알림을 여러 진입점에서 띄우려고 global notifier 로 승격)이 곧 재검토 시점. 근거는 [decisions.md](docs/decisions.md) "Flutter 상태 관리 재검토".
- **새 화면 코드가 `import '../../main.dart'` 하면 잘못된 방향.** Scope·SessionGate·navigatorKey는 모두 `app/`에 있다.

## 코딩 컨벤션 — 백엔드

- **컨트롤러는 얇게**, 비즈니스 로직은 서비스에. 엔티티는 정적 팩토리 메서드로 생성하고 invariant 검증.
- **에러는 `BusinessException(ErrorCode.XXX)`로 던지기.** 새 케이스는 `ErrorCode` enum에 추가. 메시지는 한국어.
- **클라이언트 잘못을 500 으로 내보내지 말 것.** [GlobalExceptionHandler](tenk-backend/src/main/java/com/hjson/tenk/common/exception/GlobalExceptionHandler.java) 의 `handleEtc(Exception)` 이 모든 걸 받아 **C0001/500** 으로 내리기 때문에, 디스패치 단계 예외에 전용 핸들러가 없으면 *잘못된 호출*이 *서버 장애*와 같은 신호로 찍힌다 — 로그·모니터링에서 진짜 장애를 못 찾고, 앱은 재시도해도 소용없는 요청을 재시도한다. 현재 막아둔 갈래는 `handleUnreadableBody`(깨진 body → 400)와 `handleMalformedRequest`(경로변수·쿼리 타입 불일치·multipart part 누락 → 400 / 없는 경로 → 404 / 메서드 → 405 / Content-Type → 415). **파싱 실패 원문은 내부 정보라 응답에 담지 않고 로그로만** 남긴다. 회귀 가드는 [MalformedRequestIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/common/exception/MalformedRequestIntegrationTest.java) 7건 — **새 엔드포인트를 추가했는데 이게 깨지면 핸들러가 아니라 그 엔드포인트를 의심할 것.**
- **DTO는 record로**. 요청 DTO는 Bean Validation 어노테이션 사용.
- **코드성 컬럼은 `VARCHAR` + `@Enumerated(EnumType.STRING)` 로 통일한다** (2026-07-30 확정, 8개 전부 적용됨).
  - **MariaDB 네이티브 `ENUM(...)` 을 쓰지 말 것.** 상수 목록이 코드와 DB 두 곳에 생겨 어긋나고(`AuthProvider.TEST` 가 실제로 그랬다), 값을 추가·삭제할 때마다 `ALTER TABLE` 이 필요해진다 — `VARCHAR` 면 `UPDATE` 한 줄로 끝난다(`Gender.OTHER` 제거가 그 사례). 정렬이 사전순이 아니라 선언 순서인 점, 정수와 비교하면 인덱스로 해석되는 점도 함정이다. 근거는 [decisions.md](docs/decisions.md) "DB 코드성 컬럼 정리".
  - **`@Enumerated(EnumType.ORDINAL)` 은 절대 쓰지 말 것** — 상수 순서만 바꿔도 과거 데이터의 의미가 통째로 뒤집힌다. 현재 한 곳도 없다.
  - ⚠️ **enum 상수를 지우거나 이름을 바꿀 땐 DB 정리가 한 쌍이다** — `UPDATE <table> SET <col>=NULL(또는 대체값) WHERE <col>='<지운 값>';` 을 **이미지 재배포 전에** 칠 것. enum 에 없는 문자열이 남아 있으면 그 row 조회가 예외로 죽는다.
  - **룩업 테이블(FK)은 "코드 말고 그 값에 딸린 다른 정보가 있을 때"만.** 해당하는 건 `badge`(조건값·아이콘 경로) 하나이고 이미 그렇게 돼 있다. 코드가 전부인 값에 테이블을 만들면 컬럼 하나짜리 테이블이 된다 — 과설계.
- **트랜잭션**: 서비스 클래스는 기본 `@Transactional(readOnly = true)`, 쓰기 메서드만 `@Transactional`.
- **사용자 ID 주입**: 컨트롤러 파라미터에 `@CurrentUserId Long userId` 사용. (내부적으로 `@AuthenticationPrincipal(expression="userId")`)
- **댓글은 최소화.** "왜"가 비자명할 때만 작성. JavaDoc은 정책 문서 역할일 때만 (예: `BadgeGrantService` 상단).
- **새 API를 만들 때**: `@Tag`, `@Operation` 어노테이션을 빠뜨리지 말 것 (Swagger).
- **LAZY 연관 매핑된 엔티티를 응답 DTO로 변환할 때**: 컨트롤러가 트랜잭션 밖에서 매핑하면 `LazyInitializationException`. **컨트롤러에 `@Transactional` 붙이지 말고, repository 쿼리에서 `JOIN FETCH`로 같이 끌어와라.** N+1도 피한다. 회귀 가드는 `@SpringBootTest` 통합 테스트로 — 단위/`@DataJpaTest`는 못 잡는다 ([UserBadgeRepository.findByUserOrderByCreatedDtDesc](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/UserBadgeRepository.java) + [BadgeControllerIntegrationTest.returnsAcquiredBadgesWithBadgeFieldsResolved](tenk-backend/src/test/java/com/hjson/tenk/domain/badge/BadgeControllerIntegrationTest.java) 패턴 참고).

## 코딩 컨벤션 — Flutter

- **화면의 비동기 로딩은 `AsyncStateMixin` + `AsyncStateView` 사용**. `FutureBuilder` 금지.
  - **재로딩 실패는 mixin 이 SnackBar 로 알린다 — 화면에서 따로 처리하지 말 것.** `AsyncStateView` 는 `data != null` 이면 계속 builder 를 그려서 재로딩 에러를 아무도 안 읽는다. 그대로 두면 **새로고침이 성공한 것처럼 보여** 사용자가 stale 을 fresh 로 오인하므로, `reload()` 가 *데이터가 이미 있는 상태에서* 실패하면 `새로고침 실패: …` 를 띄운다(첫 로드 실패는 `ErrorView` 담당이라 중복 없음). 2026-07-31 에뮬 실측으로 확인된 갭이다. 이유: `FutureBuilder`가 새 future로 교체돼도 stale snapshot으로 그리는 케이스가 있어 챌린지 생성/삭제 후 갱신이 누락된 적이 있음. mixin은 `_loading/_data/_error/_loadGen` 4-tuple과 stale-response 가드를 한 곳에 캡슐화한다. 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state를 들 것. ([presentation/common/async_state.dart](tenk_app/lib/presentation/common/async_state.dart))
- **`Scope.of(context)` 등 InheritedWidget 의존 호출을 `initState()` 안에서(또는 initState 가 동기적으로 부르는 메서드의 첫 await 이전에) 하지 말 것.** `dependOnInheritedWidgetOfExactType` 는 initState 완료 전엔 `... called before initState() completed` 로 크래시한다. `AsyncStateMixin` 의 `fetch()` 는 `didChangeDependencies` 단계라 안전하고, mixin 을 안 쓰는 화면은 `WidgetsBinding.instance.addPostFrameCallback((_) => ...)` 으로 첫 프레임 이후에 접근할 것 ([result_card_screen](tenk_app/lib/presentation/challenge/result_card/result_card_screen.dart) / [export_prefetch_screen](tenk_app/lib/presentation/challenge/export/export_prefetch_screen.dart) 패턴). 버튼 콜백·build 안에서의 `Scope.of` 는 build phase 이후라 무관. 실제 [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 이 이 규칙 위반으로 신규 가입 직후 크래시한 적 있음 (2026-06-16 수정).
- **HTTP 응답은 항상 `unwrapData` / `unwrapList` 통과**. 백엔드 envelope 풀이 로직을 도메인마다 복붙하지 말 것. ([data/api/api_response.dart](tenk_app/lib/data/api/api_response.dart))
- **에러는 SnackBar로 노출 시 `toApiException(e).message` 사용**. dio 에러·서버 에러·기타 예외를 일관된 한국어 메시지로 변환.
- **예외 원문을 사용자에게 노출하지 말 것 (`'실패: $e'` 금지).** dio 의 `message` 와 Dart 예외의 `toString()` 은 **영문**이라 한국어 화면이 영문으로 덮인다. [api_error.dart](tenk_app/lib/data/api/api_error.dart) 가 진실의 원천 — 서버 envelope 이 있으면 그 한국어 메시지를, 없으면 **원인별 3분기** 폴백(`networkErrorMessage` 연결 / `timeoutErrorMessage` 지연 / `unknownErrorMessage` 그 외)을 준다. 원인을 뭉뚱그리지 않는 건 **"인터넷이 끊긴 것"과 "서버가 느린 것"에 사용자가 취할 행동이 다르기** 때문.
  - 한국어 메시지를 자체적으로 들고 있는 예외(`GalException`·`VideoComposeFailed`·`WithdrawnAccountException`·우리가 던지는 `CameraException`)는 **`on XxxException catch` 로 먼저 잡는다.** 뒤의 포괄 `catch` 까지 흘러오는 건 정체를 모르는 예외뿐이라 원문을 버려도 잃는 정보가 없다 — 이 순서를 뒤집으면 한국어 안내가 일반 문구에 먹힌다.
  - **기기 기능 실패는 원인별로 갈라 안내한다** — 카메라는 [_cameraErrorMessage](tenk_app/lib/presentation/amount/amount_camera_screen.dart) 가 **권한 거부만** 따로 짚어준다(설정으로 보내야 하므로). 플랫폼이 주는 `description` 은 영문이라 그대로 쓰지 말 것.
- **사용자에게 보이는 문구는 전부 해요체다 — 합쇼체(`…합니다`/`…없습니다`)를 섞지 말 것.** 경고를 무겁게 하려고 어미를 올리고 싶어지는데(챌린지 삭제 다이얼로그가 실제로 그랬다), 무게는 **문장이 말하는 사실과 버튼 색**이 만든다. 2026-08-04 에 앱 전체를 훑어 정리했고 남은 합쇼체는 [nickname_setup_screen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 의 `환영합니다!` **하나뿐**(문장이 아니라 인사말이라 예외). 예외를 늘리려면 여기에 함께 적을 것.
  - **설명을 덧붙이고 싶을 때 세 가지는 쓰지 말 것**: ① 제목·라벨이 이미 말하는 것 ② 앱 밖 상식(무음 모드면 소리가 안 난다 등) ③ 구현 디테일(로컬 알림 여부, "하나라도 빠지면 전체가 중단된다" 같은 우리 쪽 사정). 같은 말이 **두 화면에서 반복되면 고칠 때 읽는 자리**를 정본으로 두고 나머지를 지운다(export 목록 안내 → 자막 편집 시트).
  - 반대로 **지우면 안 되는 설명**: 수집 목적 고지(법적 요건) · 비가역 제약 · **입력칸이 없는 이유**(무지출 일시) · 게이트에서 빠져나가는 조건(강제 업데이트) · 미리보기가 없는 화면의 결과 설명(export 설정). 판정이 갈리면 **문서로 논쟁하지 말고 에뮬로 A/B 를 찍어 비교할 것** — 실제로 두 번 결론이 뒤집혔다([handoff-archive.md](docs/handoff-archive.md) 2026-08-04 #26). 이미 "현행 유지" 로 판정난 목록도 거기 있다.
- **모델은 immutable + `fromJson` 팩토리**. `@immutable` 어노테이션 + `final` 필드. JSON 키는 백엔드 응답 그대로 (snake/camel 변환 X).
- **Navigator push/pop의 generic은 양쪽 모두 명시** (`push<T>(MaterialPageRoute<T>(...))`). push 결과에 의존하지 말고 push 종료 시점에 무조건 새로고침 — 결과 누락 케이스가 있음 ([docs/handoff.md](docs/handoff.md) "함정 — Flutter" 참고).
- **위젯 중복은 즉시 추출**: 두 화면이 같은 위젯을 쓰면 도메인 위젯은 `presentation/<domain>/widgets/`, 도메인 무관 공용 위젯은 `presentation/common/`에. 화면 파일 안에 `_PrivateView` 클래스로 두는 건 그 화면에서만 쓸 때.
- **앱은 세로 고정이다** ([main.dart](tenk_app/lib/main.dart) `setPreferredOrientations` — portraitUp/Down). TenK 은 구조적으로 세로 전용이고(세로 2초 영상 · 9:16 결과 카드 · 단일 컬럼 화면), **가로를 풀면 앱 영역이 387dp 로 줄어 키보드가 없어도 레이아웃이 눌린다**(2026-08-04 실기 확인 — 시각 picker 휠이 반쪽씩 잘렸다). 가로를 지원하려면 게이트·폼·다이얼로그를 전부 다시 봐야 하므로 **잠금을 풀지 말 것.**
- **Scaffold body 는 항상 `SafeArea(top: false, child: ...)` 로 감싼다** (AppBar 가 있는 화면 기준). 안드로이드 제스처 내비/3-버튼 바가 본문 하단 액션 버튼을 가리는 기기가 있어 일관 적용한다. AppBar 가 없는 화면(login 처럼)만 `SafeArea(child: ...)` 전체 방향. ⚠️ **`bottomNavigationBar` 슬롯도 반드시 `SafeArea` 로 감쌀 것** — Scaffold 는 이 슬롯에 inset 을 **넣어주지 않는다.** `BottomNavigationBar`/`NavigationBar` 위젯이 *자체적으로* SafeArea 를 갖고 있어 자동처럼 보일 뿐이고, `Padding`+버튼을 직접 넣으면 **제스처 바에 잘린다.** (예전 이 자리에 "자동 처리라 불필요, export_screen 패턴은 historical" 이라고 적혀 있었는데 **틀린 규칙이었고, 그걸 보고 만든 화면 2개가 실제로 잘렸다** — 2026-08-03 실기기 확인.) 화면별로 SafeArea 가 있는 곳·없는 곳이 섞이면 디바이스 따라 가림이 들쭉날쭉해진다.
  - ⚠️ **바텀시트도 같다** — `showModalBottomSheet` 은 화면 바닥에 붙으므로 시트 내용을 `SafeArea(top: false)` 로 감쌀 것. 공용 시트 2종([selection_sheet](tenk_app/lib/presentation/common/selection_sheet.dart) / [text_input_sheet](tenk_app/lib/presentation/common/text_input_sheet.dart))이 한동안 **한쪽만** 갖고 있었다.
  - **규칙 대신 테스트가 지킨다** — [test/keyboard_layout_test.dart](tenk_app/test/keyboard_layout_test.dart). 이 자리가 *틀린 규칙 때문에* 두 번 깨졌으므로 문장을 믿지 말고 가드를 늘릴 것. 실행은 `cd tenk_app && flutter test`.
- **키보드가 뜨는 화면에서 하단 CTA 를 `Column` 의 고정 자식으로 두지 말 것.** 키보드가 먹은 높이를 스크롤 영역 혼자 떠안아 짜부라지고, 결국 **입력칸이 버튼 밑으로 잘린다** — 2026-08-03 실측: 560dp 화면 + 키보드 300 에서 연령 확인 화면의 스크롤 영역이 **38px** 로 줄어 입력칸(56px)이 확인 버튼에 **14px 덮였다**. 스크롤이 아예 없으면(`Spacer()` 만 있는 경우) 그대로 **RenderFlex overflow** 로 터진다.
  - 방법은 둘 중 하나다: ① 버튼을 **`ListView` 의 마지막 항목**으로 (기록·수정·챌린지 생성·닉네임 변경이 이미 이 형태) ② 버튼이 **바닥에 붙어 보여야 하는 게이트/온보딩 화면**은 공용 위젯 [BottomActionScrollView](tenk_app/lib/presentation/common/bottom_action_scroll_view.dart) — 공간이 남으면 액션을 바닥에 붙이고 모자라면 본문과 함께 스크롤한다. 연령 확인·약관 동의·닉네임 설정 3화면이 이걸 공유한다.
  - ⚠️ **`Spacer()` 하나로 액션을 밀어내면 최소 여백이 보장되지 않는다.** 내용이 넘치는 순간 `Spacer` 는 0 으로 접혀 **본문 마지막 줄과 버튼이 맞붙는다**(2026-08-03 실기기: 연령 확인 화면의 안내문과 확인 버튼이 11dp 까지 좁아졌다). `BottomActionScrollView` 는 **접히지 않는 `minActionGap`(기본 24)** 을 `Spacer` 와 **따로** 둬서 이걸 막는다 — 둘의 역할이 다르니 하나로 합치지 말 것.
  - **키보드가 없어도 작은 화면만으로 터진다** — 알림 권유가 `Spacer()` 2개 + 고정 버튼 구조라 560dp 에서 **2.6px overflow** 였다(2026-08-03 실기기 발견, 지금은 시트로 바뀌었다). 입력칸이 없는 화면도 이 규칙의 대상이다.
  - `bottomNavigationBar` 로 버튼을 고정하는 것도 답이 아니다 — 잘리지는 않지만 **본문 스크롤 영역이 짜부라지는 건 똑같다**. 그 슬롯은 본문이 `ListView` 라 스크롤 영역이 넉넉한 화면(의견 보내기·탈퇴·export)에만 쓴다.
- **빈 곳 탭 시 키보드 닫기는 전역 처리** — [main.dart](tenk_app/lib/main.dart) 의 `MaterialApp.builder` 가 `GestureDetector(translucent, onTap: unfocus)` 로 전 화면에 적용한다. **화면마다 GestureDetector 를 새로 달지 말 것** (입력칸 있는 화면이 계속 늘어나는데 화면별로 붙이면 빠지는 곳이 생긴다 — 실제로 전 화면에 아예 없던 상태였다). 하위 위젯의 탭·핀치는 제스처 아레나에서 안쪽 recognizer 가 이기므로 카메라 탭 초점·휠 picker 등은 영향 없다.
- **폼 키보드 이동 규칙 (전 화면 공통)**: 입력칸이 2개 이상인 폼은 **다음 칸이 있으면 `textInputAction: next` + `onFieldSubmitted`(TextField 는 `onSubmitted`)에서 다음 `FocusNode` 를 직접 `requestFocus()`**, **마지막 칸이면 `done` + 제출**. 다음 대상을 traversal 자동 계산에 맡기지 말 것 — 중간에 탭 필드(날짜 picker 등 `InkWell`)가 끼면 포커스가 그쪽으로 샌다 ([challenge_create_screen](tenk_app/lib/presentation/challenge/challenge_create_screen.dart) 의 이름→목표금액이 실제 사례). **자릿수 고정 숫자 칸**(생년월일 년/월/일)은 숫자 키보드에 액션 키가 없으므로 **`maxLength` 를 채우면 자동 이동**하고, 짝으로 **빈 칸 백스페이스 시 이전 칸 복귀**를 같이 둔다(자동 이동만 있으면 오타 수정이 막힌다) — 구현은 [age_gate_screen](tenk_app/lib/presentation/legal/age_gate_screen.dart) `_BirthField` 가 레퍼런스. **autofocus 는 "빈 칸을 반드시 채워야 하는 단일 목적 화면·다이얼로그"에만** — 값이 pre-fill 된 화면([NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 은 카카오 닉네임이 채워져 있어 대부분 그대로 확정)에 걸면 키보드가 액션 버튼을 밀어올려 손해다.
- **날짜·시간 선택은 공용 헬퍼만 쓴다 — `showDatePicker`/`showTimePicker` 직접 호출 금지.** [common/date_time_picker.dart](tenk_app/lib/presentation/common/date_time_picker.dart) 의 `pickTenkDate` / `pickTenkTime` 을 경유할 것. 호출부가 4곳(챌린지 생성 시작/종료일, 기록 날짜·시간, 수정 시간)으로 흩어져 각자 옵션을 박으면 화면마다 다른 picker 가 뜬다.
  - **날짜는 Material 달력 picker**(`pickTenkDate`) 유지. 범위 밖 `initial` 은 헬퍼가 클램프하므로 호출부에서 미리 보정하지 말 것.
  - **시각은 Material `showTimePicker` 를 쓰지 않는다** — 아날로그 시계(dial)가 분을 맞추기 불편해서 **휠(드럼) 방식 자체 위젯**([common/wheel_time_picker.dart](tenk_app/lib/presentation/common/wheel_time_picker.dart))으로 대체했다. 규격: 오전·오후(2항, 순환 X) / 시 1~12(**무한 순환**) / 분 00~59(**무한 순환**), 가운데 숫자 탭 → 그 열만 직접 입력, 스크롤마다 `HapticFeedback.selectionClick`. **dial 로 되돌리지 말 것.**
  - **휠은 평면이다 — 3D 드럼으로 되돌리지 말 것.** `ListWheelScrollView` 기본값은 항목을 원통에 배치해 위아래가 기울고 작아지는데, `diameterRatio` 를 크게(`_flatDiameterRatio`) + `perspective` 를 거의 0 으로 + `useMagnifier: false` + `squeeze: 1` 로 곡률을 없애 **모든 항목이 같은 크기**다. 선택 여부는 **크기가 아니라 색으로만** 구분한다.
  - **선택 밴드는 민트 채움 + 흰 글자**(`primary` / `onPrimary`) — 날짜 picker 의 선택된 날(민트 원 + 흰 글자)·`FilledButton` 과 같은 언어. 콜론도 밴드 안이라 흰색이고, 직접 입력 오버레이도 같은 민트·같은 라운드라야 밴드가 이어져 보인다. **`surfaceAlt` 를 쓰지 말 것** — 다이얼로그 표면이 이미 옅은 틴트라 밴드가 오히려 더 밝아져 흰 알약처럼 보이고 "선택됨" 으로 안 읽힌다.
  - **시 휠이 경계를 넘으면 오전/오후가 자동 전환된다. 경계는 "11시↔12시" — 12시↔1시가 아니다.** 실제 시계가 오전 11시 다음 오후 12시(정오)로 넘어가므로 이렇게 해야 휠을 굴리는 게 24시간 타임라인을 그대로 걷는다. 12↔1 로 바꾸면 정오가 `오전 12시`(자정)로 잡혀 중간 한 칸이 12시간 틀어진다. 판정은 `_amPmBoundariesUpTo`(경계 개수 차가 홀수면 뒤집기). **분은 시로 carry 하지 않는다**(의도).
  - ⚠️ **직접 입력(가운데 숫자 탭)으로 키보드가 떠도 휠을 줄이지 말 것.** `AlertDialog` 는 공간이 모자라면 content 를 `Flexible` 로 **눌러버려** 항목이 반쪽씩 걸치며 숫자가 겹쳐 보인다(2026-08-03 실기기). 대응은 **공간이 될 때와 안 될 때를 가르는 것**: 되면 그냥 둬서 `Dialog` 기본 동작대로 키보드 위로 올라가게 하고, **안 되면 아래쪽 `viewInsets` 를 지워 원래 크기를 유지**시키고 위로 붙인다(부족한 만큼은 키보드가 덮되 입력칸은 남는다). *접는 것보다 덮는 게 낫다*가 결정이다(2026-08-04). ⚠️ **가용 높이를 재려고 `LayoutBuilder` 를 쓰지 말 것** — `AlertDialog` 의 `IntrinsicWidth` 측정과 충돌해 **다이얼로그가 통째로 렌더에 실패한다**(위젯 테스트는 이걸 못 잡았다 — 그래서 가드가 `takeException()` 까지 본다). 회귀 가드는 [test/wheel_time_picker_test.dart](tenk_app/test/wheel_time_picker_test.dart) 5건.
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
flutter test   # 위젯 테스트 20개 (로그인 스모크 1 + 하단 액션·키보드 레이아웃 11 + 휠 시각 picker 5 + 결과 카드 컨페티 3). 기기·서버 불필요
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
| 배지 카탈로그 변경 | 서버는 `badge` 테이블의 9행(STREAK 3/7/14/30, NO_SPEND 3/7/14/30, CHALLENGE_SUCCESS 1)으로 고정. 새 단계/타입 추가 시 **네 곳을 동시에 갱신**: ① [docs/schema.sql](docs/schema.sql)의 INSERT (+ DB에 수동 적용) ② [tenk_app/lib/data/badge/badge.dart](tenk_app/lib/data/badge/badge.dart)의 `BadgeType` enum (label 매핑까지) ③ [tenk_app/assets/badges/](tenk_app/assets/badges/)에 아이콘 파일 ④ [kBadgeLadder](tenk_app/lib/data/badge/badge.dart) 의 단계 배열 (**클라 단일 출처** — 무지출 성취감 카드 게이지 + 배지 획득 모달의 '다음 목표'가 공유한다. 사본을 새로 만들지 말 것) ⑤ 단계를 늘렸다면 [badge_style.dart](tenk_app/lib/presentation/challenge/widgets/badge_style.dart) 의 단계별 색 매핑 + [assets_src/badges/](tenk_app/assets_src/badges/) 원본·리사이즈. **챌린지 단위라 클라에 카탈로그 전체를 두지 않는다** — 획득한 것만 챌린지 응답에 인라인되므로 미획득 노출 위젯이 없음 |
| 배지 획득 연출 변경 | 위 "배지 획득 연출" 규칙이 진실의 원천. [badge_celebration_dialog.dart](tenk_app/lib/presentation/challenge/widgets/badge_celebration_dialog.dart)(3막 타임라인 상수 `_totalDuration`/`_impactAt`/`_impactStart`/`_impactPeak`/`_settleEnd` + `CustomPainter` 컨페티) / [badge_style.dart](tenk_app/lib/presentation/challenge/widgets/badge_style.dart)(단계별 5색 — 타입 아님) / [badge_next_goal.dart](tenk_app/lib/presentation/challenge/widgets/badge_next_goal.dart)('다음 목표', 도달 가능할 때만 사다리·아니면 완주 폴백). **9종 전부 동일 연출 유지**(위계는 자산 색이 만든다), **Lottie 로 되돌리지 말 것**(색 연동 불가), **CTA 를 힌트 텍스트로 되돌리지 말 것**(체인이면 `다음 (1/2)`). `showBadgeCelebrations` 는 챌린지를 받아야 한다(다음 목표 판정에 종료일 필요) + 모달 진입 전 `precacheImage`. 트리거는 [ChallengeDetailScreen](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) reload diff 한 곳뿐이고, **finalize 경로는 반드시 `reload()` 재조회**(위 "결과 카드" 함정). 수동 테스트는 [docs/seed-badge-demo.sql](docs/seed-badge-demo.sql) |
| 효과음·진동(설정) 변경 | 위 "설정" 규칙이 진실의 원천. 값은 [AppSettings](tenk_app/lib/data/settings/app_settings.dart)(`shared_preferences`) + `SettingsScope`, 화면은 [settings_screen.dart](tenk_app/lib/presentation/settings/settings_screen.dart). **`HapticFeedback` 직접 호출 금지 — `AppSettings` 헬퍼 경유**, 새 효과음은 재생 전 `soundEnabled` 확인. 자산은 royalty-free 다운로드만([assets/sounds/README.md](tenk_app/assets/sounds/README.md), 합성음 3회 반려 전례). **구독(리스너)을 붙이면** 이 Scope 가 "화면 간 공유 상태"가 되어 Riverpod 도입 트리거([decisions.md](docs/decisions.md) "Flutter 상태 관리 재검토")에 걸린다 |
| 알림 변경 | 위 **"알림"** 도메인 규칙 + [decisions.md](docs/decisions.md) "알림 기능" 이 진실의 원천. 규칙을 바꾸려면 대부분 [notification_plan.dart](tenk_app/lib/data/notification/notification_plan.dart) **한 파일**만 고치면 된다(순수 함수라 부수효과 없음). 넘지 말아야 할 선 6가지: ① **로컬 알림만**(FCM 금지 — iOS 는 유료 계정 없이 푸시 불가 + Play 데이터 안전 답안이 흔들린다. 도입 트리거는 decisions.md 참고) ② **발신 채널 3종**이고 배지 근접은 리마인더 **문구 승격**(별도 채널로 만들면 근접일에 두 번 울린다) ③ 겹치면 **발신 1개 + 문구 우선순위**(마지막 날 > 배지 근접 > 평소), 채널 토글은 유지 ④ **inexact 예약**(`USE_EXACT_ALARM` 자격 없음 — 매니페스트에 선언하지 말 것) ⑤ 프라이밍은 **첫 챌린지 생성 직후 바텀시트**이고 **게이트가 아니다**(back 차단 금지) — 온보딩 뒤로 되돌리면 챌린지 0개라 승인해도 예약이 0건이다 ⑥ 연속·무지출 집계를 **클라에서 재구현하지 말 것** — 서버 `ChallengeResponse.currentStreak`/`noSpendDays` 가 배지 지급과 같은 계산기([ChallengeStatsCalculator](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeStatsCalculator.java))를 쓴다. 재예약은 **전량 취소 후 다시 걸기**(부분 갱신 금지). 권한을 늘리면 [play-console-app-content.md](docs/play-console-app-content.md) §0 권한 목록 동시 갱신, **데이터 안전 폼·privacy.html 은 무변경**(로컬 알림은 수집이 아니다). 회귀 가드는 [ChallengeStatsCalculatorTest](tenk-backend/src/test/java/com/hjson/tenk/domain/challenge/ChallengeStatsCalculatorTest.java) + [ChallengeStatsIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/challenge/ChallengeStatsIntegrationTest.java) |
| 배지를 부여하는 로직 변경 | [BadgeGrantService](tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeGrantService.java) 는 항상 **챌린지 단위**로 평가. `evaluateForChallenge(challengeId)` / `grantChallengeSuccess(challengeId, result)`. 유저 단위 누적이 필요하면 새 서비스(추후 achievement 시스템)로 분리할 것 — 여기에 user 파라미터를 다시 끼우지 말 것. amount 쿼리는 `findByChallengeOrderBySpentDtAscCreatedDtAsc(challenge)` 사용. **STREAK는 연속, NO_SPEND는 누적** (서로 다른 행동에 대한 보상이라 정의가 다름). 단일 패스 `applyLadder` 가 grant/revoke 양방향을 처리 — 회수가 필요한 변경(예: 무지출 자동 삭제)에서도 별도 호출 없이 재평가만 하면 정합. |
| 사용자에게 보이는 문구 추가·변경 | **말투와 분량 기준은 [코딩 컨벤션 — Flutter]의 '해요체 통일' 항목이 진실의 원천.** 합쇼체를 섞지 말 것(예외는 `환영합니다!` 하나). 설명을 덧붙일 땐 **제목이 이미 말하는 것 / 앱 밖 상식 / 구현 디테일** 세 가지를 피하고, 같은 말이 두 화면에 있으면 **고칠 때 읽는 자리**만 남긴다. 반대로 **수집 목적 고지·비가역 제약·입력칸이 없는 이유·게이트 탈출 조건**은 지우지 말 것. 설정 화면은 [설정 (효과음·진동)]의 별도 규칙이 추가로 적용된다(subtitle 로 토글 이름을 반복하지 않는다). **이미 "현행 유지" 로 판정난 5건**은 [handoff-archive.md](docs/handoff-archive.md) 2026-08-04 #26 에 있으니 다시 후보로 올리지 말 것. 판단이 갈리면 에뮬로 A/B 를 찍어 비교한다 |
| 오류 응답·오류 문구 변경 | **서버는 [GlobalExceptionHandler](tenk-backend/src/main/java/com/hjson/tenk/common/exception/GlobalExceptionHandler.java) + [ErrorCode](tenk-backend/src/main/java/com/hjson/tenk/common/exception/ErrorCode.java), 앱은 [api_error.dart](tenk_app/lib/data/api/api_error.dart) 가 진실의 원천.** 새 `ErrorCode` 는 도메인 prefix 로 추가하고 메시지는 한국어. **클라이언트 잘못을 500 으로 내보내지 말 것** — 디스패치 단계 예외는 `handleMalformedRequest` 에 등록(회귀 가드 [MalformedRequestIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/common/exception/MalformedRequestIntegrationTest.java) 7건). 앱에서는 **예외 원문(`$e`)을 노출하지 말 것** — 서버 envelope 이 없으면 `toApiException` 의 원인별 폴백(연결/지연/그 외)이 한국어를 준다. 한국어 메시지를 자체적으로 든 예외(`GalException`·`VideoComposeFailed`·`CameraException` 등)는 포괄 catch 보다 **먼저** 잡을 것 |
| Flutter 새 화면의 비동기 로딩 | `AsyncStateMixin<W, T>` + `AsyncStateView<T>` 사용 ([presentation/common/async_state.dart](tenk_app/lib/presentation/common/async_state.dart)). `FutureBuilder` 금지. `fetch()` 오버라이드 + `didChangeDependencies`에서 `ensureLoaded()`. 외부 동작 결과를 즉시 반영하려면 `replaceData(next)`, 그 외 갱신은 `reload()`. 에러는 `toApiException(e).message`로 SnackBar 노출 |
| Flutter 새 공용 위젯 | 두 화면 이상이 같은 위젯을 쓰면 즉시 추출. 도메인 전용은 `presentation/<domain>/widgets/`, 도메인 무관은 `presentation/common/` |
| 화면 하단에 액션(버튼)을 붙일 때 | 위 "코딩 컨벤션 — Flutter" 의 SafeArea·키보드 규칙이 진실의 원천. **3택1**: 본문이 `ListView` 면 **버튼을 마지막 항목**으로 / 바닥에 붙어 보여야 하는 게이트·온보딩이면 [BottomActionScrollView](tenk_app/lib/presentation/common/bottom_action_scroll_view.dart) / `bottomNavigationBar` 를 쓸 거면 **반드시 `SafeArea`** (Scaffold 가 이 슬롯엔 inset 을 안 준다). 바텀시트도 `SafeArea(top:false)` 필수. **키보드가 뜨는 화면에서 CTA 를 `Column` 고정 자식으로 두지 말 것** — 스크롤 영역이 짜부라져 입력칸이 잘린다. 회귀 가드 [test/keyboard_layout_test.dart](tenk_app/test/keyboard_layout_test.dart) 11건 (`cd tenk_app && flutter test`) — **이 자리는 틀린 규칙 때문에 두 번 깨졌으니 문장보다 가드를 늘릴 것** |
| 날짜·시간 선택 / 시각 표기 추가·변경 | 진실의 원천은 [common/date_time_picker.dart](tenk_app/lib/presentation/common/date_time_picker.dart) — `pickTenkDate`/`pickTenkTime`(선택) + `formatTimeOfDay`/`formatDateWithTime`(표기). **화면에서 `showDatePicker`/`showTimePicker` 를 직접 부르거나 24시간제 고정 포맷을 새로 만들지 말 것** (위 "코딩 컨벤션 — Flutter" 참고). 한국어 라벨은 [main.dart](tenk_app/lib/main.dart) 의 `locale: Locale('ko')` 고정에서 오므로 **로케일을 시스템 추종으로 바꾸면 picker 만 영어로 튄다**. 시각 picker 본체는 자체 휠 위젯 [wheel_time_picker.dart](tenk_app/lib/presentation/common/wheel_time_picker.dart) — 무한 순환·직접 입력·**오전/오후 자동 전환 경계는 11↔12**(12↔1 아님)가 모두 UX 결정이라 유지. 폼의 `날짜 \| 시간` 2칸은 [DateTimeFields](tenk_app/lib/presentation/amount/widgets/date_time_fields.dart) 공유 (수정 화면은 날짜 읽기 전용) |
| 색·타이포·여백·컴포넌트 기본 스타일 변경 | 진실의 원천은 [design/tokens.dart](tenk_app/lib/design/tokens.dart)(`AppColors`/`AppTypo`/`AppSpacing`/`AppRadius`) + [design/app_theme.dart](tenk_app/lib/design/app_theme.dart)(`buildTenkTheme`). **화면에 hex·매직넘버 직접 박지 말 것** — 토큰을 가져다 쓰거나 토큰을 고쳐라. 컴포넌트(버튼/카드/입력 등) 기본 룩은 개별 화면이 아니라 app_theme 에서. 방향("절제+리워드")·팔레트(민트+화이트) 근거는 위 "디자인 시스템" + `references/`. **예외**: 오프스크린 캡처되는 결과 카드는 색 hardcode 유지 |
| 로고 · 앱(런처) 아이콘 변경 | 위 "로고 / 앱 아이콘" 규칙이 진실의 원천. 형상은 **[assets_src/icon/generate_icons.py](tenk_app/assets_src/icon/generate_icons.py)**(런처 PNG 생성) 와 **[design/tenk_logo.dart](tenk_app/lib/design/tenk_logo.dart)** `TenkLogoPainter`(앱 안 렌더) **두 곳에 같은 비율 상수**가 있다 — 한쪽만 고치면 갈라진다(Dart 가 쓰는 잉크 bbox 는 `--ink` 로 재추출). **단 `MARK_EXTENT` 는 아이콘 캔버스 여백 전용이라 파이썬에만 있다** — 그것만 바꿀 땐 Dart 무변경이 정상. 산출물은 **손으로 갈아끼우지 말고** `python generate_icons.py` 로 전 밀도·전 플랫폼 41개를 한 번에 갱신하고, 함정 4종(iOS 알파 금지 · adaptive 가운데 72dp · `Contents.json` 은 읽기만 · themed 는 단색이라 두 톤 소멸)은 [README](tenk_app/assets_src/icon/README.md) 참고. **`flutter_launcher_icons` 를 도입하지 말 것**(생성기가 둘이 된다). **게이지 트랙을 지우지 말 것** — 갭이 열리면 `0` 이 `C` 로 읽힌다. Play Console 아이콘은 `assets_src/icon/play_store_512.png` 를 콘솔에 직접 업로드. 노출 3지점(로그인 lockup · 결과 카드 워터마크 · 런처)을 같이 확인할 것 |
| 챌린지 목록 화면/상태 표시 변경 | [challenge_list_screen.dart](tenk_app/lib/presentation/challenge/challenge_list_screen.dart)(상태 탭·그룹핑·정렬) + [challenge_card.dart](tenk_app/lib/presentation/challenge/widgets/challenge_card.dart)(카드) + [challenge_status.dart](tenk_app/lib/presentation/challenge/widgets/challenge_status.dart)(`ChallengeStatusStyle` = 라벨·색·틴트 단일 매핑). 정렬/필터는 클라이언트 처리(백엔드 무변경). 위 "챌린지 목록 IA" 가 규칙의 진실의 원천 |
| camera 패키지 fork 갱신 | [tenk_app/vendor/camera_patched/camera_android_camerax](tenk_app/vendor/camera_patched/camera_android_camerax) 가 업스트림 `camera_android_camerax` 의 fork. `pubspec.yaml` `dependency_overrides` 로 주입. **패치 두 군데**: `initializeCamera` 의 `bindToLifecycle` 리스트 (`imageAnalysis` 자리에 `videoCapture` 를 넣음) + `stopVideoRecording` 의 `_unbindUseCaseFromLifecycle(videoCapture!)` 제거. 둘 다 `[tenk fork patch]` 주석으로 표시. **사유**: 업스트림은 VideoCapture 를 lazy bind 라 매 녹화 시작마다 Camera2 capture session 이 재구성돼 preview freeze. eager bind 로 전환해 freeze 자체 제거. Tenk 가 image stream 을 안 써서 ImageAnalysis 를 lazy 로 미뤄도 무해. **업스트림 버전 올릴 때**: pub cache 에서 신버전 디렉토리 통째로 vendor 에 덮어쓰고 두 지점 재적용. CameraX UseCase 조합 표 ([공식 문서](https://developer.android.com/media/camera/camerax/architecture#combine-use-cases)) 기준 P+IC+VC 는 LIMITED 이상 지원 — 4-way 는 LEVEL_3 한정이므로 ImageAnalysis 를 같이 추가하지 말 것 |
| 영상 export 합성 파이프라인 변경 | [VideoComposer](tenk_app/lib/data/export/video_composer.dart) 에서 ffmpeg 명령 구성. **인코더는 sw `mpeg4` 고정 — 바꾸지 말 것**. `h264_mediacodec`(hw silent fail) / `libx264`(GPL · 빌드 미포함) / `libkvazaar`(native crash) 모두 실격됐고 경로는 `_videoEncoder` 주석 + [decisions.md "함정 — H.264/HEVC sw 인코더 다 막힘"](docs/decisions.md) 에 박혀 있다. **자막은 ffmpeg drawtext 대신 Flutter `TextPainter` 로 PNG 그려 `overlay` 필터로 합성 — drawtext 로 회귀하지 말 것** (ffmpeg 8.0 의 multi-codepoint 한글 silent drop 회귀, [decisions.md "함정 — drawtext 한글 회귀"](docs/decisions.md) 참고). 자막 좌표/폰트크기/박스 스타일은 `_drawTextBlock` 안에서 조절. **자막 위치(중단/하단)·배경(박스 vs 외곽선)은 사용자가 export 설정 화면([ExportSettingsScreen](tenk_app/lib/presentation/challenge/export/export_settings_screen.dart))에서 영상 전체 단위로 고름** — `SubtitlePosition` enum + `compose(subtitlePosition, subtitleBackground)` → `_renderTextOverlayPng` → `_drawTextBlock(withBox/withOutline, centerY)`. 상단은 대시보드와 겹쳐 제외했고 대시보드 자체는 항상 `withBox:true` 유지(자막만 영향). 흐름은 `includeResultCard` 와 동일하게 ExportSettingsScreen state → ExportComposeScreen 생성자 → compose 로 thread. 합성 파라미터(해상도/비트레이트/xfade 길이 등)는 모두 클래스 상단 상수. **결과 카드 마지막 클립**은 `resultCardPngPath` 옵션으로 합성 — `_normalizeStaticImageClip` 가 `-loop 1 -t 3.0` 으로 3초 정지 클립 만들고 `_concatWithXfade` 가 가변 duration 으로 xfade offset 누적 |
| 결과 카드 도메인 변경 | **위 "결과 카드" 도메인 규칙이 진실의 원천** (2026-08-01 #18 로 디자인 전면 재설계 — 컬러 블록+화이트 / 히어로 문장 / 예산 바 + 일자 그리드 / 축하 두 겹. 회의록 [decisions.md](docs/decisions.md) "결과 카드 디자인"). [ResultCardWidget](tenk_app/lib/presentation/challenge/result_card/result_card_widget.dart) 가 480x864 고정 사이즈로 모든 콘텐츠를 그리고, 배경 틴트·컨페티는 [result_card_painters.dart](tenk_app/lib/presentation/challenge/result_card/result_card_painters.dart) — 좌표/폰트 크기는 영상 export 해상도와 1:1. **색은 ThemeData 안 쓰고 hardcode** (캡처 시 컨텍스트 영향 회피, `AppColors.reward*` 와 정합). **이모지 금지**(기기별 글리프 차이), **도넛/링 금지**(척도를 못 나른다), **카테고리 분포 금지**(정산서라 공유 카드의 주인공이 못 된다 — 상세 화면에 있다), **정적 컨페티는 컬러 블록 안에서 비율 좌표 + 콘텐츠 열 침범 금지**(캡처에 영원히 박히므로), **진입 연출 오버레이는 끝난 뒤 흔적 금지**(멈춘 조각이 그리드·범례를 영구히 가린다 — 가드 [test/result_card_confetti_test.dart](tenk_app/test/result_card_confetti_test.dart)). 실패 카드는 **게이지 초과 구간(밝기 반전)·지출일 칸**이 빨강을 데이터로 쓰고 **막대 아래 라벨 줄은 두지 않는다**(블록 높이가 성공과 어긋난다). 하단은 **배지 → 그리드** 순이고 간격은 30일+2줄 이름 기준으로 맞춰져 있다. 배지 0개면 row 통째 생략. 화면은 **풀블리드**(AppBar 없음, 우상단 X, 상태바 뒤를 블록색으로). 캡처는 [ResultCardCapture](tenk_app/lib/data/export/result_card_capture.dart) 가 Overlay off-screen + RepaintBoundary 패턴으로 처리 (배지 자산 `precacheImage` + 2 frame 대기 필수). 진입점은 ① [ChallengeDetailScreen._finalize](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) 의 finalize 직후 자동 push (배지 큐 뒤) ② [_ResultCardEntryCard](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) (확정 후에만 노출) ③ 영상 export 마지막 클립 (체크박스 기본 ON). 영상용은 `pixelRatio: 1.0` (480x864), 갤러리/공유는 `2.0` (HiDPI). 배지 카탈로그를 바꾸면 결과 카드 안의 `_BadgeRow` (최대 6 + N) 도 같이 검토 |
| 닉네임 정책 변경 | 진실의 원천은 [UserService.updateNickname](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserService.java) — trim 후 NICKNAME_FORBIDDEN_CHARS (`\p{Cc}\p{Cf}`) / NICKNAME_MAX_LENGTH (50) / enforceChangeCooldown(24h) 3단 검증. **쿨다운 상수 `NICKNAME_CHANGE_COOLDOWN` 은 `UserService`(판정)와 [UserResponse.computeAvailableFrom](tenk-backend/src/main/java/com/hjson/tenk/domain/user/dto/UserResponse.java)(안내 시각) 양쪽에 있으니 바꿀 땐 둘 다 + 앱 안내 문구(`_NicknameEditDialog` / [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) 의 "24시간" 문구) 까지 같이.** 거부 패턴/길이를 바꾸려면 클라 측 1차 검증 [NicknameSetupScreen](tenk_app/lib/presentation/profile/nickname_setup_screen.dart) `_forbiddenChars` + [my_info_screen.dart](tenk_app/lib/presentation/profile/my_info_screen.dart) `_NicknameEditDialog._forbiddenChars` 도 동일하게. 같은 값 PATCH 는 `User.changeNickname` 에서 멱등 no-op — 이걸 깨면 가입 화면 흐름이 1회 제한에 걸린다. 카카오 재로그인 시 닉네임 동기화는 절대 다시 추가하지 말 것 — [AuthService.provisionUser](tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java) 의 기존 사용자 분기는 `updateEmail` 만 호출. `isNewUser` 가 가입 화면 분기의 trigger 라 응답에서 누락되면 신규 사용자가 카카오 닉네임으로 자동 가입되어 설정 화면을 못 본다 |
| 챌린지 이름 정책 변경 | 진실의 원천은 [Challenge.validateAndNormalizeName](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/Challenge.java) — trim 후 1~100자(`NAME_MAX_LENGTH`) + `NAME_FORBIDDEN_CHARS` (`\p{Cc}\p{Cf}`). **이름은 필수 — 비울 수 없다.** 서버는 빈값 거부 (`ChallengeCreateRequest.name` `@NotBlank` 1차, 엔티티 2차). 기본값 `챌린지 N` 은 **클라이언트가 생성**해 미리 채운다 ([challenge_list_screen `_openCreate`](tenk_app/lib/presentation/challenge/challenge_list_screen.dart), N = `data.length + 1`) — 서버엔 더 이상 default-fill 로직 없음(`resolveName` 제거됨). 이름 변경은 `PATCH /api/challenges/{id}` ([ChallengeService.rename](tenk-backend/src/main/java/com/hjson/tenk/domain/challenge/ChallengeService.java)) — 게이트는 `result != null` (확정 후 차단, amount 수정과 동일 기준). 거부 패턴/길이를 바꾸면 클라 1차 검증도 같이: [challenge_create_screen.dart](tenk_app/lib/presentation/challenge/challenge_create_screen.dart) `_forbiddenChars`(+빈값 거부) + [challenge_detail_screen.dart](tenk_app/lib/presentation/challenge/challenge_detail_screen.dart) `_RenameDialogState._forbiddenChars`. 노출 위치 3곳: 목록 카드 / 상세 AppBar 타이틀(+result==null 일 때만 연필 아이콘) / 결과 카드 헤더. `ChallengeResponse.name` 누락되면 Flutter `Challenge.fromJson` 이 깨짐 (non-null) |
| 메뉴 / '내 정보' / 회원 탈퇴 흐름 변경 | 진입점은 [ChallengeListScreen](tenk_app/lib/presentation/challenge/challenge_list_screen.dart) AppBar 의 `Icons.menu`(햄버거) IconButton → [ProfileScreen](tenk_app/lib/presentation/profile/profile_screen.dart)(순수 메뉴) push. 메뉴는 내 정보(→ [MyInfoScreen](tenk_app/lib/presentation/profile/my_info_screen.dart): 닉네임·성별) + 계정 설정(→ [AccountSettingsScreen](tenk_app/lib/presentation/profile/account_settings_screen.dart)) + 의견 보내기(→ [FeedbackScreen](tenk_app/lib/presentation/feedback/feedback_screen.dart), **설정보다 위**) + 고객센터(→ [CustomerSupportScreen](tenk_app/lib/presentation/support/customer_support_screen.dart): 문의하기) + 법적 고지(→ [LegalNoticeScreen](tenk_app/lib/presentation/legal/legal_notice_screen.dart): 약관·개인정보·**오픈소스 라이선스**(showLicensePage)) + **앱 버전 행**(`_AppVersionTile` — 현재 버전+최신여부, 업데이트 있으면 스토어로) 으로 분기한다. **새 항목은 "본인 정보 → 내 정보 / 계정 자체 → 계정 정보 / 제품 의견 → 의견 보내기 / 답변이 필요한 문의 → 고객센터 / 설정성(소리·진동·알림) → 설정" 기준으로 배치** (최상위에 토글 두지 말 것). **로그아웃은 AccountSettingsScreen 소유. 회원 탈퇴는 계정 설정이 confirm 다이얼로그로 의사만 확인하고, 실제 처리는 [WithdrawScreen](tenk_app/lib/presentation/profile/withdraw_screen.dart) 소유** — 사유(선택) 입력 후 `UserScope.withdraw(reason, detail)` → `AuthScope.logout()` (storage clear) → LoginScreen 으로 `pushAndRemoveUntil`. **확인 → 사유 순서를 뒤집지 말 것** (위 "탈퇴 사유" 규칙). 백엔드는 [User.withdraw](tenk-backend/src/main/java/com/hjson/tenk/domain/user/User.java) 로 soft delete(`deleted_dt` 기록) + RT 무효화 후, 새벽 배치 [UserRetentionScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java)/[WithdrawnUserPurgeService](tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 **탈퇴 1개월 후 challenge/amount/media_file row + 디스크 영상 + refresh_token 까지 물리 삭제**. 보관 기간 상수(`RETENTION`)를 바꾸면 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §3 + [delete-account.html](tenk-backend/src/main/resources/static/delete-account.html) 도 같이 갱신 (진실의 원천 = 개인정보처리방침과 코드 일치). **탈퇴 확인 다이얼로그는 철회를 안내하지 않는다 (의도)** — 위 "탈퇴 철회" 규칙 참고. 파기 삭제 순서는 FK 자식→부모 (디스크→media_file→challenge_badge→amount→challenge→refresh_token→inquiry→user) — 새 자식 테이블 추가 시 순서 앞쪽에 끼울 것. **회귀 가드는 [WithdrawnUserPurgeIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeIntegrationTest.java)** (보관기간 경계 + 디스크 파일 삭제 + 타 계정 격리) — 자식 테이블을 추가하면 이 테스트의 시딩·`Counts` 에도 같이 넣을 것 |
| 의견 보내기(피드백) 변경 | 위 "의견 보내기 (피드백)" 규칙이 진실의 원천. **유형은 서버 [FeedbackType](tenk-backend/src/main/java/com/hjson/tenk/domain/feedback/FeedbackType.java) enum 과 [feedback_screen.dart](tenk_app/lib/presentation/feedback/feedback_screen.dart) 의 `_types` 를 같은 코드로 동시 갱신**(서버는 코드만, 문구는 클라). 검증은 [Feedback](tenk-backend/src/main/java/com/hjson/tenk/domain/feedback/Feedback.java) 이 원천 — **줄바꿈만 예외 허용**(한 줄 필드 정책을 그대로 복사하지 말 것), 진단 정보는 거부 대신 절단. `POST /api/feedback` 는 **인증 필요**(PERMIT_ALL 에 넣지 말 것)지만 **`user_id` 는 저장하지 않는다**. **`reply_email` 은 개인정보** — 보관 상한(`FeedbackService.REPLY_EMAIL_RETENTION` = 1년)을 바꾸면 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §3 과 [play-console-app-content.md](docs/play-console-app-content.md) §6-2 도 같이. **"답변이 필요한가"를 유형으로 판정하는 코드를 넣지 말 것**(이메일 유무가 유일한 스위치). 컬럼을 늘릴 땐 식별 가능성부터 따질 것. 회귀 가드는 [FeedbackTest](tenk-backend/src/test/java/com/hjson/tenk/domain/feedback/FeedbackTest.java) 7건 + [FeedbackIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/feedback/FeedbackIntegrationTest.java) 5건(익명성 컬럼 검사·미인증 401·이메일 보관 상한 포함) |
| 문의하기 변경 | 위 **"문의하기"** 규칙이 진실의 원천. **진입은 메뉴 → 고객센터**이고 법적 고지로 되돌리지 말 것. **유형은 서버 [InquiryType](tenk-backend/src/main/java/com/hjson/tenk/domain/inquiry/InquiryType.java) 과 [inquiry_screen.dart](tenk_app/lib/presentation/inquiry/inquiry_screen.dart) 의 `_types` 를 같은 코드로 동시 갱신**(서버는 코드만, 문구는 클라). 검증은 [Inquiry](tenk-backend/src/main/java/com/hjson/tenk/domain/inquiry/Inquiry.java) 가 원천 — **줄바꿈만 예외 허용**, **회신 이메일은 빈 값을 null 로 넘기지 말 것**(의견과 갈리는 핵심). `POST /api/inquiry` 는 **인증 필요**(PERMIT_ALL 금지)이고 **`user_id` 를 저장한다** — 이걸 빼면 권리 요구를 처리할 수 없다. 보관은 **회원 탈퇴 시까지**라 파기 배치가 없다 — 답변 여부로 지우는 배치를 다시 만들지 말 것(바꾸면 [privacy.html](tenk-backend/src/main/resources/static/privacy.html) §3 + [play-console-app-content.md](docs/play-console-app-content.md) §6-2 도 같이). **`feedback` 과 한 화면·한 테이블로 합치지 말 것**(익명성 공개 약속이 깨진다). 새 자식 테이블이므로 계정 파기 순서·[WithdrawnUserPurgeIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeIntegrationTest.java) 의 `Counts` 에 이미 들어가 있다. 회귀 가드는 [InquiryTest](tenk-backend/src/test/java/com/hjson/tenk/domain/inquiry/InquiryTest.java) 7건 + [InquiryIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/domain/inquiry/InquiryIntegrationTest.java) 6건(계정 연결·이메일 필수·미인증 401·파기 동반·리마인드·처리 후 생존) |
| 관리자 알림(문의·의견 도착, 리마인드) 변경 | 위 **"관리자 알림"** 규칙이 진실의 원천. 발송은 [AdminNotifier](tenk-backend/src/main/java/com/hjson/tenk/common/notify/AdminNotifier.java) 한 곳, 설정은 [NotifyProperties](tenk-backend/src/main/java/com/hjson/tenk/common/config/NotifyProperties.java)(`tenk.notify.*`)이고 **자격증명은 prod 프로파일에만**(공통 yaml 에 fallback 두지 말 것 — jwt secret 과 같은 원칙). ⚠️ **예외를 삼키는 best-effort 를 깨지 말 것**(발송 실패로 저장이 롤백되면 문의가 유실된다), **`@Async` 를 떼지 말 것**(외부 호출 지연이 사용자 응답에 붙는다), **같은 빈 안에서 호출하지 말 것**(프록시를 안 탄다). 리마인드는 [InquiryScheduler](tenk-backend/src/main/java/com/hjson/tenk/domain/inquiry/InquiryScheduler.java) 오전 9시이고 **0건이면 안 보낸다**. SMTP 는 `spring.mail.host` 가 있어야 `JavaMailSender` 가 자동 구성된다(없으면 빈 자체가 없고 `ObjectProvider` 가 견딘다). 본문 끝의 패널 링크는 `tenk.admin.base-url` 이 있을 때만 붙고 **없으면 링크 줄만 빠진다**(알림이 실패하면 안 된다) |
| 관리자 패널 변경 | 위 **"관리자 패널"** 규칙이 진실의 원천. 코드는 [admin/](tenk-backend/src/main/java/com/hjson/tenk/admin/) + [templates/admin/](tenk-backend/src/main/resources/templates/admin/). ⚠️ **보안 체인 2개를 합치지 말 것** — `/admin/**` 은 세션+폼+CSRF, 나머지는 STATELESS+JWT 다. 합치면 앱이 401 JSON 대신 로그인 화면으로 리다이렉트된다(가드: [AdminPanelIntegrationTest](tenk-backend/src/test/java/com/hjson/tenk/admin/AdminPanelIntegrationTest.java) 마지막 2건). **관리자 계정을 `user` 테이블로 옮기지 말 것**(생명주기가 다르다 — 파기 배치·동의/연령 게이트에 섞인다). **비밀번호는 yaml 이 원천**이라 변경 화면을 만들면 재부팅에 되돌아간다. **범위를 늘리지 말 것**: 이용자 데이터 편집·삭제 · 답변 발송 · 통계 대시보드는 의도적으로 뺐다. 모든 변경은 [AdminAudit](tenk-backend/src/main/java/com/hjson/tenk/admin/AdminAudit.java) 를 거치고 **로그에 본문·이메일을 담지 말 것**. 새 `@ConfigurationProperties` 를 admin 패키지에 만들면 [TenkApplication](tenk-backend/src/main/java/com/hjson/tenk/TenkApplication.java) 의 `basePackageClasses` 를 확인할 것(스캔 범위가 못박혀 있어 빠뜨리면 부팅이 죽는다) |
| 문의처(이메일) 변경 | ⚠️ **주소가 세 개고 역할이 다르다** — 발신 `system.tenk@`(`spring.mail.username`, 서버가 알림 쏠 때만) / **수신·공개 `support.tenk@`**(`tenk.notify.mail.to` + 사용자에게 보이는 모든 곳) / 패널 로그인 ID `admin.tenk@`(`tenk.admin.account.email`, 메일이 오가지 않는 순수 ID). **공개 주소**를 바꾸면 [legal_config.dart](tenk_app/lib/config/legal_config.dart) `supportEmail` + [privacy.html](tenk-backend/src/main/resources/static/privacy.html) 보호책임자 항목 + [terms.html](tenk-backend/src/main/resources/static/terms.html) 문의처 조항 + [delete-account.html](tenk-backend/src/main/resources/static/delete-account.html) + `tenk.notify.mail.to` + Play Console 개발자 연락처·IARC 이메일을 **한꺼번에** — 고지한 창구와 앱이 여는 창구가 다르면 안 된다. **발신 계정·패널 ID 만 바꿀 땐 yaml 한 곳**(사용자에게 안 보인다). 셋 다 **서비스 전용 계정**이고 개발자 개인 메일이 아니다. 앱 안 유일한 mailto 진입점은 [InquiryScreen](tenk_app/lib/presentation/inquiry/inquiry_screen.dart) 전송 실패 스낵바의 `메일로 보내기` → [openSupportEmail](tenk_app/lib/presentation/legal/support_contact.dart). 새 mailto 진입점을 만들면 그 헬퍼를 재사용하고, **Android `<queries>` 의 `mailto` 선언을 지우지 말 것**(Android 11+ 에서 조용히 실패) |
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
