package com.hjson.tenk.domain.user;

/**
 * 계정 권한. 기본은 {@link #USER}, 내부 테스터 계정만 DB 에서 {@link #TESTER} 로 승격한다
 * (승격은 SQL 로 직접 — 앱에는 권한을 부여하는 경로가 없다).
 *
 * <p>추후 {@code ADMIN} 등 운영 권한을 추가할 여지를 두려고 boolean 플래그가 아니라 role 로 뒀다.
 * 능력 판정은 enum 비교가 코드에 흩어지지 않도록 {@link #canUseTestTools()} 같은 헬퍼로 캡슐화한다.
 */
public enum UserRole {
    USER,
    TESTER;

    /** 테스트 데이터 시딩({@code POST /api/dev/seed}) 등 테스트 도구를 쓸 수 있는지. */
    public boolean canUseTestTools() {
        return this == TESTER;
    }
}
