# TenK

**절약을 소재로 한 챌린지 앱.** 짧은 영상으로 지출/무지출을 기록하고, 챌린지 기간(최대 30일) 안에서 목표 금액을 지키는 `만원 챌린지`.

핵심은 절약 자체가 아니라 **뿌듯한 재미**다 — 절약은 난이도(룰)이고, 성취는 배지·결과 카드·영상 합본으로 남아 공유된다.
포지셔닝 규칙(`만원`을 쓸 수 있는 자리 등)은 [CLAUDE.md](CLAUDE.md) "프로젝트 개요" 참고.

## 리포 구조 (모노레포)

- [tenk-backend/](tenk-backend/) — Spring Boot REST API (Java 21, MariaDB, JWT)
- [tenk_app/](tenk_app/) — Flutter 모바일 앱 (iOS/Android)
- [docs/](docs/) — 핸드오프·DB 스키마 등 공통 문서

자세한 작업 가이드는 [CLAUDE.md](CLAUDE.md), 진행 상태는 [docs/handoff.md](docs/handoff.md) 참고.