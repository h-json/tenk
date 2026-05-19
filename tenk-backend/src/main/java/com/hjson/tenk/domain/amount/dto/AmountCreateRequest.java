package com.hjson.tenk.domain.amount.dto;

import java.time.LocalDateTime;

/**
 * {@code dateTime}는 클라이언트가 비워두면 서버에서 지금 시각으로 채운다.
 * 날짜 부분이 챌린지 기간 안에 있어야 한다 ({@link com.hjson.tenk.domain.amount.Amount} 검증).
 */
public record AmountCreateRequest(
        String category,
        String content,
        Integer amount,
        Boolean noSpend,
        LocalDateTime dateTime
) {
}
