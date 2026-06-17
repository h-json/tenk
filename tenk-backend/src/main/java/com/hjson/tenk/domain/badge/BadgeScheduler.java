package com.hjson.tenk.domain.badge;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class BadgeScheduler {

    private final BadgeGrantService badgeGrantService;

    /**
     * 매일 새벽 1시: 활성 챌린지 배지 재평가 (이벤트 누락 보강).
     *
     * <p>결과 확정은 사용자가 직접 {@code POST /api/challenges/{id}/finalize} 로만 한다 —
     * 자동 확정은 두지 않는다. 사유: ① 종료 후에도 확정 전까지 기록(영상/내용)을 보완할 수
     * 있어야 하고 ({@code AmountService.update} 는 {@code result == null} 이면 수정 허용),
     * ② 결과 확정은 사용자에게 페이오프 모먼트(배지 → 결과 카드)라 본인이 누르는 게 자연스럽다.
     */
    @Scheduled(cron = "0 0 1 * * *", zone = "Asia/Seoul")
    public void dailyReconciliation() {
        log.info("[BadgeScheduler] daily reconciliation start");
        badgeGrantService.evaluateAllActive();
        log.info("[BadgeScheduler] daily reconciliation done");
    }
}
