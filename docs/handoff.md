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
- ✅ **이메일 수집 중단 (#10, 2026-07-26)** — 원인은 카카오 이메일 동의항목 **'권한 없음'**(개인 개발자 앱). 쓰이는 곳이 표시 한 곳뿐이라 수집을 접고 **컬럼까지 DROP**. privacy.html·Play 데이터 안전의 **고지 불일치도 함께 해소**. ⚠️ **라이브 DB ALTER 필수** — §0-DEPLOY.
- ✅ **닉네임 안내 문구 정리 + 제한 규칙 24시간화 (#11) · 메뉴 진입 로딩 제거 (#12) — 2026-07-26.** #11: 상시 라벨 제거·탭 시에만 안내, 어긋나 있던 "다음 날 자정" 판정을 **정확히 24시간**으로 통일. 테스트 **161개** 전원 통과 + **에뮬 E2E 검증 완료**. #12: 메뉴를 낙관적 렌더로 전환(`/me` 안 기다림) + `flutter analyze` 완전 clean. **#11 은 백엔드 재배포 대기**(스키마 변경 없음) — §0-DEPLOY.
- 🔵 **Play 앱 콘텐츠 폼 진행 중** — 개인정보처리방침·광고·콘텐츠 등급 ✅ / App access **답안 확정(데모 계정)**·타겟층·데이터 안전 **콘솔 입력 미완**. 데모 카카오 계정 생성 남음. §0.
- ⏭️ 다음 후보: 위 §0 마무리(백엔드 재배포 + 데모 계정 생성 + 콘솔 폼 3종) / iOS 빌드(맥 필요, 보류 — Sign in with Apple 4.8 요건 [decisions.md](decisions.md) 참고) / 앱 아이콘 / 페이지네이션 / 업적 시스템(최후순위).

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
6. 백엔드 테스트: `cd tenk-backend && ./gradlew.bat test` (총 161개 — 단위 116 + 통합 40 + WebMvc 4 + ContextLoads 1. 전원 통과). ⚠️ **테스트 실행 시 로컬 `tenk` DB의 user/challenge/amount/challenge_badge/refresh_token 데이터가 비워진다** (badge·app_config 마스터는 유지). Flutter 재로그인으로 복구 가능. ⚠️ **앱 버전 통합 테스트는 `app_config` 테이블 선적용 필요** (schema.sql CREATE+INSERT).
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
- ✅ **테스트 현황**: `./gradlew.bat test` 총 **161개**(단위 116 + 통합 40 + WebMvc 4 + 컨텍스트 1, 2026-07-26 실측). **전원 통과**. 통합 40 = 기존 36 + 앱 버전 게이트 E2E 4. 단위 116 = 기존 106 + SemanticVersion 3 + AppVersionService 6 + 닉네임 24h 경계 1. (2026-07-26: 닉네임 제한이 24시간 기준으로 바뀌면서 `UserServiceTest` 의 날짜 의존 테스트 2건을 상대 시간 기준으로 교체 — 자정 flaky 요인 자체가 사라짐.) `LocalDate.now()` 정적이라 종료 상태는 reflection backdate. 통합은 로컬 `tenk` 스키마 공유 → 실행 시 dev 데이터 비워짐(Flutter 재로그인 복구). 상세 패턴은 [../CLAUDE.md](../CLAUDE.md) 테스트 컨벤션 행 + 아래 "함정".
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
- [ ] (선택) 앱 아이콘 교체 — 현재 기본 Flutter 아이콘 (`flutter_launcher_icons` 권장)
- [ ] (선택) APK 크기(~165MB) 줄이려면 `--split-per-abi` (arch별 ~55MB)

**Play Console 내부 테스트 — ✅ 게시·카카오 로그인 확인 (2026-07-08).**

**앱 콘텐츠 (프로덕션 전 필수) — 답안은 [play-console-app-content.md](play-console-app-content.md) 에 전부 준비됨.** 남은 실행 항목:
- [x] ✅ **백엔드 재배포 완료 (2026-07-25)** — 연령 게이트 + 성별 + role/테스트로그인 제거를 prod 에 배포. 라이브 DB 3컬럼(`birth_date`/`gender`/`role`) `ALTER` 선적용 → `docker compose pull && up -d` → 부팅 정상 + `/api/auth/test/login` 제거 확인(401=security-first). `tenk_dbinit` 볼륨 `01-schema.sql` 도 갱신(클린 재구축 대비). `delete-account.html`/`privacy.html` 은 이미지에 구워져 함께 반영. 배포 순서·함정은 [docker-deployment.md](docker-deployment.md) §5.5.
  - [ ] **시딩 쓰려면 내부 테스터 계정을 TESTER 로 승격** (선택): `UPDATE user SET role='TESTER' WHERE provider='KAKAO' AND provider_user_id='<카카오회원번호>';` — **심사자 데모 계정은 승격 금지**(시딩 버튼 노출됨).
- [ ] 🟠 **§0-DEPLOY — 다음 prod 백엔드 재배포 묶음 (미착수).** 아래 "운영 배포 런북" 이 실행 순서의 진실의 원천. 코드·로컬 검증은 전부 끝났고 **라이브 반영만** 남았다.
- [x] **연령 확인 게이트 에뮬 E2E — ✅ 완료 (2026-07-21)** — 신규 가입(연령→동의→닉네임), 기존 미확인 계정(앱 시작 시 연령 게이트), 만 14세 미만 입력 시 안내→로그아웃→계정 파기 확인. (실기기 재확인은 새 화면 추가 시 상시 체크 항목)
- [x] **'내 정보' 성별 선택 입력 — ✅ 완료 (2026-07-21)** — 입력 / '입력 안 함'으로 되돌리기 양방향
- **Play Console 폼 입력** (답안은 [play-console-app-content.md](play-console-app-content.md)):
  - [x] 개인정보처리방침 URL / 광고 / 콘텐츠 등급 설문 — ✅ 완료 (2026-07-21)
  - [ ] **앱 액세스 권한(로그인 세부정보)** — 답안 확정(**데모 카카오 계정**, [play-console-app-content.md](play-console-app-content.md) §2). 남은 실행: **데모 카카오 계정 생성** + 콘솔 폼에 아이디/비번 입력 + **새 기기 로그인 재현**(추가 인증 안 뜨는지)
  - [ ] **타겟층 및 콘텐츠** (13~15 포함 → 가족 정책 확인란) — 미완
  - [ ] **데이터 안전** + 데이터 삭제 URL — 미완
- [x] ✅ **테스터 로그인 회의 완료 (2026-07-25)** — 결정·구현 완료. App access=데모 카카오 계정, 앱/서버 테스트 로그인 제거, 시딩은 계정 role(USER/TESTER)로 재게이팅. 회의록·근거는 [decisions.md](decisions.md) "테스터 로그인 회의". 남은 실행 항목은 위 "앱 액세스 권한"(데모 계정 생성)으로 흡수됨.
- [ ] terms.html / privacy.html 변호사 검수 (권장, 미착수)

---

#### 🚀 운영 배포 런북 (§0-DEPLOY) — 2026-07-26 묶음, 미실행

> 맥(서버)에서 실행. 배포 구조·명령의 원본은 [docker-deployment.md](docker-deployment.md) §5.1(업데이트 사이클) / §5.5(라이브 DB 스키마 변경).
> **이 묶음은 스키마 변경 2건을 포함**하므로 `ddl-auto=validate` 특성상 **SQL 먼저, 이미지 나중**이 절대 원칙이다. 순서를 뒤집으면 백엔드가 부팅 실패한다.

**들어 있는 것 (3건)**

| # | 내용 | DB 작업 | 이미지 재배포 |
|---|---|---|---|
| #5 | 앱 버전 게이트 / 강제·권장 업데이트 | ✅ `app_config` CREATE + INSERT | ✅ |
| #10 | 이메일 수집 중단 | ✅ `user.email` DROP COLUMN | ✅ (privacy.html 도 이미지에 구워져 함께 반영) |
| #11 | 닉네임 제한 24시간화 | ❌ 없음 | ✅ |

**1단계 — 이미지 빌드·push** (개발 머신에서. 상세 §5.1)

**2단계 — 라이브 DB 스키마 선적용** (맥)
```bash
cd ~/Documents/projects/claude/tenk
set -a; . ./.env; set +a

# (a) 백업 먼저 — DROP COLUMN 이 섞여 있어 되돌리기가 비싸다
docker compose exec -T db mariadb-dump -uroot -p"$DB_ROOT_PASSWORD" tenk > ~/tenk-backup-$(date +%Y%m%d-%H%M).sql

# (b) #5 app_config 생성 + 시드 1행
docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" tenk -e "
CREATE TABLE \`app_config\` (
  \`app_config_id\`         BIGINT AUTO_INCREMENT                   NOT NULL,
  \`min_supported_version\` VARCHAR(20)                             NOT NULL,
  \`latest_version\`        VARCHAR(20)                             NOT NULL,
  \`android_store_url\`     VARCHAR(255)                            NULL,
  \`ios_store_url\`         VARCHAR(255)                            NULL,
  \`updated_dt\`            DATETIME DEFAULT CURRENT_TIMESTAMP      NOT NULL,
  PRIMARY KEY (\`app_config_id\`)
);
INSERT INTO \`app_config\`
  (\`app_config_id\`,\`min_supported_version\`,\`latest_version\`,\`android_store_url\`,\`ios_store_url\`)
VALUES
  (1,'1.0.0','1.0.0','https://play.google.com/store/apps/details?id=com.hjson.tenk_app',NULL);
"

# (c) #10 email 컬럼 제거
docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" tenk \
  -e "ALTER TABLE \`user\` DROP COLUMN \`email\`;"
```

**3단계 — 이미지 재배포** (맥)
```bash
docker compose pull && docker compose up -d
docker compose logs -f backend   # 부팅 성공(= validate 통과) 확인
```

**4단계 — `dbinit` 볼륨 시드 갱신** (클린 재구축 대비. §5.4 방식)
`tenk_dbinit` 볼륨의 `01-schema.sql` 을 이번 `docs/schema.sql` 로 교체. **안 하면 라이브는 멀쩡한데 클린 재구축 때만 스키마가 어긋나** 부팅 실패한다.

**5단계 — 검증**
- [ ] `curl 'https://tenk.hjson248.com/api/app/version?platform=android&currentVersion=1.0.0'` → `status: LATEST`
- [ ] `curl 'https://tenk.hjson248.com/api/app/version?platform=android&currentVersion=0.9.0'` → `UPDATE_REQUIRED` (min=1.0.0 이므로)
- [ ] `https://tenk.hjson248.com/privacy.html` 수집항목에 **이메일이 없어졌는지**
- [ ] 실기기(`(device)` 구성)로 카카오 로그인 → 메뉴 → 계정 설정에 "카카오 계정으로 로그인 중" / 앱 버전 행 "최신 버전이에요"
- [ ] 닉네임 변경 후 재탭 → "내일 오후 ○시 ○분부터 가능해요"

**롤백 주의**: #10 의 `DROP COLUMN` 은 되돌려도 **값은 복구되지 않는다**(2-a 백업에서만 복원 가능). 다만 그 값들은 어차피 전부 NULL 이었으므로 실질 손실은 없다.

**향후 릴리스 때**: 스토어 게시가 끝나면 재배포 없이 SQL 한 줄로 최신 버전을 올린다 —
`UPDATE app_config SET latest_version='<pubspec version>', min_supported_version='<하한>' WHERE app_config_id=1;`

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

- [ ] **#1 탈퇴 철회 흐름** — 탈퇴 후 3개월 보관 기간 안에 같은 카카오로 재로그인하면, 현재는 `USER_ALREADY_WITHDRAWN` 로 막힌다. 대신 **"탈퇴한 계정입니다. 탈퇴를 철회하시겠습니까?"** 확인을 받아 → 철회 선택 시 `is_deleted`/`deleted_dt` 를 해제해 복구, 거부 시 기존 3개월 보관 유지. 백엔드([AuthService.provisionUser](../tenk-backend/src/main/java/com/hjson/tenk/domain/auth/AuthService.java) 의 탈퇴 계정 분기) + 철회 엔드포인트 + Flutter 로그인 흐름 분기 동반. 보관 만료(hard delete) 후엔 철회 불가(계정이 이미 없음).
- [ ] **#2 메뉴 항목 추가** — ✅ **이름·아이콘 확정 (2026-07-25): '메뉴' + `Icons.menu`** + ✅ **앱 버전 행 완료 (2026-07-26, #5·라이선스와 함께)** — 현재 버전(`v1.0.0`)+최신여부 표시, 업데이트 있으면 스토어로. 남은 것: **피드백 보내기** 항목 추가. (효과음/진동 설정은 #8 연동 — 그 기능 생기면 '알림/효과 설정' 하위 화면으로 추가, 최상위 토글 금지.)
- [ ] **#3 날짜·시간 선택 UI 정리** — 현재 picker 가 영어로 뜨거나 시간이 시계(analog) UI 로 떠서 불편함. 한국어 로케일 적용(`MaterialLocalizations`/`flutter_localizations` + `supportedLocales`) + 시간 입력을 쓰기 편한 형태로 교체. 노출 지점: 챌린지 생성(기간) + amount 기록/수정(spent_dt 시간).
- [ ] **#4 모달 → 화면 전환** — 카테고리 셀렉박스 / 성별 선택 팝업 / 닉네임 변경 팝업 등 다이얼로그를 별도 화면(push)으로 재구성. 연령·동의·닉네임을 이미 별도 화면으로 분리한 방향과 일관 ([../CLAUDE.md](../CLAUDE.md) 게이트 화면 분리 원칙). 대상: [spend_category.dart](../tenk_app/lib/presentation/amount/spend_category.dart) 드롭다운, [my_info_screen.dart](../tenk_app/lib/presentation/profile/my_info_screen.dart) 의 `_NicknameEditDialog`·성별 다이얼로그.
- [x] ✅ **#5 앱 시작 강제/권장 업데이트 — 구현 완료 (2026-07-26)** — 판정은 **서버가 진실의 원천**(클라 semver 비교 안 함). 정책은 `app_config` **단일 행**(min/latest/스토어 URL)에 두고 **재배포 없이 SQL 로 갱신**(관리자 UI 없음 — TESTER 승격과 동일 운영 방식으로 결정, [decisions.md](decisions.md) "앱 버전·업데이트 게이트 회의"). `GET /api/app/version`(PERMIT_ALL) → [SessionGate](../tenk_app/lib/app/session_gate.dart) 가 **버전 게이트를 가장 먼저** 판정 → 강제=[ForceUpdateScreen](../tenk_app/lib/presentation/update/update_gate.dart)(back 차단)/권장=[RecommendedUpdateHost](../tenk_app/lib/presentation/update/update_gate.dart)(1회 안내). fail-open(서버·버전 이상 시 미적용). 규칙 진실의 원천은 [../CLAUDE.md](../CLAUDE.md) "앱 버전 / 강제·권장 업데이트". ✅ **로컬 DB `app_config` 적용 + 백엔드 테스트 160개 전원 통과 + 에뮬 E2E 검증 완료 (2026-07-26)**. **남은 것: 라이브 DB `app_config` CREATE+INSERT + 백엔드 재배포 — 다음 prod 배포 때 다른 항목과 함께 일괄 업로드 예정(아래 §0-DEPLOY).** iOS 스토어 URL 은 iOS 출시 때 SQL 로 채움. 배포 메모는 아래 "운영 고려사항" 참고.
- [ ] **#6 로고 / 앱 아이콘 정리** — Tenk 로고 + 런처 아이콘 확정. §0 의 "(선택) 앱 아이콘 교체"(`flutter_launcher_icons`)와 동일 건 — 이쪽으로 통합.
- [ ] **#7 예외처리 전수 점검** — 백엔드 `ErrorCode`/`BusinessException` 커버리지 + Flutter `toApiException` SnackBar 노출 누락·엣지 케이스(네트워크 끊김, 토큰 만료, 파일 IO 실패 등) 전수 정리. 범위가 넓어 착수 시 영역별로 쪼갤 것.
- [ ] **#8 배지 획득 효과 개선** — 현재 [badge_celebration_dialog.dart](../tenk_app/lib/presentation/challenge/widgets/badge_celebration_dialog.dart)(Lottie 컨페티 + 줌·바운스) 연출을 더 풍부하게. 효과음·진동(#2 의 효과음/진동 설정 항목과 연동) + 모션 폴리시. 착수 전 레퍼런스 정하고 진행.
- [ ] **#9 DB 컬럼 enum 전환 검토** — 문자열로 저장 중인 코드성 컬럼을 `@Enumerated`/enum 으로 정리. 특히 `amount.category` 는 현재 **의도적으로 String** (검증 이전 자유 텍스트 row 읽기 호환 — [../CLAUDE.md](../CLAUDE.md) 지출 카테고리 규칙). 전환하려면 레거시 자유 텍스트 데이터 마이그레이션(재시딩/백필)이 선행돼야 함. 착수 전 대상 컬럼 목록화 + 마이그레이션 전략부터.
- ~~#10 email NULL 원인 분석~~ → ✅ 완료 (2026-07-26). 원인 = 카카오 '카카오계정(이메일)' 동의항목이 **개인 개발자 일반 앱에선 '권한 없음'**(콘솔 확인). 코드 버그 아님. **수집을 접기로 결정** — 컬럼까지 삭제. 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증".
- ~~#11 닉네임 변경 안내 날짜 텍스트 삭제~~ → ✅ 완료 (2026-07-26). 제한 규칙까지 실제 24시간으로 통일. 상세는 [handoff-archive.md](handoff-archive.md), 문구 근거는 [decisions.md](decisions.md) "닉네임 쿨다운 안내 문구".
- ~~#12 메뉴 진입 시 매번 로딩 대기 UX 개선~~ → ✅ 완료 (2026-07-26). 메뉴를 **낙관적 렌더**로 전환(`/me` 안 기다림, 실패해도 내비게이션 안 막음). 상세는 [handoff-archive.md](handoff-archive.md), 규칙은 [../CLAUDE.md](../CLAUDE.md) "메뉴 화면".
  - **남은 갈래(미착수)**: '내 정보'(MyInfoScreen) 진입 스피너는 그대로 — 닉네임·성별이 화면 콘텐츠 자체라 없애려면 `UserApi` 에 캐시(stale-while-revalidate)가 필요하고, **로그아웃·탈퇴 시 무효화**를 빠뜨리면 재로그인 후 이전 계정 값이 한 순간 보인다. 거슬리면 그때 착수.
- [ ] **#13 생년월일 입력 자동 포커스 이동** — [AgeGateScreen](../tenk_app/lib/presentation/legal/age_gate_screen.dart) 의 연/월/일 3칸 입력에서, 연도 4자리·월/일 2자리를 채우면 자동으로 다음 칸으로 포커스 이동(`TextInputFormatter` maxLength + `FocusNode` 넘김). 중립성 3원칙(컷오프 비노출·기본값 없음·이탈 차단)은 유지 — 자동 이동은 편의 기능이라 무관.

- **실기기 점검** — ✅ 현재까지 대상 화면 전부 통과(기존 3블록 닉네임/결과카드/SafeArea 2026-06-16 전원 통과, [handoff-archive.md](handoff-archive.md)). 미착수 작업이 아니라 상시 체크 항목: **새 화면을 추가할 때만** 하단 가림 / 제스처·3버튼 내비 / 키보드 inset 을 실기기에서 재점검.

> **업적(achievement) 시스템**은 우선순위를 최후로 내렸다 → 맨 아래 §5.

### 2. 페이지네이션 / 정렬
- `/api/challenges`, `/api/challenges/{id}/amounts`가 전체 목록 반환 중. `Pageable` 도입 시점 결정 (지금은 사용자당 챌린지 수가 적어 무방).

### 3. Google / Naver 로그인 추가 (예정)
- 동일 패턴: `GoogleTokenVerifier` / `NaverTokenVerifier` + `AuthService`에 분기 + `POST /api/auth/google/login` / `/naver/login`. **브라우저 redirect 흐름은 사용하지 않음** (모바일 SDK 전제).

### 4. 운영 고려사항 (필요해지면)
- **⚠️ 미배포 변경 3건 (2026-07-26)** — 실행 순서·SQL·검증 체크리스트는 **§0 의 "🚀 운영 배포 런북"** 하나로 모아뒀다(여기 중복 기재하지 말 것). 요약만: `app_config` CREATE+INSERT(#5) + `user.email` DROP(#10) 을 **SQL 먼저** 친 뒤 이미지 재배포. `ios_store_url` 은 iOS 출시 전까지 NULL 유지. **버전을 올릴 땐 재배포 없이** `UPDATE app_config SET latest_version=..., min_supported_version=... WHERE app_config_id=1;`.
- **관리자 패널 (트리거: 콘텐츠 모더레이션·사용자 관리) — 지금 X, 백로그 O.** 현재 관리자 제어 대상은 TESTER 승격 + 앱 버전 정책 2개뿐이고 둘 다 저빈도 SQL 로 충분해 패널을 지을 근거가 없다(과설계). **출시 후 UGC(영상·닉네임·한 줄 평) 신고/모더레이션이 생기면** SQL 로 감당이 안 돼 이때 착수: ADMIN role + 인증 + (웹) 관리 화면. 그때 TESTER 승격·app_config·신고 상태가 모두 "DB 행 편집" 이라 패널이 자연스럽게 흡수. 근거는 [decisions.md](decisions.md) "앱 버전·업데이트 게이트 회의".
- **영상 저장소 S3/MinIO 이전** — `LocalFileStorage`를 인터페이스로 추출 후 구현체 분리.
- **AT 강제 무효화(블랙리스트)** — 필요 시 Redis. 현재는 AT 만료 시간(1시간)에 의존.
- **CI 도입** — 현재 통합 테스트가 로컬 `tenk` 스키마를 비우는 구조라 CI 에서 그대로 못 돈다. 도입 시 Testcontainers + 별도 `tenk_test` 스키마로 갈아탈 것.
- **개인정보처리방침 (2026-07-07 작성 + 배포 LIVE)** — [privacy.html](../tenk-backend/src/main/resources/static/privacy.html) 로 작성, Spring Boot static 서빙. ✅ **`https://tenk.hjson248.com/privacy.html` 배포 완료·브라우저 접속 확인** (SecurityConfig PERMIT_ALL 등록, 맥 이미지 재배포로 LIVE). 수집항목/이용목적/보관기간(탈퇴 후 3개월)/제3자(카카오)/파기/권한/문의처 포함. **Play Console 개인정보처리방침 URL 에 이 주소 입력.** 남은 것: ① ✅ **앱 내 링크 노출 + 필수 동의 플로우 완료 (2026-07-19)** — 아래 별도 항목 참고 ② 실서비스 전 변호사 검수 권장 (privacy.html + terms.html 둘 다) ③ 문구는 실제 동작(음성 미수집, 자체 서버 저장, 3개월 보관 후 파기)과 일치시켜 작성했으니 정책 바꾸면 동시 갱신.

- **필수 동의 플로우 (2026-07-19 구현 완료)** — "앱 내 링크 노출" 태스크를 출시 기준으로 확장. **이용약관([terms.html](../tenk-backend/src/main/resources/static/terms.html), 신규 작성) + 개인정보 수집·이용** 2개 필수 동의를 **동의 화면(ConsentGateScreen)** 에서 받고 `user.terms_agreed_dt`/`privacy_agreed_dt` 에 기록. **동의 화면과 닉네임 설정 화면은 분리** — 신규 가입은 동의(ConsentGateScreen) → 닉네임(NicknameSetupScreen) 2단계, 기존 미동의자는 동의 → 홈. 규칙·구조는 [../CLAUDE.md](../CLAUDE.md) "인증 — 필수 동의" 섹션이 진실의 원천. **⚠️ 라이브 DB 는 새 컬럼을 ALTER 로 추가해야 부팅됨**(ddl-auto=validate): `ALTER TABLE user ADD COLUMN terms_agreed_dt DATETIME NULL AFTER nickname_changed_dt, ADD COLUMN privacy_agreed_dt DATETIME NULL AFTER terms_agreed_dt;` (TEST enum 마이그레이션과 동일 패턴).
  - ✅ **prod 배포 + 에뮬 E2E 검증 완료 (2026-07-20)** — 이력·검증 상세는 [handoff-archive.md](handoff-archive.md) 참고.
  - ✅ **통합 테스트 작성 완료 (2026-07-20)** — [UserConsentIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/UserConsentIntegrationTest.java) 5건(MockMvc E2E): 신규 유저 `consentRequired=true` / 동의 POST 후 false + DB 스탬프 / 재호출 멱등(최초 시각 보존) / 미인증 401 / **TEST 계정 auto-consent 가드**. 스탬프 규칙 자체는 `UserServiceTest` 단위 5건이 담당.
  - **남은 것**: terms.html 변호사 검수.
- **회원 탈퇴 hard delete (2026-07-07 구현 완료)** — soft delete + 3개월 보관 후 물리 삭제. `User.withdraw()` 는 여전히 soft delete(`deleted_dt`) + RT 무효화, 새벽 1:30 배치 [UserRetentionScheduler](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java) → [WithdrawnUserPurgeService.purge](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 `deleted_dt` +3개월 지난 계정을 challenge/amount/media_file row + 디스크 `uploads/` 영상 + refresh_token 까지 FK 순서(디스크→media_file→challenge_badge→amount→challenge→refresh_token→user)로 삭제. 유저 1명 단위 트랜잭션, 파일은 best-effort(`deleteQuietly`). user 는 hard delete 라 provider/provider_user_id 재사용 가능. 보관기간 상수는 `WithdrawnUserPurgeService.RETENTION`. ✅ **통합 테스트 작성 완료 (2026-07-20)** — [WithdrawnUserPurgeIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeIntegrationTest.java) 5건: 탈퇴 직후·미탈퇴는 파기 대상 아님 / `deletedDt` reflection backdate 후 대상 포함 / purge 시 challenge·amount·media_file·challenge_badge·refresh_token row 전멸 + **디스크 mp4 실제 삭제**(`deleteQuietly` 가 조용히 실패해도 아무도 모르는 지점이라 이게 유일한 감시) / 타 계정 데이터 무손상. **남은 것**: 3개월 미도래 계정은 그대로라 UI "영구히 삭제" 문구와 즉시성엔 여전히 시차 있음(정책상 의도).

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
- **`app_config` 싱글턴 행을 건드리는 통합 테스트는 반드시 원복할 것**: [AppVersionIntegrationTest](../tenk-backend/src/test/java/com/hjson/tenk/domain/app/AppVersionIntegrationTest.java) 는 앱이 읽는 그 한 행(id=1)을 테스트용 더미(latest=1.2.0, `https://play/android`)로 덮어쓴다. `@AfterEach` 로 시드값(1.0.0/실 Play URL)으로 되돌리지 않으면, 테스트 실행 후 로컬 dev 앱이 가짜 "업데이트 있어요" 를 스토어 더미 주소로 띄운다 (2026-07-26 실제로 발생·수정). app_config 를 만지는 새 테스트도 같은 원복을 넣을 것.

### Flutter
- **✅ 해결됨 — 릴리스 APK 에서만 카카오 로그인 실패 = R8 이 카카오 Pigeon 클래스 제거 (2026-07-02, 삼성 실기기 확인)**. 증상: 릴리스 APK 에서 "카카오로 로그인" 탭 → `카카오 로그인 실패: Unable to establish connection on channel: "dev.flutter.pigeon.kakao_flutter_sdk_common.CommonHostApi.isKakaoTalkAvailable"`. 카카오 창이 아예 안 뜨고 즉시 실패. 진단: 최신 Flutter/AGP 가 `flutter build apk --release` 에서 **R8 축소를 기본 ON** 으로 도는데(gradle 에 `minifyEnabled` 명시 없어도 적용), `build/app/outputs/mapping/release/usage.txt` 에 `com.kakao.sdk.flutter.common.CommonHostApi.setUp(...)` 등 카카오 네이티브 58개 항목이 **제거됨**으로 찍혀 있었다 — 채널 핸들러를 등록하는 `setUp` 이 stripped 되어 채널이 안 열림. **키해시와 무관**(키해시 정상 등록돼도 이 에러). 해결: [build.gradle.kts](../tenk_app/android/app/build.gradle.kts) release 블록에 `isMinifyEnabled = false` + `isShrinkResources = false`. 이 앱은 kakao + ffmpeg_kit + camera fork 등 네이티브 플러그인이 무거워 keep 규칙 개별 관리보다 축소 OFF 가 안전(테스트 빌드 기준). **Play Store 정식 출시로 크기 최적화가 필요하면** R8 을 다시 켜고 `proguard-rules.pro` 에 플러그인별 keep 규칙(카카오/ffmpeg/camera) 추가할 것. 진단 명령: `grep -i kakao build/app/outputs/mapping/release/usage.txt`.
- **릴리스 APK 빌드 시 Kotlin 증분컴파일 스택트레이스는 무해**: `flutter build apk --release` 끝에 `Could not close incremental caches ... this and base files have different roots` 류의 긴 stacktrace 가 찍히는데, **pub 캐시가 `C:` 드라이브(`AppData\Local\Pub\Cache`)·프로젝트가 `D:` 드라이브라** Kotlin 이 상대경로 계산에 실패하는 것뿐이고 **빌드는 성공한다**. 판단 기준은 맨 끝의 `√ Built build\app\outputs\flutter-apk\app-release.apk` 줄. 없애려면 pub 캐시를 같은 드라이브로 옮기거나(`PUB_CACHE`) 무시. APK 산출물·서명엔 영향 없음.
- **목록/상세 화면의 비동기 데이터는 `AsyncStateMixin` + `AsyncStateView` 사용**, `FutureBuilder` 금지 ([presentation/common/async_state.dart](../tenk_app/lib/presentation/common/async_state.dart)). 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state.
- **Navigator push/pop의 generic은 양쪽 모두 명시.** `MaterialPageRoute<T>(builder: ...)`로 T를 박지 않으면 result가 null로 빠지는 경우. push 종료 시점에 무조건 refresh하는 패턴이 안전.
- **에뮬레이터에서 텍스트가 첫 프레임에 안 보이고 화면을 움직이면 나타나면** [[reference-flutter-android-impeller-text-glitch]] — Impeller 텍스트 atlas 버그. `flutter run --no-enable-impeller`로 검증.
- **매니페스트(`AndroidManifest.xml`) 변경은 hot reload로 반영 안 됨.** 콜드 부팅(`q` → `flutter run`) 또는 hot restart(`R`).
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
