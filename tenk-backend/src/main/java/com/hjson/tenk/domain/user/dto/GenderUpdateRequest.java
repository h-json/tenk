package com.hjson.tenk.domain.user.dto;

import com.hjson.tenk.domain.user.Gender;

/**
 * 성별 변경 요청. {@code gender} 가 null 이면 <b>미입력으로 되돌린다</b> — 선택 항목의 수집 철회 경로라
 * 일부러 {@code @NotNull} 을 걸지 않는다.
 */
public record GenderUpdateRequest(
        Gender gender
) {
}
