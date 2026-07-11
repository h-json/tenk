package com.hjson.tenk.devtools;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.auth.AuthTokens;
import com.hjson.tenk.domain.badge.BadgeType;
import com.hjson.tenk.domain.badge.ChallengeBadge;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * 테스트 전용 지원(카카오 우회 로그인 + 상태별 시딩) E2E.
 *
 * <p>reflection backdate 로 만든 챌린지가 실제로 각 상태(시작 전/진행 중/확정 대기/성공/실패)로
 * 저장되는지, wipe 가 누적 없이 재생성하는지, provider=TEST 가드가 실제 카카오 계정을 막는지 확인.
 */
class TestSupportServiceIntegrationTest extends IntegrationTestBase {

    private static final String KEY = "test-integration-key"; // application-test.yaml 과 일치

    @Autowired TestSupportService testSupportService;
    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired ChallengeBadgeRepository challengeBadgeRepository;

    @Test
    @DisplayName("올바른 키+슬롯이면 TEST 계정을 즉석 생성하고 토큰을 발급한다")
    void testLoginProvisionsTestUser() {
        AuthTokens tokens = testSupportService.testLogin(KEY, "alice");

        assertThat(tokens.accessToken()).isNotBlank();
        assertThat(tokens.userId()).isNotNull();
        assertThat(tokens.isNewUser()).isFalse();

        User user = userRepository.findByProviderAndProviderUserId(AuthProvider.TEST, "test-alice")
                .orElseThrow();
        assertThat(user.getNickname()).isEqualTo("테스터-alice");

        // 같은 슬롯 재로그인은 새 계정을 만들지 않는다.
        AuthTokens again = testSupportService.testLogin(KEY, "alice");
        assertThat(again.userId()).isEqualTo(tokens.userId());
    }

    @Test
    @DisplayName("키가 틀리거나 슬롯이 규칙에 안 맞으면 거부한다")
    void testLoginRejectsBadKeyOrSlot() {
        assertThatThrownBy(() -> testSupportService.testLogin("wrong-key", "alice"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEST_LOGIN_KEY_INVALID);

        assertThatThrownBy(() -> testSupportService.testLogin(KEY, "has space"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEST_SLOT_INVALID);
    }

    @Test
    @DisplayName("reseed 는 상태별 챌린지 5종을 만들고 성공 챌린지에 CHALLENGE_SUCCESS 배지를 준다")
    void reseedCreatesFiveStates() {
        Long userId = testSupportService.testLogin(KEY, "bob").userId();

        testSupportService.reseed(userId);

        User user = userRepository.findById(userId).orElseThrow();
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
        Long userId = testSupportService.testLogin(KEY, "carol").userId();

        testSupportService.reseed(userId);
        testSupportService.reseed(userId);

        User user = userRepository.findById(userId).orElseThrow();
        assertThat(challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(user)).hasSize(5);
    }

    @Test
    @DisplayName("카카오(비-TEST) 계정에서 reseed 하면 거부한다")
    void reseedRejectsNonTestUser() {
        User kakao = userRepository.save(
                User.create(AuthProvider.KAKAO, "kakao-real-1", "a@b.com", "실사용자"));

        assertThatThrownBy(() -> testSupportService.reseed(kakao.getId()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEST_ONLY_OPERATION);
    }
}
