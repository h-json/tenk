package com.hjson.tenk.devtools;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.badge.BadgeType;
import com.hjson.tenk.domain.badge.ChallengeBadge;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.UserRole;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 테스트 전용 지원(상태별 시딩) E2E.
 *
 * <p>reflection backdate 로 만든 챌린지가 실제로 각 상태(시작 전/진행 중/확정 대기/성공/실패)로
 * 저장되는지, wipe 가 누적 없이 재생성하는지, TESTER 권한 가드가 일반 계정을 막는지 확인.
 */
class TestSupportServiceIntegrationTest extends IntegrationTestBase {

    @Autowired TestSupportService testSupportService;
    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired ChallengeBadgeRepository challengeBadgeRepository;

    /** 실제 카카오 계정을 DB 에서 TESTER 로 승격한 상황(운영은 SQL 로 함)을 재현. */
    private User tester(String providerUserId) {
        User user = userRepository.save(
                User.create(AuthProvider.KAKAO, providerUserId, "테스터"));
        ReflectionTestUtils.setField(user, "role", UserRole.TESTER);
        return userRepository.save(user);
    }

    @Test
    @DisplayName("reseed 는 상태별 챌린지 5종을 만들고 성공 챌린지에 CHALLENGE_SUCCESS 배지를 준다")
    void reseedCreatesFiveStates() {
        User user = tester("tester-bob");

        testSupportService.reseed(user.getId());

        List<Challenge> challenges =
                challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(user);
        assertThat(challenges).hasSize(5);

        LocalDate today = LocalDate.now();
        assertThat(challenges).anyMatch(c -> c.getStartDate().isAfter(today) && c.getResult() == null); // 시작 전
        assertThat(challenges).anyMatch(c -> c.containsDate(today) && c.getResult() == null);            // 진행 중
        assertThat(challenges).anyMatch(c -> c.getEndDate().isBefore(today) && c.getResult() == null);   // 확정 대기
        assertThat(challenges).anyMatch(c -> c.getResult() == ChallengeResult.SUCCESS);                  // 완료-성공
        assertThat(challenges).anyMatch(c -> c.getResult() == ChallengeResult.FAIL);                     // 완료-실패

        Challenge success = challenges.stream()
                .filter(c -> c.getResult() == ChallengeResult.SUCCESS).findFirst().orElseThrow();
        List<ChallengeBadge> successBadges =
                challengeBadgeRepository.findByChallengeOrderByCreatedDtAsc(success);
        assertThat(successBadges)
                .anyMatch(cb -> cb.getBadge().getType() == BadgeType.CHALLENGE_SUCCESS);
    }

    @Test
    @DisplayName("reseed 를 두 번 호출해도 누적되지 않고 항상 5개다 (기존 데이터 wipe)")
    void reseedWipesBeforeCreating() {
        User user = tester("tester-carol");

        testSupportService.reseed(user.getId());
        testSupportService.reseed(user.getId());

        assertThat(challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(user)).hasSize(5);
    }

    @Test
    @DisplayName("TESTER 가 아닌 일반(USER) 계정에서 reseed 하면 거부한다")
    void reseedRejectsNonTesterUser() {
        User plain = userRepository.save(
                User.create(AuthProvider.KAKAO, "kakao-real-1", "실사용자"));

        assertThatThrownBy(() -> testSupportService.reseed(plain.getId()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEST_ONLY_OPERATION);
    }
}
