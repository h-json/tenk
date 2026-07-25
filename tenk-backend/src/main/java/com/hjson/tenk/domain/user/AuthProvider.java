package com.hjson.tenk.domain.user;

public enum AuthProvider {
    GOOGLE,
    KAKAO,
    NAVER,
    /**
     * @deprecated 카카오 우회 테스트 로그인 제거로 더 이상 새로 생성되지 않는다. 기존 로컬 데이터
     * 호환을 위해 enum·스키마 값만 남겨둠. 내부 테스터는 이제 실제 카카오 계정을
     * {@link UserRole#TESTER} 로 승격해 쓴다.
     */
    @Deprecated
    TEST
}
