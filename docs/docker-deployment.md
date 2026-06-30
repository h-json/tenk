# Tenk 백엔드 — Docker 배포 & 강의 문서

> 이 문서는 두 역할을 한다.
> 1. **배포 운영 런북** — tenk 백엔드가 맥 서버에 어떻게 떠 있는지, 업데이트·재부팅·문제해결을 어떻게 하는지.
> 2. **Docker 1:1 강의 재개 지점** — "도커 강의 이어서" 류 요청 시 이 문서를 읽고 아래 **§7 강의 상태**부터 재개.
>
> 강의 시작 2026-06-29 · 배포 완료 2026-06-30.
> **갱신 규칙**: 배포 구성/명령/좌표가 바뀌거나 강의 진도·결정이 바뀌면 **같은 턴에 이 문서도 갱신**할 것. 일시적 진행상태가 아니라 영구 규칙·구조·런북을 담는다.

---

## 1. 지금 상태 (한눈에)

- ✅ **tenk 백엔드가 M1 맥미니에 컨테이너로 LIVE.** "윈도우 빌드 → Docker Hub → 맥 pull"(경로 B) 완주.
- ✅ **재부팅 생존 검증 완료** (2026-07-01): Colima autostart(`brew services`) + 자동 로그인 + compose restart policy. 실제 `sudo reboot` 후 무인으로 backend 복귀 확인.
- ⏭ **다음 본선**: 폰에서 접속 — (가) Wi-Fi 내부 / (나) 외부+HTTPS. **미결정**.
- ⏸ **개념 강의(멀티스테이지 심화 등)는 분리·보류.** 배포부터 끝내기로 합의. §7.4 참고.

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

---

## 7. 강의 상태 & 방식

### 7.1 목표 (우선순위)
1. **(진짜 목표) 사용자가 혼자서 Docker를 다루는 독립 역량** — Dockerfile을 도움 없이 작성.
2. **(부수, 달성) tenk 백엔드를 M1 맥에 배포.** iOS 빌드도 같은 맥.

### 7.2 교육 방식 (반드시 지킬 것)
- **개념**: 강의식 — 비유·AWS 매핑·"왜/원리". 사용자가 이 방식에 만족.
- **"만드는 법"보다 "언제·왜·용도"를 먼저** (사용자 명시 요청). 산출물 작성법 전에 *언제 만들고 / 왜 / 뭐에 쓰는지*부터. 아는 것(`pull httpd`, `-v` 볼륨)에서 다리 놓기. → `feedback_situate_in_common_best_practice`
- **실습**: 학생이 직접 산출물 작성, 나는 Socratic 코치. 완성본 떠먹이지 말 것. → `feedback_teaching_hands_on_student_authors`
- **맥락 항상 제시**: 표준인지/특수케이스인지/더 나은 법.
- **한 번에 하나씩.** 압도 금지. 명령은 하나씩 주고 결과 확인 후 다음.

### 7.3 사용자 이해 수준
- **AWS 경험 풍부**: EC2/AMI/ECR, cgroup·namespace 등 시스템 개념 익숙. 비유는 AWS로 들면 잘 통함(이미지↔AMI, 컨테이너↔EC2, 레지스트리↔ECR).
- **외부 강의(경로 A)를 병행**: httpd 예제로 `run`/`ps`/`stop`/`start`/`logs`/`rm`/`-p` 포트포워딩/`exec -it`/`-v` 볼륨까지 익힘 = 컨테이너 CLI 손맛 완료. 이 강의(경로 B = 배포 직행)는 그 위 2층. **둘은 충돌 아니라 상호보완**(한때 "전혀 다른 방향"이라 혼란 → 정리됨).
- **이미 잡은 멘탈모델**: 이미지/컨테이너/레지스트리, 포트포워딩, 볼륨, 맥/윈도우의 리눅스 VM 구조, arm64/amd64, **Colima=진짜 도커**, **Dockerfile = 내 앱을 *어디서든 pull해서 도는 이미지*로 굽는 레시피(소비자→생산자 전환)**, 멀티스테이지의 동기(빌드환경 ≠ 실행환경).
- **주의**: 한 번에 쏟으면 압도("갑자기 어려워졌어"). buildx/`$BUILDPLATFORM` 같은 건 단계적으로.

### 7.4 보류된 개념 강의 토픽 (배포 일단락 후 따로)
사용자가 "개념 강의 이어서" 류로 원할 때 재개. 멈춘 지점:
- **멀티스테이지 심화 실습** — 학생이 Dockerfile을 직접 재작성하던 중 중단. **멈춘 질문**: ① 2단계 `FROM`이 왜 JDK 아닌 JRE인지 ② "삭제 명령을 안 썼는데 JDK·Gradle·소스는 최종 이미지에서 어디로 사라지나"(= 앞 스테이지는 최종 이미지에 안 실림). 개념 설명(왜 분리/COPY --from/언제 쓰나)은 이미 1회 강의함.
- 레이어 캐싱, buildx·`$BUILDPLATFORM` 원리, `docker compose` 개념 정리(이미 실사용 중), HTTPS/리버스 프록시(Caddy).
- **보너스(시점 봐서)**: Spring Boot buildpacks(`./gradlew bootBuildImage`, Dockerfile 없이 이미지), layered jar(캐싱 최적화).

### 7.5 독립용 사고 틀 (Dockerfile 작성 5질문) — 가르친 것
1. 최종적으로 뭘 실행? → 최소 런타임 베이스(`FROM`)
2. 산출물 만드는 도구 ≠ 실행 도구? → 다르면 멀티스테이지
3. 파일 넣는 순서 → 안 바뀌는 것 위, 자주 바뀌는 것 아래(캐싱)
4. 실행에 필요한 정보 → 포트(`EXPOSE`)/환경변수(`ENV`)/시작 명령(`ENTRYPOINT`)
5. 빌드에 안 보낼 것 → `.dockerignore`

---

## 8. 다음 단계

- [ ] **폰 접속 방향 결정** — (가) 같은 Wi-Fi 내부 테스트(`http://<맥 LAN IP>:8080` + [network_security_config.xml](../tenk_app/android/app/src/main/res/xml/network_security_config.xml)에 IP 추가) vs (나) 외부 어디서나 + HTTPS(도메인 + Caddy 리버스 프록시).
- [x] 자동 로그인 + `sudo reboot` 최종 생존 테스트 — **완료(2026-07-01), 무인 복귀 확인.**
- [ ] 개념 강의 재개(멀티스테이지부터) — 사용자가 원할 때.
- 운영 향후(범위 밖): 회원 탈퇴 hard-delete cascade + 개인정보처리방침 → [handoff.md](handoff.md) "운영 고려사항".

## 9. 기술 사실 (강의 중 확정)

- 백엔드: Spring Boot **4.0.6** / Java 21 / Gradle wrapper. 산출물 `build/libs/tenk-0.0.1-SNAPSHOT.jar`.
- 빌드 시 **테스트 제외** 필수 → `bootJar`만(`build` 아님). 통합테스트가 실제 MariaDB를 요구해 빌드 컨테이너에선 못 돎.
- DB는 컨테이너(`mariadb:11`). 맥 1대 self-host라 컨테이너 DB가 합리적. `ddl-auto=validate`라 schema.sql 선적용 필수 → compose가 init 스크립트로 자동 처리.
