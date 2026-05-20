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
            badgeGrantService.evaluateForUser(event.userId());
        } catch (Exception e) {
            log.warn("[BadgeEventListener] amount evaluation failed userId={}", event.userId(), e);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onChallengeFinished(ChallengeFinishedEvent event) {
        try {
            badgeGrantService.grantChallengeSuccess(event.userId(), event.result());
        } catch (Exception e) {
            log.warn("[BadgeEventListener] challenge result handling failed userId={}", event.userId(), e);
        }
    }
}
