package com.hjson.tenk.domain.challenge.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChallengeUpdateRequest(
        @NotBlank @Size(max = 100) String name
) {
}
