package com.hjson.tenk.domain.feedback;

import com.hjson.tenk.admin.AdminProperties;
import com.hjson.tenk.common.notify.AdminNotifier;
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
    private final AdminNotifier adminNotifier;
    private final AdminProperties adminProperties;

    /**
     * 의견 1건 저장. 검증은 {@link Feedback} 이 진실의 원천이다.
     *
     * <p><b>호출자(userId)를 받지 않는 게 의도다.</b> 엔드포인트는 인증을 요구하지만(토큰 없이
     * 아무나 밀어 넣지 못하게) 누가 썼는지는 저장하지 않는다 — 익명이라야 개인정보가 아니다.
     *
     * <p>저장 후 개발자에게 알린다. 의견은 즉시 처리해야 하는 큐가 아니라 모아서 보는 데이터지만,
     * <b>도착 사실조차 모르면 모아서 볼 계기가 없다</b>. 미처리 리마인드는 문의에만 있고 의견에는
     * 없는 것도 같은 이유다 — 의견에는 "처리 완료"라는 상태가 없다.
     *
     * <p>⚠️ <b>알림은 "왔다"는 신호뿐이고 본문·회신 이메일을 담지 않는다</b> (2026-08-07). 내용을
     * 실으면 메일함·텔레그램이 또 하나의 개인정보 보관소가 되고, 접속기록({@code AdminAudit})이 남는
     * 패널 열람을 우회하는 경로가 생긴다. 내용은 패널에서 본다.
     */
    @Transactional
    public void submit(FeedbackType type, String content, String replyEmail,
                       String appVersion, String platform, String osVersion) {
        feedbackRepository.save(Feedback.of(type, content, replyEmail, appVersion, platform, osVersion));

        // 주소 설정이 없으면 링크 줄을 통째로 생략한다 — 알림이 실패해선 안 된다.
        String panelUrl = adminProperties.panelUrl("/admin/feedbacks");
        adminNotifier.notifyAdmin(
                "[TenK] 새 의견이 도착했어요.",
                panelUrl == null ? "" : "목록: " + panelUrl);
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
