package com.hjson.tenk.domain.challenge.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record ChallengeCreateRequest(
        // 비우면 서버가 "챌린지 N" 기본값을 생성한다 (그래서 nullable).
        @Size(max = 100) String name,
        @NotNull LocalDate startDate,
        @NotNull LocalDate endDate,
        @NotNull @Min(1) Integer targetAmount
) {
}
