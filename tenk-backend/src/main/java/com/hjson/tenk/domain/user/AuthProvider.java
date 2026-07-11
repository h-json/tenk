package com.hjson.tenk.domain.user;

public enum AuthProvider {
    GOOGLE,
    KAKAO,
    NAVER,
    /** 테스트 전용 — 카카오 없이 발급되는 격리된 테스트 계정 (tenk.test.enabled=true 일 때만). */
    TEST
}
