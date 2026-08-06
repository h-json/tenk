package com.hjson.tenk.domain.inquiry;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 매일 저녁 6시: 미처리 문의 리마인드.
 *
 * <p>도착 알림은 그 순간 한 번뿐이라 자는 사이에 오면 놓친다. 처리될 때까지 매일 다시 알리는 게
 * "한 번 놓치면 모른다"에 대한 실제 대비책이다. 다른 배치와 달리 <b>새벽이 아니라 저녁</b>인 건
 * 사람이 볼 시간에, 그리고 <b>답장할 시간이 남아 있을 때</b> 도착해야 하기 때문.
 *
 * <p><b>파기 배치는 없다</b> — 문의는 회원 탈퇴 시까지 보관하고 계정 파기 때 함께 지워진다
 * ({@code WithdrawnUserPurgeService}). 답변 여부로 지우는 배치를 다시 만들지 말 것.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class InquiryScheduler {

    private final InquiryService inquiryService;

    @Scheduled(cron = "0 0 18 * * *", zone = "Asia/Seoul")
    public void remindPending() {
        long pending = inquiryService.remindPendingInquiries();
        if (pending > 0) {
            log.info("[InquiryScheduler] pending inquiries reminded={}", pending);
        }
    }
}
