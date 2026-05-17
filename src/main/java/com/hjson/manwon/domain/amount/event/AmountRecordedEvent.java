package com.hjson.manwon.domain.amount.event;

public record AmountRecordedEvent(Long amountId, Long userId, Long challengeId) {
}
