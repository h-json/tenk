package com.hjson.manwon.domain.amount.dto;

public record AmountCreateRequest(
        String category,
        String content,
        Integer amount,
        Boolean noSpend
) {
}
