package com.hjson.tenk.domain.challenge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.dto.ChallengeResponse;
import com.hjson.tenk.domain.challenge.event.ChallengeFinishedEvent;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserService;
import java.time.LocalDate;
import java.util.Collections;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChallengeServiceTest {

    @Mock ChallengeRepository challengeRepository;
    @Mock AmountRepository amountRepository;
    @Mock ChallengeBadgeRepository challengeBadgeRepository;
    @Mock UserService userService;
    @Mock ApplicationEventPublisher eventPublisher;

    @InjectMocks ChallengeService service;

    private User user;

    @BeforeEach
    void setUp() {
        user = User.create(AuthProvider.KAKAO, "kakao-1", "u@example.com", "tester");
        ReflectionTestUtils.setField(user, "id", 100L);
        // 모든 toResponse 경로가 badge 조회를 거치므로 디폴트 빈 리스트로 stub.
        given(challengeBadgeRepository.findByChallengeOrderByCreatedDtAsc(any()))
                .willReturn(Collections.emptyList());
    }

    private Challenge ongoingChallenge(long id, int target) {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, today, today.plusDays(3), target);
        ReflectionTestUtils.setField(c, "id", id);
        return c;
    }

    /** invariant를 거친 도메인 객체를 만든 뒤, "어제 종료된 상태"로 강제 — finalize 분기 검증용. */
    private Challenge finishedChallenge(long id, int target) {
        LocalDate today = LocalDate.now();
        Challenge c = Challenge.create(user, today, today, target);
        ReflectionTestUtils.setField(c, "id", id);
        ReflectionTestUtils.setField(c, "startDate", today.minusDays(2));
        ReflectionTestUtils.setField(c, "endDate", today.minusDays(1));
        return c;
    }

    @Test
    void loadOwned_returns_challenge_when_owner_matches() {
        Challenge c = ongoingChallenge(1L, 10_000);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        assertThat(service.loadOwned(100L, 1L)).isSameAs(c);
    }

    @Test
    void loadOwned_throws_not_found_when_missing() {
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.empty());
        assertThatThrownBy(() -> service.loadOwned(100L, 1L))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NOT_FOUND);
    }

    @Test
    void loadOwned_throws_when_owner_mismatch() {
        Challenge c = ongoingChallenge(1L, 10_000);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        assertThatThrownBy(() -> service.loadOwned(999L, 1L))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.CHALLENGE_NOT_OWNER);
    }

    @Test
    void finalize_marks_success_when_total_at_or_under_target_and_publishes_event() {
        Challenge c = finishedChallenge(1L, 10_000);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        given(amountRepository.sumByChallenge(c)).willReturn(10_000L);

        ChallengeResponse response = service.finalizeIfDue(100L, 1L);

        assertThat(c.getResult()).isEqualTo(ChallengeResult.SUCCESS);
        assertThat(response.result()).isEqualTo(ChallengeResult.SUCCESS);
        verify(eventPublisher).publishEvent(any(ChallengeFinishedEvent.class));
    }

    @Test
    void finalize_marks_fail_when_total_over_target_and_publishes_event() {
        Challenge c = finishedChallenge(1L, 10_000);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        given(amountRepository.sumByChallenge(c)).willReturn(10_001L);

        service.finalizeIfDue(100L, 1L);

        assertThat(c.getResult()).isEqualTo(ChallengeResult.FAIL);
        verify(eventPublisher).publishEvent(any(ChallengeFinishedEvent.class));
    }

    @Test
    void finalize_no_op_when_already_resolved() {
        Challenge c = finishedChallenge(1L, 10_000);
        c.markResult(ChallengeResult.SUCCESS);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        given(amountRepository.sumByChallenge(c)).willReturn(50_000L);

        service.finalizeIfDue(100L, 1L);

        assertThat(c.getResult()).isEqualTo(ChallengeResult.SUCCESS);
        verify(eventPublisher, never()).publishEvent(any(ChallengeFinishedEvent.class));
    }

    @Test
    void finalize_no_op_when_not_yet_finished() {
        Challenge c = ongoingChallenge(1L, 10_000);
        given(challengeRepository.findByIdAndDeletedFalse(1L)).willReturn(Optional.of(c));
        given(amountRepository.sumByChallenge(c)).willReturn(0L);

        service.finalizeIfDue(100L, 1L);

        assertThat(c.getResult()).isNull();
        verify(eventPublisher, never()).publishEvent(any(ChallengeFinishedEvent.class));
    }
}
