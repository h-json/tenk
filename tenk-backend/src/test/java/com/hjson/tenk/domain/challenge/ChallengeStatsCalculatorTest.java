package com.hjson.tenk.domain.challenge;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 진행 지표 계산 규칙 고정. 배지 지급과 응답의 currentStreak/noSpendDays 가 <b>이 클래스 하나</b>를
 * 공유하므로, 여기가 깨지면 "받은 배지" 와 "알림이 약속한 것" 이 동시에 어긋난다.
 */
class ChallengeStatsCalculatorTest {

    private static final LocalDate TODAY = LocalDate.parse("2026-08-03");

    private Challenge challenge;

    @BeforeEach
    void setUp() {
        User user = User.create(AuthProvider.KAKAO, "kakao-stats", "tester");
        // Challenge.create invariant(startDate >= today, 30일 이내)를 통과시킨 뒤 기간만 넓게 덮는다
        // — BadgeGrantServiceTest 와 같은 패턴. Amount 팩토리가 "기간 안" 검증을 하기 때문에 필요.
        challenge = Challenge.create(user, "지표 테스트", LocalDate.now(), LocalDate.now().plusDays(1), 10_000);
        ReflectionTestUtils.setField(challenge, "startDate", LocalDate.parse("2026-01-01"));
        ReflectionTestUtils.setField(challenge, "endDate", LocalDate.parse("2099-12-31"));
    }

    private static Set<LocalDate> days(String... isoDates) {
        Set<LocalDate> set = new TreeSet<>();
        for (String d : isoDates) {
            set.add(LocalDate.parse(d));
        }
        return set;
    }

    private Amount spendOn(String isoDate) {
        return Amount.spend(challenge, "FOOD", "x", 100, null, LocalDate.parse(isoDate).atTime(12, 0));
    }

    private Amount noSpendOn(String isoDate) {
        return Amount.noSpend(challenge, null, LocalDate.parse(isoDate).atTime(12, 0));
    }

    @Test
    @DisplayName("기준일부터 거꾸로 이어진 날만 센다")
    void countsConsecutiveDaysBackwards() {
        assertThat(ChallengeStatsCalculator.consecutiveEndingOn(
                days("2026-08-01", "2026-08-02", "2026-08-03"), TODAY))
                .isEqualTo(3);
    }

    @Test
    @DisplayName("중간에 빈 날이 있으면 그 앞은 세지 않는다")
    void stopsAtTheFirstGap() {
        assertThat(ChallengeStatsCalculator.consecutiveEndingOn(
                days("2026-07-28", "2026-07-29", "2026-08-02", "2026-08-03"), TODAY))
                .isEqualTo(2);
    }

    @Test
    @DisplayName("오늘 기록이 없으면 어제 기준으로 봐준다 — 아직 기록할 시간이 남았기 때문")
    void fallsBackToYesterdayWhenTodayIsEmpty() {
        assertThat(ChallengeStatsCalculator.consecutiveEndingOn(
                days("2026-08-01", "2026-08-02"), TODAY))
                .isEqualTo(2);
    }

    @Test
    @DisplayName("이틀 이상 비면 0 — 어제까지만 봐준다")
    void twoEmptyDaysBreakTheStreak() {
        assertThat(ChallengeStatsCalculator.consecutiveEndingOn(
                days("2026-08-01", "2026-08-02"), LocalDate.parse("2026-08-04")))
                .isZero();
    }

    @Test
    @DisplayName("기록이 하나도 없으면 0")
    void emptyIsZero() {
        assertThat(ChallengeStatsCalculator.consecutiveEndingOn(Set.of(), TODAY)).isZero();
    }

    @Test
    @DisplayName("진행 중이면 today, 종료된 뒤면 endDate 가 기준일")
    void endingOnClampsToEndDate() {
        LocalDate endDate = LocalDate.parse("2026-08-10");

        assertThat(ChallengeStatsCalculator.endingOn(endDate, LocalDate.parse("2026-08-05")))
                .isEqualTo(LocalDate.parse("2026-08-05"));
        assertThat(ChallengeStatsCalculator.endingOn(endDate, LocalDate.parse("2026-08-20")))
                .isEqualTo(endDate);
    }

    @Test
    @DisplayName("같은 날 여러 건을 기록해도 연속은 하루로 센다")
    void multipleRecordsOnOneDayCountOnce() {
        ChallengeStats stats = ChallengeStatsCalculator.from(
                List.of(spendOn("2026-08-03"), spendOn("2026-08-03"), spendOn("2026-08-03")),
                challenge.getEndDate(), TODAY);

        assertThat(stats.currentStreak()).isEqualTo(1);
    }

    @Test
    @DisplayName("무지출은 연속이 아니라 누적 — 끊겨도 합산된다")
    void noSpendAccumulatesEvenWithGaps() {
        ChallengeStats stats = ChallengeStatsCalculator.from(
                List.of(noSpendOn("2026-07-30"), noSpendOn("2026-08-01"), noSpendOn("2026-08-03")),
                challenge.getEndDate(), TODAY);

        assertThat(stats.noSpendDays()).isEqualTo(3);
        // 하루씩 띄엄띄엄이라 연속은 오늘 하루뿐
        assertThat(stats.currentStreak()).isEqualTo(1);
    }

    @Test
    @DisplayName("같은 날 지출이 한 건이라도 있으면 그 날은 무지출로 치지 않는다")
    void spendOnTheSameDayDisqualifiesNoSpend() {
        ChallengeStats stats = ChallengeStatsCalculator.from(
                List.of(noSpendOn("2026-08-02"), noSpendOn("2026-08-03"), spendOn("2026-08-03")),
                challenge.getEndDate(), TODAY);

        assertThat(stats.noSpendDays()).isEqualTo(1);
        // 이틀 다 "기록은 있는" 날이라 연속은 2
        assertThat(stats.currentStreak()).isEqualTo(2);
    }

    @Test
    @DisplayName("종료된 챌린지는 한참 뒤에 조회해도 연속일이 유지된다")
    void finishedChallengeKeepsItsStreak() {
        ChallengeStats stats = ChallengeStatsCalculator.from(
                List.of(spendOn("2026-08-01"), spendOn("2026-08-02"), spendOn("2026-08-03")),
                LocalDate.parse("2026-08-03"), LocalDate.parse("2026-09-01"));

        assertThat(stats.currentStreak()).isEqualTo(3);
    }

    @Test
    @DisplayName("기록이 없으면 두 지표 모두 0")
    void emptyRecordsGiveZeroStats() {
        assertThat(ChallengeStatsCalculator.from(List.of(), challenge.getEndDate(), TODAY))
                .isEqualTo(ChallengeStats.EMPTY);
    }

    @Test
    @DisplayName("spentDt 의 시각 부분은 무시하고 날짜만 본다")
    void ignoresTimeOfDay() {
        Amount lateNight = Amount.spend(
                challenge, "FOOD", "x", 100, null, LocalDate.parse("2026-08-02").atTime(23, 59));
        Amount earlyMorning = Amount.spend(
                challenge, "FOOD", "x", 100, null, LocalDate.parse("2026-08-03").atTime(0, 1));

        ChallengeStats stats = ChallengeStatsCalculator.from(
                List.of(lateNight, earlyMorning), challenge.getEndDate(), TODAY);

        assertThat(stats.currentStreak()).isEqualTo(2);
    }
}
