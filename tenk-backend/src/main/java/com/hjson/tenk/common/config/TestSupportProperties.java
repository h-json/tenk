package com.hjson.tenk.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 테스트 전용 기능(카카오 우회 로그인 + 상태별 챌린지 시딩) 게이팅.
 *
 * <p><b>enabled</b>: 전체 on/off 킬스위치. false 면 테스트 엔드포인트가 모두 거부된다.
 * 배포 환경에선 docker-compose 의 {@code TENK_TEST_ENABLED} 환경변수로 재빌드 없이 토글 (Spring
 * relaxed binding 이 {@code tenk.test.enabled} 를 덮어씀). 정식 출시 시 false 로.
 * <p><b>loginKey</b>: {@code POST /api/auth/test/login} 요청이 제시해야 하는 공유 시크릿.
 * Flutter 빌드의 {@code --dart-define=TEST_LOGIN_KEY} 와 같은 값이어야 한다.
 * <p><b>providerUserIdPrefix</b>: 슬롯 이름 앞에 붙는 접두어. 테스터별 격리 계정
 * {@code provider_user_id = prefix + slot} (예: {@code test-alice}).
 */
@ConfigurationProperties(prefix = "tenk.test")
public record TestSupportProperties(boolean enabled, String loginKey, String providerUserIdPrefix) {

    public TestSupportProperties {
        if (providerUserIdPrefix == null || providerUserIdPrefix.isBlank()) {
            providerUserIdPrefix = "test-";
        }
    }
}
