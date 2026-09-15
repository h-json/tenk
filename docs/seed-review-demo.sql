-- =====================================================================
-- Play 심사용 데모 계정 시딩 — TestSupportService.seedAll 의 SQL 판
-- =====================================================================
-- 용도: 심사자에게 줄 데모 카카오 계정에 5종 상태 챌린지를 심는다.
--       **연령·동의 게이트(birth_date / terms_agreed_dt / privacy_agreed_dt)는 건드리지 않는다** —
--       심사자가 가입 흐름을 그대로 보고, 끝나면 홈에 5종 챌린지가 있게 하는 게 목적이다.
--       근거·절차는 docs/play-console-app-content.md §2-1.
--
-- 왜 SQL 인가: 앱의 '테스트 데이터 재생성' 버튼은 게이트 **안쪽** 메뉴에 있어, 게이트를 비워둔 계정으로는
--       누를 수 없다. 이 스크립트는 role 게이트도 거치지 않으므로 **TESTER 승격·강등이 필요 없다.**
--
-- 사용법 (DBeaver):
--   1) 데모 계정으로 prod 앱에 카카오 로그인 1회 → 연령 확인 화면에서 **그대로 멈춘다** (계정 행이 생긴다)
--   2) 아래 @kakao_id 를 확인하고 **스크립트 전체 실행(Alt+X)** — Ctrl+Enter 는 한 문장만 돈다
--   3) 첫 SELECT 의 user_id 가 NULL 이면 계정이 없는 것 — 아무것도 바뀌지 않는다(모든 INSERT 가 가드됨)
--   4) 맨 아래 검증 결과가 "기대값" 주석과 같은지 확인
--
-- 반복 실행 안전: 그 계정의 챌린지·기록·배지를 먼저 지우고 다시 만든다(서비스의 wipe 와 같은 FK 순서).
-- ⚠️ 제출 직전에 돌릴 것 — 날짜가 '실행한 날' 기준 상대값이라 5종이 모두 보이는 건 2일간이다(§2-1 표).
-- ⚠️ media_file 행은 지우지만 디스크의 영상 파일은 못 지운다. 심사자가 영상을 찍은 뒤 재실행하면
--    파일만 고아로 남는다(데모 계정 한정이라 무해).
-- ⚠️ TestSupportService.seedAll 을 바꾸면 이 파일도 같이 고칠 것 — 둘이 갈라지면 로컬과 심사 화면이 달라진다.
-- =====================================================================

SET @kakao_id := '5006994690';   -- 데모 계정의 카카오 회원번호 (관리자 패널 '사용자' 에 보이는 값)

SET @uid   := (SELECT `user_id` FROM `user`
                WHERE `provider` = 'KAKAO' AND `provider_user_id` = @kakao_id AND `is_deleted` = 0);
-- DB 컨테이너는 UTC 다(compose 의 db 서비스에 TZ 없음). 앱은 KST 로 날짜를 판정하므로 여기서 KST 로 맞춘다.
-- CURDATE() 를 쓰면 한국 오전 9시 전에 돌렸을 때 모든 날짜가 하루 밀린다.
SET @today := DATE(UTC_TIMESTAMP() + INTERVAL 9 HOUR);
SET @now   := UTC_TIMESTAMP() + INTERVAL 9 HOUR;

SELECT @uid AS user_id, @today AS today_kst,
       (SELECT `nickname` FROM `user` WHERE `user_id` = @uid) AS nickname;   -- ← user_id 가 NULL 이면 중단

START TRANSACTION;

-- ── wipe (TestSupportService.wipe 와 같은 FK 순서) ───────────────────
DELETE mf FROM `media_file` mf
  JOIN `amount` a    ON a.`amount_id` = mf.`amount_id`
  JOIN `challenge` c ON c.`challenge_id` = a.`challenge_id`
 WHERE c.`user_id` = @uid;
DELETE cb FROM `challenge_badge` cb
  JOIN `challenge` c ON c.`challenge_id` = cb.`challenge_id`
 WHERE c.`user_id` = @uid;
DELETE a FROM `amount` a
  JOIN `challenge` c ON c.`challenge_id` = a.`challenge_id`
 WHERE c.`user_id` = @uid;
DELETE FROM `challenge` WHERE `user_id` = @uid;

-- ── 챌린지 5종 (목표 10,000원) ──────────────────────────────────────
INSERT INTO `challenge` (`user_id`, `name`, `start_date`, `end_date`, `target_amount`, `result`, `created_dt`, `updated_dt`)
SELECT @uid, x.name, x.s, x.e, 10000, x.r, @now, @now
  FROM (
        SELECT '시작 전 챌린지'   AS name, @today + INTERVAL 3 DAY  AS s, @today + INTERVAL 12 DAY AS e, NULL      AS r
        UNION ALL SELECT '진행 중 챌린지',   @today - INTERVAL 4 DAY,  @today + INTERVAL 5 DAY,  NULL
        UNION ALL SELECT '확정 대기 챌린지', @today - INTERVAL 12 DAY, @today - INTERVAL 2 DAY,  NULL
        UNION ALL SELECT '성공 완료 챌린지', @today - INTERVAL 25 DAY, @today - INTERVAL 15 DAY, 'SUCCESS'
        UNION ALL SELECT '실패 완료 챌린지', @today - INTERVAL 25 DAY, @today - INTERVAL 15 DAY, 'FAIL'
       ) x
 WHERE @uid IS NOT NULL;

-- LAST_INSERT_ID 대신 이름으로 다시 잡는다 — 위 INSERT 가 가드로 건너뛰었을 때 엉뚱한 id 를 물지 않게.
SET @c_ongoing := (SELECT `challenge_id` FROM `challenge` WHERE `user_id` = @uid AND `name` = '진행 중 챌린지');
SET @c_pending := (SELECT `challenge_id` FROM `challenge` WHERE `user_id` = @uid AND `name` = '확정 대기 챌린지');
SET @c_success := (SELECT `challenge_id` FROM `challenge` WHERE `user_id` = @uid AND `name` = '성공 완료 챌린지');
SET @c_fail    := (SELECT `challenge_id` FROM `challenge` WHERE `user_id` = @uid AND `name` = '실패 완료 챌린지');

-- ── 기록 (지출/무지출 모두 정오. 무지출은 amount=0, category/content NULL) ─────────────
INSERT INTO `amount` (`challenge_id`, `category`, `content`, `amount`, `is_no_spend`, `memo`, `spent_dt`, `created_dt`)
SELECT x.cid, x.cat, x.content, x.amt, x.ns, NULL, TIMESTAMP(x.d, '12:00:00'), @now
  FROM (
        -- 진행 중: 5일 연속 기록(STREAK 3) + 무지출 3일(NO_SPEND 3). 총지출 4,200 < 목표
        SELECT @c_ongoing AS cid, 'FOOD' AS cat, '점심 김밥' AS content, 3000 AS amt, 0 AS ns, @today - INTERVAL 4 DAY AS d
        UNION ALL SELECT @c_ongoing, 'TRANSPORT', '버스', 1200, 0, @today - INTERVAL 3 DAY
        UNION ALL SELECT @c_ongoing, NULL, NULL, 0, 1, @today - INTERVAL 2 DAY
        UNION ALL SELECT @c_ongoing, NULL, NULL, 0, 1, @today - INTERVAL 1 DAY
        UNION ALL SELECT @c_ongoing, NULL, NULL, 0, 1, @today
        -- 확정 대기: finalize 누르면 SUCCESS (총지출 3,000). 배지도 미리 형성
        UNION ALL SELECT @c_pending, 'SHOPPING', '양말', 3000, 0, @today - INTERVAL 12 DAY
        UNION ALL SELECT @c_pending, NULL, NULL, 0, 1, @today - INTERVAL 4 DAY
        UNION ALL SELECT @c_pending, NULL, NULL, 0, 1, @today - INTERVAL 3 DAY
        UNION ALL SELECT @c_pending, NULL, NULL, 0, 1, @today - INTERVAL 2 DAY
        -- 완료-성공: 총지출 5,500
        UNION ALL SELECT @c_success, 'FOOD', '커피', 2000, 0, @today - INTERVAL 25 DAY
        UNION ALL SELECT @c_success, 'LIVING', '세제', 1500, 0, @today - INTERVAL 24 DAY
        UNION ALL SELECT @c_success, 'TRANSPORT', '지하철', 2000, 0, @today - INTERVAL 23 DAY
        UNION ALL SELECT @c_success, NULL, NULL, 0, 1, @today - INTERVAL 17 DAY
        UNION ALL SELECT @c_success, NULL, NULL, 0, 1, @today - INTERVAL 16 DAY
        UNION ALL SELECT @c_success, NULL, NULL, 0, 1, @today - INTERVAL 15 DAY
        -- 완료-실패: 총지출 12,000
        UNION ALL SELECT @c_fail, 'SHOPPING', '신발', 6000, 0, @today - INTERVAL 25 DAY
        UNION ALL SELECT @c_fail, 'FOOD', '저녁', 6000, 0, @today - INTERVAL 24 DAY
       ) x
 WHERE x.cid IS NOT NULL;

-- ── 배지 (BadgeGrantService 가 위 데이터로 계산하는 결과를 그대로 박는다) ──────────────
--   진행 중   : STREAK 3 (d-4~d0 연속 5일) + NO_SPEND 3
--   확정 대기 : STREAK 3 (d-4~d-2)          + NO_SPEND 3
--   성공 완료 : STREAK 3 (d-17~d-15)        + NO_SPEND 3 + CHALLENGE_SUCCESS
--   실패 완료·시작 전 : 없음
INSERT INTO `challenge_badge` (`challenge_id`, `badge_id`, `created_dt`)
SELECT x.cid, b.`badge_id`, @now
  FROM (
        SELECT @c_ongoing AS cid, 'STREAK' AS t, 3 AS v
        UNION ALL SELECT @c_ongoing, 'NO_SPEND', 3
        UNION ALL SELECT @c_pending, 'STREAK', 3
        UNION ALL SELECT @c_pending, 'NO_SPEND', 3
        UNION ALL SELECT @c_success, 'STREAK', 3
        UNION ALL SELECT @c_success, 'NO_SPEND', 3
        UNION ALL SELECT @c_success, 'CHALLENGE_SUCCESS', 1
       ) x
  JOIN `badge` b ON b.`type` = x.t AND b.`condition_value` = x.v
 WHERE x.cid IS NOT NULL;

COMMIT;

-- ── 검증 ─────────────────────────────────────────────────────────────
-- 기대값: role=USER, 게이트 3컬럼 + nickname_changed_dt 전부 NULL
SELECT `user_id`, `role`, `birth_date`, `terms_agreed_dt`, `privacy_agreed_dt`, `nickname_changed_dt`
  FROM `user` WHERE `user_id` = @uid;

-- 기대값 (start_date 순):
--   성공 완료  SUCCESS  기록 6  배지 3
--   실패 완료  FAIL     기록 2  배지 0
--   확정 대기  NULL     기록 4  배지 2
--   진행 중    NULL     기록 5  배지 2
--   시작 전    NULL     기록 0  배지 0
SELECT c.`name`, c.`start_date`, c.`end_date`, c.`result`,
       (SELECT COUNT(*) FROM `amount` a          WHERE a.`challenge_id` = c.`challenge_id`) AS amounts,
       (SELECT COUNT(*) FROM `challenge_badge` b WHERE b.`challenge_id` = c.`challenge_id`) AS badges
  FROM `challenge` c
 WHERE c.`user_id` = @uid
 ORDER BY c.`start_date`, c.`name`;
