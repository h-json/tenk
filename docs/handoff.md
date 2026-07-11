# Handoff — Tenk

> 다른 컴퓨터/세션에서 이 작업을 이어받는 사람(또는 미래의 나)을 위한 인계 노트.
> 영구적인 규칙·결정은 [../CLAUDE.md](../CLAUDE.md)에 있고, 이 문서는 **현재 진행 상태와 다음 할 일**만 기록함.

**최근 변경 이력** — 최신순 한 줄 요약. 상세는 git log / 아래 "완료된 것" 섹션 / 회의록 참고.

- **2026-07-11**: 📝 **UX 다듬기 백로그 8건 접수** (미착수) — 상태색/카테고리 목록화+아이콘/금액입력 보조표시/필수 별표/'메모'→'한 줄 평'/챌린지 색깔 기능/성공 트로피 배지 + 🐛 7/11 날짜 안 됨 제보 조사. 상세는 "남은 일 §1 앱 UX 다듬기 (백로그)" 2026-07-11 배치.
- **2026-07-11**: 🧪 **테스트 지원(devtools) 추가 + 운영 배포·검증 완료.** 날짜 기반 앱이라 완료/확정 대기 상태를 현실 날짜 없이 즉시 만들려고 도입. `POST /api/auth/test/login {key,slot}`(카카오 없이 `provider=TEST` 계정 즉석 생성, 슬롯별 격리 → 내부 테스터 각자 사용) + `POST /api/dev/seed`(기존 데이터 wipe 후 5종 상태 시딩: 시작 전/진행 중/확정 대기/완료-성공/완료-실패, 배지 포함). 이중 잠금: 서버 `tenk.test.enabled`(prod 는 env `TENK_TEST_ENABLED` 로 토글) + 시크릿 `login-key`, 클라 `--dart-define=TEST_LOGIN_KEY`. Flutter: 로그인 화면 "테스트 로그인"(슬롯 입력) + '내 정보'의 "테스트 데이터 재생성"(TEST 계정만). 챌린지는 reflection 으로 backdate, 금액·배지는 정상 로직 재사용. 통합 테스트 5개 추가(로컬 실DB 전원 통과, `./gradlew test` 90개 그린). 상세는 [CLAUDE.md](../CLAUDE.md) "테스트 지원 (devtools)".
  - **schema 변경**: `user.provider` ENUM 에 `TEST` 추가 ([schema.sql](schema.sql)). `ddl-auto=validate` 라 필수.
  - **prod 배포 완료·검증**: 백엔드 이미지 재빌드·푸시(§5.1) + **라이브 DB 에 `ALTER TABLE user MODIFY provider ENUM(...,'TEST')` 수동 적용**(dbinit 볼륨은 최초 부팅에만 시딩되므로 이미 뜬 DB 는 ALTER 필수 — [docker-deployment.md §5.5](docker-deployment.md)) + 맥 `pull && up -d`. **prod E2E 검증 통과**: `https://tenk.hjson248.com` 에 테스트 로그인 → 시딩 → 5종 상태·배지 확인.
  - **내부 테스트 AAB(versionCode 3) 빌드 완료** — `--dart-define` 에 base URL + `TEST_LOGIN_KEY` 주입, `CN=Tenk` 릴리스 서명 확인. **Play Console 업로드는 사용자 수동**(§0).
  - **정식 출시 시**: 앱을 `TEST_LOGIN_KEY` 빼고 재빌드 + 맥 compose 에 `TENK_TEST_ENABLED=false`.
- **2026-07-08**: 🚀 **Play Console 내부 테스트 준비.** 개발자 계정 $25 + **신원 확인 완료** → 앱 생성·게시 가능. AAB 빌드 완료(`app-release.aab`), 개인정보처리방침 `https://tenk.hjson248.com/privacy.html` **LIVE**. 앞서 회원 탈퇴 3개월 hard-delete 배치 + privacy.html 구현·배포·커밋(`9e9e031`). 다음: 앱 만들기 → AAB 업로드 → **Play 앱 서명 키해시 카카오 등록** → 테스터 초대 (§0).
- **2026-07-08**: 🚀 **Play Console 내부 테스트 게시 성공 + 카카오 로그인 확인.** 신규 Play 개발자 계정($25) 신원 확인 완료 → 앱(`com.hjson.tenk_app`) 생성 → 내부 테스트에 AAB(versionCode 2) 업로드 → 게시 → 테스터 링크로 Play 설치 → **카카오 로그인 정상**. **Play App Signing 키해시 함정 넘김**: Play 앱 서명 키 SHA-1 `AF:BB:40:...` → base64 `r7tAXmn5jf61RifLeD82qJVg3Z0=` 를 카카오 Android 플랫폼에 추가 등록([[reference-play-app-signing-kakao-keyhash]]). 개인정보처리방침 URL 은 내부 테스트에선 비필수(프로덕션 전 입력). 첫 업로드 3-오류(번들 없음/업그레이드 불가/번들 미변경)는 versionCode 중복이라 `pubspec` 1.0.0+1→+2 로 해결. 상세 §0.
- **2026-07-03**: 🚀 **Android 테스트 APK 빌드·핵심검증 완료.** 릴리스 keystore/서명/앱이름(Tenk)/키해시 카카오 등록/서명 APK 빌드까지 끝. 실기기(갤럭시 S24, 무선 adb)에서 **카카오 로그인 + 배포 백엔드 연동 확인**. **릴리스에서만 카카오 로그인이 깨지던 버그 발견·수정 = R8 축소가 카카오 SDK Pigeon 클래스 제거 → `isMinifyEnabled=false`**(아래 함정). 남은 스모크(챌린지 생성/카메라/영상 export)는 다음. iOS 무료 빌드 경로(시뮬레이터/개인팀)·SSH 원격빌드 범위 문서화(§0). **커밋 후 iOS 빌드 착수 예정.**
- **2026-07-02 (2)**: 🚀 **테스트 배포 빌드 준비 착수** — 최우선 작업. 결정: 앱 표시 이름 `Tenk`, Android 배포 채널 = **직접 서명 APK 공유**(Firebase/Play Console 아님), Apple Developer 계정 **미보유 → iOS 는 절차만 문서화하고 보류**, Android 릴리스 keystore **신규 생성**(private 레포에 git 추적 — yaml 자격증명과 동일 방침). 상세·진행은 아래 "남은 일 §0".
- **2026-07-02**: Flutter 실기기 base URL 을 배포 HTTPS 도메인(`https://tenk.hjson248.com`)으로 전환 — LAN IP·cleartext 예외 제거(에뮬레이터는 `10.0.2.2` 유지, [docker-deployment.md §9.3](docker-deployment.md)). handoff·docker-deployment 문서 부피 축소(회의록은 유지). 리버스 프록시(Traefik)는 별도 리포 `reverse-proxy` 로 분리 확정 — 엣지 문서·기록은 그 리포 소관.
- **2026-06-27**: 영상 export 흐름 2화면 분리(클립 선택 / 합성 설정) + 자막 위치(중단·하단)·배경 사용자 설정화. 챌린지 이름 필드 에뮬레이터 검증 전원 통과. (에뮬레이터 검증 완료)
- **2026-06-19**: 영상 프리뷰 깜빡임 = Impeller 외부 텍스처 버그 확정·영구 수정(매니페스트 `EnableImpeller=false`, 아래 "함정 — Flutter" 참고). 챌린지 이름 서버 default-fill 제거(필수화, 클라가 `챌린지 N` pre-fill).
- **2026-06-17**: 챌린지 이름 필드 추가(필수 · 확정 전 변경 `PATCH` · 결과 카드 헤더 노출).
- **2026-06-16**: 결과 확정 전 기록 수정 허용 + 자동 확정 배치 제거(확정은 사용자 수동만). 닉네임/결과카드/SafeArea 실기기 검증 통과 + NicknameSetup initState 크래시 픽스.
- **2026-06-02**: 닉네임 도메인 정비(신규 가입 설정 화면 + '내 정보' 화면 + 하루 1회 변경 제한 + 재로그인 시 닉네임 보존).
- **2026-05-26**: 결과 카드(풀스크린 + 영상 마지막 3초 클립) / SafeArea(top:false) 전 화면 통일 / 카메라 녹화 시작 효과음(royalty-free MP3, 탭 즉시 트리거).
- **2026-05-25**: 카메라 녹화 시작 UX(preview freeze 제거 fork + transitional morph + chime) / 배지 획득 축하 모달(Lottie).
- **~2026-05-23**: 영상 합본 export 구현 / 기록 수정·촬영 분리 / 무지출·배지 도메인 정합성 / 백엔드 테스트(단위·통합·WebMvc). 상세는 "완료된 것" 섹션 + 회의록.

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
6. 백엔드 테스트: `cd tenk-backend && ./gradlew.bat test` (총 90개 — 단위 63 + 통합 22 + WebMvc 4 + ContextLoads 1). ⚠️ **테스트 실행 시 로컬 `tenk` DB의 user/challenge/amount/challenge_badge/refresh_token 데이터가 비워진다** (badge 마스터는 유지). Flutter 재로그인으로 복구 가능
7. **Flutter 앱 셋업** (앱 작업까지 할 거면):
   - 새 머신의 `~/.android/debug.keystore`에서 키해시 추출:
     `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64` (Git Bash). PowerShell `Get-FileHash` 안 됨 — [[reference-kakao-android-keyhash]] 참고.
   - 출력값을 카카오 디벨로퍼스 → Tenk 앱 → 플랫폼 → Android의 키해시 목록에 **추가** 등록 (기존 머신 키해시는 그대로 두고 추가). 한 플랫폼에 여러 해시 등록 가능.
   - `cd tenk_app && flutter pub get && flutter run`. 에뮬레이터에서 글자가 안 보이면 [[reference-flutter-android-impeller-text-glitch]] 참고.
8. Claude 세션 시작: 리포 루트에서 `claude` (CLAUDE.md 자동 로딩됨). 첫 메시지로 *"docs/handoff.md 읽고 이어서 진행해줘"* 라고 말하면 컨텍스트 빠르게 복구.

---

## 완료된 것 (요약)

> 디테일은 git log/blame에 있음. 여기엔 "어디까지 왔는지" + "코드에 안 보이는 결정"만.

**백엔드**
- ✅ **골격**: JPA 엔티티 7종 + Repository, 공통 응답/에러, REST API(User/Challenge/Amount/Media/Badge), 영상 업로드, Swagger UI, JPA Auditing. Spring Boot 4 + Jackson v3(`tools.jackson.*`).
- ✅ **인증**: 카카오 SDK + 자체 JWT(AT 1시간/RT 14일 회전). `KakaoTokenVerifier` `app_id` 매칭 검증, RT는 SHA-256 해시 저장. **Swagger 시나리오 1·2·3 통과** (RT 회전/logout 일괄 무효화/만료 AT `AU0002`≠`AU0001`). JWT secret 환경별 분리(공통 yaml엔 없음).
- ✅ **배지 자동 지급**: 이벤트(AFTER_COMMIT + REQUIRES_NEW) + 새벽 1시 배치 재평가. 유저 단위 → **챌린지 단위**로 재편(`challenge_badge`, `ChallengeResponse.badges` 인라인, 전용 화면 없음). 회수(revoke)는 `applyLadder` 단일 패스.
- ✅ **결과 export**: `GET /api/challenges/{id}/export` 일별/카테고리별 JSON. **CORS 비활성화**(네이티브 앱 전용).
- ✅ **amount.memo**(VARCHAR 500, 빈값 null 정규화) + **무지출/배지 정합성**(일시 서버 now 강제, 하루 1회 UNIQUE, 지출 시 같은 날 무지출 자동 삭제 + 배지 revoke, NO_SPEND=누적/STREAK=연속).
- ✅ **테스트 현황**: `./gradlew.bat test` 총 **90개**(단위 63 + 통합 22 + WebMvc 4 + 컨텍스트 1). 통합 22 = 기존 17 + devtools 시딩/로그인 5(2026-07-11). `LocalDate.now()` 정적이라 종료 상태는 reflection backdate. 통합은 로컬 `tenk` 스키마 공유 → 실행 시 dev 데이터 비워짐(Flutter 재로그인 복구). 상세 패턴은 [../CLAUDE.md](../CLAUDE.md) 테스트 컨벤션 행 + 아래 "함정".
- ✅ **카카오 키**(git 추적): 네이티브 앱 키 `589078d3c7daa590c71d9a6e77080b18` 3곳(kakao_config.dart/Android build.gradle/iOS Info.plist), 백엔드 `tenk.auth.kakao.app-id = 1459747`. Android **debug** 키해시 `Dt3/ajH81vV0Ex78dS1ACaqelWc=`(이 머신 기준, 새 머신은 [[reference-kakao-android-keyhash]]). Android **release** 키해시(`tenk-release.keystore`, alias `tenk`) `NsYpNZftCOyk4LygMWF7mdtowdg=` — **카카오 콘솔에 이 값도 추가 등록해야 릴리스 APK 에서 로그인 됨** (미등록 시 로그인만 실패). keystore 이동·재생성하면 이 값도 바뀌니 재추출: `keytool -exportcert -alias tenk -keystore tenk-release.keystore -storepass '<pw>' | openssl sha1 -binary | openssl base64`.

**Flutter 앱** (구조: `lib/app`(셸) + `lib/data` + `lib/presentation` 3층, 컨벤션은 [../CLAUDE.md](../CLAUDE.md))
- ✅ **핵심 흐름**: 카카오 로그인 + 챌린지 CRUD + 지출/무지출 기록 + 2초 영상 녹화·업로드(`camera` medium, enableAudio:false) + 일시 picker + finalize. 에뮬레이터 E2E 통과.
- ✅ **챌린지 상세 UX**: amount 날짜별 그룹화, 오늘 상태 기반 동적 액션 패널(3분기), 무지출 성취감 카드(NO_SPEND 사다리 게이지).
- ✅ **영상 합본 export**: 확정 후 기록 영상 시간순 합성 → 갤러리 저장·공유. `ffmpeg_kit_flutter_new_video`, sw `mpeg4` 인코더 고정, 자막은 TextPainter PNG + overlay. 상세·함정은 아래 "영상 내보내기 회의록".
- ✅ **결과 카드**: 확정 후 480x864 1장 카드(풀스크린 + 영상 마지막 3초 클립 옵션). 색 hardcode, off-screen RepaintBoundary 캡처. 상세는 "결과 카드 회의록".
- ✅ **카메라 녹화 시작 UX**: preview freeze 제거(camera 패키지 fork, eager bind), transitional morph, 효과음(royalty-free MP3 탭 즉시 트리거).
- ✅ **배지 획득 축하 모달**(Lottie): 챌린지 상세 reload diff 로 신규 배지 감지 → 순차 큐 모달.
- ✅ **영상 미리보기**: 촬영 직후 자동 재생 + 수정 화면 lazy 다운로드 미리보기(retake/delete).

---

## 남은 일 (우선순위 순)

> 백엔드 테스트(단위·통합·WebMvc) + 영상 합본 export + 배지 획득 축하 모달 + 카메라 녹화 시작 UX (transitional morph + 효과음 royalty-free MP3 + 탭 즉시 트리거 분리) + 챌린지 결과 카드 (풀스크린 + 영상 마지막 클립 합성) 모두 ✅ 완료. 자세한 건 "완료된 것" 섹션 참고. **카메라 / 결과 카드 / 닉네임 도메인 일단락 + 위 3개 블록 실기기 검증 전원 통과 (2026-06-16)** — 다음은 다른 백로그.

### 0. 🚀 테스트 배포 빌드 준비 (최우선 · 진행 중, 2026-07-02 착수)

> 목표: Android/iOS 테스트 버전 배포. **결정 사항**은 위 "최근 변경 이력" 참고. 릴리스 빌드 규칙·함정은 [CLAUDE.md](../CLAUDE.md) "릴리스 빌드 / 배포" 섹션에 영구 규칙으로 박음.

**환경 제약 (중요)**
- **iOS 빌드는 이 Windows 머신에서 불가** — `flutter build ios/ipa`/`pod install`/Xcode 전부 macOS + Xcode 필수. iOS 작업은 전부 맥에서 (도커 배포하던 그 맥).
- **iOS 앱스토어/TestFlight 배포만 Apple Developer Program($99/년) 필요** — 미보유라 배포는 보류. 하지만 **빌드·실행은 공짜로 가능**(시뮬레이터=계정 불필요, 본인 아이폰=무료 Apple ID 개인팀). 아래 iOS 항목 참고.

**Android (직접 서명 APK 공유) — ✅ 빌드·핵심검증 완료 (2026-07-02)**
- [x] 릴리스 keystore(PKCS12) 생성 → `tenk_app/android/tenk-release.keystore` (alias `tenk`, git 추적) + [key.properties](../tenk_app/android/key.properties) (git 추적, 양쪽 .gitignore 무시 해제)
- [x] [build.gradle.kts](../tenk_app/android/app/build.gradle.kts) key.properties 로드 + `release` signingConfig (없으면 debug 폴백). **R8 축소 OFF**(`isMinifyEnabled=false`/`isShrinkResources=false`) — 아래 함정 참고
- [x] 앱 표시 이름 `Tenk` (android:label + iOS CFBundleDisplayName)
- [x] 릴리스 키해시 `NsYpNZftCOyk4LygMWF7mdtowdg=` 추출 → **카카오 콘솔 등록 완료**(debug 와 함께 2개)
- [x] `flutter build apk --release --dart-define=API_BASE_URL=https://tenk.hjson248.com` → app-release.apk (fat, ~165MB). apksigner 로 릴리스 키 서명 확인
- [x] **실기기 스모크 부분 통과** (SM-S921N 갤럭시 S24, 무선 adb): ✅ 카카오 로그인(릴리스 키해시 유효) / ✅ 배포 백엔드 연동(챌린지 목록 로딩) / ✅ 앱 이름·로그인·목록 화면 정상. **R8 이 카카오 SDK 제거해 릴리스에서만 로그인 깨지던 버그 발견·수정**(아래 함정)
- [ ] **남은 스모크**(다음): 챌린지 생성 → 지출/무지출 기록 → **카메라 녹화·업로드** → 확정 → 결과 카드 → **영상 export**. (adb input 으로 이어서 구동 가능)
- [ ] (선택) 앱 아이콘 교체 — 현재 기본 Flutter 아이콘 (`flutter_launcher_icons` 권장)
- [ ] (선택) APK 크기(~165MB) 줄이려면 `--split-per-abi` (arch별 ~55MB)

**Play Console 내부 테스트 (직접 APK 와 병행) — ✅ 게시·로그인 확인 (2026-07-08)**
- [x] Play 개발자 계정 $25 + **신원 확인 완료**. 앱 생성 (패키지명 = applicationId **`com.hjson.tenk_app`**, 영구 고정 — 백엔드 자바 패키지 `com.hjson.tenk` 와 무관).
- [x] AAB 빌드: `flutter build appbundle --release --dart-define=API_BASE_URL=https://tenk.hjson248.com`(+ 테스트 기능 배포 시 `--dart-define=TEST_LOGIN_KEY=<서버 login-key>`) → `build/app/outputs/bundle/release/app-release.aab`(~104MB). Play 는 신규앱 APK 불가·AAB 필수. **재업로드 시 `pubspec` versionCode 필히 증가**. 이력: +2(2026-07-08 게시) → **+3(2026-07-11, devtools 테스트 기능 포함, 업로드 대기)**.
- [x] 내부 테스트 트랙 업로드 → 게시 → 테스터 목록 → 참여 링크로 Play 설치. 개인계정 "비공개 12명×14일" 요건은 **프로덕션 전용** — 내부 테스트는 면제(100명 즉시).
- [x] **⚠️ Play 앱 서명 키해시 카카오 등록 완료** — Play App Signing 이 구글 키로 재서명하므로 앱 서명 키 인증서 SHA-1(`AF:BB:40:5E:...`)을 base64(`r7tAXmn5jf61RifLeD82qJVg3Z0=`)로 변환해 카카오 Android 에 추가. 안 하면 Play 설치분만 로그인 실패. 변환·3종 키해시 목록은 [[reference-play-app-signing-kakao-keyhash]]. **✅ 테스터 폰 Play 설치 → 카카오 로그인 성공 확인.**
- [ ] (프로덕션 전) 앱 콘텐츠 완성: 개인정보처리방침 URL(`https://tenk.hjson248.com/privacy.html`, 준비됨) + 데이터 안전 폼 + 콘텐츠 등급 + 타겟층. 내부 테스트에선 비필수라 미입력 상태.

**Play Console 내부 테스트 (2026-07-07 피벗 · 진행 중)** — 직접 APK 공유에 더해 Play 내부 테스트 트랙으로도 배포
- [x] 개발자 계정 $25 결제 + **신원 확인 완료 (2026-07-08)** → 앱 생성·게시 가능
- [x] AAB 빌드: `flutter build appbundle --release --dart-define=API_BASE_URL=https://tenk.hjson248.com` → `tenk_app/build/app/outputs/bundle/release/app-release.aab` (~104MB). 신규앱은 APK 불가·**AAB 필수**
- [x] 개인정보처리방침 LIVE: `https://tenk.hjson248.com/privacy.html` (위 §4 운영 고려사항 참고)
- [ ] Play Console → **앱 만들기**(이름 Tenk, 무료) → **앱 콘텐츠**에서 개인정보처리방침 URL 입력 + 데이터 안전·콘텐츠 등급·타겟층 폼 작성
- [ ] **내부 테스트** 트랙 → 새 버전 → `app-release.aab` 업로드 (첫 업로드 시 **Play App Signing 자동 활성화**)
- [ ] ⚠️ **Play 앱 서명 키 인증서 SHA-1 → 카카오 콘솔 추가 등록** — Play 는 구글이 재서명하므로 로컬 릴리스 키해시(`NsYpNZftCOyk4LygMWF7mdtowdg=`)로는 Play 설치본 로그인이 실패. Play Console → 앱 무결성 → 앱 서명 키 인증서 SHA-1 을 base64 변환([[reference-kakao-android-keyhash]] 방식)해 **추가** 등록(기존은 유지). 근거 [[reference-play-app-signing-kakao-keyhash]]
- [ ] 테스터 이메일 등록 → 옵트인 링크 배포 → 설치·카카오 로그인 확인
- 참고: 신규 개인계정은 프로덕션 출시 전 "비공개 테스트 12명×14일" 요건이 있으나 **내부 테스트 트랙은 면제**(최대 100명 즉시 배포). 승인 전까지도 **직접 APK 설치**(`app-release.apk`)로 테스트 가능

**iOS — 맥에서. 빌드·실행은 지금 무료로 가능, TestFlight 만 유료(나중)**
- 공통 사전: `xcode-select --install`, `sudo gem install cocoapods`(또는 brew), `cd tenk_app && flutter pub get && (cd ios && pod install)`.
- 첫 빌드 걸림돌: **ffmpeg_kit/camera pod 의 iOS 최소버전** — `ios/Podfile` 의 `platform :ios, 'xx'` 를 14.0 정도로 올려야 pod install 될 수 있음. 카카오 iOS URL scheme·권한 usage description 은 이미 Info.plist 에 있음. **단 카카오 콘솔에 iOS 플랫폼(번들 ID) 추가 등록 필요**(현재 Android 만 등록). iOS 는 키해시 개념 없음.
  - **(무료) 시뮬레이터**: `open -a Simulator` → `flutter run --dart-define=API_BASE_URL=https://tenk.hjson248.com`. 계정 불필요. ⚠️ 시뮬레이터엔 카메라 없어 영상 녹화 테스트 불가(로그인·챌린지·기록 흐름은 OK).
  - **(무료) 본인 아이폰 실기기**: `open ios/Runner.xcworkspace` → Runner 타깃 → Signing & Capabilities → Team=무료 Apple ID(Personal Team), Bundle ID 유니크(예 `com.hjson.tenkApp`), automatic signing. 아이폰 개발자 모드 ON + "이 컴퓨터 신뢰" → `flutter run -d <iphone>`. 무료 서명은 **7일 만료**(재실행으로 갱신).
  - **(유료·나중) TestFlight**: Apple Developer Program 가입 → App Store Connect 앱 레코드 → `flutter build ipa --release --dart-define=...` → Transporter 업로드 → 내부 테스터 초대.
- **SSH 로 원격 빌드 가능 범위**: 컴파일·`flutter build`·`xcodebuild`·`xcrun simctl`(시뮬레이터 부팅/설치/실행/스크린샷)은 SSH OK → **시뮬레이터 목표면 SSH로 거의 다 됨**. 단 **코드 서명 키체인**(codesign 이 GUI 팝업 → `security unlock-keychain` + `set-key-partition-list` 로 사전 인가 필요), **무료 개인팀 자동 프로비저닝**(Xcode GUI 한 번 필수), **실기기 신뢰·개발자 모드**(아이폰 화면 탭)는 순수 SSH 불가. 권장: **첫 서명·기기신뢰 세팅은 화면공유(VNC)로 한 번, 이후 반복 빌드만 SSH**.

### 1. 앱 UX 다듬기 (백로그)

**2026-07-11 요청 배치 (UX 다듬기 + 버그 제보)** — 아직 미착수, 결정/구현 전. 착수 시 세부 결정 필요한 항목은 각 줄에 표기.
- [ ] **챌린지 상태 색 변경** — 상태값(시작 전 / 진행 중 / 확정 대기 / 성공 / 실패)별 색상 재정의. 현재는 [challenge_status.dart](../tenk_app/lib/presentation/challenge/widgets/challenge_status.dart) 기준. 아래 "챌린지 색깔 기능"과 역할 충돌 안 나게 분리(상태색 vs 챌린지별 사용자 지정색).
- [ ] **카테고리 목록화 + 아이콘** — 지출 카테고리를 자유 입력 대신 **정해진 목록에서 선택**으로 전환 + 카테고리별 아이콘. 결정 필요: 카테고리 카탈로그(항목/개수), 서버 enum 화 여부(현재 `category` 는 자유 문자열), 기존 자유입력 데이터 마이그레이션. 클라 record/edit 폼 + 상세 목록 아이콘까지.
- [ ] **금액 입력 보조 표시** — 지출 기록 금액 입력 칸 밑에 좌:현재(입력) 금액 / 우:박스(목표) 금액 기준 남는 금액 실시간 표시. [amount_record_screen.dart](../tenk_app/lib/presentation/amount/amount_record_screen.dart). "남는 금액"이 이미 사용한 지출 합계까지 반영할지(목표 − 기존지출 − 입력값) 결정 필요.
- [ ] **필수/선택 표기를 빨간 별표로** — `(필수)`/`(선택)` 텍스트 대신 필수 항목에 빨간 `*`. 전 폼 일관 적용(record/edit/create/nickname 등) — [[feedback-consistency-over-pinpoint]] 원칙대로 짚어준 화면만 말고 전수.
- [ ] **'메모' → '한 줄 평' 용어 변경** — UI 라벨만 교체(백엔드 필드명 `memo` 는 유지). export 자막·record/edit 폼·상세 등 노출 위치 전수. CLAUDE.md 의 도메인 설명 용어도 함께 검토.
- [ ] **챌린지 색깔 기능 추가** — 챌린지별 사용자 지정 색상(목록/상세 구분용). 결정 필요: 프리셋 팔레트 vs 자유 피커, 서버 컬럼 추가(`challenge.color`) + schema.sql, 적용 범위(목록 카드 액센트만 vs 상세까지), 상태색과의 시각 충돌 회피. (원래 "설명 추가"였다가 색깔 기능으로 대체됨.)
- [ ] **챌린지 성공 트로피 배지** — 성공 확정 시 트로피 배지. 백엔드 `CHALLENGE_SUCCESS` 배지 지급 로직은 이미 존재([BadgeGrantService](../tenk-backend/src/main/java/com/hjson/tenk/domain/badge/BadgeGrantService.java)) — 신규 로직인지 기존 성공 배지 아이콘을 트로피로 교체/개선하는지 착수 시 확정.
- [ ] 🐛 **7/11 날짜 제보 조사** — 2026-07-11 00:48 기준 "7월 11일(오늘)이 안 된다"는 제보. 증상 미상. 유력 후보: 자정 경계/타임존에서 "오늘" 기준일이 하루 어긋나 ① 오늘 시작 챌린지 생성이 `startDate >= today` 로 거부되거나 ② 오늘 지출 `spent_dt` 가 `AMOUNT_DATE_OUT_OF_RANGE` 로 걸리는 케이스. 재현·원인 파악 필요.

- ✅ **챌린지 이름 필드 추가** (2026-06-17 구현, 2026-06-19 정책 변경, **2026-06-27 에뮬레이터 검증 통과**). **이름 필수 — 비울 수 없음.** 기본값 `챌린지 N` 은 **클라가 미리 채움**(서버 default-fill `resolveName` 제거, `@NotBlank` 로 빈값 거부), 결과 확정 전까지 변경 가능(`PATCH /api/challenges/{id}`), 결과 카드 헤더에 노출. 상세는 위 "마지막 갱신"(상단 + 2개) + [CLAUDE.md](../CLAUDE.md) "챌린지 도메인 규칙" / 위치별 책임 "챌린지 이름 정책 변경" 행 참고. 에뮬레이터 검증 완료(기본 이름 pre-fill / 빈값 거부 / 확정 전 rename / 확정 후 연필 숨김 / 결과 카드 이름) — 추가 작업 없음.
- **업적(achievement) 시스템** — 챌린지 경계를 가로지르는 누적 보상. 새 테이블(예: `user_achievement`) + 별도 컨트롤러/서비스 + 별도 Flutter 화면. 자산은 기존 `assets/badges/` 재활용 가능. 배지와 디자인 언어가 자연스럽게 이어지도록 설계.
- **목록에 메모 노출** — 챌린지 상세의 amount 목록 (`_AmountTile`) 에서 memo 가 있을 때 미리보기(1~2줄 ellipsis) 또는 메모 아이콘 배지. 결정 필요: 본문 노출이 좋은지 아이콘만 노출이 좋은지 (긴 메모가 목록 높이를 흔들 수 있음).
- ✅ **내보낸 영상 자막 위치/스타일 — 사용자 설정화** (2026-06-27 구현 + **에뮬레이터 검증 통과**). 하드코딩 변경 대신 **사용자가 export 화면에서 고르게** 함 (영상 전체 단위, 클립별 아님). ① **위치**: SegmentedButton **중단/하단** (기본 하단 = 기존 동작 유지. 상단은 대시보드 Day N+잔여와 겹쳐 의도적 제외 — 사용자 합의). ② **배경**: Switch. ON=반투명 박스(black@0.55)+흰 글자(외곽선 X, 기존 스타일), OFF=흰 글자+검은 외곽선(stroke 4px, StrokeJoin.round)+drop shadow(박스 X). 배경/외곽선은 배타적(배경 있으면 외곽선 불필요 — 사용자 결정). **변경 파일 3개**: [video_composer.dart](../tenk_app/lib/data/export/video_composer.dart) — `SubtitlePosition{middle,bottom}` enum + `compose()`/`_normalizeClip()`/`_renderTextOverlayPng()` 시그니처에 `subtitlePosition`/`subtitleBackground` 추가(기본 bottom/true 라 backward compat) + `_drawTextBlock` 에 `centerY`/`withBox`/`withOutline` 파라미터(외곽선은 stroke Paint 2-pass). [export_compose_screen.dart](../tenk_app/lib/presentation/challenge/export/export_compose_screen.dart) — 생성자 2필드 + compose 전달. [export_screen.dart](../tenk_app/lib/presentation/challenge/export/export_screen.dart) — `_SubtitleStyleControls` 위젯(_ResultCardToggle 아래) + state 2필드. 흐름은 `includeResultCard` 패턴 그대로. **상단 대시보드는 손대지 않음**(항상 박스 유지). 결과 카드 PNG·백엔드 무관. flutter analyze 0 issues(3파일). **✅ 에뮬레이터 검증 통과 (2026-06-27, Pixel emulator)**: 확정 챌린지 "바보"(영상 1개, 자막 "아꼈다!!")로 export → ① 컨트롤 렌더(위치 SegmentedButton 중단/하단 + 배경 Switch, 선택 표시·설명 문구 전환 정상) ② **중단+배경 OFF** 합성 → 결과 미리보기에서 자막이 영상 정중앙 + 박스 없이 흰 글자+검은 외곽선, 밝은 흰 배경에서도 또렷하게 읽힘(외곽선 보강 작동 확인) ③ **하단+배경 ON(기본)** 합성 → 하단 + 반투명 박스(기존 동작 회귀 확인) ④ 상단 대시보드는 양쪽 모두 박스 유지(자막만 영향) ⑤ 멀티코드포인트 한글 완전 렌더(drawtext 회귀 없음). **미커버**: 텍스트 카드(무지출+영상없음) 클립 — 검증 데이터에 해당 케이스가 없었음. 코드상 같은 `_renderTextOverlayPng` 경로라 동일 적용되나 실제 화면 확인은 다음 기회에. (검증 중 에뮬레이터 저장공간 부족으로 재설치 시 토큰이 날아가 카카오 재로그인 1회 필요했음 — 코드 무관.)
- **실기기 테스트** — `--dart-define=API_BASE_URL=http://192.168.x.x:8080`로 같은 Wi-Fi의 PC IP 주입. 에뮬레이터와 카메라 동작이 미묘하게 다름.
  - ✅ **2026-06-16 실기기 검증 전원 통과** — 그동안 미검증으로 쌓여 있던 3개 블록을 실기기에서 모두 확인:
    - **닉네임 도메인** (2026-06-02 적용): 신규 가입 시 NicknameSetupScreen 분기·카카오 닉네임 pre-fill·back 차단 / 가입 화면 멱등 no-op(같은 날 1회 자유 변경) / 닉네임 수정 시 하루 1회 제한 / 재로그인 시 닉네임 보존(카카오 프로필로 안 덮어씀) / AppBar `account_circle_outlined` → 내 정보 / 회원 탈퇴 soft delete + 재로그인 차단 / 클라 측 제어문자 validation. **검증 중 NicknameSetupScreen initState 크래시 1건 발견·수정** (위 '마지막 갱신' 참고).
    - **결과 카드** (2026-05-26 적용): finalize 직후 자동 풀스크린 push(배지 모달 뒤) / 상세 진입점 카드 / 닉네임 헤더 fetch·폴백 / SUCCESS=노랑·보라·🎉 vs FAIL=그레이·💪 색 분기 / 배지 row·무지출 라인 빈 슬롯 생략 / 갤러리 저장·공유 / 영상 export 마지막 3초 정지 클립 합성.
    - **SafeArea(top:false)** (2026-05-26 적용): 11화면(amount_record / amount_edit / amount_camera / amount_video_preview / challenge_list / challenge_detail / challenge_create / export_screen / export_prefetch / export_compose / export_result) 하단 시스템 바 가림 없음 + ListView 마지막 항목 visual gap 적정.
  - 향후 새 화면 추가 시에도 같은 항목(하단 가림 / 제스처·3버튼 내비 양쪽 / 키보드 inset)을 실기기에서 점검할 것.

### 2. 페이지네이션 / 정렬
- `/api/challenges`, `/api/challenges/{id}/amounts`가 전체 목록 반환 중. `Pageable` 도입 시점 결정 (지금은 사용자당 챌린지 수가 적어 무방).

### 3. Google / Naver 로그인 추가 (예정)
- 동일 패턴: `GoogleTokenVerifier` / `NaverTokenVerifier` + `AuthService`에 분기 + `POST /api/auth/google/login` / `/naver/login`. **브라우저 redirect 흐름은 사용하지 않음** (모바일 SDK 전제).

### 4. 운영 고려사항 (필요해지면)
- **영상 저장소 S3/MinIO 이전** — `LocalFileStorage`를 인터페이스로 추출 후 구현체 분리.
- **AT 강제 무효화(블랙리스트)** — 필요 시 Redis. 현재는 AT 만료 시간(1시간)에 의존.
- **CI 도입** — 현재 통합 테스트가 로컬 `tenk` 스키마를 비우는 구조라 CI 에서 그대로 못 돈다. 도입 시 Testcontainers + 별도 `tenk_test` 스키마로 갈아탈 것.
- **개인정보처리방침 (2026-07-07 작성 + 배포 LIVE)** — [privacy.html](../tenk-backend/src/main/resources/static/privacy.html) 로 작성, Spring Boot static 서빙. ✅ **`https://tenk.hjson248.com/privacy.html` 배포 완료·브라우저 접속 확인** (SecurityConfig PERMIT_ALL 등록, 맥 이미지 재배포로 LIVE). 수집항목/이용목적/보관기간(탈퇴 후 3개월)/제3자(카카오)/파기/권한/문의처 포함. **Play Console 개인정보처리방침 URL 에 이 주소 입력.** 남은 것: ① 앱 내 링크 노출 (LoginScreen 또는 NicknameSetupScreen 에 "개인정보처리방침" 링크) ② 실서비스 전 변호사 검수 권장 ③ 문구는 실제 동작(음성 미수집, 자체 서버 저장, 3개월 보관 후 파기)과 일치시켜 작성했으니 정책 바꾸면 동시 갱신.
- **회원 탈퇴 hard delete (2026-07-07 구현 완료)** — soft delete + 3개월 보관 후 물리 삭제. `User.withdraw()` 는 여전히 soft delete(`deleted_dt`) + RT 무효화, 새벽 1:30 배치 [UserRetentionScheduler](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/UserRetentionScheduler.java) → [WithdrawnUserPurgeService.purge](../tenk-backend/src/main/java/com/hjson/tenk/domain/user/WithdrawnUserPurgeService.java) 가 `deleted_dt` +3개월 지난 계정을 challenge/amount/media_file row + 디스크 `uploads/` 영상 + refresh_token 까지 FK 순서(디스크→media_file→challenge_badge→amount→challenge→refresh_token→user)로 삭제. 유저 1명 단위 트랜잭션, 파일은 best-effort(`deleteQuietly`). user 는 hard delete 라 provider/provider_user_id 재사용 가능. 보관기간 상수는 `WithdrawnUserPurgeService.RETENTION`. **남은 것**: ① 통합 테스트 (탈퇴+deletedDt 과거로 박고 purge → row·파일 소멸 확인) 미작성 ② 3개월 미도래 계정은 그대로라 UI "영구히 삭제" 문구와 즉시성엔 여전히 시차 있음(정책상 의도).

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
- **✅ 해결됨 — 릴리스 APK 에서만 카카오 로그인 실패 = R8 이 카카오 Pigeon 클래스 제거 (2026-07-02, 삼성 실기기 확인)**. 증상: 릴리스 APK 에서 "카카오로 로그인" 탭 → `카카오 로그인 실패: Unable to establish connection on channel: "dev.flutter.pigeon.kakao_flutter_sdk_common.CommonHostApi.isKakaoTalkAvailable"`. 카카오 창이 아예 안 뜨고 즉시 실패. 진단: 최신 Flutter/AGP 가 `flutter build apk --release` 에서 **R8 축소를 기본 ON** 으로 도는데(gradle 에 `minifyEnabled` 명시 없어도 적용), `build/app/outputs/mapping/release/usage.txt` 에 `com.kakao.sdk.flutter.common.CommonHostApi.setUp(...)` 등 카카오 네이티브 58개 항목이 **제거됨**으로 찍혀 있었다 — 채널 핸들러를 등록하는 `setUp` 이 stripped 되어 채널이 안 열림. **키해시와 무관**(키해시 정상 등록돼도 이 에러). 해결: [build.gradle.kts](../tenk_app/android/app/build.gradle.kts) release 블록에 `isMinifyEnabled = false` + `isShrinkResources = false`. 이 앱은 kakao + ffmpeg_kit + camera fork 등 네이티브 플러그인이 무거워 keep 규칙 개별 관리보다 축소 OFF 가 안전(테스트 빌드 기준). **Play Store 정식 출시로 크기 최적화가 필요하면** R8 을 다시 켜고 `proguard-rules.pro` 에 플러그인별 keep 규칙(카카오/ffmpeg/camera) 추가할 것. 진단 명령: `grep -i kakao build/app/outputs/mapping/release/usage.txt`.
- **릴리스 APK 빌드 시 Kotlin 증분컴파일 스택트레이스는 무해**: `flutter build apk --release` 끝에 `Could not close incremental caches ... this and base files have different roots` 류의 긴 stacktrace 가 찍히는데, **pub 캐시가 `C:` 드라이브(`AppData\Local\Pub\Cache`)·프로젝트가 `D:` 드라이브라** Kotlin 이 상대경로 계산에 실패하는 것뿐이고 **빌드는 성공한다**. 판단 기준은 맨 끝의 `√ Built build\app\outputs\flutter-apk\app-release.apk` 줄. 없애려면 pub 캐시를 같은 드라이브로 옮기거나(`PUB_CACHE`) 무시. APK 산출물·서명엔 영향 없음.
- **목록/상세 화면의 비동기 데이터는 `AsyncStateMixin` + `AsyncStateView` 사용**, `FutureBuilder` 금지 ([presentation/common/async_state.dart](../tenk_app/lib/presentation/common/async_state.dart)). 한 화면이 두 종류 이상의 비동기 자원을 다루면 mixin 대신 직접 state.
- **Navigator push/pop의 generic은 양쪽 모두 명시.** `MaterialPageRoute<T>(builder: ...)`로 T를 박지 않으면 result가 null로 빠지는 경우. push 종료 시점에 무조건 refresh하는 패턴이 안전.
- **에뮬레이터에서 텍스트가 첫 프레임에 안 보이고 화면을 움직이면 나타나면** [[reference-flutter-android-impeller-text-glitch]] — Impeller 텍스트 atlas 버그. `flutter run --no-enable-impeller`로 검증.
- **매니페스트(`AndroidManifest.xml`) 변경은 hot reload로 반영 안 됨.** 콜드 부팅(`q` → `flutter run`) 또는 hot restart(`R`).
- **카카오 키해시는 머신마다 다름.** 새 머신 [[reference-kakao-android-keyhash]] 절차로 재등록.
- **실기기에서 백엔드 도달 불가**: 기본 base URL 인 `10.0.2.2` 는 에뮬레이터 전용 호스트 루프백. 같은 Wi-Fi 의 실기기에서 PC 백엔드를 호출하려면 PC LAN IP 로 바꿔야 한다. 증상은 "카카오 동의 화면까지는 뜨는데 그 뒤 로그인이 안 됨" — 카카오 SDK 는 인터넷에 닿지만 백엔드 교환 콜이 끊긴다. 현재 머신 IP 와 셋업은 아래 "PC LAN IP" 참고.
- **Android `res/xml/*.xml` 주석에 이중 하이픈 금지**: `<!-- ... -->` 안에 `--` 두 글자가 들어가면 `mergeDebugResources` 가 `ParseError ... 주석에서는 "--" 문자열이 허용되지 않습니다` 로 빌드 실패. XML 1.0 §2.5 strict 적용이라 `--dart-define`, `--flag` 같은 CLI 옵션을 주석에 인용할 때 자주 걸린다. AndroidManifest.xml / network_security_config.xml / 그 외 `app/src/main/res/**.xml` 모두 동일. 해결은 단순히 하이픈을 빼거나 문구를 바꾸면 됨.
- **✅ 해결됨 — 영상 프리뷰 깜빡임 = Impeller 외부 텍스처 버그 (2026-06-19, 삼성 S24 실기기 재현·확정·수정)**. 증상: [export_result_screen](../tenk_app/lib/presentation/challenge/export/export_result_screen.dart) 의 미리보기 영상**만** 초당 10여 회 깜빡임 — 주변 UI(제목/저장/공유 버튼)는 멀쩡. 즉 화면 전체 리프레시 문제가 아니라 **영상 텍스처 합성 단계**의 문제. 진단: live logcat 결과 디코더(mpeg4)는 **단일 인스턴스가 에러 0 으로 정상 디코딩**(`BufferPoolAccessor2.0` 단일 풀, recycle/alloc 단조 증가, used 4~5 일정), 컨트롤러 dispose 도 정상 → 디코딩/컨트롤러 멀쩡, **그리는 단계만** 깜빡임. `flutter run` 에 no-enable-impeller 플래그를 줘서 실행하니 깜빡임 즉시 소멸 → **Impeller 백엔드의 외부 텍스처 렌더 버그로 확정**. 영구 수정: [AndroidManifest.xml](../tenk_app/android/app/src/main/AndroidManifest.xml) 의 `<application>` 에 `io.flutter.embedding.android.EnableImpeller=false` meta-data 추가(Skia 폴백). 매니페스트만으로 재빌드 후 깜빡임 없음 검증 완료. **2026-06-16 의 "삼성 적응형 120Hz thrashing / 양성 / 코드변경 없음" 결론은 오진이었다** — `requestGpisForSFSluggish` 는 노이즈였고 진짜 원인은 Impeller. 같은 프로젝트의 Impeller 텍스트 깨짐 이슈와 같은 계열. **함정 메모**: 그 meta-data 주석에 `--no-enable-impeller` 를 적었다가 XML 이중 하이픈 금지(아래 Android res/xml 항목)로 manifest merge 가 깨졌음 — 하이픈 빼서 해결. Impeller 외부 텍스처 버그가 업스트림에서 고쳐지면 meta-data 제거 검토.

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
| 5 | 자막 영상 안 표시 | 클립 내내 하단 고정 자막. **구현은 Flutter TextPainter PNG + ffmpeg overlay** (drawtext 폐기, 위 "함정 — drawtext 한글 회귀" 참고) |
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
챌린지 확정 화면 자체가 별도 의사결정 항목으로 분리될 가능성이 있어 영상 내보내기 구현 도중 함께 정리.

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
