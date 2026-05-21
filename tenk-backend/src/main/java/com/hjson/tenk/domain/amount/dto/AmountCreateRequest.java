package com.hjson.tenk.domain.amount.dto;

import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;

/**
 * {@code dateTime}는 클라이언트가 비워두면 서버에서 지금 시각으로 채운다.
 * 날짜 부분이 챌린지 기간 안에 있어야 한다 ({@link com.hjson.tenk.domain.amount.Amount} 검증).
 *
 * <p>{@code memo}는 사용자가 기록 시 남기는 자유 텍스트. 영상 export 시 자막 디폴트를 오버라이드한다
 * (있으면 그 값, 없으면 지출="내용 금액원" / 무지출="무지출").
 */
public record AmountCreateRequest(
        String category,
        String content,
        Integer amount,
        Boolean noSpend,
        @Size(max = 500) String memo,
        LocalDateTime dateTime
) {
}
