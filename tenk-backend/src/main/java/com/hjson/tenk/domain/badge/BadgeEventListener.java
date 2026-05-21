package com.hjson.tenk.domain.badge;

import com.hjson.tenk.domain.amount.event.AmountRecordedEvent;
import com.hjson.tenk.domain.challenge.event.ChallengeFinishedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 배지 지급 이벤트 리스너.
 *
 * <p>{@code @Transactional(REQUIRES_NEW)} 가 핵심이다. {@code AFTER_COMMIT} 콜백은 원본
 * 트랜잭션이 막 커밋된 직후에 호출되는데, 이 시점엔 트랜잭션 동기화가 정리 중이라 단순한
 * {@code REQUIRED} 호출은 새 tx 를 열지 못하고 쓰기가 조용히 사라진다
 * (BadgeEventIntegrationTest 의 grantChallengeSuccessDirectCall vs challengeSuccessGrantsBadge
 * 비교로 검증됨). 그래서 리스너 메서드에서 명시적으로 새 tx 를 강제한다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BadgeEventListener {

    private final BadgeGrantService badgeGrantService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onAmountRecorded(AmountRecordedEvent event) {
        try {
            badgeGrantService.evaluateForChallenge(event.challengeId());
        } catch (Exception e) {
            log.warn("[BadgeEventListener] amount evaluation failed challengeId={}", event.challengeId(), e);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onChallengeFinished(ChallengeFinishedEvent event) {
        try {
            // CHALLENGE_SUCCESS 지급
            badgeGrantService.grantChallengeSuccess(event.challengeId(), event.result());
            // 종료 시점 기준으로 STREAK/NO_SPEND 도 한 번 더 재평가 — 마지막 날 기록이
            // 진행 중에 평가됐던 것과 동일한 결과여야 하지만 안전망 차원.
            badgeGrantService.evaluateForChallenge(event.challengeId());
        } catch (Exception e) {
            log.warn("[BadgeEventListener] challenge result handling failed challengeId={}", event.challengeId(), e);
        }
    }
}
