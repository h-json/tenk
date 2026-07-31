-- ============================================================
-- 배지 획득 연출(#8) 수동 테스트용 시드 데이터
--
-- 무엇:
--   - 챌린지 6개. 각각 "한 번만 기록하면 목표 배지가 터지는" 직전 상태로 맞춰져 있다.
--   - 배지 자산의 색 사다리(브론즈 3 / 실버 7 / 골드 14 / 주얼 30 / 금 트로피)를 전부 한 번씩 볼 수 있다.
--   - 하위 단계 배지는 미리 지급해 둬서 목표 배지 하나(또는 의도한 2개)만 새로 터진다.
--
--   | 챌린지            | 뭘 누르면 | 기대 결과                                                     |
--   |-------------------|-----------|---------------------------------------------------------------|
--   | ① 브론즈 3일      | 지출 기록 | STREAK 3 (구리) + "4일 더 기록하면 7일 연속 배지예요"         |
--   | ② 배지 2개 동시   | 무지출    | STREAK 3 + NO_SPEND 3 체인 (`다음 (1/2)` → `완료`)            |
--   | ③ 실버 7일        | 지출 기록 | STREAK 7 (은색)                                               |
--   | ④ 골드 14일       | 지출 기록 | STREAK 14 (금색)                                              |
--   | ⑤ 주얼 30일       | 무지출    | STREAK 30 + NO_SPEND 30 체인 (다색 파티클) + 마지막 날 폴백   |
--   | ⑥ 확정→트로피     | 확정하기  | CHALLENGE_SUCCESS (트로피) → 배지 모달 뒤 결과 카드 자동 진입 |
--
-- 어떻게:
--   1. 앱에서 카카오 로그인 1회 (로그인된 그 계정이 시드 대상 — 아래 @uid 참고)
--   2. 리포 루트에서: mysql -u tenk -p tenk < docs/seed-badge-demo.sql
--   3. 앱에서 챌린지 목록을 당겨 새로고침 → `[연출]` 로 시작하는 6개가 보인다
--
-- 다시 돌리기:
--   - 실행할 때마다 `[연출]%` 를 먼저 지우고 새로 만든다. **몇 번이든 반복 실행 가능**하고,
--     시나리오를 하나 소비했으면 그냥 다시 돌리면 전부 원상복구된다.
--
-- 주의:
--   - ⚠️ 앱 메뉴의 **'테스트 데이터 재생성'(TESTER 전용)을 누르면 이 세트가 전부 날아간다.**
--     그건 호출자 데이터를 통째로 wipe 하고 상태별 챌린지 5종을 새로 만드는 별개 도구다.
--   - ⚠️ 통합 테스트(`./gradlew test`)도 user/challenge/amount 를 DELETE 한다. 테스트를 돌렸다면
--     카카오 재로그인 후 이 스크립트를 다시 실행할 것.
--   - 날짜는 전부 CURDATE() 기준 상대값이라 **아무 날에 돌려도 동작**한다. 단 기기(에뮬)와 서버의
--     타임존이 다르면 "오늘"이 어긋나 시나리오가 하루씩 밀린다 — 에뮬 타임존을 Asia/Seoul 로 맞출 것.
--   - 엔티티 검증을 우회하는 네이티브 INSERT 다 (backdate 가 목적). category 는 반드시
--     SpendCategory 의 유효 코드('FOOD' 등)를 쓸 것 — 아무 문자열이나 넣으면 *읽을 때* enum 매핑이 깨진다.
-- ============================================================

USE `tenk`;

-- 시드 대상 = **앱에 지금 로그인돼 있는 계정** (가장 최근에 발급된 유효 refresh token 의 주인).
-- created_dt 기준으로 고르면 통합 테스트가 남긴 더미 계정이 뽑힐 수 있어 이렇게 찾는다.
SET @uid := (
    SELECT rt.user_id
      FROM refresh_token rt
      JOIN `user` u ON u.user_id = rt.user_id
     WHERE rt.is_revoked = 0 AND u.is_deleted = 0
     ORDER BY rt.refresh_token_id DESC
     LIMIT 1
);
-- @uid 가 NULL 이면 아래 INSERT 가 FK 로 실패한다 → 앱에서 카카오 로그인부터 할 것.
SELECT @uid AS seeding_for_user_id;

-- ── 이전 실행분 정리 (이 스크립트가 만든 것만 — 이름 prefix 로 식별) ──
DELETE cb FROM challenge_badge cb
  JOIN challenge c ON c.challenge_id = cb.challenge_id
 WHERE c.user_id = @uid AND c.name LIKE '[연출]%';
DELETE a FROM amount a
  JOIN challenge c ON c.challenge_id = a.challenge_id
 WHERE c.user_id = @uid AND c.name LIKE '[연출]%';
DELETE FROM challenge WHERE user_id = @uid AND name LIKE '[연출]%';

-- ① 브론즈: 2일 연속 기록됨, 배지 없음 → 오늘 '지출 기록' 하면 STREAK 3
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ① 브론즈 3일', DATE_SUB(CURDATE(), INTERVAL 2 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 30000, 0);
SET @c1 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 2)
SELECT @c1, 'FOOD', CONCAT('테스트 지출 ', n), 1000, 0,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;

-- ② 체인 2개: 무지출 2일 → 오늘 '무지출' 누르면 STREAK 3 + NO_SPEND 3 이 함께 터진다
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ② 배지 2개 동시', DATE_SUB(CURDATE(), INTERVAL 2 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 30000, 0);
SET @c2 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 2)
SELECT @c2, 0, 1, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;

-- ③ 실버: 6일 연속 + STREAK 3 보유 → 오늘 기록하면 STREAK 7
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ③ 실버 7일', DATE_SUB(CURDATE(), INTERVAL 6 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 30000, 0);
SET @c3 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 6)
SELECT @c3, 'FOOD', CONCAT('테스트 지출 ', n), 1000, 0,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;
INSERT INTO challenge_badge (challenge_id, badge_id) VALUES (@c3, 1);

-- ④ 골드: 13일 연속 + STREAK 3·7 보유 → 오늘 기록하면 STREAK 14
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ④ 골드 14일', DATE_SUB(CURDATE(), INTERVAL 13 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 30000, 0);
SET @c4 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 13)
SELECT @c4, 'FOOD', CONCAT('테스트 지출 ', n), 500, 0,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;
INSERT INTO challenge_badge (challenge_id, badge_id) VALUES (@c4, 1), (@c4, 2);

-- ⑤ 주얼 + 마지막 날: 무지출 29일 + 하위 배지 보유, 오늘이 종료일(기간이 정확히 30일)
--    → 오늘 '무지출' 누르면 STREAK 30 + NO_SPEND 30 (다색 파티클) + "오늘이 챌린지 마지막 날이에요"
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ⑤ 주얼 30일', DATE_SUB(CURDATE(), INTERVAL 29 DAY), CURDATE(), 30000, 0);
SET @c5 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 29)
SELECT @c5, 0, 1, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;
INSERT INTO challenge_badge (challenge_id, badge_id)
VALUES (@c5, 1), (@c5, 2), (@c5, 3), (@c5, 5), (@c5, 6), (@c5, 7);

-- ⑥ 확정 대기(성공): 어제 종료 + 예산 내 → '확정하기' 누르면 트로피 배지 후 결과 카드
INSERT INTO challenge (user_id, name, start_date, end_date, target_amount, is_deleted)
VALUES (@uid, '[연출] ⑥ 확정→트로피', DATE_SUB(CURDATE(), INTERVAL 5 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY), 30000, 0);
SET @c6 = LAST_INSERT_ID();
INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 5)
SELECT @c6, 'FOOD', CONCAT('테스트 지출 ', n), 1000, 0,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL n DAY), '12:00:00') FROM seq;
INSERT INTO challenge_badge (challenge_id, badge_id) VALUES (@c6, 1);

-- ── 확인: amounts 는 2/2/6/13/29/5, badges 는 0/0/1/2/6/1, out_of_range 는 전부 0 이어야 정상 ──
SELECT c.challenge_id, c.name, c.start_date, c.end_date,
       (SELECT COUNT(*) FROM amount a WHERE a.challenge_id = c.challenge_id) AS amounts,
       (SELECT COUNT(*) FROM challenge_badge b WHERE b.challenge_id = c.challenge_id) AS badges,
       (SELECT COUNT(*) FROM amount a
         WHERE a.challenge_id = c.challenge_id
           AND (DATE(a.spent_dt) < c.start_date OR DATE(a.spent_dt) > c.end_date)) AS out_of_range
  FROM challenge c
 WHERE c.user_id = @uid AND c.name LIKE '[연출]%'
 ORDER BY c.challenge_id;
