package com.hjson.tenk.devtools;

import jakarta.validation.constraints.NotBlank;

/**
 * 테스트 로그인 요청.
 *
 * @param key  공유 시크릿 (tenk.test.login-key 와 일치해야 함)
 * @param slot 테스터별 격리 계정 식별자 (예: 본인 이름). {@code provider_user_id = prefix + slot}
 */
public record TestLoginRequest(
        @NotBlank String key,
        @NotBlank String slot
) {}
