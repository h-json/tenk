package com.hjson.tenk.domain.inquiry;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.domain.inquiry.dto.InquiryCreateRequest;
import com.hjson.tenk.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Inquiry", description = "문의하기 API")
@RestController
@RequestMapping("/api/inquiry")
@RequiredArgsConstructor
public class InquiryController {

    private final InquiryService inquiryService;

    /**
     * 의견 보내기와 달리 <b>{@code @CurrentUserId} 를 받아 저장한다</b> — 열람·정정·삭제 요구는
     * 누구의 데이터인지 특정돼야 처리할 수 있기 때문. (SecurityConfig 의 PERMIT_ALL 에 이 경로를
     * 추가하지 말 것.)
     *
     * <p>앱 밖에서 오는 문의(탈퇴자·로그인 불가·설치 전)는 이 경로로 못 들어온다 — 그쪽 창구는
     * privacy.html·terms.html·delete-account.html 에 고지한 이메일이며 <b>없애면 안 된다</b>.
     */
    @Operation(summary = "문의 보내기",
            description = "인증 필요. 답변을 위해 계정 식별자와 함께 저장하며 replyEmail 은 필수다. "
                    + "일반적인 제품 의견은 익명으로 저장되는 POST /api/feedback 을 쓸 것.")
    @PostMapping
    public ApiResponse<Void> submit(@CurrentUserId Long userId,
                                    @Valid @RequestBody InquiryCreateRequest request) {
        inquiryService.submit(userId, request.type(), request.content(), request.replyEmail());
        return ApiResponse.ok();
    }
}
