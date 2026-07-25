package com.hjson.tenk.domain.user.dto;

import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.Gender;
import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record UserResponse(
        Long userId,
        AuthProvider provider,
        String email,
        String nickname,
        // 다음 닉네임 변경이 가능해지는 시각. null = 지금 바로 변경 가능 (한 번도 변경 안 했거나 이미 다음 날이 됨).
        // 클라이언트는 이 값으로 "내일 자정 이후 변경 가능" 등 안내 표시.
        LocalDateTime nicknameChangeAvailableFrom,
        // 필수 동의(이용약관 + 개인정보 수집·이용) 미완료 여부. true 면 클라이언트가 동의 화면으로 게이트.
        boolean consentRequired,
        // 연령 확인 미완료 여부. true 면 클라이언트가 연령 확인 화면으로 게이트 — 동의보다 먼저 통과해야 한다.
        boolean ageVerificationRequired,
        // 성별 (선택 입력). null = 미입력이 정상 상태 — 기능에 쓰이지 않는다.
        Gender gender
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getProvider(),
                user.getEmail(),
                user.getNickname(),
                computeAvailableFrom(user.getNicknameChangedDt()),
                !user.hasAgreedToRequiredConsents(),
                !user.hasVerifiedAge(),
                user.getGender()
        );
    }

    private static LocalDateTime computeAvailableFrom(LocalDateTime lastChanged) {
        if (lastChanged == null) {
            return null;
        }
        LocalDate availableDate = lastChanged.toLocalDate().plusDays(1);
        if (!availableDate.isAfter(LocalDate.now())) {
            return null;
        }
        return availableDate.atStartOfDay();
    }
}
