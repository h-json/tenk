# Handoff — Manwon 백엔드

> 다른 컴퓨터/세션에서 이 작업을 이어받는 사람(또는 미래의 나)을 위한 인계 노트.
> 영구적인 규칙·결정은 [../CLAUDE.md](../CLAUDE.md)에 있고, 이 문서는 **현재 진행 상태와 다음 할 일**만 기록함.

마지막 갱신: 2026-05-17

---

## 새 컴퓨터에서 시작하는 순서

1. 저장소 클론 후 IntelliJ 등으로 열기. JDK 21 확인.
2. MariaDB 준비 → `docs/schema.sql` 적용 (CLAUDE.md '로컬 실행 방법' 참고).
3. OAuth2 키 발급/주입:
   - Google: https://console.cloud.google.com — OAuth 동의화면 + Web 클라이언트 → 리다이렉트 `http://localhost:8080/login/oauth2/code/google`
   - Kakao: https://developers.kakao.com — 앱 추가 → "카카오 로그인" 활성화 → 리다이렉트 `http://localhost:8080/login/oauth2/code/kakao`
   - Naver: https://developers.naver.com — 애플리케이션 등록 → 콜백 `http://localhost:8080/login/oauth2/code/naver`
4. 환경변수 세팅 → `./gradlew.bat bootRun` → `http://localhost:8080/swagger-ui.html`
5. Claude 세션 시작: `claude` (CLAUDE.md 자동 로딩됨). 첫 메시지로 *"docs/handoff.md 읽고 이어서 진행해줘"* 라고 말하면 컨텍스트 빠르게 복구.

## 완료된 것

- [x] 프로젝트 스캐폴딩 (의존성, application.yaml, gitignore)
- [x] 스키마 정의 (`docs/schema.sql`, 배지 마스터 시드 9건 포함)
- [x] 공통 응답/에러 처리 (`ApiResponse`, `ErrorCode`, `GlobalExceptionHandler`)
- [x] JPA 엔티티 6종 + Repository (User, Challenge, Amount, MediaFile, Badge, UserBadge)
- [x] Spring Security + OAuth2 (Google/Kakao/Naver) + 사용자 자동 프로비저닝
- [x] User/Challenge/Amount/Media/Badge REST API
- [x] 영상 업로드 (지출 시 필수, 무지출 시 선택), 다운로드/스트리밍 엔드포인트
- [x] 배지 자동 지급 — 이벤트 트리거 + 매일 새벽 1시 배치 재검증
- [x] 챌린지 결과 내보내기 (JSON: 일별/카테고리별 집계)
- [x] Swagger UI (`/swagger-ui.html`)
- [x] `./gradlew.bat compileJava` 통과 확인 (런타임은 아직 미검증)

## 남은 일 (우선순위 순)

### 1. OAuth2 키 발급 후 실제 로그인 흐름 검증
- 세 공급자 모두에서 콜백 → 사용자 자동 생성 → 세션 유지 → `GET /api/users/me` 200 확인.
- 각 공급자 응답 포맷이 다르므로 `OAuth2UserInfoFactory`에서 NPE 안 나는지 실데이터로 점검 (특히 Kakao `kakao_account.profile.nickname`이 동의 항목에서 빠지면 null).

### 2. 챌린지 → 지출(영상 업로드) → 배지 흐름 E2E
- multipart 요청 형식: `request`(application/json) + `video`(video/*) part 2개. Swagger UI에서 직접 시도 가능.
- 무지출 기록만 4일 연속 → `NO_SPEND` condition_value=3 배지 자동 지급되는지.
- 챌린지 종료 후 `POST /finalize` → `CHALLENGE_SUCCESS` 배지 지급되는지.

### 3. 통합 테스트 작성 (현재 없음)
- 도메인별 `@SpringBootTest` 시나리오 테스트가 0개. 최소한 다음 4개는 빠르게 추가하면 좋음:
  - `ChallengeServiceTest` — 7일 초과/역순 기간 검증, finalize SUCCESS/FAIL 분기
  - `AmountServiceTest` — 지출 시 영상 누락 → `AMOUNT_VIDEO_REQUIRED`, 무지출 시 영상 없어도 통과
  - `BadgeGrantServiceTest` — `consecutiveStreakEndingOn` 경계값 (오늘 미기록·어제까지 연속 케이스 등)
  - `OAuth2UserInfoFactoryTest` — 공급자별 attribute 파싱

### 4. 페이지네이션 / 정렬
- `/api/challenges`, `/api/challenges/{id}/amounts`가 전체 목록 반환 중. `Pageable` 도입 시점 결정.

### 5. 운영 고려사항 (필요해지면)
- 영상 저장소를 S3/MinIO로 옮기는 경우: `LocalFileStorage`를 인터페이스로 추출 후 구현체 분리.
- 영상 워터마크(날짜·잔액 오버레이) 기능 — 이번 범위 제외했지만 추후 FFmpeg 도입 시 별도 서비스 분리 권장.
- `open-in-view: false`로 인해 컨트롤러에서 lazy 컬렉션 접근 금지. DTO 변환을 서비스 안에서 끝낼 것.

## 알려진 주의사항 / 함정

- **DDL과 엔티티가 어긋나면 부팅 실패** (`ddl-auto=validate`). 컬럼·인덱스 추가 시 `docs/schema.sql`도 같이 수정 후 DB에 적용해야 함.
- **`BadgeGrantService.consecutiveStreakEndingOn`은 "오늘 기록이 없으면 어제 기준"** 까지만 봐줌. 이틀 이상 비면 streak=0. 의도된 동작.
- **`AuthenticationPrincipal(expression="userId")`** 가 비인증 요청에서는 null. SecurityConfig가 `permitAll` 외 전부 차단하므로 컨트롤러에 도달하면 null 일 일 없지만, 새 permitAll 경로 추가할 때 주의.
- **세션은 default 인메모리 저장소**. 서버 재시작 시 모든 로그인 풀림. 운영 가면 Redis 등 외부 세션 저장소 필요.

## 옮겨야 하는 비-git 자산

- OAuth2 client_id/secret 6개 (Google/Kakao/Naver × id, secret)
- DB 비밀번호
- (선택) MariaDB 데이터 — 새 환경에서 `schema.sql` 다시 적용해도 무방하면 불필요
- (선택) `./uploads/` 디렉토리 — 이번 머신 영상이 필요 없으면 무시
