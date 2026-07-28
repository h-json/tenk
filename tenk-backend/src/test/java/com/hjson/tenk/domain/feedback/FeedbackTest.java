package com.hjson.tenk.domain.feedback;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 의견 엔티티의 검증 규칙 — 서버가 진실의 원천이다. */
class FeedbackTest {

    @Test
    @DisplayName("내용은 trim 되고 줄바꿈은 허용된다 — 의견은 여러 줄로 쓰는 게 자연스럽다")
    void contentIsTrimmedAndKeepsNewlines() {
        Feedback feedback = Feedback.of(
                FeedbackType.SUGGESTION, "  첫 줄\n둘째 줄  ", null, null, null, null);

        assertThat(feedback.getContent()).isEqualTo("첫 줄\n둘째 줄");
    }

    @Test
    @DisplayName("줄바꿈 외의 제어·형식 문자는 거부한다")
    void controlCharactersAreRejected() {
        assertThatThrownBy(() -> Feedback.of(
                FeedbackType.ETC, "표시​위장", null, null, null, null)) // zero-width space
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.FEEDBACK_CONTENT_INVALID);
    }

    @Test
    @DisplayName("빈 내용과 길이 초과는 거부한다")
    void blankOrTooLongContentIsRejected() {
        assertThatThrownBy(() -> Feedback.of(FeedbackType.ETC, "   ", null, null, null, null))
                .isInstanceOf(BusinessException.class);

        String tooLong = "가".repeat(Feedback.CONTENT_MAX_LENGTH + 1);
        assertThatThrownBy(() -> Feedback.of(FeedbackType.ETC, tooLong, null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.FEEDBACK_CONTENT_INVALID);
    }

    @Test
    @DisplayName("유형이 없으면 거부한다")
    void typeIsRequired() {
        assertThatThrownBy(() -> Feedback.of(null, "내용", null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.FEEDBACK_TYPE_INVALID);
    }

    @Test
    @DisplayName("회신 이메일은 선택 — 빈 값이면 '안 적었다'로 정규화한다")
    void blankReplyEmailBecomesNull() {
        Feedback feedback = Feedback.of(FeedbackType.PRAISE, "잘 쓰고 있어요", "   ", null, null, null);

        assertThat(feedback.getReplyEmail()).isNull();
    }

    @Test
    @DisplayName("회신 이메일을 적었다면 형식을 본다")
    void malformedReplyEmailIsRejected() {
        assertThatThrownBy(() -> Feedback.of(
                FeedbackType.PROBLEM, "안 돼요", "not-an-email", null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.FEEDBACK_REPLY_EMAIL_INVALID);
    }

    @Test
    @DisplayName("진단 정보는 길어도 거부하지 않고 잘라 담는다 — 부가 정보 때문에 전송이 실패하면 안 된다")
    void diagnosticsAreTruncatedNotRejected() {
        Feedback feedback = Feedback.of(
                FeedbackType.PROBLEM,
                "영상이 저장되지 않아요",
                "user@example.com",
                "1.0.0",
                "android",
                "x".repeat(Feedback.OS_VERSION_MAX_LENGTH + 50));

        assertThat(feedback.getReplyEmail()).isEqualTo("user@example.com");
        assertThat(feedback.getOsVersion()).hasSize(Feedback.OS_VERSION_MAX_LENGTH);
    }
}
