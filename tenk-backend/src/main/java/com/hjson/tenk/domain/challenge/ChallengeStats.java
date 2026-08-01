package com.hjson.tenk.domain.challenge;

/**
 * 한 챌린지의 진행 지표 — 배지 사다리가 보는 값과 <b>같은 값</b>이다.
 *
 * @param currentStreak 매일(지출·무지출 무관) 기록한 <b>연속</b> 일수
 * @param noSpendDays   "지출 0원" 만 기록된 날의 <b>누적</b> 일수 (연속이 아니다)
 */
public record ChallengeStats(int currentStreak, int noSpendDays) {

    public static final ChallengeStats EMPTY = new ChallengeStats(0, 0);
}
