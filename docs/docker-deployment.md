# Tenk 백엔드 — Docker 배포 문서

> tenk 백엔드가 맥 서버에 어떻게 떠 있는지, 업데이트·재부팅·문제해결을 어떻게 하는지에 대한 **배포 운영 런북**.
>
> 배포 완료 2026-06-30.
> **갱신 규칙**: 배포 구성/명령/좌표가 바뀌면 **같은 턴에 이 문서도 갱신**할 것. 일시적 진행상태가 아니라 영구 규칙·구조·런북을 담는다.

---

## 1. 지금 상태 (한눈에)

- ✅ **tenk 백엔드가 M1 맥미니에 컨테이너로 LIVE.** "윈도우 빌드 → Docker Hub → 맥 pull"(경로 B) 완주.
- ✅ **재부팅 생존 검증 완료** (2026-07-01): Colima autostart(`brew services`) + 자동 로그인 + compose restart policy. 실제 `sudo reboot` 후 무인으로 backend 복귀 확인.
- ⏭ **다음 작업(진행 중)**: 폰에서 **외부 어디서나 접속 + HTTPS**. 경로 = **Traefik 리버스 프록시(포트포워딩 + Let's Encrypt 자동 TLS)**. 도메인·DNS·CGNAT·포트포워딩 전제 확인 완료. **Traefik 독립 스택(`~/traefik/`) 기동 성공** (2026-07-01, `v3.6.1` — Docker 29 API 버전 삽질 해결, §9.4 교훈). **남은 것**: tenk 스택에 라벨/네트워크 반영 → ACME staging 발급 검증 → prod 전환. 상세 §9.5.

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
  ~/tenk/docker-compose.yml
    ├─ backend (hjson248/tenk:latest)  ─ :8080
    └─ db (mariadb:11) + schema.sql 자동적용 + named volume
```

**왜 이렇게:**
- **윈도우에서 빌드 → 맥은 pull만**: 맥(prod 서버)에 소스·빌드도구를 안 둬서 서버를 깨끗하게 유지. 맥은 완성 이미지만 받아 실행.
- **arm64**: M1 맥의 Colima VM이 arm64라 arm64 이미지가 필요. Dockerfile build 단계는 `$BUILDPLATFORM`으로 윈도우 네이티브(amd64) 빌드 → jar는 중립 → 런타임 단계만 arm64로 받음 (QEMU 풀에뮬레이션 회피).
- **맥 엔진 = Colima** (Docker Desktop 아님): CLI·무료·헤드리스 서버에 적합. 내부적으로 도는 건 동일한 `dockerd`. 맥/윈도우는 리눅스 커널이 없어 도커가 가벼운 리눅스 VM을 띄워 그 위에서 컨테이너를 돌린다(윈도우=WSL2, 맥=Colima/Lima).

---

## 3. 배포 파일 (리포)

| 파일 | 역할 |
|---|---|
| [tenk-backend/Dockerfile](../tenk-backend/Dockerfile) | 멀티스테이지. ①JDK+Gradle로 `bootJar`, ②JRE+jar 실행. build 단계 `--platform=$BUILDPLATFORM`. |
| [tenk-backend/.dockerignore](../tenk-backend/.dockerignore) | build context 제외 목록(build/, .gradle/, uploads/, .git/ 등). |
| [deploy/docker-compose.yml](../deploy/docker-compose.yml) | backend + mariadb:11. DB 시크릿은 `.env` 주입, `SPRING_DATASOURCE_*` env가 prod yaml의 TODO를 덮음. `schema.sql`→`/docker-entrypoint-initdb.d`로 첫 기동 자동적용. uploads/db named volume. |
| [deploy/.env.example](../deploy/.env.example) | `DB_PASSWORD`/`DB_ROOT_PASSWORD` 템플릿. 실제 `.env`는 gitignore. |

**맥(`~/tenk/`)에 두는 것 = 배포 설정 3개뿐**: `docker-compose.yml` + `schema.sql`(=`docs/schema.sql` 복사) + `.env`. **소스코드는 안 둠.**

---

## 4. 핵심 좌표·값

- **Docker Hub**: username `hjson248`, 이미지 `hjson248/tenk:latest`. CLI 로그인은 **PAT**로(구글 로그인 계정이라 비번 없음 → Personal Access Token, Read & Write).
- **맥 서버**: `sonhuijun@sonhuijun-ui-Macmini`, 배포 폴더 `~/tenk/`. Colima VM = 2cpu / 4GB.
- **prod 설정**: `SPRING_PROFILES_ACTIVE=prod`. DB url/user/pw는 compose env로 주입. JWT secret은 `application-prod.yaml`에 박혀 이미지에 구워짐(private repo 전제).

---

## 5. 런북

### 5.1 코드 고친 뒤 재배포 (업데이트 사이클)
```powershell
# ① 윈도우 (tenk-backend/ 에서) — 다시 빌드 & push
docker buildx build --platform linux/arm64 -t hjson248/tenk:latest --push .
```
```bash
# ② 맥 (~/tenk/ 에서) — 새 이미지 받아 backend만 교체 (db는 유지)
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

### 5.3 자주 쓰는 명령 (맥, `~/tenk/`)
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
# 배포 파일 복사(scp) 후
cd ~/tenk && cp .env.example .env   # 비밀번호 채우기
docker compose up -d
```

---

## 6. 트러블슈팅 (실제로 겪은 것)

| 증상 | 원인·해결 |
|---|---|
| `docker compose` → unknown command | brew의 compose v2를 docker CLI가 못 찾음 → §5.4의 `ln` 심링크. |
| `docker`가 `/var/run/docker.sock` 못 찾음 | 활성 context가 `default`로 튕김 → `docker context use colima` (한 번, `~/.docker`에 영구 저장). |
| `/v3/api-docs` 500 (`NoSuchMethodError: ControllerAdviceBean.<init>`) | springdoc 2.6.0은 Spring Boot 3용. Spring Boot 4=Spring Framework 7엔 **springdoc 3.0.x**. → `build.gradle` `3.0.3`로 올림(완료). |
| 로그 `Using generated security password` 경고 | stateless JWT + 커스텀 SecurityConfig라 그 기본 유저는 안 쓰임. **무해**(로컬과 동일). |
| Traefik 로그 `client version 1.24 is too old` 무한 반복 + 라우팅 안 잡힘 | **Docker Engine 29.0(2025-11)이 최소 도커 API 를 1.44 로 올려** Traefik 3.6.1 미만의 옛 SDK(API 1.24)가 데몬에 거부당함(도커 프로바이더가 라벨을 못 읽음). → **Traefik 을 `v3.6.1`+ 로 올리면 해결**(자동 버전 협상 포함). Colima 는 Docker 29 계열이라 필수. **❌ 안 통한 우회들**: `DOCKER_API_VERSION=1.54` env(Traefik 이 안 읽음), docker-socket-proxy(요청 URL 의 `/v1.24/` 를 그대로 전달해 동일 거부). 상세 §9.4. |

---

## 7. 다음 단계

- [x] **폰 접속 방향 결정 (2026-07-01)** — **(나) 외부 어디서나 + HTTPS** 로 결정. 리버스 프록시는 **Traefik**. 근거·아키텍처 §9.
- [ ] **Traefik 리버스 프록시 + 자동 HTTPS 구축 (진행 중)** — §9 아키텍처대로 Traefik 독립 스택 → tenk 라벨 연결 → `https://tenk.hjson248.com` 검증.
- [x] 자동 로그인 + `sudo reboot` 최종 생존 테스트 — **완료(2026-07-01), 무인 복귀 확인.**
- 운영 향후(범위 밖): 회원 탈퇴 hard-delete cascade + 개인정보처리방침 → [handoff.md](handoff.md) "운영 고려사항".

## 8. 기술 사실

- 백엔드: Spring Boot **4.0.6** / Java 21 / Gradle wrapper. 산출물 `build/libs/tenk-0.0.1-SNAPSHOT.jar`.
- 빌드 시 **테스트 제외** 필수 → `bootJar`만(`build` 아님). 통합테스트가 실제 MariaDB를 요구해 빌드 컨테이너에선 못 돎.
- DB는 컨테이너(`mariadb:11`). 맥 1대 self-host라 컨테이너 DB가 합리적. `ddl-auto=validate`라 schema.sql 선적용 필수 → compose가 init 스크립트로 자동 처리.

---

## 9. 외부 접속 + HTTPS (진행 중) — Traefik 리버스 프록시

> 여기부터는 **결정·확인된 사실 + 목표 아키텍처**. 실제 구축은 진행 중.

### 9.1 결정 (2026-07-01)
- **폰에서 어디서나 접속 + HTTPS** 로 방향 확정. Wi-Fi 내부 접속안은 폐기 — 외부가 상위집합이라 별도로 안 함.
- **도달성(reachability)**: 공유기 **포트포워딩(80·443 → 맥)** 방식 채택(경로 A-1). Cloudflare Tunnel(A-2)은 포트포워딩이 이미 되어 있어 불필요 — 터널은 "인바운드를 못 여는 상황"의 우회책이라 이 케이스엔 안 맞음.
- **리버스 프록시 = Traefik.** Caddy·네이티브 nginx도 후보였으나, **"단일 맥에 여러 백엔드 앱을 계속 올린다"** 는 전제라 **라벨 기반 자동 발견 + 자동 TLS** 인 Traefik 선택. nginx(중앙 config 수동 편집 + certbot)·Caddy(중앙 Caddyfile) 대비 **앱 추가 마찰이 가장 적음**.
- **구조 원칙**: 리버스 프록시는 모든 앱 위에 걸치는 **공유 엣지**라 tenk 스택에 넣지 않는다(넣으면 tenk 재배포 시 다른 앱 트래픽까지 끊김). **독립 스택 `~/traefik/`** 으로 분리하고, 앱들은 **공유 external 도커 네트워크 `web`** 에 join, 각 앱이 자기 라우팅을 **라벨로 선언**.

### 9.2 도메인·네트워크 좌표 (확인 완료)
- **도메인**: `hjson248.com` (가비아 구매). A레코드 `@`(=apex) + `tenk` 둘 다 → **`222.234.234.207`** (맥 공인 IP). DNS 전파 확인 완료.
- **CGNAT 아님 확정**: 맥 `curl -s https://api.ipify.org` = `222.234.234.207` = A레코드와 일치(인터넷이 보는 IP = 맥 공인 IP). 게이트웨이 `192.168.0.1`. → 포트포워딩이 실제로 도달함.
- **포트포워딩**: 공유기 **80·443 → 맥** 완료.
- **TLS 검증 = Let's Encrypt HTTP-01.** 80 이 열려 있어 성립. **가비아 DNS API 불필요**(DNS-01/와일드카드 회피) — 서브도메인은 개별 A레코드로 충분.

### 9.3 목표 아키텍처
```
인터넷 :80/:443 → 공유기(포워딩) → [맥] Traefik (독립 스택 ~/traefik/)
                                       │ Host 헤더 라우팅 + Let's Encrypt 자동 TLS
                                       └(도커 web 네트워크)→ backend:8080 → tenk
  db(mariadb)는 internal 네트워크에 은닉 (Traefik 무관)
```
- **Traefik 독립 스택**(`~/traefik/docker-compose.yml`): entrypoints `web(:80)`/`websecure(:443)`, http→https 전역 리다이렉트, certresolver `le`(ACME HTTP-01, `acme.json` 은 `./letsencrypt` 볼륨으로 영속화), 공유 network `web`.
- **tenk 연결**: backend 를 `web`(Traefik용) + `internal`(db용) **두 네트워크**에 두고, 아래 라벨로 라우팅 선언.
  ```
  traefik.enable=true
  traefik.http.routers.tenk.rule=Host(`tenk.hjson248.com`)
  traefik.http.routers.tenk.entrypoints=websecure
  traefik.http.routers.tenk.tls.certresolver=le
  traefik.http.services.tenk.loadbalancer.server.port=8080
  traefik.docker.network=web
  ```
- **앱 추가 시**: 그 앱 compose 를 `web` 에 join + 같은 4~5줄 라벨만 붙임. **중앙 파일 무편집.**
- **운영 안전**: 첫 발급은 Let's Encrypt **staging** 으로 흐름 검증 후 prod 로 전환(rate limit 락아웃 회피).

### 9.4 파일 (리포에 작성 완료)
| 파일 | 역할 |
|---|---|
| [deploy/traefik/docker-compose.yml](../deploy/traefik/docker-compose.yml) | Traefik 공유 엣지 스택. 맥 `~/traefik/` 로 복사해 실행. 이미지 **`traefik:v3.6.1`**(Docker 29 호환 필수 — 아래 교훈), ACME 이메일·staging caserver·http→https 리다이렉트·docker 라벨 프로바이더 포함. `/var/run/docker.sock` 읽기전용 마운트. **앱별 설정 없음** — 앱 추가해도 이 파일 무편집. |
| [deploy/docker-compose.yml](../deploy/docker-compose.yml) | tenk 스택에 `web`/`internal` 네트워크 분리 + backend 에 Traefik 라우팅 라벨 추가. db 는 `internal` 에만 두어 격리. `8080:8080` 퍼블리시는 맥 로컬 헬스체크 전용으로 유지(인터넷 미노출). |

#### 교훈 — Traefik × Docker 29 (하지 말 것 / 할 것)
2026-07-01 Traefik 기동 시 `client version 1.24 is too old, Minimum supported API version is 1.44` 가 무한 반복되며 라우팅이 하나도 안 잡히는 삽질을 함. **원인은 설정이 아니라 버전 조합**: Docker Engine 29.0(2025-11)이 최소 도커 API 를 1.44 로 올렸는데 Traefik 3.6.1 미만은 옛 도커 SDK(API 1.24)로 접속 → 데몬이 거부. Colima 는 Docker 29 계열이라 그대로 걸린다. 같은 시기 Coolify·Dokploy·Appwrite 등도 동일 이슈([traefik#12253](https://github.com/traefik/traefik/issues/12253)).
- ✅ **할 것**: Traefik 이미지를 **`v3.6.1` 이상**으로. 자동 API 버전 협상이 들어가 근본 해결. (Docker 엔진을 28.x 로 내리거나 `daemon.json` `min-api-version` 으로 1.24 를 다시 허용하는 우회도 있으나, 서버를 낡은 쪽으로 맞추는 거라 비권장.)
- ❌ **하지 말 것 1**: `DOCKER_API_VERSION=1.54` 를 Traefik 컨테이너 env 로 박기 — 도커 CLI 용 변수라 Traefik 의 도커 프로바이더는 안 읽는다. env 는 들어가는데(`docker inspect` 로 확인됨) 에러는 그대로.
- ❌ **하지 말 것 2**: docker-socket-proxy 를 끼워 우회 시도 — 프록시는 요청 URL(`/v1.24/info`)을 그대로 데몬에 전달하므로 동일하게 거부당한다. (소켓 프록시는 *보안 하드닝* 용도로는 유효하지만 이 버전 문제의 해결책이 아니다.)
- **진단 팁**: `client version 1.24 is too old` 는 **데몬이 만든 메시지** = Traefik 이 실제로 `/v1.24/...` 로 요청을 보내고 있다는 뜻. `curl --unix-socket /var/run/docker.sock http://localhost/version` 은 1.54 로 정상인데 프로바이더만 실패하면 → 클라이언트(=Traefik SDK) 버전 문제로 좁혀진다.

### 9.5 배포 절차 (맥에서 실행)
```bash
# ── 0) 공유 네트워크 한 번 생성 (양 스택이 external 로 참조) ──
docker network create web

# ── 1) Traefik 스택 올리기 (staging 인증서로 흐름 검증) ──
#   deploy/traefik/docker-compose.yml 을 맥 ~/traefik/ 로 복사(scp) 후:
cd ~/traefik && docker compose up -d
docker compose logs -f traefik      # acme staging 발급 로그 확인 (Ctrl-C)

# ── 2) tenk 스택 갱신 (새 라벨/네트워크 반영) ──
#   갱신된 deploy/docker-compose.yml 을 맥 ~/tenk/ 로 복사 후:
cd ~/tenk && docker compose up -d

# ── 3) 검증 (staging: 인증서 "신뢰 안 함" 뜨는 게 정상) ──
curl -k -I https://tenk.hjson248.com/v3/api-docs        # 200
#   폰(LTE, Wi-Fi 밖)에서 https://tenk.hjson248.com/swagger-ui.html 접속 확인

# ── 4) prod 인증서로 전환 (staging 흐름 OK 확인 후) ──
#   ~/traefik/docker-compose.yml 의 staging caserver 줄 삭제/주석 후:
cd ~/traefik && rm ./letsencrypt/acme.json && docker compose up -d --force-recreate
docker compose logs -f traefik      # prod 발급 로그 확인
curl -I https://tenk.hjson248.com/v3/api-docs           # 이제 -k 없이 200 (신뢰됨)
```

### 9.6 검증 후 마무리 (prod TLS 성공 시)
- **Flutter base URL 전환**: 실기기가 이제 `https://tenk.hjson248.com` 로 접속 가능. [.vscode/launch.json](../.vscode/launch.json) `tenk_app (device)` 의 `--dart-define=API_BASE_URL` 을 이 도메인으로. LAN IP/cleartext(`network_security_config.xml`) 의존이 사라져 셋업이 단순해진다.
- **문서 갱신**: §1·§7 체크박스를 완료로, `⏭ 진행 중` 을 실제 상태로.
