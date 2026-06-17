package com.hjson.tenk.domain.badge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.multipart.MultipartFile;

/**
 * 챌린지 단위 배지 자동 지급 E2E.
 *
 * <p>핸드오프 §1의 검증 항목 — {@code @TransactionalEventListener(AFTER_COMMIT)} 가 실제
 * 커밋 후 호출되어 배지가 DB ({@code challenge_badge} 테이블)에 기록되는지, 그리고 누적/회수
 * 정책이 실제로 동작하는지를 본다. 단위 테스트({@link BadgeGrantServiceTest})는 정책 분기만
 * 커버하므로 propagation·DB constraint 는 여기서만 확인 가능.
 *
 * <p><b>왜 reflection 으로 startDate / endDate 를 사후에 박는가?</b>
 * <ul>
 *   <li>{@link Challenge#create} invariant: {@code startDate >= today}. API 로는 과거
 *       시작일을 만들 수 없다.</li>
 *   <li>하지만 NO_SPEND 누적 시나리오는 백데이트된 spentDt 가 필요하므로 챌린지의
 *       startDate 도 과거여야 한다.</li>
 *   <li>따라서 정상 생성 후 startDate / endDate 만 reflection 으로 backdate.</li>
 * </ul>
 *
 * <p><b>왜 무지출도 native insert 인가?</b> 무지출은 {@link AmountService#record} 에서
 * spentDt 가 서버 now() 로 강제 박힘 (도메인 규칙: 과거/미래 무지출 불가). 백데이트가
 * 필요한 시나리오는 native insert 후 {@code badgeGrantService.evaluateForChallenge} 를
 * 직접 호출하거나, 이벤트 propagation 자체를 보고 싶을 땐 마지막 한 건을 service 경유로 박는다.
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
    @DisplayName("무지출 3일 누적 (연속 아님) 시 NO_SPEND 3 배지가 지급된다")
    void noSpendThreeDaysGrantsBadge() {
        Long userId = createUser("kakao-nospend");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(6), LocalDate.now().plusDays(1), 1_000_000);

        // 불연속 무지출 3일 (day-6, day-4, day-2). 연속 STREAK 은 받지 못해야 함.
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(6), 0, true);
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(4), 0, true);
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(2), 0, true);
        badgeGrantService.evaluateForChallenge(challengeId);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        Badge noSpend7 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 7).orElseThrow();
        Badge streak3 = badgeRepository.findByTypeAndConditionValue(BadgeType.STREAK, 3).orElseThrow();

        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isTrue();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend7)).isFalse();
        // 오늘/어제 미기록 → STREAK 끊김
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, streak3)).isFalse();
    }

    @Test
    @DisplayName("같은 날 무지출 두 번째 등록은 AMOUNT_NO_SPEND_ALREADY_EXISTS 로 거부된다")
    void noSpendDuplicateOnSameDayRejected() {
        Long userId = createUser("kakao-dup");
        Long challengeId = createChallenge(userId, LocalDate.now(), LocalDate.now().plusDays(2), 1_000_000);

        amountService.record(userId, challengeId, noSpendRequest(), null);

        assertThatThrownBy(() -> amountService.record(userId, challengeId, noSpendRequest(), null))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AMOUNT_NO_SPEND_ALREADY_EXISTS);
    }

    @Test
    @DisplayName("같은 날 지출+무지출이 끼면 NO_SPEND 누적에서 그 날이 제외된다")
    void spendIntrudesOnNoSpendDayReducesCount() {
        Long userId = createUser("kakao-mixed");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(6), LocalDate.now().plusDays(1), 1_000_000);

        // 무지출 3일 + 그 중 하루엔 지출도 함께 있음. service 우회 (event 가 도는지가 핵심이 아님)
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(6), 0, true);
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(6), 500, false); // 같은 날 지출 끼움
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(4), 0, true);
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(2), 0, true);
        badgeGrantService.evaluateForChallenge(challengeId);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();

        // day-6 은 지출이 끼어 무지출-only 아님 → 누적 2일 → 미달
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isFalse();
    }

    @Test
    @DisplayName("이미 지급된 NO_SPEND 배지는 그 날 지출이 끼어 무지출이 자동 삭제되면 회수된다 (revoke)")
    void noSpendBadgeRevokedWhenSpendAddedSameDay() {
        Long userId = createUser("kakao-revoke");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(6), LocalDate.now().plusDays(1), 1_000_000);

        // 무지출 3일 누적 → NO_SPEND 3 grant
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(6), 0, true);
        insertAmountDirectly(challengeId, LocalDate.now().minusDays(4), 0, true);
        // today 무지출은 service 로 박아야 자동 삭제 흐름을 탈 수 있음
        amountService.record(userId, challengeId, noSpendRequest(), null);

        Challenge challenge = challengeRepository.findById(challengeId).orElseThrow();
        Badge noSpend3 = badgeRepository.findByTypeAndConditionValue(BadgeType.NO_SPEND, 3).orElseThrow();
        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isTrue();

        // today 에 지출 등록 → today 무지출 자동 삭제 → 누적 2일 → revoke
        amountService.record(userId, challengeId,
                new AmountCreateRequest("food", "lunch", 500, false, null, null), videoPart());

        assertThat(challengeBadgeRepository.existsByChallengeAndBadge(challenge, noSpend3)).isFalse();
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
        Long aId = createChallenge(userId, LocalDate.now().minusDays(6), LocalDate.now().plusDays(1), 1_000_000);
        Long bId = createChallenge(userId, LocalDate.now().minusDays(6), LocalDate.now().plusDays(1), 1_000_000);

        // 챌린지 A 에만 3일 무지출 (불연속) 기록
        insertAmountDirectly(aId, LocalDate.now().minusDays(6), 0, true);
        insertAmountDirectly(aId, LocalDate.now().minusDays(4), 0, true);
        insertAmountDirectly(aId, LocalDate.now().minusDays(2), 0, true);
        badgeGrantService.evaluateForChallenge(aId);
        badgeGrantService.evaluateForChallenge(bId);

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
            Challenge c = Challenge.create(user, "테스트 챌린지", LocalDate.now(), LocalDate.now().plusDays(1), targetAmount);
            Challenge saved = challengeRepository.save(c);
            ReflectionTestUtils.setField(saved, "startDate", startDate);
            ReflectionTestUtils.setField(saved, "endDate", endDate);
            return saved.getId();
        });
    }

    private AmountCreateRequest noSpendRequest() {
        return new AmountCreateRequest(null, null, 0, true, null, null);
    }

    private MultipartFile videoPart() {
        return new MockMultipartFile("video", "clip.mp4", "video/mp4", new byte[]{1, 2, 3});
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
