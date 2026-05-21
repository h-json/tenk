package com.hjson.tenk.domain.badge;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.amount.AmountService;
import com.hjson.tenk.domain.amount.dto.AmountCreateRequest;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeService;
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
 * 챌린지 단위 배지 자동 지급 E2E.
 *
 * <p>핸드오프 §1의 검증 항목 — {@code @TransactionalEventListener(AFTER_COMMIT)} 가 실제
 * 커밋 후 호출되어 배지가 DB ({@code challenge_badge} 테이블)에 기록되는지를 본다.
 * 단위 테스트({@link BadgeGrantServiceTest})는 정책만 커버하므로 propagation 자체는
 * 여기서만 확인 가능.
 *
 * <p><b>왜 reflection 으로 startDate / endDate 를 사후에 박는가?</b>
 * <ul>
 *   <li>{@link Challenge#create} invariant: {@code startDate >= today}. API 로는 과거
 *       시작일을 만들 수 없다.</li>
 *   <li>하지만 NO_SPEND 3 단계는 그제~오늘 3일치 spentDt 가 필요하므로 챌린지의 startDate 가
 *       today-2 이하여야 한다.</li>
 *   <li>따라서 정상 생성 후 startDate / endDate 만 reflection 으로 backdate.</li>
 * </ul>
 */
class BadgeEventIntegrationTest extends IntegrationTestBase {

    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired ChallengeService challengeService;
    @Autowired AmountService amountService;
    @Autowired ChallengeBadgeRepository challengeBadgeRepository;
    @Autowired BadgeRepository badgeRepository;
    @Autowired BadgeGrantService badgeGrantService;

    @Test
    @DisplayName("[가설검증] grantChallengeSuccess 를 직접 호출하면 challenge_badge 가 정상 저장된다")
    void grantChallengeSuccessDirectCall() {
        Long userId = createUser("kakao-direct");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().minusDays(1), 10_000);

        // 이벤트 우회 — AFTER_COMMIT 콜백 안이 아니라 평범한 호출
        badgeGrantService.grantChallengeSuccess(
                challengeId, com.hjson.tenk.domain.challenge.ChallengeResult.SUCCESS);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge cs = badgeRepository.findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, cs)).isTrue();
    }

    @Test
    @DisplayName("무지출 3일 연속 기록 시 NO_SPEND 3 배지가 AFTER_COMMIT 으로 지급된다")
    void noSpendThreeDaysGrantsBadge() {
        Long userId = createUser("kakao-nospend");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().plusDays(1), 1_000_000);

        recordNoSpendOn(userId, challengeId, LocalDate.now().minusDays(2));
        recordNoSpendOn(userId, challengeId, LocalDate.now().minusDays(1));
        recordNoSpendOn(userId, challengeId, LocalDate.now());

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        Badge streak3 = badgeRepository.findByTypeAndConditionValue(BadgeType.STREAK, 3).orElseThrow();
        Badge noSpend7 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 7).orElseThrow();

        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isTrue();
        // 3일 무지출은 STREAK 3 단계도 같이 충족 (모든 날 기록은 했으므로)
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, streak3)).isTrue();
        // 7단계는 미달
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend7)).isFalse();
    }

    @Test
    @DisplayName("같은 날 무지출이 여러 건이어도 배지 단계는 같다 (Set 기반 카운트)")
    void multipleNoSpendOnSameDayCountAsOne() {
        Long userId = createUser("kakao-dup");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().plusDays(1), 1_000_000);

        // 오늘 2건, 어제 1건. 그제는 비어있음 → streak 2일 → 배지 미지급.
        recordNoSpendOn(userId, challengeId, LocalDate.now().minusDays(1));
        recordNoSpendOn(userId, challengeId, LocalDate.now());
        recordNoSpendOn(userId, challengeId, LocalDate.now());

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isFalse();
    }

    @Test
    @DisplayName("같은 날 지출 + 무지출이 끼면 그날은 NO_SPEND 대상에서 빠진다")
    void spendBreaksNoSpendStreak() {
        Long userId = createUser("kakao-broken");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().plusDays(1), 1_000_000);

        recordNoSpendOn(userId, challengeId, LocalDate.now().minusDays(2));
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(2), 100, false); // 그제에 지출도 끼움 (영상 필수라 직접 insert)
        recordNoSpendOn(userId, challengeId, LocalDate.now().minusDays(1));
        recordNoSpendOn(userId, challengeId, LocalDate.now());

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        Badge streak3 = badgeRepository.findByTypeAndConditionValue(BadgeType.STREAK, 3).orElseThrow();

        // NO_SPEND: 그제는 지출이 끼어 자격 박탈 → 오늘+어제 2일만 → 3단계 미달
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isFalse();
        // STREAK: 어떤 기록이든 있으면 카운트 → 3일 모두 기록 있음 → 3단계 충족
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, streak3)).isTrue();
    }

    @Test
    @DisplayName("챌린지 finalize 가 SUCCESS 면 CHALLENGE_SUCCESS 배지가 AFTER_COMMIT 으로 지급된다")
    void challengeSuccessGrantsBadge() {
        Long userId = createUser("kakao-success");
        // 어제 종료된 챌린지 (지출 0 → target 통과)
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().minusDays(1), 10_000);

        challengeService.finalizeIfDue(userId, challengeId);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge cs = badgeRepository.findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, cs)).isTrue();
    }

    @Test
    @DisplayName("챌린지 finalize 가 FAIL 이면 CHALLENGE_SUCCESS 배지는 지급되지 않는다")
    void challengeFailDoesNotGrantBadge() {
        Long userId = createUser("kakao-fail");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().minusDays(1), 100);
        // target=100 인데 어제 500 지출 → FAIL
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(1), 500, false);

        challengeService.finalizeIfDue(userId, challengeId);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge cs = badgeRepository.findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, cs)).isFalse();
    }

    @Test
    @DisplayName("다른 챌린지의 기록은 이 챌린지의 배지에 영향을 주지 않는다 (챌린지 격리)")
    void otherChallengeRecordsDoNotLeakIntoThisChallenge() {
        Long userId = createUser("kakao-isolation");
        Long aId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().plusDays(1), 1_000_000);
        Long bId = createChallenge(userId, LocalDate.now().minusDays(2), LocalDate.now().plusDays(1), 1_000_000);

        // 챌린지 A 에만 3일 무지출 기록
        recordNoSpendOn(userId, aId, LocalDate.now().minusDays(2));
        recordNoSpendOn(userId, aId, LocalDate.now().minusDays(1));
        recordNoSpendOn(userId, aId, LocalDate.now());

        Challenge a = challengeRepository.findById(aId).orElseThrow();
        Challenge b = challengeRepository.findById(bId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();

        // A 는 NO_SPEND 3 받음, B 는 빈 챌린지라 못 받음
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(a, noSpend3)).isTrue();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(b, noSpend3)).isFalse();
    }

    // ---------- helpers ----------

    private Long createUser(String providerUserId) {
        return tx.execute(status -> {
            User u = User.create(AuthProvider.KAKAO, providerUserId, providerUserId + "@example.com", "tester");
            return userRepository.save(u).getId();
        });
    }

    /**
     * 임의의 startDate / endDate 를 가진 챌린지를 만든다. {@link Challenge#create} invariant
     * ({@code startDate >= today}, 30일 이내) 우회를 위해 일단 today/today+1 로 생성한 뒤
     * reflection 으로 사후에 덮어쓴다. BadgeGrantServiceTest 와 같은 패턴.
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

    private void recordNoSpendOn(Long userId, Long challengeId, LocalDate day) {
        amountService.record(userId, challengeId,
                new AmountCreateRequest(null, null, 0, true, day.atTime(12, 0)),
                null);
    }

    private void insertAmountDirectly(Long challengeId, LocalDate day, int amount, boolean noSpend) {
        tx.executeWithoutResult(status ->
                em.createNativeQuery(
                                "INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt, created_dt) "
                                        + "VALUES (?1, ?2, ?3, ?4, ?5, ?6, NOW())")
                        .setParameter(1, challengeId)
                        .setParameter(2, noSpend ? null : "test-category")
                        .setParameter(3, noSpend ? null : "test-content")
                        .setParameter(4, amount)
                        .setParameter(5, noSpend ? 1 : 0)
                        .setParameter(6, day.atTime(12, 0))
                        .executeUpdate());
    }
}
