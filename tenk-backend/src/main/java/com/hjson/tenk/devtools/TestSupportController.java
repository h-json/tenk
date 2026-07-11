package com.hjson.tenk.devtools;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.domain.auth.AuthTokens;
import com.hjson.tenk.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * 테스트 전용 엔드포인트. {@code tenk.test.enabled=true} 이고 시크릿 키가 맞을 때만 동작.
 *
 * <ul>
 *   <li>{@code POST /api/auth/test/login} — 카카오 우회 로그인 (permitAll, 키 검증은 서비스에서)</li>
 *   <li>{@code POST /api/dev/seed} — 인증 필요. 호출한 TEST 계정의 데이터를 지우고 5종 상태 시딩</li>
 * </ul>
 */
@Tag(name = "TestSupport", description = "테스트 전용 — 카카오 없이 로그인 + 상태별 챌린지 시딩")
@RestController
@RequiredArgsConstructor
public class TestSupportController {

    private final TestSupportService testSupportService;

    @Operation(summary = "테스트 로그인 (카카오 우회)",
            description = "시크릿 키 + 슬롯(테스터 식별자)으로 격리된 테스트 계정에 로그인해 자체 JWT 를 발급한다.")
    @PostMapping("/api/auth/test/login")
    public ApiResponse<AuthTokens> testLogin(@Valid @RequestBody TestLoginRequest request) {
        return ApiResponse.ok(testSupportService.testLogin(request.key(), request.slot()));
    }

    @Operation(summary = "테스트 데이터 재생성",
            description = "호출한 테스트 계정의 기존 데이터를 모두 삭제하고 상태별(시작 전/진행 중/확정 대기/완료-성공/완료-실패) 챌린지를 시딩한다.")
    @PostMapping("/api/dev/seed")
    public ApiResponse<Void> seed(@CurrentUserId Long userId) {
        testSupportService.reseed(userId);
        return ApiResponse.ok();
    }
}
