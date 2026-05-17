# Manwon — Claude 작업 가이드

이 문서는 새 세션이 시작될 때 Claude가 자동으로 읽는 프로젝트 컨텍스트야.
다른 컴퓨터에서 작업을 이어갈 때 가장 먼저 이 파일을 참고할 것.

---

## 프로젝트 개요

- **서비스 컨셉**: "만원 챌린지" — 짧은 영상으로 지출/무지출을 기록하고, 챌린지 기간(최대 7일) 내 목표 금액 안에서 소비하기.
- **현재 단계**: 백엔드 REST API 골격 1차 구현 완료. OAuth2 키·DB 연동·통합테스트는 미수행.

## 기술 스택

| 영역 | 선택 |
|---|---|
| 언어/런타임 | Java 21 |
| 프레임워크 | Spring Boot 4.0.6 |
| 영속성 | Spring Data JPA + MariaDB |
| 보안 | Spring Security + OAuth2 Client (Google / Kakao / Naver) |
| 인증 방식 | OAuth2 세션 기반 (JWT 아님) |
| 마이그레이션 | **JPA `ddl-auto=validate` + `docs/schema.sql` 수동 적용** (Flyway 등 미사용) |
| 파일 저장 | 로컬 파일 시스템 (`./uploads/`, gitignore) |
| API 문서 | springdoc-openapi (`/swagger-ui.html`) |
| 빌드 | Gradle Wrapper |

## 도메인 규칙 (의사결정 합의)

### 인증
- OAuth2 3사: `GOOGLE`, `KAKAO`, `NAVER`. ID/비밀번호 자체 로그인 없음.
- `user.password` 컬럼은 **제거**, 대신 `provider`, `provider_user_id`, `email`을 사용. `(provider, provider_user_id)`가 unique.
- 신규 사용자는 OAuth 콜백 시 자동 프로비저닝.

### 영상
- "저화질·2초" 변환은 **클라이언트 책임**. 백엔드는 업로드받은 파일을 그대로 저장.
- 저장소는 로컬 파일 시스템 (`manwon.upload.base-dir`, 기본 `./uploads`). `.gitignore`에 등록됨.

### 챌린지
- 한 사용자가 **여러 챌린지 동시 진행 가능**.
- 기간은 자유 선택, **최대 7일**. 엔티티 생성 시 검증(`Challenge.MAX_DURATION_DAYS`).
- 종료 시점에 `result` 컬럼 확정: `SUCCESS`(총지출 ≤ target_amount) / `FAIL`. `NULL`이면 진행 중.
- 확정 트리거는 ① 사용자 호출(`POST /api/challenges/{id}/finalize`) ② 매일 새벽 1시 배치(`BadgeScheduler.dailyReconciliation`) 두 가지.

### 지출(amount)
- **지출 기록**: `category`, `content` NOT BLANK, `amount > 0`, **영상 1개 필수**.
- **무지출 기록**: `is_no_spend = true`, `amount = 0`, `category/content` NULL 허용, **영상 선택**.
- `created_dt`가 곧 "지출/기록 발생일". 별도 `spent_date` 컬럼 없음.

### 배지
- 단계: `condition_value` = **3 / 7 / 14 / 30**.
- `STREAK`: 매일(지출 또는 무지출 무관) 기록한 **연속 일수**.
- `NO_SPEND`: 그날 기록이 **무지출만** 있는 날의 연속 일수. 같은 날 지출 기록이 끼면 끊김.
- `CHALLENGE_SUCCESS`: `condition_value = 1` 1개만 존재, 챌린지 성공 시 1회 지급.
- **지급 트리거 2종**: 
  - 이벤트: `AmountRecordedEvent`(지출/무지출 기록 후), `ChallengeFinishedEvent`(챌린지 확정 후) — `BadgeEventListener`에서 `AFTER_COMMIT` 처리
  - 배치: 매일 새벽 1시 전체 사용자 재평가 (이벤트 누락 대비)

### 내보내기
- **영상 내보내기(워터마크/오버레이)는 이번 범위에서 제외.**
- 챌린지 결과는 **JSON 반환**만 함 (`GET /api/challenges/{id}/export`). 화면 구성은 클라이언트 몫.

## 패키지 구조

```
com.hjson.manwon
├── ManwonApplication.java          # @EnableScheduling, @ConfigurationPropertiesScan
├── common
│   ├── api/ApiResponse.java        # 공통 응답 포맷 {success, data, error}
│   ├── config/                     # JpaAuditing, OpenApi, *Properties
│   └── exception/                  # ErrorCode, BusinessException, GlobalExceptionHandler
├── security/                       # SecurityConfig + OAuth2 사용자 처리 + @CurrentUserId
└── domain
    ├── user/        (entity, repo, service, controller, dto/, AuthProvider)
    ├── challenge/   (+ ChallengeExportService, event/ChallengeFinishedEvent)
    ├── amount/      (+ event/AmountRecordedEvent)
    ├── media/       (MediaFile, LocalFileStorage, MediaController)
    └── badge/       (Badge, UserBadge, BadgeGrantService, BadgeEventListener, BadgeScheduler)
```

## 코딩 컨벤션

- **컨트롤러는 얇게**, 비즈니스 로직은 서비스에. 엔티티는 정적 팩토리 메서드로 생성하고 invariant 검증.
- **에러는 `BusinessException(ErrorCode.XXX)`로 던지기.** 새 케이스는 `ErrorCode` enum에 추가. 메시지는 한국어.
- **DTO는 record로**. 요청 DTO는 Bean Validation 어노테이션 사용.
- **트랜잭션**: 서비스 클래스는 기본 `@Transactional(readOnly = true)`, 쓰기 메서드만 `@Transactional`.
- **사용자 ID 주입**: 컨트롤러 파라미터에 `@CurrentUserId Long userId` 사용. (내부적으로 `@AuthenticationPrincipal(expression="userId")`)
- **댓글은 최소화.** "왜"가 비자명할 때만 작성. JavaDoc은 정책 문서 역할일 때만 (예: `BadgeGrantService` 상단).
- **새 API를 만들 때**: `@Tag`, `@Operation` 어노테이션을 빠뜨리지 말 것 (Swagger).

## 로컬 실행 방법

```bash
# 1. DB 준비
mysql -u root -p
> CREATE DATABASE manwon DEFAULT CHARACTER SET utf8mb4;
> CREATE USER 'manwon'@'localhost' IDENTIFIED BY 'manwon';
> GRANT ALL ON manwon.* TO 'manwon'@'localhost';
# 또는 사용 중인 계정에 권한 부여

# 2. 스키마 적용 (ddl-auto=validate 이므로 필수)
mysql -u manwon -p manwon < docs/schema.sql

# 3. 환경변수 설정 (PowerShell)
$env:GOOGLE_CLIENT_ID = "..."
$env:GOOGLE_CLIENT_SECRET = "..."
$env:KAKAO_CLIENT_ID = "..."
$env:KAKAO_CLIENT_SECRET = "..."
$env:NAVER_CLIENT_ID = "..."
$env:NAVER_CLIENT_SECRET = "..."
$env:DB_USERNAME = "manwon"
$env:DB_PASSWORD = "manwon"

# 4. 실행
./gradlew.bat bootRun
# 브라우저: http://localhost:8080/swagger-ui.html
```

## 위치별 책임 (요약)

| 변경 위치 | 동시에 챙겨야 할 곳 |
|---|---|
| 엔티티 컬럼 추가 | `docs/schema.sql` 수동 동기화 (validate 모드라 안 맞으면 부팅 실패) |
| 새 도메인 추가 | 패키지 분리 (`domain/<name>/`), `ErrorCode`에 도메인 prefix 코드 추가 |
| 새 이벤트 추가 | `*Event` record는 도메인의 `event/` 하위에, 리스너는 소비자 도메인에 |
| OAuth2 공급자 추가 | `OAuth2UserInfoFactory`에 분기, `application.yaml` registration·provider 추가, `AuthProvider` enum 추가 |
| 파일 업로드 | 항상 `LocalFileStorage.store(file, subdir)`을 거치기. 경로를 직접 조립하지 말 것 |

## 미해결/다음 단계

진행 상태와 남은 작업은 [docs/handoff.md](docs/handoff.md) 참고.
