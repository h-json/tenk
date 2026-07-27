package com.hjson.tenk.domain.user;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.domain.user.dto.BirthDateRequest;
import com.hjson.tenk.domain.user.dto.GenderUpdateRequest;
import com.hjson.tenk.domain.user.dto.NicknameUpdateRequest;
import com.hjson.tenk.domain.user.dto.UserResponse;
import com.hjson.tenk.domain.user.dto.WithdrawRequest;
import com.hjson.tenk.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "User", description = "사용자 API")
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @Operation(summary = "내 정보 조회")
    @GetMapping("/me")
    public ApiResponse<UserResponse> me(@CurrentUserId Long userId) {
        return ApiResponse.ok(UserResponse.from(userService.getActiveUser(userId)));
    }

    @Operation(summary = "닉네임 수정")
    @PatchMapping("/me/nickname")
    public ApiResponse<UserResponse> updateNickname(@CurrentUserId Long userId,
                                                    @Valid @RequestBody NicknameUpdateRequest request) {
        userService.updateNickname(userId, request.nickname());
        return ApiResponse.ok(UserResponse.from(userService.getActiveUser(userId)));
    }

    @Operation(summary = "성별 설정 (선택 항목)",
            description = "'내 정보' 화면에서만 호출. gender 를 null 로 보내면 미입력으로 되돌린다(수집 철회).")
    @PatchMapping("/me/gender")
    public ApiResponse<UserResponse> updateGender(@CurrentUserId Long userId,
                                                  @RequestBody GenderUpdateRequest request) {
        userService.updateGender(userId, request.gender());
        return ApiResponse.ok(UserResponse.from(userService.getActiveUser(userId)));
    }

    @Operation(summary = "연령 확인(생년월일) 기록",
            description = "연령 확인 게이트에서 호출. 만 14세 미만이면 계정을 즉시 파기하고 U0006 으로 거부한다.")
    @PostMapping("/me/birth-date")
    public ApiResponse<UserResponse> verifyAge(@CurrentUserId Long userId,
                                               @Valid @RequestBody BirthDateRequest request) {
        userService.verifyAge(userId, request.birthDate());
        return ApiResponse.ok(UserResponse.from(userService.getActiveUser(userId)));
    }

    @Operation(summary = "필수 동의(이용약관 + 개인정보 수집·이용) 기록",
            description = "가입 온보딩/동의 게이트에서 두 필수 항목을 모두 체크한 뒤 호출. 미동의 항목만 스탬프.")
    @PostMapping("/me/consent")
    public ApiResponse<UserResponse> agreeConsents(@CurrentUserId Long userId) {
        userService.agreeConsents(userId);
        return ApiResponse.ok(UserResponse.from(userService.getActiveUser(userId)));
    }

    @Operation(summary = "회원 탈퇴(소프트 딜리트) — 모든 RT가 함께 무효화됨",
            description = "탈퇴 사유(reason/detail)는 선택이며 body 를 생략해도 된다. "
                    + "사유는 계정과 연결되지 않는 익명 테이블에 기록된다.")
    @DeleteMapping("/me")
    public ApiResponse<Void> withdraw(@CurrentUserId Long userId,
                                      @Valid @RequestBody(required = false) WithdrawRequest request) {
        userService.withdraw(
                userId,
                request == null ? null : request.reason(),
                request == null ? null : request.detail());
        return ApiResponse.ok();
    }
}
