package com.hjson.tenk.domain.badge;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * {@link BadgeScheduler#dailyReconciliation()} 을 검증한다.
 * <ul>
 *   <li>배치는 결과 확정을 하지 않는다 — 확정은 사용자 수동 호출({@code finalize})만.</li>
 *   <li>{@code badgeGrantService.evaluateAllActive()} : 이벤트가 누락된 케이스 보강 (챌린지 단위).</li>
 * </ul>
 *
 * <p>이벤트 path 는 {@link BadgeEventIntegrationTest} 가 커버. 여기는 "이벤트가 비어있어도
 * 새벽 1시 배치로 보강된다" 만 본다 — 그래서 amount 는 native insert 로 직접 박아 이벤트를
 * 우회한다.
 */
class BadgeSchedulerIntegrationTest extends IntegrationTestBase {

    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired BadgeRepository badgeRepository;
    @Autowired ChallengeBadgeRepository challengeBadgeRepository;
    @Autowired BadgeScheduler badgeScheduler;

    @Test
    @DisplayName("배치는 종료된 챌린지를 자동 확정하지 않는다 (확정은 사용자 수동 호출만)")
    void batchDoesNotAutoFinalize() {
        Long userId = createUser("kakao-batch-1");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().minusDays(1), 10_000);

        Challenge before = challengeRepository.findById(challengeId).orElseThrow();
        assertThat(before.getResult()).isNull();

        badgeScheduler.dailyReconciliation();

        Challenge after = challengeRepository.findById(challengeId).orElseThrow();
        assertThat(after.getResult()).as("자동 확정 제거 — 결과는 미확정 유지").isNull();

        Badge cs = badgeRepository.findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(after, cs))
                .as("확정 안 됐으므로 CHALLENGE_SUCCESS 미지급").isFalse();
    }

    @Test
    @DisplayName("이벤트 없이 DB 에 무지출 3일이 박혀 있어도 배치가 NO_SPEND 3 을 보강 지급한다")
    void batchBackfillsMissedNoSpendBadge() {
        Long userId = createUser("kakao-batch-2");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(4), LocalDate.now().plusDays(1), 1_000_000);

        // 이벤트 없이 직접 insert → AFTER_COMMIT 이 안 도는 시뮬레이션
        insertNoSpend(challengeId, LocalDate.now().minusDays(2));
        insertNoSpend(challengeId, LocalDate.now().minusDays(1));
        insertNoSpend(challengeId, LocalDate.now());

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3))
                .as("이벤트 우회로 박힌 직후에는 아직 배지 없음").isFalse();

        badgeScheduler.dailyReconciliation();

        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3))
                .as("배치가 evaluateAllActive 로 보강").isTrue();
    }

    // ---------- helpers ----------

    private Long createUser(String providerUserId) {
        return tx.execute(status -> {
            User u = User.create(AuthProvider.KAKAO, providerUserId, providerUserId + "@example.com", "tester");
            return userRepository.save(u).getId();
        });
    }

    /**
     * 임의의 startDate/endDate 챌린지를 만든다. {@link Challenge#create} invariant 우회를 위해
     * 일단 today/today+1 로 생성한 뒤 reflection 으로 덮어쓴다. BadgeEventIntegrationTest 와 동일 패턴.
     */
    private Long createChallenge(Long userId, LocalDate startDate, LocalDate endDate, int targetAmount) {
        return tx.execute(status -> {
            User user = userRepository.findById(userId).orElseThrow();
            Challenge c = Challenge.create(user, LocalDate.now(), LocalDate.now().plusDays(1), targetAmount);
            Challenge saved = challengeRepository.save(c);
            ReflectionTestUtils.setField(saved, "startDate", startDate);
            ReflectionTestUtils.setField(saved, "endDate", endDate);
            return saved.getId();
        });
    }

    private void insertNoSpend(Long challengeId, LocalDate day) {
        tx.executeWithoutResult(status ->
                em.createNativeQuery(
                                "INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt, created_dt) "
                                        + "VALUES (?1, NULL, NULL, 0, 1, ?2, NOW())")
                        .setParameter(1, challengeId)
                        .setParameter(2, day.atTime(12, 0))
                        .executeUpdate());
    }
}
