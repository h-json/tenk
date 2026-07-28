package com.hjson.tenk.domain.feedback.dto;

import com.hjson.tenk.domain.feedback.Feedback;
import com.hjson.tenk.domain.feedback.FeedbackType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 의견 보내기 요청.
 *
 * @param replyEmail 답변받을 이메일. <b>선택</b> — 적은 사람에게만 답장한다.
 * @param appVersion 진단용 앱 버전. 선택이고 길면 엔티티가 잘라 담는다.
 * @param platform   진단용 플랫폼 (android/ios).
 * @param osVersion  진단용 OS 버전 문자열.
 */
public record FeedbackCreateRequest(
        @NotNull(message = "의견 유형을 골라주세요.")
        FeedbackType type,

        @NotBlank(message = "내용을 입력해주세요.")
        @Size(max = Feedback.CONTENT_MAX_LENGTH, message = "내용은 1000자까지 쓸 수 있어요.")
        String content,

        @Size(max = Feedback.REPLY_EMAIL_MAX_LENGTH, message = "이메일이 너무 길어요.")
        String replyEmail,

        String appVersion,
        String platform,
        String osVersion
) {}
