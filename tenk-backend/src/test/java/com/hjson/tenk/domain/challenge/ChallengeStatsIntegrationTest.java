package com.hjson.tenk.domain.challenge;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.badge.BadgeGrantService;
import com.hjson.tenk.domain.badge.BadgeType;
import com.hjson.tenk.domain.challenge.dto.ChallengeResponse;
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
 * 응답의 {@code currentStreak} 이 <b>배지 지급과 같은 값</b>인지 본다.
 *
 * <p>클라이언트는 이 값을 알림 문구("오늘 기록하면 7일 연속 배지예요")에 그대로 쓰고
 * <b>직접 세지 않는다</b>. 두 경로가 갈라지면 사용자는 "1일 남았다" 는 알림을 받고 기록했는데
 * 배지가 안 나오는 상황을 겪는다 — 단위 테스트로는 못 잡는 자리라 여기서 묶어 고정한다.
 */
class ChallengeStatsIntegrationTest extends IntegrationTestBase {

    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired ChallengeService challengeService;
    @Autowired BadgeGrantService badgeGrantService;

    @Test
    @DisplayName("연속 3일 기록하면 응답 currentStreak 이 3")
    void exposesCurrentStreak() {
        Long userId = createUser("kakao-streak-3");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(5));
        insertAmount(challengeId, LocalDate.now().minusDays(2));
        insertAmount(challengeId, LocalDate.now().minusDays(1));
        insertAmount(challengeId, LocalDate.now());

        ChallengeResponse response = challengeService.getOne(userId, challengeId);

        assertThat(response.currentStreak()).isEqualTo(3);
    }

    @Test
    @DisplayName("기록이 없으면 0 — 방금 만든 챌린지도 0")
    void zeroWithoutRecords() {
        Long userId = createUser("kakao-streak-0");
        Long challengeId = createChallenge(userId, LocalDate.now(), LocalDate.now().plusDays(5));

        assertThat(challengeService.getOne(userId, challengeId).currentStreak()).isZero();
    }

    @Test
    @DisplayName("불연속 기록은 마지막 연속 구간만 센다")
    void gapResetsStreak() {
        Long userId = createUser("kakao-streak-gap");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(9), LocalDate.now().plusDays(5));
        insertAmount(challengeId, LocalDate.now().minusDays(8));
        insertAmount(challengeId, LocalDate.now().minusDays(7));
        insertAmount(challengeId, LocalDate.now().minusDays(6));
        insertAmount(challengeId, LocalDate.now().minusDays(1));
        insertAmount(challengeId, LocalDate.now());

        assertThat(challengeService.getOne(userId, challengeId).currentStreak()).isEqualTo(2);
    }

    @Test
    @DisplayName("무지출 누적 일수도 응답에 실린다 — 지출이 낀 날은 빠진다")
    void exposesNoSpendDays() {
        Long userId = createUser("kakao-nospend-days");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(5));
        insertNoSpend(challengeId, LocalDate.now().minusDays(4));
        insertNoSpend(challengeId, LocalDate.now().minusDays(2));
        insertNoSpend(challengeId, LocalDate.now().minusDays(1));
        // 같은 날 지출이 끼면 그 날은 무지출로 치지 않는다
        insertAmount(challengeId, LocalDate.now().minusDays(1));

        assertThat(challengeService.getOne(userId, challengeId).noSpendDays()).isEqualTo(2);
    }

    @Test
    @DisplayName("배지가 지급된 값과 응답의 currentStreak 이 일치한다 (계산기 공유 가드)")
    void matchesTheValueBadgesWereGrantedFor() {
        Long userId = createUser("kakao-streak-badge");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(5), LocalDate.now().plusDays(5));
        for (int i = 2; i >= 0; i--) {
            insertAmount(challengeId, LocalDate.now().minusDays(i));
        }

        badgeGrantService.evaluateForChallenge(challengeId);
        ChallengeResponse response = challengeService.getOne(userId, challengeId);

        assertThat(response.currentStreak()).isEqualTo(3);
        assertThat(response.badges())
                .anySatisfy(badge -> {
                    assertThat(badge.type()).isEqualTo(BadgeType.STREAK);
                    assertThat(badge.conditionValue()).isEqualTo(3);
                });
    }

    @Test
    @DisplayName("종료된 챌린지는 endDate 기준이라 시간이 지나도 연속일이 남아 있다")
    void finishedChallengeKeepsStreak() {
        Long userId = createUser("kakao-streak-finished");
        Long challengeId = createChallenge(userId, LocalDate.now().minusDays(10), LocalDate.now().minusDays(5));
        insertAmount(challengeId, LocalDate.now().minusDays(7));
        insertAmount(challengeId, LocalDate.now().minusDays(6));
        insertAmount(challengeId, LocalDate.now().minusDays(5));

        assertThat(challengeService.getOne(userId, challengeId).currentStreak()).isEqualTo(3);
    }

    private Long createUser(String providerUserId) {
        return tx.execute(status ->
                userRepository.save(User.create(AuthProvider.KAKAO, providerUserId, "tester")).getId());
    }

    /** {@code startDate >= today} invariant 우회 — 정상 생성 후 reflection 으로 backdate (기존 통합 테스트와 같은 패턴). */
    private Long createChallenge(Long userId, LocalDate startDate, LocalDate endDate) {
        return tx.execute(status -> {
            User user = userRepository.findById(userId).orElseThrow();
            Challenge saved = challengeRepository.save(
                    Challenge.create(user, "연속일 테스트", LocalDate.now(), LocalDate.now().plusDays(1), 10_000));
            ReflectionTestUtils.setField(saved, "startDate", startDate);
            ReflectionTestUtils.setField(saved, "endDate", endDate);
            return saved.getId();
        });
    }

    private void insertAmount(Long challengeId, LocalDate day) {
        insertRow(challengeId, day, false);
    }

    private void insertNoSpend(Long challengeId, LocalDate day) {
        insertRow(challengeId, day, true);
    }

    /// 네이티브 INSERT 라 엔티티 검증을 우회한다 — category 는 반드시 SpendCategory 코드여야 하고,
    /// 아니면 읽을 때 @Enumerated(STRING) 매핑이 깨진다 (handoff "함정" 참고).
    private void insertRow(Long challengeId, LocalDate day, boolean noSpend) {
        tx.executeWithoutResult(status ->
                em.createNativeQuery(
                                "INSERT INTO amount (challenge_id, category, content, amount, is_no_spend, spent_dt, created_dt) "
                                        + "VALUES (?1, ?2, ?3, ?4, ?5, ?6, NOW())")
                        .setParameter(1, challengeId)
                        .setParameter(2, noSpend ? null : "FOOD")
                        .setParameter(3, noSpend ? null : "test-content")
                        .setParameter(4, noSpend ? 0 : 1000)
                        .setParameter(5, noSpend ? 1 : 0)
                        .setParameter(6, day.atTime(noSpend ? 9 : 12, 0))
                        .executeUpdate());
    }
}
