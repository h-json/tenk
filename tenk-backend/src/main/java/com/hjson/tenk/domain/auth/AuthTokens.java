package com.hjson.tenk.domain.auth;

public record AuthTokens(
        String accessToken,
        String refreshToken,
        long accessTokenExpiresIn,
        Long userId,
        String nickname,
        // 이번 카카오 로그인이 신규 가입을 만든 경우 true. refresh 응답에서는 항상 false.
        // 클라이언트는 true 일 때 NicknameSetupScreen 으로 분기 (가입 화면 강제).
        boolean isNewUser,
        // 필수 동의(이용약관 + 개인정보 수집·이용) 미완료 여부. 로그인 직후 클라이언트가 동의 게이트 분기에 사용.
        // 신규 가입은 항상 true, 테스트 계정은 auto-consent 라 false.
        boolean consentRequired
) {}
