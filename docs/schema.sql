-- ============================================================
-- Tenk 백엔드 DDL
-- ddl-auto=validate 이므로 운영 전 이 스크립트를 수동 적용해야 함.
-- ERD 대비 변경 사항:
--   user             : password 제거, provider/provider_user_id/email 추가
--                      + nickname_changed_dt (직접 변경 마지막 시각, NULL=미변경) — 하루 1회 제한용
--   challenge        : start_date / end_date (DATE, 양끝 포함) + result 컬럼 추가
--   amount           : created_dt (감사용) + spent_dt (사용자 지정 발생 일시) + is_no_spend 추가, category/content NULL 허용
--                      + no_spend_day_key (생성 컬럼) + uk_amount_no_spend_day 인덱스로 "무지출 하루 1회" 강제
--                      + memo (NULL 허용, 영상 export 시 자막 디폴트 오버라이드 용도)
--   refresh_token    : 신설 — JWT 모바일 인증의 RT 보관소
-- ============================================================

use `tenk`;

-- 외래키 순서를 고려한 드롭
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
    `provider`            ENUM('GOOGLE', 'KAKAO', 'NAVER')               NOT NULL,
    `provider_user_id`    VARCHAR(255)                                   NOT NULL,
    `email`               VARCHAR(255)                                   NULL,
    `nickname`            VARCHAR(255)                                   NOT NULL,
    -- 사용자가 '내 정보' 또는 가입 화면에서 직접 닉네임을 변경한 마지막 시각.
    -- NULL = 아직 한 번도 변경한 적 없음. 하루 1회 제한은 이 컬럼의 DATE 부분과 오늘을 비교.
    `nickname_changed_dt` DATETIME                                       NULL,
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
    `result`            ENUM('SUCCESS', 'FAIL')                          NULL,
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
    `category`          VARCHAR(255)                                     NULL,
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
    `type`              ENUM('STREAK', 'NO_SPEND', 'CHALLENGE_SUCCESS')  NOT NULL,
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
