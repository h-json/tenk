package com.hjson.tenk.domain.inquiry;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.regex.Pattern;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * 개인정보 관련 문의 1건. <b>의견 보내기({@code Feedback})와는 계약이 정반대인 창구다.</b>
 *
 * <table border="1">
 *   <caption>두 창구의 차이</caption>
 *   <tr><th></th><th>의견 보내기</th><th>문의(이 엔티티)</th></tr>
 *   <tr><td>신원</td><td>익명 (user 참조 없음)</td><td><b>{@code user_id} 저장</b></td></tr>
 *   <tr><td>회신 이메일</td><td>선택</td><td><b>필수</b></td></tr>
 *   <tr><td>답변</td><td>전제되지 않음</td><td>전제됨 (10일 내 조치 원칙)</td></tr>
 * </table>
 *
 * <p><b>{@code user_id} 를 저장하는 게 이 테이블의 존재 이유다.</b> 열람·정정·삭제 요구는 "누구의
 * 데이터인가"가 특정돼야 처리할 수 있어서, 익명 폼으로는 애초에 성립하지 않는다. 그 대가로 이 테이블은
 * 개인정보가 되어 개인정보처리방침 수집표·보관 기간의 대상이고, 계정 파기 배치
 * ({@code WithdrawnUserPurgeService})의 삭제 대상이기도 하다 — 의견 테이블과 정반대다.
 *
 * <p>내용 검증은 의견과 같은 기준으로 <b>줄바꿈만 예외</b>로 허용한다. 문의는 여러 줄로 쓰는 게
 * 자연스러워 한 줄 필드 정책(닉네임·챌린지 이름)을 그대로 복사하면 정상 입력이 거부된다.
 */
@Getter
@Entity
@Table(name = "inquiry")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Inquiry {

    public static final int CONTENT_MAX_LENGTH = 1000;
    public static final int REPLY_EMAIL_MAX_LENGTH = 100;

    /** 제어·형식 문자 거부하되 줄바꿈만 허용 — {@code Feedback} 과 같은 정책. */
    private static final Pattern CONTENT_FORBIDDEN_CHARS = Pattern.compile("[\\p{Cc}\\p{Cf}&&[^\\n]]");

    /** 오탈자를 걸러내는 최소 형식 검사. 실제 도달 가능 여부는 답장을 보내봐야 안다. */
    private static final Pattern EMAIL_SHAPE = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "inquiry_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 30)
    private InquiryType type;

    @Column(name = "content", nullable = false, length = CONTENT_MAX_LENGTH)
    private String content;

    /** <b>필수</b>. 답변이 전제된 창구라 회신 경로가 없으면 문의가 성립하지 않는다. */
    @Column(name = "reply_email", nullable = false, length = REPLY_EMAIL_MAX_LENGTH)
    private String replyEmail;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private InquiryStatus status;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    /** 답변을 마친 시각. 파기 배치의 기준점이라 {@code status=DONE} 과 짝으로 채운다. */
    @Column(name = "handled_dt")
    private LocalDateTime handledDt;

    private Inquiry(User user, InquiryType type, String content, String replyEmail) {
        this.user = user;
        this.type = type;
        this.content = content;
        this.replyEmail = replyEmail;
        this.status = InquiryStatus.PENDING;
    }

    public static Inquiry of(User user, InquiryType type, String content, String replyEmail) {
        if (type == null) {
            throw new BusinessException(ErrorCode.INQUIRY_TYPE_INVALID);
        }
        return new Inquiry(
                user,
                type,
                validateAndNormalizeContent(content),
                validateAndNormalizeReplyEmail(replyEmail));
    }

    private static String validateAndNormalizeContent(String raw) {
        if (raw == null) {
            throw new BusinessException(ErrorCode.INQUIRY_CONTENT_INVALID);
        }
        // 기기·플랫폼마다 줄바꿈 표기가 달라 먼저 통일한다 (\r 은 그 뒤 금지 문자로 잡힌다).
        String trimmed = raw.replace("\r\n", "\n").replace('\r', '\n').trim();
        if (trimmed.isEmpty() || trimmed.length() > CONTENT_MAX_LENGTH) {
            throw new BusinessException(ErrorCode.INQUIRY_CONTENT_INVALID);
        }
        if (CONTENT_FORBIDDEN_CHARS.matcher(trimmed).find()) {
            throw new BusinessException(ErrorCode.INQUIRY_CONTENT_INVALID);
        }
        return trimmed;
    }

    /** 의견과 달리 <b>빈 값을 "안 적었다"로 넘기지 않는다</b> — 답변할 수 없는 문의는 받지 않는다. */
    private static String validateAndNormalizeReplyEmail(String raw) {
        if (raw == null) {
            throw new BusinessException(ErrorCode.INQUIRY_REPLY_EMAIL_INVALID);
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()
                || trimmed.length() > REPLY_EMAIL_MAX_LENGTH
                || !EMAIL_SHAPE.matcher(trimmed).matches()) {
            throw new BusinessException(ErrorCode.INQUIRY_REPLY_EMAIL_INVALID);
        }
        return trimmed;
    }
}
