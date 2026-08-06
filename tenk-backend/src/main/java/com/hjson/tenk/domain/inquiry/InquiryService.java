package com.hjson.tenk.domain.inquiry;

import com.hjson.tenk.admin.AdminProperties;
import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.common.notify.AdminNotifier;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * ⚠️ <b>알림은 "왔다/남았다"는 신호만 보낸다 — 본문·회신 이메일·계정을 담지 말 것</b> (2026-08-07).
 * 내용은 패널에서 보고, 답장은 패널의 '메일로 답장'({@link com.hjson.tenk.admin.InquiryReplyDraft})이
 * 원문을 인용해 준다. 알림에 본문을 도로 넣으면 <b>메일·텔레그램이 또 하나의 개인정보 보관소</b>가 되고,
 * 접속기록을 남기지 않는 경로로 개인정보가 흘러나간다(패널 열람은 {@code AdminAudit} 에 남는다).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class InquiryService {

    private final InquiryRepository inquiryRepository;
    private final UserRepository userRepository;
    private final AdminNotifier adminNotifier;
    private final AdminProperties adminProperties;

    /**
     * 문의 1건 저장 후 개발자에게 알린다. 검증은 {@link Inquiry} 가 진실의 원천이다.
     *
     * <p>의견({@code FeedbackService.submit})과 달리 <b>{@code userId} 를 받아 저장한다</b> —
     * 권리 행사 요구는 누구의 데이터인지 특정돼야 처리할 수 있기 때문이다.
     *
     * <p>알림은 {@code @Async} 라 이 트랜잭션이 커밋되기 전에 발송이 시작될 수 있다. 알림 본문은
     * DB 를 다시 읽지 않고 여기서 만든 문자열만 쓰므로 문제되지 않고, 발송이 실패해도
     * {@link AdminNotifier} 가 예외를 삼켜 <b>저장은 그대로 성공한다</b>.
     */
    @Transactional
    public void submit(Long userId, InquiryType type, String content, String replyEmail) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));

        inquiryRepository.save(Inquiry.of(user, type, content, replyEmail));

        // 방금 저장한 건까지 센 값이다 (JPQL 조회가 flush 를 강제한다).
        adminNotifier.notifyAdmin(
                "[TenK] 새 문의가 도착했어요.",
                pendingBody(inquiryRepository.countByStatus(InquiryStatus.PENDING)));
    }

    /**
     * 미처리 문의가 남아 있으면 다시 알린다 (매일 1회).
     *
     * <p>도착 알림은 그 순간 한 번뿐이라 자는 사이에 오면 놓친다. <b>미처리가 사라질 때까지 계속
     * 알리는 것</b>이 "한 번 놓치면 모른다"에 대한 실제 대비책이다. 0건이면 아무것도 보내지 않는다 —
     * 매일 오는 "0건" 알림은 곧 무시되고, 그러면 진짜 알림도 같이 묻힌다.
     *
     * @return 미처리 건수 (0이면 발송하지 않았다는 뜻)
     */
    public long remindPendingInquiries() {
        long pending = inquiryRepository.countByStatus(InquiryStatus.PENDING);
        if (pending == 0) {
            return 0;
        }
        adminNotifier.notifyAdmin("[TenK] 처리되지 않은 문의 내역이 있습니다.", pendingBody(pending));
        return pending;
    }

    /**
     * 도착 알림과 리마인드가 공유하는 본문 — <b>미처리 건수 한 줄 + 패널 링크</b>가 전부다.
     *
     * <p>주소 설정({@code tenk.admin.base-url})이 없으면 링크 줄만 빠진다 — 링크가 없다고 알림이
     * 실패하면 안 된다.
     */
    private String pendingBody(long pending) {
        String counted = "미처리 문의 개수 : " + pending;
        String url = adminProperties.panelUrl("/admin/inquiries");
        return url == null ? counted : counted + "\n\n처리: " + url;
    }
}
