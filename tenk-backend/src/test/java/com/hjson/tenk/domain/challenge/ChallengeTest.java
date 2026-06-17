package com.hjson.tenk.domain.challenge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class ChallengeTest {

    private final User user = User.create(AuthProvider.KAKAO, "kakao-1", "u@example.com", "tester");

    @Test
    void create_today_to_29days_inclusive_is_30_days_and_passes() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(29), 10_000);
        assertThat(c.getStartDate()).isEqualTo(today);
        assertThat(c.getEndDate()).isEqualTo(today.plusDays(29));
    }

    @Test
    void create_31_days_throws_period_invalid() {
        LocalDate today = LocalDate.now();
        assertThatThrownBy(() -> Challenge.create(user, "테스트 챌린지", today, today.plusDays(30), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_PERIOD_INVALID);
    }

    @Test
    void create_start_date_in_past_throws() {
        LocalDate today = LocalDate.now();
        assertThatThrownBy(() -> Challenge.create(user, "테스트 챌린지", today.minusDays(1), today.plusDays(5), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_PERIOD_INVALID);
    }

    @Test
    void create_end_before_start_throws() {
        LocalDate today = LocalDate.now();
        assertThatThrownBy(() -> Challenge.create(user, "테스트 챌린지", today.plusDays(5), today.plusDays(3), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_PERIOD_INVALID);
    }

    @Test
    void create_null_dates_throw() {
        LocalDate today = LocalDate.now();
        assertThatThrownBy(() -> Challenge.create(user, "테스트 챌린지", null, today, 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_PERIOD_INVALID);
        assertThatThrownBy(() -> Challenge.create(user, "테스트 챌린지", today, null, 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_PERIOD_INVALID);
    }

    @Test
    void isStarted_returns_false_before_start_date_and_true_on_and_after() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today.plusDays(2), today.plusDays(5), 10_000);
        assertThat(c.isStarted(today.plusDays(1))).isFalse();
        assertThat(c.isStarted(today.plusDays(2))).isTrue();
        assertThat(c.isStarted(today.plusDays(3))).isTrue();
    }

    @Test
    void isFinished_returns_false_on_end_date_and_true_after() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(3), 10_000);
        assertThat(c.isFinished(today.plusDays(3))).isFalse();
        assertThat(c.isFinished(today.plusDays(4))).isTrue();
    }

    @Test
    void containsDate_inclusive_both_ends() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(3), 10_000);
        assertThat(c.containsDate(today.minusDays(1))).isFalse();
        assertThat(c.containsDate(today)).isTrue();
        assertThat(c.containsDate(today.plusDays(3))).isTrue();
        assertThat(c.containsDate(today.plusDays(4))).isFalse();
    }

    @Test
    void markResult_twice_throws_already_finished() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(1), 10_000);
        c.markResult(ChallengeResult.SUCCESS);
        assertThatThrownBy(() -> c.markResult(ChallengeResult.FAIL))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_ALREADY_FINISHED);
    }

    @Test
    void create_trims_name() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "  외식 줄이기  ", today, today.plusDays(1), 10_000);
        assertThat(c.getName()).isEqualTo("외식 줄이기");
    }

    @Test
    void create_blank_name_throws_name_invalid() {
        LocalDate today = LocalDate.now();
        assertThatThrownBy(() -> Challenge.create(user, "   ", today, today.plusDays(1), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NAME_INVALID);
    }

    @Test
    void create_too_long_name_throws_name_invalid() {
        LocalDate today = LocalDate.now();
        String tooLong = "가".repeat(101);
        assertThatThrownBy(() -> Challenge.create(user, tooLong, today, today.plusDays(1), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NAME_INVALID);
    }

    @Test
    void create_control_char_name_throws_name_invalid() {
        LocalDate today = LocalDate.now();
        String withControlChar = "이름" + ((char) 7) + "삽입";
        assertThatThrownBy(() -> Challenge.create(user, withControlChar, today, today.plusDays(1), 10_000))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NAME_INVALID);
    }

    @Test
    void rename_changes_name_and_trims() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(1), 10_000);
        c.rename("  새 이름  ");
        assertThat(c.getName()).isEqualTo("새 이름");
    }

    @Test
    void rename_blank_throws_name_invalid() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(1), 10_000);
        assertThatThrownBy(() -> c.rename("  "))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NAME_INVALID);
    }

    @Test
    void softDelete_sets_flag_and_timestamp() {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, "테스트 챌린지", today, today.plusDays(1), 10_000);
        assertThat(c.isDeleted()).isFalse();
        c.softDelete();
        assertThat(c.isDeleted()).isTrue();
        assertThat(c.getDeletedDt()).isNotNull();
    }
}
