package com.hjson.tenk.domain.inquiry;

import com.hjson.tenk.admin.AdminProperties;
import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.common.notify.AdminNotifier;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class InquiryService {

    private static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

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

        Inquiry inquiry = inquiryRepository.save(Inquiry.of(user, type, content, replyEmail));

        adminNotifier.notifyAdmin(
                "[TenK] 새 문의 #%d (%s)".formatted(inquiry.getId(), inquiry.getType()),
                """
                유형: %s
                회신: %s
                계정: #%d %s
                접수: %s

                %s
                %s""".formatted(
                        inquiry.getType(),
                        inquiry.getReplyEmail(),
                        user.getId(),
                        user.getNickname(),
                        LocalDateTime.now().format(STAMP),
                        inquiry.getContent(),
                        panelLink("/admin/inquiries/" + inquiry.getId())));
    }

    /**
     * 알림 끝에 붙일 패널 링크 한 줄. <b>주소 설정이 없으면 빈 문자열</b>이라 본문에 아무것도 안 붙는다 —
     * 링크가 없다고 알림이 실패하면 안 된다.
     */
    private String panelLink(String path) {
        String url = adminProperties.panelUrl(path);
        return url == null ? "" : "\n처리: " + url + "\n";
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

        String oldest = inquiryRepository.findOldestCreatedDt(InquiryStatus.PENDING)
                .map(dt -> "가장 오래된 건 %d일 경과 (%s 접수)"
                        .formatted(Duration.between(dt, LocalDateTime.now()).toDays(), dt.format(STAMP)))
                .orElse("");

        adminNotifier.notifyAdmin(
                "[TenK] 미처리 문의 %d건".formatted(pending),
                """
                %s

                관리자 페이지에서 '처리 완료'로 표시해야 알림이 멈춥니다.
                %s""".formatted(oldest, panelLink("/admin/inquiries")));
        return pending;
    }

}
