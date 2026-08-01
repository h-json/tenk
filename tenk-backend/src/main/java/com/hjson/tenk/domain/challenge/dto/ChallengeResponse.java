package com.hjson.tenk.domain.challenge.dto;

import com.hjson.tenk.domain.badge.dto.AcquiredBadgeResponse;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import com.hjson.tenk.domain.challenge.ChallengeStats;
import java.time.LocalDate;
import java.util.List;

public record ChallengeResponse(
        Long challengeId,
        String name,
        LocalDate startDate,
        LocalDate endDate,
        int targetAmount,
        long totalSpent,
        long balance,
        ChallengeResult result,
        boolean started,
        boolean finished,
        /// 연속 기록 일수 / 무지출 누적 일수. 배지 지급과 <b>같은 계산</b>({@code ChallengeStatsCalculator})이라,
        /// 클라이언트는 이 값을 다시 세지 않고 알림 문구("오늘 기록하면 7일 연속 배지예요")에 그대로 쓴다.
        int currentStreak,
        int noSpendDays,
        List<AcquiredBadgeResponse> badges
) {
    public static ChallengeResponse of(
            Challenge challenge,
            long totalSpent,
            LocalDate today,
            ChallengeStats stats,
            List<AcquiredBadgeResponse> badges
    ) {
        return new ChallengeResponse(
                challenge.getId(),
                challenge.getName(),
                challenge.getStartDate(),
                challenge.getEndDate(),
                challenge.getTargetAmount(),
                totalSpent,
                challenge.getTargetAmount() - totalSpent,
                challenge.getResult(),
                challenge.isStarted(today),
                challenge.isFinished(today),
                stats.currentStreak(),
                stats.noSpendDays(),
                badges
        );
    }
}
