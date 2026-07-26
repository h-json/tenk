package com.hjson.tenk.domain.user.dto;

import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.Gender;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRole;
import java.time.Duration;
import java.time.LocalDateTime;

public record UserResponse(
        Long userId,
        AuthProvider provider,
        // 이메일은 수집하지 않으므로 응답에도 없다 (2026-07-26). 사유는 User 엔티티 주석 참고.
        String nickname,
        // 다음 닉네임 변경이 가능해지는 시각 = 마지막 변경 + 24시간.
        // null = 지금 바로 변경 가능 (한 번도 변경 안 했거나 이미 24시간이 지남).
        // 클라이언트는 이 값으로 "X월 X일 X시 X분 이후 변경 가능" 안내를 표시한다.
        LocalDateTime nicknameChangeAvailableFrom,
        // 필수 동의(이용약관 + 개인정보 수집·이용) 미완료 여부. true 면 클라이언트가 동의 화면으로 게이트.
        boolean consentRequired,
        // 연령 확인 미완료 여부. true 면 클라이언트가 연령 확인 화면으로 게이트 — 동의보다 먼저 통과해야 한다.
        boolean ageVerificationRequired,
        // 성별 (선택 입력). null = 미입력이 정상 상태 — 기능에 쓰이지 않는다.
        Gender gender,
        // 계정 권한 (USER / TESTER). 클라이언트는 TESTER 일 때만 테스트 데이터 시딩 버튼을 노출한다.
        UserRole role
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getProvider(),
                user.getNickname(),
                computeAvailableFrom(user.getNicknameChangedDt()),
                !user.hasAgreedToRequiredConsents(),
                !user.hasVerifiedAge(),
                user.getGender(),
                user.getRole()
        );
    }

    // 대기 시간은 UserService.NICKNAME_CHANGE_COOLDOWN 과 같은 값이어야 한다 (판정과 안내가 어긋나면 안 됨).
    private static final Duration NICKNAME_CHANGE_COOLDOWN = Duration.ofHours(24);

    private static LocalDateTime computeAvailableFrom(LocalDateTime lastChanged) {
        if (lastChanged == null) {
            return null;
        }
        LocalDateTime availableFrom = lastChanged.plus(NICKNAME_CHANGE_COOLDOWN);
        if (!availableFrom.isAfter(LocalDateTime.now())) {
            return null;
        }
        return availableFrom;
    }
}
