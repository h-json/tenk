package com.hjson.tenk.domain.challenge.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record ChallengeCreateRequest(
        // 이름은 필수. 클라이언트가 "챌린지 N" 기본값을 미리 채워 보낸다 (서버는 빈값 거부).
        @NotBlank @Size(max = 100) String name,
        @NotNull LocalDate startDate,
        @NotNull LocalDate endDate,
        @NotNull @Min(1) Integer targetAmount
) {
}
