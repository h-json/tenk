# Tenk 백엔드 — Docker 배포 문서

> tenk 백엔드가 맥 서버에 어떻게 떠 있는지, 업데이트·재부팅·문제해결을 어떻게 하는지에 대한 **배포 운영 런북**.
>
> 배포 완료 2026-06-30.
> **갱신 규칙**: 배포 구성/명령/좌표가 바뀌면 **같은 턴에 이 문서도 갱신**할 것. 일시적 진행상태가 아니라 영구 규칙·구조·런북을 담는다.

---

## 1. 지금 상태 (한눈에)

- ✅ **tenk 백엔드가 M1 맥미니에 컨테이너로 LIVE.** "윈도우 빌드 → Docker Hub → 맥 pull"(경로 B) 완주.
- ✅ **재부팅 생존 검증 완료** (2026-07-01): Colima autostart(`brew services`) + 자동 로그인 + compose restart policy. 실제 `sudo reboot` 후 무인으로 backend 복귀 확인.
- ✅ **외부 어디서나 접속 + HTTPS LIVE** (2026-07-01): **Traefik 리버스 프록시(`~/Documents/projects/claude/reverse-proxy/` 독립 스택, `v3.6.1`) + Let's Encrypt prod 인증서**. `https://tenk.hjson248.com` 폰(LTE)·PC 브라우저 접속 확인. 흐름: staging 발급 검증 → prod 전환(caserver staging 줄 제거 → `rm acme.json` → force-recreate) 완료. **주의 요함(mixed content) 해결**: 스프링부트가 Traefik 의 `X-Forwarded-Proto=https` 를 신뢰하도록 `server.forward-headers-strategy=framework` 적용 — 안 하면 springdoc 이 `http://` 서버 URL 을 만들어 HTTPS 페이지가 "주의 요함". 상세 §9.5·§9.6.

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
cd ~/Documents/projects/claude/reverse-proxy && docker compose up -d
cd ~/Documents/projects/claude/tenk && cp .env.example .env   # 비밀번호 채우기
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
| 컨테이너가 `Created` 에서 멈추고 `error while creating mount source path ... mkdir /Users/…/Documents: operation not permitted` | **macOS TCC(프라이버시)가 `~/Documents`·Desktop·Downloads 를 보호**해 Colima VM(virtiofs)이 그 하위 경로를 bind mount 못 함(홈 루트 `~/` 밑은 됨). compose 파일 자체는 호스트가 읽어 어디 둬도 되지만 **compose 안 상대경로 bind mount 가 전부 막힌다**. → 런타임 파일을 **named volume** 으로 전환(폴더 위치 무관). 시딩은 §5.4, 전말은 §10.6. |

---

## 7. 다음 단계

- [x] **폰 접속 방향 결정 (2026-07-01)** — **(나) 외부 어디서나 + HTTPS** 로 결정. 리버스 프록시는 **Traefik**. 근거·아키텍처 §9.
- [x] **Traefik 리버스 프록시 + 자동 HTTPS 구축 (2026-07-01 완료)** — Traefik 독립 스택 → tenk 라벨 연결 → LE prod 인증서 → `https://tenk.hjson248.com` 검증. `forward-headers-strategy` 로 mixed content("주의 요함")까지 해결. §9.5·§9.6.
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
- **구조 원칙**: 리버스 프록시는 모든 앱 위에 걸치는 **공유 엣지**라 tenk 스택에 넣지 않는다(넣으면 tenk 재배포 시 다른 앱 트래픽까지 끊김). **독립 스택 `~/Documents/projects/claude/reverse-proxy/`** 으로 분리하고, 앱들은 **공유 external 도커 네트워크 `web`** 에 join, 각 앱이 자기 라우팅을 **라벨로 선언**.

### 9.2 도메인·네트워크 좌표 (확인 완료)
- **도메인**: `hjson248.com` (가비아 구매). A레코드 `@`(=apex) + `tenk` 둘 다 → **`222.234.234.207`** (맥 공인 IP). DNS 전파 확인 완료.
- **CGNAT 아님 확정**: 맥 `curl -s https://api.ipify.org` = `222.234.234.207` = A레코드와 일치(인터넷이 보는 IP = 맥 공인 IP). 게이트웨이 `192.168.0.1`. → 포트포워딩이 실제로 도달함.
- **포트포워딩**: 공유기 **80·443 → 맥** 완료.
- **TLS 검증 = Let's Encrypt HTTP-01.** 80 이 열려 있어 성립. **가비아 DNS API 불필요**(DNS-01/와일드카드 회피) — 서브도메인은 개별 A레코드로 충분.

### 9.3 목표 아키텍처
```
인터넷 :80/:443 → 공유기(포워딩) → [맥] Traefik (독립 스택 ~/Documents/projects/claude/reverse-proxy/)
                                       │ Host 헤더 라우팅 + Let's Encrypt 자동 TLS
                                       └(도커 web 네트워크)→ backend:8080 → tenk
  db(mariadb)는 internal 네트워크에 은닉 (Traefik 무관)
```
- **Traefik 독립 스택**(`~/Documents/projects/claude/reverse-proxy/docker-compose.yml`): entrypoints `web(:80)`/`websecure(:443)`, http→https 전역 리다이렉트, certresolver `le`(ACME HTTP-01, `acme.json` 은 **named volume `traefik_letsencrypt`** 로 영속화 — 폴더가 `~/Documents` 밑이라 bind mount 회피, §10.6), 공유 network `web`.
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
| [deploy/traefik/docker-compose.yml](../deploy/traefik/docker-compose.yml) | Traefik 공유 엣지 스택. `name: traefik`. 맥 `~/Documents/projects/claude/reverse-proxy/` 로 복사해 실행(리포 폴더명은 `traefik/` 유지 — 매핑만 기억). 이미지 **`traefik:v3.6.1`**(Docker 29 호환 필수 — 아래 교훈), ACME 이메일(prod 기본, staging 은 caserver 줄 추가 시)·http→https 리다이렉트·docker 라벨 프로바이더 포함. 인증서는 **named volume `letsencrypt`**, `/var/run/docker.sock` 읽기전용 마운트. **앱별 설정 없음** — 앱 추가해도 이 파일 무편집. |
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
#   deploy/traefik/docker-compose.yml 을 맥 ~/Documents/projects/claude/reverse-proxy/ 로 복사(scp) 후:
cd ~/Documents/projects/claude/reverse-proxy && docker compose up -d
docker compose logs -f traefik      # acme staging 발급 로그 확인 (Ctrl-C)

# ── 2) tenk 스택 갱신 (새 라벨/네트워크 반영) ──
#   갱신된 deploy/docker-compose.yml 을 맥 ~/Documents/projects/claude/tenk/ 로 복사 후:
cd ~/Documents/projects/claude/tenk && docker compose up -d

# ── 3) 검증 (staging: 인증서 "신뢰 안 함" 뜨는 게 정상) ──
curl -k -I https://tenk.hjson248.com/v3/api-docs        # 200
#   폰(LTE, Wi-Fi 밖)에서 https://tenk.hjson248.com/swagger-ui.html 접속 확인

# ── 4) prod 인증서로 전환 (staging 흐름 OK 확인 후) ──
#   reverse-proxy/docker-compose.yml 의 staging caserver 줄 제거 후,
#   named volume 의 acme.json(=staging 인증서)을 비워 prod 재발급 유도:
cd ~/Documents/projects/claude/reverse-proxy && docker compose down && docker volume rm traefik_letsencrypt && docker compose up -d
docker compose logs -f traefik      # prod 발급 로그 확인
curl -I https://tenk.hjson248.com/v3/api-docs           # 이제 -k 없이 200 (신뢰됨)
```
> **현재는 prod 가 기본** — 정답본 compose 엔 staging caserver 줄이 없다. staging 으로 흐름만 볼 땐 그 줄을 **추가**(§9.4 파일 상단 안내). acme.json 은 bind mount 가 아니라 **named volume `traefik_letsencrypt`** 라서, 재발급은 파일 `rm` 이 아니라 위처럼 `docker volume rm` 으로 한다(§10.6).

### 9.6 검증 후 마무리 (prod TLS 성공 — 2026-07-01)
- ✅ **prod 인증서 발급 확인**: 브라우저 인증서 뷰어 발급기관 `Let's Encrypt (CN=YR2)`, 90일 유효(7/1~9/29). staging 이면 "STAGING"/"Fake LE" 로 떴을 것.
- ✅ **주의 요함(mixed content) 해결 — `server.forward-headers-strategy=framework`**: 증상은 인증서는 "유효함" 인데 크롬이 "주의 요함". 원인은 스프링부트가 Traefik 뒤에서 `X-Forwarded-Proto=https` 를 안 믿어 springdoc 이 Swagger `Servers` URL 을 `http://tenk.hjson248.com` 로 생성 → HTTPS 페이지 안 http 참조 = mixed content. 적용 위치 2곳: [application-prod.yaml](../tenk-backend/src/main/resources/application-prod.yaml) `server.forward-headers-strategy: framework`(소스 오브 트루스, 다음 이미지 빌드에 반영) + [deploy/docker-compose.yml](../deploy/docker-compose.yml) `SERVER_FORWARD_HEADERS_STRATEGY=framework` env(**이미지 재빌드 없이** `docker compose up -d` 로 즉시 적용). 검증: `curl -s --resolve tenk.hjson248.com:443:127.0.0.1 https://tenk.hjson248.com/v3/api-docs | grep -oE 'https?://tenk[^"]*'` → `https://tenk.hjson248.com`.
  - **함정 — 맥에서 자기 도메인 curl 이 `status=000`**: 공유기 NAT 헤어핀 미지원이라 맥이 자기 공인 IP 로 loopback 을 못 한다. 실사용자(폰 LTE/외부)는 정상. 맥 로컬 검증은 `--resolve tenk.hjson248.com:443:127.0.0.1` 로 Traefik 을 직접 때려 우회.
- ⏭ **Flutter base URL 전환(남음)**: 실기기가 이제 `https://tenk.hjson248.com` 로 접속 가능. [.vscode/launch.json](../.vscode/launch.json) `tenk_app (device)` 의 `--dart-define=API_BASE_URL` 을 이 도메인으로 바꾸면 LAN IP/cleartext(`network_security_config.xml`) 의존이 사라진다.

---

## 10. 맥에서 Claude Code 로 운영하기 (operator orientation)

> 이 맥미니(`sonhuijun-ui-Macmini`)가 **tenk 운영 서버 그 자체**다. 여기서 도는 Claude Code 는
> 윈도우 세션과 달리 **docker 명령을 사람 손 거치지 않고 직접 실행**할 수 있다. 이 절은 맥 Claude Code 가
> 배포를 이어받을 때의 오리엔테이션이고, **실제 런북·아키텍처·함정은 이 문서 §1~§9 가 진실의 원천**이다.

### 10.1 전제 — 맥 = 서버, 리포 = 소스
- 맥에서 **직접 실행 가능**: `cd ~/Documents/projects/claude/tenk && docker compose ...`, `cd ~/Documents/projects/claude/reverse-proxy && docker compose ...`, `colima ...`, `docker ...`. 상태 확인·재배포·로그·재기동을 Claude Code 가 바로 수행.
- **리포의 `deploy/` 가 소스 오브 트루스, 맥의 배포 폴더는 그 복사본**이다. 구성을 바꿀 땐 **리포에서 고치고 → 맥으로 복사 → `up -d`**. 맥의 파일을 직접 손대면 리포와 드리프트하니 하지 말 것(급하면 고친 뒤 반드시 리포에 역반영).

### 10.2 맥 로컬 레이아웃 (비-git, 머신 고유)
```
~/Documents/projects/claude/
├─ tenk/            # tenk 앱 스택 (리포 deploy/ 의 복사본)
│  ├─ docker-compose.yml   # = 리포 deploy/docker-compose.yml (name: tenk)
│  ├─ schema.sql           # = 리포 docs/schema.sql — dbinit 볼륨 시드 원본
│  └─ .env                 # DB_PASSWORD/DB_ROOT_PASSWORD (커밋 금지, 맥에만)
└─ reverse-proxy/   # 공유 엣지 스택 (리포 deploy/traefik/ 의 복사본)
   └─ docker-compose.yml   # = 리포 deploy/traefik/docker-compose.yml (name: traefik)
```
- **런타임 파일은 폴더가 아니라 named volume 에 있다** (폴더가 `~/Documents` 밑이라 TCC 로 bind mount 불가 — §10.6):
  `tenk_db-data` · `tenk_uploads` · `tenk_dbinit`(schema 시드) · `traefik_letsencrypt`(acme.json). 백업은 `docker cp`.
- 두 스택은 external 네트워크 `web` 로 연결(사전 `docker network create web` 1회). 상세 §9.
- **이미지 소스코드는 맥에 없다**(§2 "clean server" 원칙). 코드 변경 재배포는 이미지 재빌드가 필요 → §10.4.

### 10.3 첫 진입 루틴 (상태부터 확인, 하드코딩된 상태를 믿지 말 것)
```bash
docker compose -f ~/Documents/projects/claude/tenk/docker-compose.yml ps        # backend/db 상태
docker compose -f ~/Documents/projects/claude/reverse-proxy/docker-compose.yml ps     # traefik 상태
colima status && docker context show                  # VM·컨텍스트(=colima)
# 전체 경로(Traefik→backend, X-Forwarded-Proto 포함) 로컬 검증 — NAT 헤어핀 우회
curl -s --resolve tenk.hjson248.com:443:127.0.0.1 https://tenk.hjson248.com/v3/api-docs | grep -oE 'https?://tenk[^"]*'
```
기대값: 컨테이너 3개 Up, 마지막 curl 이 `https://tenk.hjson248.com`. 어긋나면 §6 트러블슈팅 / §9.

### 10.4 자주 하는 운영 (요약 — 상세는 §5·§9)
- **설정만 바뀜(compose/env/schema)**: 리포에서 수정 → 해당 파일 맥으로 복사(scp/붙여넣기) → `cd ~/Documents/projects/claude/tenk && docker compose up -d`(env 바뀌면 컨테이너 재생성). **이미지 재빌드 불필요.**
- **코드가 바뀜**: 윈도우에서 `docker buildx build --platform linux/arm64 -t hjson248/tenk:latest --push .`(§5.1) → 맥 `cd ~/Documents/projects/claude/tenk && docker compose pull && docker compose up -d`. (맥엔 소스가 없어 맥 Claude Code 는 빌드 못 함 — 빌드는 윈도우 세션 담당.)
- **로그/재기동**: `docker compose logs -f backend|traefik`, `docker compose restart <svc>`.
- **인증서**: prod 활성(named volume `traefik_letsencrypt`). 재발급은 `docker compose down && docker volume rm traefik_letsencrypt && docker compose up -d`(§9.5 4)). staging 흐름만 볼 땐 caserver 줄 추가(§9.4). prod rate limit 주의.

### 10.5 맥에 둘 것 — 배포 설정만, 앱 소스는 안 둔다
- **모노레포를 통째로 클론하지 않는다.** 그러면 서버에 앱 소스가 올라가 Docker "clean server" 원칙(§2)이 깨진다 — 도커로 이미지만 받아 돌리는 의미가 사라진다. 맥에는 **배포 설정(§10.2 의 `~/Documents/projects/claude/tenk`·`~/Documents/projects/claude/reverse-proxy`)만** 둔다.
- 맥 Claude Code 가 컨텍스트를 가지려면 **이 런북 한 파일만 맥으로 복사**한다(compose 파일을 맥으로 복사하는 것과 똑같은 흐름). 예: 이 문서를 `~/Documents/projects/claude/tenk/RUNBOOK.md` 로 복사. 소스-상대 링크(`../tenk-backend/...`)는 서버에 소스가 없어 안 열리지만, 명령·아키텍처·함정 본문은 그대로 유효하다.
- **킥오프**(맥 `~/Documents/projects/claude/tenk/` 에서 `claude` 실행 후 첫 메시지):
  *"나는 이 맥에서 tenk 를 운영해. 여기 `RUNBOOK.md` 의 §10 을 먼저 읽고 §10.3 으로 현재 배포 상태를 확인한 다음 이어서 도와줘. 서버엔 앱 소스가 없고 배포 설정(`~/Documents/projects/claude/tenk`·`~/Documents/projects/claude/reverse-proxy`)만 있다."*
- **설정을 git 으로 버전관리하고 싶으면(선택)**: `deploy/` 만 담는 **별도 `tenk-deploy` 리포**로 분리하거나, 모노레포를 `deploy/` 경로만 **sparse-checkout**. 둘 다 앱 소스는 안 내려오면서 맥에서 설정 변경을 commit/push 할 수 있다. 셋업 품이 더 드니 필요해질 때 도입.

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
