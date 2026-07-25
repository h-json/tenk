package com.hjson.tenk.domain.user.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record BirthDateRequest(
        @NotNull LocalDate birthDate
) {
}
