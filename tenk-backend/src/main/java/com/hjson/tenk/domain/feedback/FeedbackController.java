package com.hjson.tenk.domain.feedback;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.domain.feedback.dto.FeedbackCreateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Feedback", description = "의견 보내기 API")
@RestController
@RequestMapping("/api/feedback")
@RequiredArgsConstructor
public class FeedbackController {

    private final FeedbackService feedbackService;

    /**
     * 인증이 필요한 경로지만 {@code @CurrentUserId} 를 받지 않는다 — 토큰은 스팸을 막기 위한
     * 통과 조건일 뿐이고, 누가 보냈는지는 저장하지 않기 때문. (SecurityConfig 의 PERMIT_ALL 에
     * 이 경로를 추가하지 말 것.)
     */
    @Operation(summary = "의견 보내기",
            description = "인증 필요. 계정과 연결하지 않고 익명으로 저장한다. "
                    + "replyEmail 은 선택이며, 적은 경우에만 답변 대상이 된다.")
    @PostMapping
    public ApiResponse<Void> submit(@Valid @RequestBody FeedbackCreateRequest request) {
        feedbackService.submit(
                request.type(),
                request.content(),
                request.replyEmail(),
                request.appVersion(),
                request.platform(),
                request.osVersion());
        return ApiResponse.ok();
    }
}
