package com.hjson.tenk.domain.feedback;

import java.time.LocalDateTime;
import java.time.Period;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FeedbackService {

    /**
     * 회신용 이메일 보관 기간. <b>개인정보처리방침 §3 에 고지한 값과 항상 같아야 한다</b>
     * (privacy.html 의 "수집일로부터 최대 1년"). 바꾸면 그 문서도 같이 고칠 것.
     */
    public static final Period REPLY_EMAIL_RETENTION = Period.ofYears(1);

    private final FeedbackRepository feedbackRepository;

    /**
     * 의견 1건 저장. 검증은 {@link Feedback} 이 진실의 원천이다.
     *
     * <p><b>호출자(userId)를 받지 않는 게 의도다.</b> 엔드포인트는 인증을 요구하지만(토큰 없이
     * 아무나 밀어 넣지 못하게) 누가 썼는지는 저장하지 않는다 — 익명이라야 개인정보가 아니다.
     */
    @Transactional
    public void submit(FeedbackType type, String content, String replyEmail,
                       String appVersion, String platform, String osVersion) {
        feedbackRepository.save(Feedback.of(type, content, replyEmail, appVersion, platform, osVersion));
    }

    /**
     * 보관 기간이 지난 회신용 이메일을 지운다 (의견 본문은 남는다).
     *
     * <p>답변을 보낸 뒤 바로 지우는 건 사람이 하는 일이라 빠질 수 있어, 배치로 상한을 강제한다 —
     * 개인정보처리방침에 적어놓고 실제로는 계속 갖고 있는 상태를 만들지 않기 위한 장치다.
     *
     * @return 지워진 건수
     */
    @Transactional
    public int purgeExpiredReplyEmails() {
        return feedbackRepository.clearReplyEmailsCreatedBefore(
                LocalDateTime.now().minus(REPLY_EMAIL_RETENTION));
    }
}
