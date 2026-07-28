package com.hjson.tenk.domain.feedback;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 매일 새벽 1시 40분: 보관 기간이 지난 의견 회신용 이메일 삭제 (의견 본문은 남긴다).
 *
 * <p>배지 재평가(1시)·탈퇴 계정 파기(1시 30분)와 겹치지 않게 10분 뒤로 둔다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class FeedbackRetentionScheduler {

    private final FeedbackService feedbackService;

    @Scheduled(cron = "0 40 1 * * *", zone = "Asia/Seoul")
    public void purgeExpiredReplyEmails() {
        int cleared = feedbackService.purgeExpiredReplyEmails();
        if (cleared > 0) {
            log.info("[FeedbackRetentionScheduler] reply emails cleared={}", cleared);
        }
    }
}
