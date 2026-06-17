package com.hjson.tenk.domain.amount;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * {@link AmountRepository#findUserAmountsBetween} 경계 검증.
 *
 * <p>이 쿼리는 {@link com.hjson.tenk.domain.badge.BadgeGrantService} 의
 * streak/no-spend 계산에 직접 쓰이므로 {@code [from, toExclusive)} 반열린 구간 의미가
 * 정확해야 한다. 단위 테스트는 도메인 로직만 보고 JPA 쿼리는 못 보므로 여기서만 검증.
 *
 * <p>챌린지/유저 생성 패턴은 {@link com.hjson.tenk.domain.badge.BadgeEventIntegrationTest} 와 동일
 * (validatePeriod invariant 를 reflection 으로 우회).
 */
class AmountRepositoryIntegrationTest extends IntegrationTestBase {

    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired AmountRepository amountRepository;

    @Test
    @DisplayName("from 은 포함, toExclusive 는 제외 — 자정 경계 정확히 동작")
    void halfOpenIntervalBoundaries() {
        Long userId = createUser("kakao-range-1");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(1));

        LocalDate base = LocalDate.now().minusDays(3);
        // from 직전 (제외)
        insertAmount(challengeId, base.minusDays(1).atTime(23, 59, 59));
        // from 정확히 (포함)
        insertAmount(challengeId, base.atStartOfDay());
        // 범위 안
        insertAmount(challengeId, base.atTime(12, 0));
        // toExclusive 직전 (포함)
        insertAmount(challengeId, base.plusDays(1).atStartOfDay().minusNanos(1));
        // toExclusive 정확히 (제외)
        insertAmount(challengeId, base.plusDays(1).atStartOfDay());

        List<Amount> result = amountRepository.findUserAmountsBetween(
                userId,
                base.atStartOfDay(),
                base.plusDays(1).atStartOfDay()
        );

        assertThat(result).hasSize(3);
        assertThat(result)
                .extracting(Amount::getSpentDt)
                .allMatch(dt -> !dt.isBefore(base.atStartOfDay()))
                .allMatch(dt -> dt.isBefore(base.plusDays(1).atStartOfDay()));
    }

    @Test
    @DisplayName("결과는 spentDt 오름차순으로 정렬된다")
    void resultSortedBySpentDtAsc() {
        Long userId = createUser("kakao-range-2");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(1));

        LocalDate day = LocalDate.now().minusDays(2);
        // 일부러 시간 역순으로 박음
        insertAmount(challengeId, day.atTime(15, 0));
        insertAmount(challengeId, day.atTime(9, 0));
        insertAmount(challengeId, day.atTime(20, 0));

        List<Amount> result = amountRepository.findUserAmountsBetween(
                userId,
                day.atStartOfDay(),
                day.plusDays(1).atStartOfDay()
        );

        assertThat(result).extracting(Amount::getSpentDt)
                .containsExactly(
                        day.atTime(9, 0),
                        day.atTime(15, 0),
                        day.atTime(20, 0)
                );
    }

    @Test
    @DisplayName("다른 사용자의 amount 는 섞여 들어오지 않는다")
    void filtersByUserId() {
        Long meId = createUser("kakao-me");
        Long otherId = createUser("kakao-other");
        Long myChallenge = createChallenge(meId, LocalDate.now().minusDays(3), LocalDate.now().plusDays(1));
        Long otherChallenge = createChallenge(otherId, LocalDate.now().minusDays(3), LocalDate.now().plusDays(1));

        LocalDate day = LocalDate.now().minusDays(1);
        insertAmount(myChallenge, day.atTime(12, 0));
        insertAmount(otherChallenge, day.atTime(12, 0));
        insertAmount(otherChallenge, day.atTime(14, 0));

        List<Amount> mine = amountRepository.findUserAmountsBetween(
                meId, day.atStartOfDay(), day.plusDays(1).atStartOfDay());
        List<Amount> theirs = amountRepository.findUserAmountsBetween(
                otherId, day.atStartOfDay(), day.plusDays(1).atStartOfDay());

        assertThat(mine).hasSize(1);
        assertThat(theirs).hasSize(2);
    }

    @Test
    @DisplayName("범위 안에 데이터가 없으면 빈 리스트")
    void emptyWhenNothingInRange() {
        Long userId = createUser("kakao-empty");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(1));

        // 범위 밖에만 박는다
        insertAmount(challengeId, LocalDate.now().minusDays(5).atTime(12, 0));

        LocalDate target = LocalDate.now().minusDays(2);
        List<Amount> result = amountRepository.findUserAmountsBetween(
                userId, target.atStartOfDay(), target.plusDays(1).atStartOfDay());

        assertThat(result).isEmpty();
    }

    @Test
    @DisplayName("BadgeGrantService 호출 패턴 — 60일 lookback 으로 흩어진 날짜 전부 조회")
    void wideRangeAcrossMultipleDays() {
        Long userId = createUser("kakao-wide");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(10), LocalDate.now().plusDays(1));

        insertAmount(challengeId, LocalDate.now().minusDays(7).atTime(10, 0));
        insertAmount(challengeId, LocalDate.now().minusDays(3).atTime(10, 0));
        insertAmount(challengeId, LocalDate.now().atTime(10, 0));

        // BadgeGrantService 와 동일한 경계: [today-60, today+1)
        List<Amount> result = amountRepository.findUserAmountsBetween(
                userId,
                LocalDate.now().minusDays(60).atStartOfDay(),
                LocalDate.now().plusDays(1).atStartOfDay()
        );

        assertThat(result).hasSize(3);
    }

    // ---------- helpers ----------

    private Long createUser(String providerUserId) {
        return tx.execute(status -> {
            User u = User.create(AuthProvider.KAKAO, providerUserId, providerUserId + "@example.com", "tester");
            return userRepository.save(u).getId();
        });
    }

    private Long createChallenge(Long userId, LocalDate startDate, LocalDate endDate) {
        return tx.execute(status -> {
            User user = userRepository.findById(userId).orElseThrow();
            Challenge c = Challenge.create(user, "테스트 챌린지", LocalDate.now(), LocalDate.now().plusDays(1), 1_000_000);
            Challenge saved = challengeRepository.save(c);
            ReflectionTestUtils.setField(saved, "startDate", startDate);
            ReflectionTestUtils.setField(saved, "endDate", endDate);
            return saved.getId();
        });
    }

    /// 쿼리 범위 검증이 목적이라 영상 필수·금액 검증 같은 도메인 룰은 우회한다. 같은 challenge+날짜에
    /// 여러 건 박는 시나리오가 있어 무지출(is_no_spend=1)로 박으면 uk_amount_no_spend_day 와 충돌 → 지출로 박는다.
    private void insertAmount(Long challengeId, LocalDateTime spentDt) {
        tx.executeWithoutResult(status ->
                em.createNativeQuery(
                                "INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt, created_dt) "
                                        + "VALUES (?1, 'x', 'x', 1, 0, ?2, NOW())")
                        .setParameter(1, challengeId)
                        .setParameter(2, spentDt)
                        .executeUpdate());
    }
}
