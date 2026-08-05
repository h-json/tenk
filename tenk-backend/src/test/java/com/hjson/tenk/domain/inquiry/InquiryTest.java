package com.hjson.tenk.domain.inquiry;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 문의 엔티티 검증. <b>의견({@code FeedbackTest})과 갈리는 지점을 고정하는 게 목적</b>이다 —
 * 특히 회신 이메일이 <b>필수</b>라는 것과, 여러 줄 입력이 허용된다는 것.
 */
class InquiryTest {

    /**
     * zero-width space (U+200B). 눈에 안 보이는 문자라 문자열 안에 그냥 박아두면 나중에 누가 지워도
     * 알아채지 못한다 — 이름 있는 상수로 빼서 이 테스트가 무엇을 재는지 드러낸다.
     */
    private static final String ZERO_WIDTH_SPACE = "​";

    private final User user = User.create(AuthProvider.KAKAO, "kakao-1", "tester");

    @Test
    @DisplayName("정상 입력은 앞뒤 공백을 다듬어 저장하고 PENDING 으로 시작한다")
    void createsPendingInquiry() {
        Inquiry inquiry = Inquiry.of(user, InquiryType.PRIVACY,
                "  내 기록을 열람하고 싶어요  ", "  me@example.com  ");

        assertThat(inquiry.getUser()).isSameAs(user);
        assertThat(inquiry.getType()).isEqualTo(InquiryType.PRIVACY);
        assertThat(inquiry.getContent()).isEqualTo("내 기록을 열람하고 싶어요");
        assertThat(inquiry.getReplyEmail()).isEqualTo("me@example.com");
        assertThat(inquiry.getStatus()).isEqualTo(InquiryStatus.PENDING);
        assertThat(inquiry.getHandledDt()).isNull();
    }

    @Test
    @DisplayName("여러 줄 입력은 허용한다 — 한 줄 필드 정책을 그대로 복사하면 정상 입력이 거부된다")
    void allowsLineBreaks() {
        Inquiry inquiry = Inquiry.of(user, InquiryType.ETC, "첫 줄\r\n둘째 줄\r셋째 줄", "me@example.com");

        assertThat(inquiry.getContent()).isEqualTo("첫 줄\n둘째 줄\n셋째 줄");
    }

    @Test
    @DisplayName("줄바꿈이 아닌 제어·형식 문자는 거부한다")
    void rejectsControlCharacters() {
        String disguised = "표시" + ZERO_WIDTH_SPACE + "위장";

        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, disguised, "me@example.com"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_CONTENT_INVALID);
    }

    @Test
    @DisplayName("내용이 비었거나 상한을 넘으면 거부한다")
    void rejectsEmptyOrTooLongContent() {
        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, "   ", "me@example.com"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_CONTENT_INVALID);

        String tooLong = "가".repeat(Inquiry.CONTENT_MAX_LENGTH + 1);
        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, tooLong, "me@example.com"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_CONTENT_INVALID);
    }

    @Test
    @DisplayName("유형이 없으면 거부한다")
    void rejectsMissingType() {
        assertThatThrownBy(() -> Inquiry.of(user, null, "내용", "me@example.com"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_TYPE_INVALID);
    }

    @Test
    @DisplayName("회신 이메일은 필수다 — 의견과 갈리는 핵심 지점이라 빈 값을 null 로 넘기지 않는다")
    void requiresReplyEmail() {
        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, "내용", null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_REPLY_EMAIL_INVALID);

        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, "내용", "   "))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_REPLY_EMAIL_INVALID);
    }

    @Test
    @DisplayName("형식이 어긋난 이메일은 거부한다")
    void rejectsMalformedReplyEmail() {
        assertThatThrownBy(() -> Inquiry.of(user, InquiryType.ETC, "내용", "broken"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INQUIRY_REPLY_EMAIL_INVALID);
    }
}
