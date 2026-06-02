package com.hjson.tenk.domain.auth;

public record AuthTokens(
        String accessToken,
        String refreshToken,
        long accessTokenExpiresIn,
        Long userId,
        String nickname,
        // 이번 카카오 로그인이 신규 가입을 만든 경우 true. refresh 응답에서는 항상 false.
        // 클라이언트는 true 일 때 NicknameSetupScreen 으로 분기 (가입 화면 강제).
        boolean isNewUser
) {}
