package com.hjson.tenk.devtools;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 테스트 전용 엔드포인트.
 *
 * <ul>
 *   <li>{@code POST /api/dev/seed} — 인증 필요. 호출자가 TESTER 권한이면 그 계정 데이터를 지우고
 *       5종 상태 챌린지를 시딩한다 (권한 검증은 서비스에서).</li>
 * </ul>
 *
 * <p>카카오 우회 로그인은 제거됐다 — 심사·데모는 데모 카카오 계정으로, 내부 테스터는 실제 카카오
 * 계정을 DB 에서 TESTER 로 승격해 쓴다.
 */
@Tag(name = "TestSupport", description = "테스트 전용 — TESTER 계정의 상태별 챌린지 시딩")
@RestController
@RequiredArgsConstructor
public class TestSupportController {

    private final TestSupportService testSupportService;

    @Operation(summary = "테스트 데이터 재생성",
            description = "호출한 TESTER 계정의 기존 데이터를 모두 삭제하고 상태별(시작 전/진행 중/확정 대기/완료-성공/완료-실패) 챌린지를 시딩한다.")
    @PostMapping("/api/dev/seed")
    public ApiResponse<Void> seed(@CurrentUserId Long userId) {
        testSupportService.reseed(userId);
        return ApiResponse.ok();
    }
}
