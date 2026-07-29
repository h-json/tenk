-- ============================================================
-- Tenk 백엔드 DDL
-- ddl-auto=validate 이므로 운영 전 이 스크립트를 수동 적용해야 함.
-- ERD 대비 변경 사항:
--   user             : password 제거, provider/provider_user_id 추가 (email 은 2026-07-26 수집 중단·컬럼 삭제)
--                      + nickname_changed_dt (직접 변경 마지막 시각, NULL=미변경) — 24시간 1회 제한용
--                      + terms/privacy_agreed_dt (필수 동의 시각) + birth_date (연령 확인) + gender (선택)
--                      + role (USER/TESTER — 테스터만 시딩 권한)
--   challenge        : start_date / end_date (DATE, 양끝 포함) + result 컬럼 추가
--   amount           : created_dt (감사용) + spent_dt (사용자 지정 발생 일시) + is_no_spend 추가, category/content NULL 허용
--                      + no_spend_day_key (생성 컬럼) + uk_amount_no_spend_day 인덱스로 "무지출 하루 1회" 강제
--                      + memo (NULL 허용, 영상 export 시 자막 디폴트 오버라이드 용도)
--   refresh_token    : 신설 — JWT 모바일 인증의 RT 보관소
--   app_config       : 신설 — 앱 최신/최소 지원 버전 + 스토어 URL (단일 행). 강제/권장 업데이트 게이트용
--   feedback         : 신설 — 메뉴 '의견 보내기'. 익명(user_id 없음) + 회신용 이메일만 선택 개인정보
-- ============================================================
-- 코드성 컬럼 규칙 (2026-07-30 통일) — 진실의 원천은 CLAUDE.md "코딩 컨벤션 — 백엔드"
--   Java enum 을 저장하는 컬럼은 **VARCHAR + @Enumerated(EnumType.STRING)** 로 통일한다.
--   MariaDB 네이티브 ENUM(...) 을 쓰지 말 것 — 상수 목록이 코드와 DB 두 곳에 생겨 어긋나고,
--   값을 추가·삭제할 때마다 ALTER TABLE 이 필요해진다 (VARCHAR 면 UPDATE 한 줄로 끝난다).
--   라이브 DB 에는 아래를 수동 적용해야 한다 (코드 배포와 순서 무관 — 양쪽 자료형 다 validate 통과):
--     ALTER TABLE `user`      MODIFY COLUMN `provider` VARCHAR(20) NOT NULL;
--     ALTER TABLE `challenge` MODIFY COLUMN `result`   VARCHAR(20) NULL;
--     ALTER TABLE `badge`     MODIFY COLUMN `type`     VARCHAR(30) NOT NULL;
-- ============================================================

use `tenk`;

-- 외래키 순서를 고려한 드롭
DROP TABLE IF EXISTS `feedback`;
DROP TABLE IF EXISTS `withdrawal_feedback`;  -- 둘 다 독립 테이블 (FK 없음)
DROP TABLE IF EXISTS `app_config`;
DROP TABLE IF EXISTS `refresh_token`;
DROP TABLE IF EXISTS `challenge_badge`;
DROP TABLE IF EXISTS `user_badge`;  -- 구 테이블 (있으면 정리)
DROP TABLE IF EXISTS `badge`;
DROP TABLE IF EXISTS `media_file`;
DROP TABLE IF EXISTS `amount`;
DROP TABLE IF EXISTS `challenge`;
DROP TABLE IF EXISTS `user`;

CREATE TABLE `user` (
    `user_id`             BIGINT AUTO_INCREMENT                          NOT NULL,
    -- AuthProvider enum name (GOOGLE/KAKAO/NAVER/TEST). 2026-07-30 네이티브 ENUM → VARCHAR
    -- (코드성 컬럼 자료형 통일 — 아래 상단 주석 "코드성 컬럼 규칙" 참고).
    `provider`            VARCHAR(20)                                    NOT NULL,
    `provider_user_id`    VARCHAR(255)                                   NOT NULL,
    -- email 컬럼은 2026-07-26 제거됨. 카카오 '카카오계정(이메일)' 동의항목이 개인 개발자 일반 앱에선
    -- '권한 없음'이라 늘 NULL 이었고, 서비스 기능에 쓰이지도 않아 수집 자체를 접었다 (최소수집 원칙).
    -- 라이브 DB 는 아래를 수동 적용해야 부팅됨 (ddl-auto=validate):
    --   ALTER TABLE `user` DROP COLUMN `email`;
    `nickname`            VARCHAR(255)                                   NOT NULL,
    -- 사용자가 '내 정보' 또는 가입 화면에서 직접 닉네임을 변경한 마지막 시각.
    -- NULL = 아직 한 번도 변경한 적 없음. 24시간 1회 제한은 이 값 + 24h 와 현재 시각을 비교 (날짜/자정 기준 아님).
    `nickname_changed_dt` DATETIME                                       NULL,
    -- 필수 동의(이용약관 / 개인정보 수집·이용) 시각. NULL = 미동의 → 클라이언트가 동의 화면 게이트.
    -- 라이브 DB 는 이 컬럼을 ALTER 로 추가해야 함 (dbinit 볼륨은 최초 부팅만 시딩):
    --   ALTER TABLE `user` ADD COLUMN `terms_agreed_dt` DATETIME NULL AFTER `nickname_changed_dt`,
    --                      ADD COLUMN `privacy_agreed_dt` DATETIME NULL AFTER `terms_agreed_dt`;
    `terms_agreed_dt`     DATETIME                                       NULL,
    `privacy_agreed_dt`   DATETIME                                       NULL,
    -- 연령 확인 화면에서 입력받은 생년월일. NULL = 미확인 → 클라이언트가 연령 확인 화면 게이트.
    -- 만 14세 미만 값은 저장되지 않는다 (즉시 계정 파기 후 거부). 라이브 DB 는 ALTER 로 추가:
    --   ALTER TABLE `user` ADD COLUMN `birth_date` DATE NULL AFTER `privacy_agreed_dt`;
    `birth_date`          DATE                                           NULL,
    -- 성별 — 선택 입력. NULL = 미입력(정상). 기능에 쓰이지 않고 통계 목적으로만 보관하며,
    -- '내 정보' 화면에서 언제든 다시 NULL 로 되돌릴 수 있다. 라이브 DB 는 ALTER 로 추가:
    --   ALTER TABLE `user` ADD COLUMN `gender` VARCHAR(10) NULL AFTER `birth_date`;
    `gender`              VARCHAR(10)                                    NULL,
    -- 계정 권한. 기본 'USER', 내부 테스터만 SQL 로 'TESTER' 승격(테스트 데이터 시딩 권한). 추후 'ADMIN' 여지.
    -- 라이브 DB 는 ALTER 로 추가:
    --   ALTER TABLE `user` ADD COLUMN `role` VARCHAR(20) NOT NULL DEFAULT 'USER' AFTER `gender`;
    -- 내부 테스터 승격 예:  UPDATE `user` SET `role`='TESTER' WHERE `provider`='KAKAO' AND `provider_user_id`='<카카오회원번호>';
    `role`                VARCHAR(20)   DEFAULT 'USER'                   NOT NULL,
    `created_dt`          DATETIME      DEFAULT CURRENT_TIMESTAMP        NOT NULL,
    `updated_dt`          DATETIME      DEFAULT CURRENT_TIMESTAMP        NOT NULL,
    `is_deleted`          TINYINT(1)    DEFAULT 0                        NOT NULL,
    `deleted_dt`          DATETIME                                       NULL,
    PRIMARY KEY (`user_id`),
    UNIQUE KEY `uk_user_provider` (`provider`, `provider_user_id`)
);

CREATE TABLE `challenge` (
    `challenge_id`      BIGINT AUTO_INCREMENT                            NOT NULL,
    `user_id`           BIGINT                                           NOT NULL,
    `name`              VARCHAR(100)                                     NOT NULL,
    `start_date`        DATE                                             NOT NULL,
    `end_date`          DATE                                             NOT NULL,
    `target_amount`     INT           DEFAULT 10000                      NOT NULL,
    `result`            VARCHAR(20)                                      NULL,  -- ChallengeResult enum name
    `created_dt`        DATETIME      DEFAULT CURRENT_TIMESTAMP          NOT NULL,
    `updated_dt`        DATETIME      DEFAULT CURRENT_TIMESTAMP          NOT NULL,
    `is_deleted`        TINYINT(1)    DEFAULT 0                          NOT NULL,
    `deleted_dt`        DATETIME                                         NULL,
    PRIMARY KEY (`challenge_id`),
    KEY `idx_challenge_user` (`user_id`),
    CONSTRAINT `fk_challenge_user`
        FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
);

CREATE TABLE `amount` (
    `amount_id`         BIGINT AUTO_INCREMENT                            NOT NULL,
    `challenge_id`      BIGINT                                           NOT NULL,
    -- SpendCategory enum name (고정 9종). 무지출이면 NULL.
    -- 2026-07-30: 엔티티가 String → @Enumerated(STRING) 로 바뀌면서 폭도 255 → 20 으로 줄였다.
    -- ⚠️ 라이브 DB 는 아래를 **이미지 재배포 전에** 적용할 것 — enum 에 없는 값이 남아 있으면
    --    그 row 조회가 예외로 죽는다 (Gender.OTHER 와 같은 함정).
    --   -- (a) 무엇을 접게 되는지 먼저 남겨둘 것:
    --   SELECT `category`, COUNT(*) FROM `amount` WHERE `is_no_spend`=0 GROUP BY `category`;
    --   -- (b) 카테고리 검증(2026-07-11) 이전에 저장된 자유 텍스트를 ETC 로 접는다.
    --   --     클라이언트가 이미 미매칭 코드를 '기타'로 폴백해 그리고 있어 화면상 변화는 없다.
    --   UPDATE `amount` SET `category`='ETC'
    --    WHERE `is_no_spend`=0 AND `category` IS NOT NULL
    --      AND `category` NOT IN ('FOOD','TRANSPORT','SHOPPING','LEISURE',
    --                             'HEALTH','EDUCATION','EVENT','LIVING','ETC');
    --   ALTER TABLE `amount` MODIFY COLUMN `category` VARCHAR(20) NULL;
    `category`          VARCHAR(20)                                      NULL,
    `content`           VARCHAR(255)                                     NULL,
    `amount`            INT                                              NOT NULL,
    `is_no_spend`       TINYINT(1)    DEFAULT 0                          NOT NULL,
    `memo`              VARCHAR(500)                                     NULL,
    `spent_dt`          DATETIME                                         NOT NULL,
    `created_dt`        DATETIME      DEFAULT CURRENT_TIMESTAMP          NOT NULL,
    -- "무지출 하루 1회" 강제용 생성 컬럼. is_no_spend=1 일 때만 challenge+날짜로 키를 만들고,
    -- 지출 row 에서는 NULL → MariaDB UNIQUE 인덱스는 NULL 중복을 허용하므로 지출은 영향 없음.
    -- 컬럼 자체는 INSERT/UPDATE 불가 (GENERATED ALWAYS).
    `no_spend_day_key`  VARCHAR(64)   GENERATED ALWAYS AS (
        CASE WHEN `is_no_spend` = 1
            THEN CONCAT(`challenge_id`, '-', DATE(`spent_dt`))
            ELSE NULL END
    ) VIRTUAL,
    PRIMARY KEY (`amount_id`),
    UNIQUE KEY `uk_amount_no_spend_day` (`no_spend_day_key`),
    KEY `idx_amount_challenge` (`challenge_id`),
    KEY `idx_amount_challenge_spent` (`challenge_id`, `spent_dt`),
    CONSTRAINT `fk_amount_challenge`
        FOREIGN KEY (`challenge_id`) REFERENCES `challenge` (`challenge_id`)
);

CREATE TABLE `media_file` (
    `file_id`           BIGINT AUTO_INCREMENT                            NOT NULL,
    `amount_id`         BIGINT                                           NOT NULL,
    `file_path`         VARCHAR(255)                                     NOT NULL,
    `original_name`     VARCHAR(255)                                     NOT NULL,
    PRIMARY KEY (`file_id`),
    KEY `idx_media_file_amount` (`amount_id`),
    CONSTRAINT `fk_media_file_amount`
        FOREIGN KEY (`amount_id`) REFERENCES `amount` (`amount_id`)
);

CREATE TABLE `badge` (
    `badge_id`          BIGINT AUTO_INCREMENT                            NOT NULL,
    `type`              VARCHAR(30)                                      NOT NULL,  -- BadgeType enum name
    `condition_value`   INT                                              NOT NULL,
    `icon_path`         VARCHAR(255)                                     NOT NULL,
    PRIMARY KEY (`badge_id`),
    UNIQUE KEY `uk_badge_type_value` (`type`, `condition_value`)
);

-- 챌린지 단위로 부여되는 배지. 유저 단위 누적(=업적)은 별도 테이블로 추후 추가.
CREATE TABLE `challenge_badge` (
    `challenge_badge_id` BIGINT AUTO_INCREMENT                           NOT NULL,
    `challenge_id`       BIGINT                                          NOT NULL,
    `badge_id`           BIGINT                                          NOT NULL,
    `created_dt`         DATETIME     DEFAULT CURRENT_TIMESTAMP          NOT NULL,
    PRIMARY KEY (`challenge_badge_id`),
    UNIQUE KEY `uk_challenge_badge` (`challenge_id`, `badge_id`),
    KEY `idx_challenge_badge_challenge` (`challenge_id`),
    CONSTRAINT `fk_challenge_badge_challenge`
        FOREIGN KEY (`challenge_id`) REFERENCES `challenge` (`challenge_id`),
    CONSTRAINT `fk_challenge_badge_badge`
        FOREIGN KEY (`badge_id`) REFERENCES `badge` (`badge_id`)
);

CREATE TABLE `refresh_token` (
    `refresh_token_id`  BIGINT AUTO_INCREMENT                            NOT NULL,
    `user_id`           BIGINT                                           NOT NULL,
    `token_hash`        VARCHAR(255)                                     NOT NULL,
    `expires_dt`        DATETIME                                         NOT NULL,
    `is_revoked`        TINYINT(1)    DEFAULT 0                          NOT NULL,
    `created_dt`        DATETIME      DEFAULT CURRENT_TIMESTAMP          NOT NULL,
    PRIMARY KEY (`refresh_token_id`),
    UNIQUE KEY `uk_refresh_token_hash` (`token_hash`),
    KEY `idx_refresh_token_user` (`user_id`),
    CONSTRAINT `fk_refresh_token_user`
        FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
);

-- 탈퇴 사유 (선택 입력). **user_id 를 일부러 두지 않는다** — 계정과 연결하지 않으면 개인정보가 아니라
-- 익명정보라서 개인정보처리방침 수집표에 항목을 늘릴 필요가 없고, 보관 기간 논쟁 없이 계속 보존할 수
-- 있으며, 계정이 파기된 뒤에도 통계가 남는다. 여기에 user 참조나 식별 가능한 값을 추가하지 말 것.
-- 계정 파기 배치(WithdrawnUserPurgeService)의 삭제 대상이 아니다.
-- 라이브 DB 는 이 테이블을 CREATE 로 추가해야 함 (dbinit 볼륨은 최초 부팅만 시딩).
CREATE TABLE `withdrawal_feedback` (
    `withdrawal_feedback_id` BIGINT AUTO_INCREMENT NOT NULL,
    `reason_code`            VARCHAR(30)           NOT NULL,  -- WithdrawalReason enum name
    `detail`                 VARCHAR(200)          NULL,      -- '기타' 선택 시의 자유 서술
    `created_dt`             DATETIME              NOT NULL,
    PRIMARY KEY (`withdrawal_feedback_id`)
);

-- 앱에서 보낸 의견 (메뉴 → '의견 보내기'). withdrawal_feedback 과 같은 이유로 **user_id 를 두지 않는다**
-- (익명정보 → 보관 기간 논쟁 없음, 계정 파기 배치의 삭제 대상 아님).
-- 단 `reply_email` 은 예외적으로 개인정보다 — **선택 입력**이고 적은 사람에게 답장할 때만 쓴다.
-- 이 컬럼 때문에 개인정보처리방침 수집표에 '회신용 이메일(선택)' 한 줄이 있다. 지우거나 필수로 바꾸면
-- privacy.html 과 Play 데이터 안전 답안도 같이 손볼 것.
-- 진단 정보(app_version/platform/os_version)는 틀려도 거부하지 않고 잘라 담는다.
-- 라이브 DB 는 이 테이블을 CREATE 로 추가해야 함 (dbinit 볼륨은 최초 부팅만 시딩).
CREATE TABLE `feedback` (
    `feedback_id`  BIGINT AUTO_INCREMENT NOT NULL,
    `type`         VARCHAR(20)           NOT NULL,  -- FeedbackType enum name
    `content`      VARCHAR(1000)         NOT NULL,
    `reply_email`  VARCHAR(100)          NULL,      -- 선택. 적은 경우에만 답변 대상
    `app_version`  VARCHAR(20)           NULL,      -- 이하 진단용 (클라이언트가 함께 전송)
    `platform`     VARCHAR(10)           NULL,      -- android / ios
    `os_version`   VARCHAR(100)          NULL,
    `created_dt`   DATETIME              NOT NULL,
    PRIMARY KEY (`feedback_id`)
);

-- 앱 버전 정책 (단일 행). 강제/권장 업데이트 게이트가 이 값을 읽어 클라 버전과 비교한다.
--   min_supported_version : 이 버전 미만은 강제 업데이트(앱 사용 차단)
--   latest_version        : 이 버전 미만은 권장 업데이트(안내만, 계속 사용 가능)
-- 값은 재배포 없이 SQL 로 갱신한다 (관리자 UI 없음 — TESTER 승격과 동일한 운영 방식):
--   UPDATE `app_config` SET `latest_version`='1.1.0', `min_supported_version`='1.0.0' WHERE `app_config_id`=1;
-- 라이브 DB 는 이 테이블을 CREATE + INSERT 로 추가해야 함 (dbinit 볼륨은 최초 부팅만 시딩):
--   위 CREATE TABLE `app_config` + 아래 INSERT 를 그대로 실행.
CREATE TABLE `app_config` (
    `app_config_id`         BIGINT AUTO_INCREMENT                       NOT NULL,
    `min_supported_version` VARCHAR(20)                                 NOT NULL,
    `latest_version`        VARCHAR(20)                                 NOT NULL,
    `android_store_url`     VARCHAR(255)                                NULL,
    `ios_store_url`         VARCHAR(255)                                NULL,
    `updated_dt`            DATETIME      DEFAULT CURRENT_TIMESTAMP     NOT NULL,
    PRIMARY KEY (`app_config_id`)
);

INSERT INTO `app_config`
    (`app_config_id`, `min_supported_version`, `latest_version`, `android_store_url`, `ios_store_url`)
VALUES
    (1, '1.0.0', '1.0.0',
     'https://play.google.com/store/apps/details?id=com.hjson.tenk_app', NULL);

-- ============================================================
-- 배지 마스터 데이터 (3 / 7 / 14 / 30 단계)
-- icon_path 는 추후 실제 리소스에 맞춰 갱신
-- ============================================================
INSERT INTO `badge` (`type`, `condition_value`, `icon_path`) VALUES
    ('STREAK',            3,  '/badges/streak_3.png'),
    ('STREAK',            7,  '/badges/streak_7.png'),
    ('STREAK',            14, '/badges/streak_14.png'),
    ('STREAK',            30, '/badges/streak_30.png'),
    ('NO_SPEND',          3,  '/badges/no_spend_3.png'),
    ('NO_SPEND',          7,  '/badges/no_spend_7.png'),
    ('NO_SPEND',          14, '/badges/no_spend_14.png'),
    ('NO_SPEND',          30, '/badges/no_spend_30.png'),
    ('CHALLENGE_SUCCESS', 1,  '/badges/challenge_success.png');
