package com.hjson.tenk.domain.user;

/**
 * 계정 권한. 기본은 {@link #USER} 이고, 나머지는 <b>DB 에서 SQL 로 직접 승격</b>한다 —
 * 앱에는 권한을 부여하는 경로가 없다.
 *
 * <pre>
 * UPDATE user SET role='TESTER' WHERE provider='KAKAO' AND provider_user_id='&lt;카카오회원번호&gt;';
 * </pre>
 *
 * <p>능력 판정은 enum 비교가 코드에 흩어지지 않도록 {@link #canUseTestTools()} 같은 헬퍼로 캡슐화한다.
 */
public enum UserRole {

    USER,

    /** 내부 테스터. 테스트 데이터 시딩을 쓸 수 있다. <b>시딩은 호출자 본인 데이터를 지우므로 소모용 계정이어야 한다.</b> */
    TESTER,

    /**
     * 운영자. 현재는 {@link #TESTER} 의 상위 권한이라는 것 외에 게이트하는 기능이 없고,
     * <b>관리자 패널을 짓게 될 때 그 게이트가 될 자리</b>다 (도입 트리거는 UGC 모더레이션 —
     * {@code decisions.md} "앱 버전·업데이트 게이트 회의").
     *
     * <p>⚠️ <b>문의·의견 알림 수신자를 이 role 로 찾지 말 것.</b> {@code user} 에는 이메일 컬럼이 없다
     * (2026-07-26 #10 에서 수집을 접고 컬럼까지 DROP 했고, 카카오에서도 받아오지 못한다). 수신 주소는
     * {@code tenk.notify.mail.to} 설정이 진실의 원천이고, DB 로 옮겨야 할 만큼 수신자가 늘면
     * {@code user} 가 아니라 별도 운영자 연락처 테이블을 만들 것 — 운영자 연락처는 이용자 개인정보가 아니다.
     */
    ADMIN;

    /** 테스트 데이터 시딩({@code POST /api/dev/seed}) 등 테스트 도구를 쓸 수 있는지. */
    public boolean canUseTestTools() {
        return this == TESTER || this == ADMIN;
    }
}
