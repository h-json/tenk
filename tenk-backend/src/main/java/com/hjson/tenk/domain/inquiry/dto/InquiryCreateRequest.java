package com.hjson.tenk.domain.inquiry.dto;

import com.hjson.tenk.domain.inquiry.Inquiry;
import com.hjson.tenk.domain.inquiry.InquiryType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 문의 요청.
 *
 * @param replyEmail 답변받을 이메일. <b>필수</b> — 답변이 전제된 창구라 회신 경로 없이는 성립하지 않는다
 *                   (의견 보내기에서는 같은 항목이 선택이다).
 */
public record InquiryCreateRequest(
        @NotNull(message = "문의 유형을 골라주세요.")
        InquiryType type,

        @NotBlank(message = "문의 내용을 입력해주세요.")
        @Size(max = Inquiry.CONTENT_MAX_LENGTH, message = "내용은 1000자까지 쓸 수 있어요.")
        String content,

        @NotBlank(message = "답변받을 이메일을 입력해주세요.")
        @Size(max = Inquiry.REPLY_EMAIL_MAX_LENGTH, message = "이메일이 너무 길어요.")
        String replyEmail
) {}
