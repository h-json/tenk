package com.hjson.tenk.domain.feedback;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.regex.Pattern;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * 사용자가 앱에서 보낸 의견 1건. <b>어느 계정이 남겼는지는 저장하지 않는다.</b>
 *
 * <p>{@code user_id} 를 일부러 두지 않은 건 {@code withdrawal_feedback} 과 같은 이유다 —
 * 계정과 연결하지 않으면 개인정보가 아니라 익명정보라서 보관 기간 논쟁이 없고, 계정이 파기된 뒤에도
 * 남는다. 계정 파기 배치의 삭제 대상도 아니다. <b>여기에 user 참조를 추가하지 말 것.</b>
 *
 * <p>다만 {@link #replyEmail} 은 예외적으로 개인정보다. <b>선택 입력</b>이고, 적은 사람에게만
 * 답을 보내기 위해서만 쓴다. 이 컬럼이 있기 때문에 개인정보처리방침 수집표에 '회신용 이메일(선택)'
 * 한 줄이 들어가 있다 — 컬럼을 지우거나 필수로 바꾸면 그 문서도 같이 손봐야 한다.
 *
 * <p>진단 정보(앱 버전·플랫폼·OS)는 클라이언트가 함께 보내며 <b>틀려도 거부하지 않고 잘라 담는다</b>.
 * 부가 정보 때문에 의견 전송 자체가 실패하는 게 훨씬 나쁘기 때문이다.
 */
@Getter
@Entity
@Table(name = "feedback")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Feedback {

    public static final int CONTENT_MAX_LENGTH = 1000;
    public static final int REPLY_EMAIL_MAX_LENGTH = 100;
    public static final int APP_VERSION_MAX_LENGTH = 20;
    public static final int PLATFORM_MAX_LENGTH = 10;
    public static final int OS_VERSION_MAX_LENGTH = 100;
    public static final int HANDLER_NOTE_MAX_LENGTH = 500;

    /**
     * 제어·형식 문자 거부 — 닉네임/챌린지 이름과 같은 정책이되 <b>줄바꿈만 예외</b>로 허용한다.
     * 의견은 여러 줄로 쓰는 게 자연스러워서, 여기까지 막으면 정상 입력이 거부된다.
     */
    private static final Pattern CONTENT_FORBIDDEN_CHARS = Pattern.compile("[\\p{Cc}\\p{Cf}&&[^\\n]]");

    /** 오탈자를 걸러내는 최소 형식 검사. 실제 도달 가능 여부는 답장을 보내봐야 안다. */
    private static final Pattern EMAIL_SHAPE = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feedback_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 20)
    private FeedbackType type;

    @Column(name = "content", nullable = false, length = CONTENT_MAX_LENGTH)
    private String content;

    /** 선택. 적은 사람에게만 답장한다 — 비어 있으면 답변하지 않는다는 뜻. */
    @Column(name = "reply_email", length = REPLY_EMAIL_MAX_LENGTH)
    private String replyEmail;

    @Column(name = "app_version", length = APP_VERSION_MAX_LENGTH)
    private String appVersion;

    @Column(name = "platform", length = PLATFORM_MAX_LENGTH)
    private String platform;

    @Column(name = "os_version", length = OS_VERSION_MAX_LENGTH)
    private String osVersion;

    /**
     * 관리자 패널에서 남기는 처리 메모.
     *
     * <p>⚠️ <b>여기에 개인정보를 적으면 이 테이블의 익명성이 깨진다</b> — 그러면 개인정보처리방침
     * 수집표에 없는 항목을 보관하게 된다. 답변 전문·이용자 신원을 옮겨 담지 말 것. 의견에는
     * 처리 상태({@code status})가 없으므로 이 메모는 <b>"봤다/반영했다"를 스스로 남기는 용도</b>다.
     */
    @Column(name = "handler_note", length = HANDLER_NOTE_MAX_LENGTH)
    private String handlerNote;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    private Feedback(FeedbackType type, String content, String replyEmail,
                     String appVersion, String platform, String osVersion) {
        this.type = type;
        this.content = content;
        this.replyEmail = replyEmail;
        this.appVersion = appVersion;
        this.platform = platform;
        this.osVersion = osVersion;
    }

    public static Feedback of(FeedbackType type, String content, String replyEmail,
                              String appVersion, String platform, String osVersion) {
        if (type == null) {
            throw new BusinessException(ErrorCode.FEEDBACK_TYPE_INVALID);
        }
        return new Feedback(
                type,
                validateAndNormalizeContent(content),
                validateAndNormalizeReplyEmail(replyEmail),
                truncate(appVersion, APP_VERSION_MAX_LENGTH),
                truncate(platform, PLATFORM_MAX_LENGTH),
                truncate(osVersion, OS_VERSION_MAX_LENGTH));
    }

    /**
     * 처리 메모를 남긴다 (관리자 패널). <b>거부하지 않고 잘라 담는다</b> — 운영자가 스스로 남기는
     * 기록이라 길이 때문에 저장이 실패할 이유가 없다. 비우면 지운다.
     */
    public void writeHandlerNote(String note) {
        if (note == null) {
            this.handlerNote = null;
            return;
        }
        String trimmed = note.replace("\r\n", "\n").replace('\r', '\n').trim();
        if (trimmed.isEmpty()) {
            this.handlerNote = null;
            return;
        }
        this.handlerNote = trimmed.length() > HANDLER_NOTE_MAX_LENGTH
                ? trimmed.substring(0, HANDLER_NOTE_MAX_LENGTH)
                : trimmed;
    }

    private static String validateAndNormalizeContent(String raw) {
        if (raw == null) {
            throw new BusinessException(ErrorCode.FEEDBACK_CONTENT_INVALID);
        }
        // 기기·플랫폼마다 줄바꿈 표기가 달라 먼저 통일한다 (\r 은 그 뒤 금지 문자로 잡힌다).
        String trimmed = raw.replace("\r\n", "\n").replace('\r', '\n').trim();
        if (trimmed.isEmpty() || trimmed.length() > CONTENT_MAX_LENGTH) {
            throw new BusinessException(ErrorCode.FEEDBACK_CONTENT_INVALID);
        }
        if (CONTENT_FORBIDDEN_CHARS.matcher(trimmed).find()) {
            throw new BusinessException(ErrorCode.FEEDBACK_CONTENT_INVALID);
        }
        return trimmed;
    }

    /** 선택 항목이라 빈 값은 "안 적었다"로 정규화하고, 적었다면 형식을 본다. */
    private static String validateAndNormalizeReplyEmail(String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        if (trimmed.length() > REPLY_EMAIL_MAX_LENGTH || !EMAIL_SHAPE.matcher(trimmed).matches()) {
            throw new BusinessException(ErrorCode.FEEDBACK_REPLY_EMAIL_INVALID);
        }
        return trimmed;
    }

    private static String truncate(String raw, int maxLength) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        return trimmed.length() > maxLength ? trimmed.substring(0, maxLength) : trimmed;
    }
}
