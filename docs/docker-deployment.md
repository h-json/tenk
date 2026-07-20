# Tenk 백엔드 — Docker 배포 문서

> tenk 백엔드가 맥 서버에 어떻게 떠 있는지, 업데이트·재부팅·문제해결을 어떻게 하는지에 대한 **배포 운영 런북**.
>
> 배포 완료 2026-06-30.
> **갱신 규칙**: 배포 구성/명령/좌표가 바뀌면 **같은 턴에 이 문서도 갱신**할 것. 일시적 진행상태가 아니라 영구 규칙·구조·런북을 담는다.

---

## 1. 지금 상태 (한눈에)

- ✅ **tenk 백엔드가 M1 맥미니에 컨테이너로 LIVE.** "윈도우 빌드 → Docker Hub → 맥 pull"(경로 B) 완주.
- ✅ **재부팅 생존 검증 완료** (2026-07-01): Colima autostart(`brew services`) + 자동 로그인 + compose restart policy. 실제 `sudo reboot` 후 무인으로 backend 복귀 확인.
- ✅ **외부 어디서나 접속 + HTTPS LIVE** (2026-07-01): 리버스 프록시(Traefik `v3.6.1`) + Let's Encrypt prod 인증서로 `https://tenk.hjson248.com` 폰(LTE)·PC 접속 확인. **리버스 프록시는 tenk 와 분리된 공유 엣지라 별도 리포 `reverse-proxy` 에서 관리**(맥 `~/Documents/projects/claude/reverse-proxy/`). **주의 요함(mixed content) 해결**: 스프링부트가 Traefik 의 `X-Forwarded-Proto=https` 를 신뢰하도록 `server.forward-headers-strategy=framework` 적용 — 안 하면 springdoc 이 `http://` 서버 URL 을 만들어 HTTPS 페이지가 "주의 요함". tenk 붙는 법·앱 설정은 §9, 엣지 상세는 `reverse-proxy` 리포 README.

---

## 2. 배포 아키텍처

```
[윈도우 개발머신 · amd64]
  Dockerfile (멀티스테이지, build 단계 FROM --platform=$BUILDPLATFORM)
  └─ docker buildx build --platform linux/arm64 -t hjson248/tenk:latest --push .
        │  (jar는 아키텍처 중립 → build는 윈도우 네이티브로 빠르게, 런타임만 arm64)
        ▼
     Docker Hub : hjson248/tenk:latest (arm64)
        │  pull
        ▼
[M1 맥미니 · arm64 = 서버]  Colima(리눅스 VM + dockerd)
  ~/Documents/projects/claude/tenk/docker-compose.yml
    ├─ backend (hjson248/tenk:latest)  ─ :8080
    └─ db (mariadb:11) + schema.sql 자동적용 + named volume
```

**왜 이렇게:** 윈도우 빌드 → 맥 pull만(맥엔 소스·빌드도구 없이 clean 유지). arm64는 M1 Colima VM용 — build 단계만 `$BUILDPLATFORM`으로 윈도우 네이티브, 런타임만 arm64(QEMU 회피). 엔진은 Colima(Docker Desktop 아님, 무료·헤드리스, 내부는 동일 `dockerd`).

---

## 3. 배포 파일 (리포)

| 파일 | 역할 |
|---|---|
| [tenk-backend/Dockerfile](../tenk-backend/Dockerfile) | 멀티스테이지. ①JDK+Gradle로 `bootJar`, ②JRE+jar 실행. build 단계 `--platform=$BUILDPLATFORM`. |
| [tenk-backend/.dockerignore](../tenk-backend/.dockerignore) | build context 제외 목록(build/, .gradle/, uploads/, .git/ 등). |
| [deploy/docker-compose.yml](../deploy/docker-compose.yml) | backend + mariadb:11. `name: tenk`. DB 시크릿은 `.env` 주입, `SPRING_DATASOURCE_*` env가 prod yaml의 TODO를 덮음. `schema.sql`은 **`dbinit` named volume에 시딩**돼 첫 기동 자동적용(`~/Documents`는 TCC로 bind mount 불가 — §6·§10.6). db/uploads/dbinit named volume. |
| [deploy/.env.example](../deploy/.env.example) | `DB_PASSWORD`/`DB_ROOT_PASSWORD` 템플릿. 실제 `.env`는 gitignore. |

**맥(`~/Documents/projects/claude/tenk/`)에 두는 것 = 배포 설정 3개뿐**: `docker-compose.yml` + `schema.sql`(=`docs/schema.sql` 복사) + `.env`. **소스코드는 안 둠.**

---

## 4. 핵심 좌표·값

- **Docker Hub**: username `hjson248`, 이미지 `hjson248/tenk:latest`. CLI 로그인은 **PAT**로(구글 로그인 계정이라 비번 없음 → Personal Access Token, Read & Write).
- **맥 서버**: `sonhuijun@sonhuijun-ui-Macmini`, 배포 폴더 `~/Documents/projects/claude/tenk/`. Colima VM = 2cpu / 4GB.
- **prod 설정**: `SPRING_PROFILES_ACTIVE=prod`. DB url/user/pw는 compose env로 주입. JWT secret은 `application-prod.yaml`에 박혀 이미지에 구워짐(private repo 전제).

---

## 5. 런북

### 5.1 코드 고친 뒤 재배포 (업데이트 사이클)
```powershell
# ① 윈도우 (tenk-backend/ 에서) — 다시 빌드 & push
docker buildx build --platform linux/arm64 -t hjson248/tenk:latest --push .
```
```bash
# ② 맥 (~/Documents/projects/claude/tenk/ 에서) — 새 이미지 받아 backend만 교체 (db는 유지)
docker compose pull && docker compose up -d
# ③ 확인
curl -s http://localhost:8080/v3/api-docs | head -c 200      # OpenAPI JSON
curl -i http://localhost:8080/api/challenges                 # 401 envelope = 정상
```

### 5.2 재부팅 생존
- **Colima 자동 시작**: `brew services start colima` (LaunchAgent 등록 → 로그인 시 자동 `colima start`). `brew services list`에 `started`.
  - 수동 colima와 충돌해 `stopped`로 뜨면: `colima stop` 후 `brew services restart colima`.
- **무인 부팅**: LaunchAgent는 *로그인* 시 떠서, 헤드리스 서버는 **자동 로그인**(시스템 설정 → 사용자 및 그룹)도 켜야 부팅만으로 복귀. (트레이드오프: 물리 접근자가 바로 세션 진입 — 집/사무실 서버면 통상 허용.)
- **컨테이너**: compose `restart: unless-stopped`로 데몬 복귀 시 자동 재기동(실측 확인). **DB/uploads는 named volume(Colima VM 디스크)에 보존**.
- **테스트**: `sudo reboot` → 1~2분 후 SSH 재접속 → `docker compose ps` / `curl`. **(2026-07-01 실측: 무인 복귀 OK.)**

### 5.3 자주 쓰는 명령 (맥, `~/Documents/projects/claude/tenk/`)
```bash
docker compose ps            # 컨테이너 상태
docker compose logs -f backend
colima status                # VM 상태
brew services list           # colima autostart 등록 상태
```

### 5.4 첫 부팅 셋업 (새 맥에서 처음부터 할 때)
```bash
brew install colima docker docker-compose
# docker compose 플러그인 연결 (안 되어 있으면)
mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose
colima start --cpu 2 --memory 4

# ── 공유 네트워크 (reverse-proxy·tenk 두 스택이 external 로 참조) ──
docker network create web

# ── named volume 시딩 (⚠️ 첫 up 전에 필수) ──
#  ~/Documents 밑은 macOS TCC 로 bind mount 불가라 런타임 파일을 named volume 에 둔다(§6·§10.6).
#  bind mount 와 달리 named volume 은 자동으로 안 채워지므로 미리 시딩해야 한다.
#  tenk_dbinit: 비어 있으면 DB 가 빈 채로 떠 ddl-auto=validate 가 실패한다.
docker volume create tenk_dbinit
docker run -d --name seed -v tenk_dbinit:/data alpine sleep 60
docker cp <schema.sql 경로> seed:/data/01-schema.sql   # docker cp 는 API 스트리밍이라 ~/Documents 도 TCC 안 막힘
docker rm -f seed
#  traefik_letsencrypt: 비어 있으면 Traefik 이 새 인증서를 자동 발급하므로 시딩 불필요.
#  (기존 인증서를 복원할 때만 acme.json 을 같은 docker cp 방식으로 넣고 chmod 600.)

# ── 두 스택 기동 (배포 파일 scp 복사 후) ──
#  reverse-proxy 스택은 별도 리포에서 옴 — 호스트/엣지 최초 셋업 상세는 그 리포 README §6.
cd ~/Documents/projects/claude/reverse-proxy && docker compose up -d
cd ~/Documents/projects/claude/tenk && cp .env.example .env   # 비밀번호 채우기
docker compose up -d
```

### 5.5 라이브 DB 스키마 변경 (⚠️ dbinit 는 최초 부팅에만 적용됨)
`tenk_dbinit` 볼륨의 `01-schema.sql` 은 **DB 데이터 디렉토리가 비어 있는 첫 기동에만** 실행된다. 즉 **이미 떠서 데이터가 있는 라이브 DB 에는 `docs/schema.sql` 을 고쳐도 반영되지 않는다** (`ddl-auto=validate` 라 엔티티/컬럼을 바꾸면 스키마도 맞춰야 부팅됨). 라이브 DB 에는 **컨테이너 안에서 직접 `ALTER` 를 쳐야** 한다:
```bash
cd ~/Documents/projects/claude/tenk
set -a; . ./.env; set +a
docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" tenk \
  -e "ALTER TABLE \`user\` MODIFY \`provider\` ENUM('GOOGLE','KAKAO','NAVER','TEST') NOT NULL;"   # 예시
```
- 리포 `docs/schema.sql` + 맥 `dbinit` 볼륨의 `01-schema.sql` **양쪽도 같이 갱신**해야 다음 클린 재구축 때 어긋나지 않는다.
- enum 값을 **끝에 추가**하는 ALTER 는 메타데이터만 바뀌어 즉시·무손실. 컬럼 추가/타입 변경은 데이터·다운타임 영향 검토 후.
- 실적용 사례:
  - 2026-07-11 `provider` ENUM 에 `TEST` 추가(devtools 테스트 계정용).
  - 2026-07-20 `user` 에 필수 동의 컬럼 2개 추가(이용약관/개인정보 동의 시각). **컬럼 추가라 순서가 중요** — 새 backend 는 `ddl-auto=validate` 라 컬럼 없이 뜨면 부팅 실패하므로 **ALTER 를 먼저 치고 그다음 `pull && up -d`**:
    ```bash
    docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" tenk \
      -e "ALTER TABLE \`user\` ADD COLUMN \`terms_agreed_dt\` DATETIME NULL AFTER \`nickname_changed_dt\`, ADD COLUMN \`privacy_agreed_dt\` DATETIME NULL AFTER \`terms_agreed_dt\`;"
    ```
    `dbinit` 볼륨 시드(`01-schema.sql`)도 새 `docs/schema.sql` 로 갱신 완료(§5.4 시딩 방식) — 안 하면 **클린 재구축 때만** 컬럼 없이 생성돼 부팅 실패한다(라이브 DB 는 ALTER 로 이미 반영).

---

## 6. 트러블슈팅 (실제로 겪은 것)

| 증상 | 원인·해결 |
|---|---|
| `docker compose` → unknown command | brew의 compose v2를 docker CLI가 못 찾음 → §5.4의 `ln` 심링크. |
| `docker`가 `/var/run/docker.sock` 못 찾음 | 활성 context가 `default`로 튕김 → `docker context use colima` (한 번, `~/.docker`에 영구 저장). |
| `/v3/api-docs` 500 (`NoSuchMethodError: ControllerAdviceBean.<init>`) | springdoc 2.6.0은 Spring Boot 3용. Spring Boot 4=Spring Framework 7엔 **springdoc 3.0.x**. → `build.gradle` `3.0.3`로 올림(완료). |
| 로그 `Using generated security password` 경고 | stateless JWT + 커스텀 SecurityConfig라 그 기본 유저는 안 쓰임. **무해**(로컬과 동일). |
| Traefik 로그 `client version 1.24 is too old` / 라우팅 안 잡힘 | **엣지(리버스 프록시) 소관** — Docker 29 API 버전 문제. `reverse-proxy` 리포 README §5 참고(요약: Traefik `v3.6.1`+ 로 해결). |
| 컨테이너가 `Created` 에서 멈추고 `error while creating mount source path ... mkdir /Users/…/Documents: operation not permitted` | **macOS TCC(프라이버시)가 `~/Documents`·Desktop·Downloads 를 보호**해 Colima VM(virtiofs)이 그 하위 경로를 bind mount 못 함(홈 루트 `~/` 밑은 됨). compose 파일 자체는 호스트가 읽어 어디 둬도 되지만 **compose 안 상대경로 bind mount 가 전부 막힌다**. → 런타임 파일을 **named volume** 으로 전환(폴더 위치 무관). 시딩은 §5.4, 전말은 §10.6. |

---

## 7. 다음 단계

- [x] **폰 접속 방향 결정 (2026-07-01)** — **(나) 외부 어디서나 + HTTPS** 로 결정. 리버스 프록시는 **Traefik**. 근거·아키텍처 §9.
- [x] **리버스 프록시 + 자동 HTTPS 구축 (2026-07-01 완료)** — 공유 엣지(Traefik)로 `https://tenk.hjson248.com` LE prod 인증서. `forward-headers-strategy` 로 mixed content("주의 요함")까지 해결. **엣지는 별도 리포 `reverse-proxy` 로 분리.** tenk 붙는 법 §9, 엣지 상세 그 리포 README.
- [x] 자동 로그인 + `sudo reboot` 최종 생존 테스트 — **완료(2026-07-01), 무인 복귀 확인.**
- [x] **개인정보처리방침 배포 (2026-07-07 LIVE)** — [privacy.html](../tenk-backend/src/main/resources/static/privacy.html)(jar static) 재배포로 `https://tenk.hjson248.com/privacy.html` 서빙·브라우저 확인. Play Console 처리방침 URL 이 이 주소.
- [x] **회원 탈퇴 hard-delete (2026-07-07 배포)** — soft delete + 3개월 보관 후 새벽 배치 물리 삭제. 상세는 [handoff.md](handoff.md) "운영 고려사항".
- [x] **필수 동의 플로우 배포 (2026-07-20)** — 이용약관(`terms.html`) static 추가 + 동의 기록 컬럼/엔드포인트. 라이브 DB ALTER(§5.5) + 이미지 재배포 + `dbinit` 시드 갱신까지 완료. 검증: `https://tenk.hjson248.com/terms.html` → 200(무인증), prod api-docs 에 `/api/users/me/consent`·`consentRequired` 노출. 규칙은 [../CLAUDE.md](../CLAUDE.md) "인증 — 필수 동의".
- [x] **서버 타임존 KST 고정 (2026-07-13 배포)** — 컨테이너 기본 UTC 라 `LocalDate.now()` 가 한국 자정~오전 9시 사이 전날로 잡혀 "오늘 시작" 챌린지가 "시작 전" 으로 보이던 버그(7/11 제보) 해결. 두 겹 고정: [TenkApplication](../tenk-backend/src/main/java/com/hjson/tenk/TenkApplication.java) `TimeZone.setDefault` (이미지 재빌드로 반영) + [docker-compose.yml](../deploy/docker-compose.yml) backend `TZ: Asia/Seoul` env (맥 compose 복사본 갱신 → `up -d`). 검증: `docker compose exec backend date` → KST. 커밋 `f30d358`.

## 8. 기술 사실

- 백엔드: Spring Boot **4.0.6** / Java 21 / Gradle wrapper. 산출물 `build/libs/tenk-0.0.1-SNAPSHOT.jar`.
- 빌드 시 **테스트 제외** 필수 → `bootJar`만(`build` 아님). 통합테스트가 실제 MariaDB를 요구해 빌드 컨테이너에선 못 돎.
- DB는 컨테이너(`mariadb:11`). 맥 1대 self-host라 컨테이너 DB가 합리적. `ddl-auto=validate`라 schema.sql 선적용 필수 → compose가 init 스크립트로 자동 처리.

---

## 9. 외부 접속 + HTTPS (LIVE) — 리버스 프록시는 별도 리포

`https://tenk.hjson248.com` 외부 접속 + 자동 TLS **LIVE**(2026-07-01). 리버스 프록시(공유 엣지)는 독립 인프라라 **별도 리포 `reverse-proxy`** 에서 관리(맥은 그 리포를 git clone). **엣지 아키텍처·DNS/포트포워딩·ACME·Traefik 함정·인증서 재발급은 그 리포 README 가 진실의 원천.** 여기엔 tenk 가 엣지에 붙는 법 + 앱-레벨 설정만 남긴다.

### 9.1 tenk 가 엣지에 붙는 법 (이 리포의 책임 범위)
- backend 를 `web`(엣지 공유) + `internal`(db 전용) **두 네트워크**에 둔다. db 는 `internal` 에만 둬 외부/엣지와 격리.
- backend 에 라우팅 라벨 선언([deploy/docker-compose.yml](../deploy/docker-compose.yml)):
  ```
  traefik.enable=true
  traefik.http.routers.tenk.rule=Host(`tenk.hjson248.com`)
  traefik.http.routers.tenk.entrypoints=websecure
  traefik.http.routers.tenk.tls.certresolver=le
  traefik.http.services.tenk.loadbalancer.server.port=8080
  traefik.docker.network=web
  ```
- `web` 네트워크는 **엣지 스택이 만들고 소유**(`docker network create web`) — tenk 는 join 만. `8080:8080` 퍼블리시는 맥 로컬 헬스체크 전용(인터넷 미노출). 새 서브도메인이면 A레코드(→ 맥 공인 IP)만 추가하면 Traefik 이 자동 발급.

### 9.2 앱-레벨 HTTPS 설정 — mixed content("주의 요함") 해결
- ✅ **`server.forward-headers-strategy=framework`**: 증상은 인증서는 "유효함" 인데 크롬이 "주의 요함". 원인은 스프링부트가 Traefik 뒤에서 `X-Forwarded-Proto=https` 를 안 믿어 springdoc 이 Swagger `Servers` URL 을 `http://tenk.hjson248.com` 로 생성 → HTTPS 페이지 안 http 참조 = mixed content. TLS 종단이 프록시라 **프록시-뒤 앱의 공통 함정** — 해결은 앱 몫(엣지는 헤더만 부착). 적용 2곳: [application-prod.yaml](../tenk-backend/src/main/resources/application-prod.yaml) `server.forward-headers-strategy: framework`(소스 오브 트루스, 다음 이미지 빌드에 반영) + [deploy/docker-compose.yml](../deploy/docker-compose.yml) `SERVER_FORWARD_HEADERS_STRATEGY=framework` env(**이미지 재빌드 없이** `docker compose up -d` 로 즉시 적용). 검증: `curl -s --resolve tenk.hjson248.com:443:127.0.0.1 https://tenk.hjson248.com/v3/api-docs | grep -oE 'https?://tenk[^"]*'` → `https://tenk.hjson248.com`.
  - **함정 — 맥에서 자기 도메인 curl 이 `status=000`**: 공유기 NAT 헤어핀 미지원이라 맥이 자기 공인 IP 로 loopback 을 못 한다. 실사용자(폰 LTE/외부)는 정상. 맥 로컬 검증은 `--resolve tenk.hjson248.com:443:127.0.0.1` 로 Traefik 을 직접 때려 우회.

### 9.3 Flutter base URL 전환 (완료 2026-07-02)
- ✅ [.vscode/launch.json](../.vscode/launch.json) `tenk_app (device)` 의 `--dart-define=API_BASE_URL` 을 `https://tenk.hjson248.com` 로 전환. [network_security_config.xml](../tenk_app/android/app/src/main/res/xml/network_security_config.xml) 의 LAN IP(`192.168.0.7`) cleartext 예외 줄 제거 — 실기기가 HTTPS 로 붙어 cleartext 불필요. `tenk_app (emulator)` 는 그대로 `http://10.0.2.2:8080`(로컬 개발용) 유지. 로컬 백엔드를 실기기로 테스트할 때만 해당 PC LAN IP 를 두 파일에 다시 추가.

---

## 10. 맥에서 Claude Code 로 운영하기 (operator orientation)

> 이 맥미니(`sonhuijun-ui-Macmini`)가 **tenk 운영 서버 그 자체**다. 여기서 도는 Claude Code 는
> 윈도우 세션과 달리 **docker 명령을 사람 손 거치지 않고 직접 실행**할 수 있다. 이 절은 맥 Claude Code 가
> 배포를 이어받을 때의 오리엔테이션이고, **실제 런북·아키텍처·함정은 이 문서 §1~§9 가 진실의 원천**이다.

### 10.1 전제 — 맥 = 서버, 리포 = 소스
- 맥 Claude Code 는 `docker compose ...`(tenk·reverse-proxy 폴더) · `colima ...` · `docker ...` 를 직접 실행 — 상태 확인·재배포·로그·재기동 즉시 수행.
- **리포 `deploy/` 가 소스 오브 트루스, 맥 폴더는 복사본.** 바꿀 땐 리포에서 고치고 → 맥 복사 → `up -d`. 맥 파일 직접 수정 금지(드리프트 — 급하면 리포 역반영).

### 10.2 맥 로컬 레이아웃 (비-git, 머신 고유)
```
~/Documents/projects/claude/
├─ tenk/            # 리포 deploy/ 복사본: docker-compose.yml(name:tenk) · schema.sql(=docs/schema.sql, dbinit 시드) · .env(커밋 금지)
└─ reverse-proxy/   # 공유 엣지 (★ 별도 리포 clone — tenk 소관 아님, name:traefik)
```
- **런타임 파일은 named volume**(폴더가 `~/Documents` 밑이라 TCC bind mount 불가 — §10.6): `tenk_db-data`·`tenk_uploads`·`tenk_dbinit`·`traefik_letsencrypt`. 백업은 `docker cp`.
- 두 스택은 external 네트워크 `web` 로 연결(`docker network create web` 1회, §9). 이미지 소스는 맥에 없음(§2) → 코드 재배포는 §10.4.

### 10.3 첫 진입 루틴 (상태부터 확인)
```bash
docker compose -f ~/Documents/projects/claude/tenk/docker-compose.yml ps        # backend/db 상태
docker compose -f ~/Documents/projects/claude/reverse-proxy/docker-compose.yml ps     # traefik 상태
colima status && docker context show                  # VM·컨텍스트(=colima)
curl -s --resolve tenk.hjson248.com:443:127.0.0.1 https://tenk.hjson248.com/v3/api-docs | grep -oE 'https?://tenk[^"]*'
```
기대값: 컨테이너 3개 Up, 마지막 curl 이 `https://tenk.hjson248.com`. 어긋나면 §6 / §9.

### 10.4 자주 하는 운영 (상세는 §5·§9)
- **설정만 바뀜**(compose/env/schema): 리포 수정 → 맥 복사 → `docker compose up -d`. 이미지 재빌드 불필요.
- **코드 바뀜**: 윈도우 `docker buildx ... --push`(§5.1) → 맥 `docker compose pull && docker compose up -d`. (맥엔 소스 없어 빌드는 윈도우 담당.)
- **로그/재기동**: `docker compose logs -f backend|traefik`, `docker compose restart <svc>`. 인증서/엣지는 `reverse-proxy` 리포 소관.

### 10.5 맥에 둘 것 — 배포 설정만, 앱 소스는 안 둔다
- **모노레포 통째 클론 금지** — 서버에 앱 소스가 올라가면 clean-server 원칙(§2)이 깨진다. 맥엔 배포 설정(§10.2)만.
- 맥 Claude Code 컨텍스트용으로 **이 런북 한 파일만 복사**(예: `~/Documents/projects/claude/tenk/RUNBOOK.md`). 소스-상대 링크는 안 열려도 명령·아키텍처·함정 본문은 유효.
- 킥오프: *"이 맥에서 tenk 를 운영해. `RUNBOOK.md` §10 읽고 §10.3 으로 배포 상태 확인 후 이어서 도와줘. 서버엔 앱 소스 없고 배포 설정만 있다."*
- 설정 버전관리 원하면(선택): 별도 `tenk-deploy` 리포 또는 `deploy/` sparse-checkout.

### 10.6 함정·결정 — `~/Documents` TCC bind mount 실패 → named volume 전환 (2026-07-01)
배포 폴더를 홈 루트에서 `~/Documents/projects/claude/` 밑(`tenk/`·`reverse-proxy/`)으로 옮겼더니 두 스택이 다 안 떴다. 컨테이너가 `Created` 에서 멈추고:
```
error while creating mount source path '.../Documents/.../letsencrypt':
mkdir /Users/sonhuijun/Documents: operation not permitted
```
- **원인**: macOS **TCC(프라이버시 보호)**가 `~/Documents`(·Desktop·Downloads)를 보호해 Colima VM(virtiofs)이 그 하위를 **bind mount 못 한다**. 실측: 홈 루트(`~/`) 밑 bind mount 는 성공, `~/Documents` 밑은 실패. compose 파일 자체는 호스트가 읽어 위치 무관이지만 **compose 안 상대경로 bind mount(`./schema.sql`, `./letsencrypt`)가 전부 막힌다**.
- **결정**: 런타임 파일을 **named volume 으로 전환**(폴더 위치와 무관). 기존 prod 인증서·스키마는 볼륨에 **시딩해 무손실 보존**(재발급/재초기화 없음). 전환 매핑:
  - `./schema.sql:/docker-entrypoint-initdb.d/...` → named volume **`dbinit`** (schema.sql 을 `01-schema.sql` 로 시딩)
  - `./letsencrypt:/letsencrypt` → named volume **`letsencrypt`**(=`traefik_letsencrypt`)
- **함정**: bind mount 는 자동으로 채워지지만 **named volume 은 비어 있으면 안 채워진다** → 새/클린 배포는 **첫 `up` 전 시딩 필수**(§5.4). `docker cp` 는 호스트 파일을 API 로 스트리밍하므로 `~/Documents` 라도 TCC 에 안 막힌다.
- **대안(안 택함)**: 폴더를 홈 루트로 되돌리기(TCC 우회되지만 "프로젝트는 Documents 밑" 정리 원칙과 충돌) / colima 에 `~/Documents` full-disk-access 부여(머신별 수동 설정이라 재현성 낮음). named volume 이 위치 독립적이라 가장 견고.
