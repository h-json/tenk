package com.hjson.tenk.domain.challenge.dto;

import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import java.time.LocalDate;

public record ChallengeResponse(
        Long challengeId,
        LocalDate startDate,
        LocalDate endDate,
        int targetAmount,
        long totalSpent,
        long balance,
        ChallengeResult result,
        boolean started,
        boolean finished
) {
    public static ChallengeResponse of(Challenge challenge, long totalSpent, LocalDate today) {
        return new ChallengeResponse(
                challenge.getId(),
                challenge.getStartDate(),
                challenge.getEndDate(),
                challenge.getTargetAmount(),
                totalSpent,
                challenge.getTargetAmount() - totalSpent,
                challenge.getResult(),
                challenge.isStarted(today),
                challenge.isFinished(today)
        );
    }
}
