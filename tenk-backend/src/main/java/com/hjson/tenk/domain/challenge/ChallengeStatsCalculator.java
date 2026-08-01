package com.hjson.tenk.domain.challenge;

import com.hjson.tenk.domain.amount.Amount;
import java.time.LocalDate;
import java.util.Collection;
import java.util.Set;
import java.util.TreeSet;

/**
 * 챌린지 진행 지표(STREAK 연속일 / NO_SPEND 누적일) 계산 — <b>이 클래스가 유일한 출처다.</b>
 *
 * <p><b>왜 뽑아뒀나</b>: 같은 값을 두 곳이 쓴다 — 배지 지급({@code BadgeGrantService})과
 * 응답 노출({@link com.hjson.tenk.domain.challenge.dto.ChallengeResponse}). 복붙하면 아래
 * "오늘 기록이 없으면 어제 기준" 같은 규칙이 갈라지고, 그러면 <b>"하루만 더 기록하면 배지"
 * 라는 알림을 받고 기록했는데 배지가 안 나오는</b> 상황이 된다.
 *
 * <p>클라이언트도 이 값을 다시 세지 않는다 (CLAUDE.md "알림" — 서버가 진실의 원천).
 */
public final class ChallengeStatsCalculator {

    private ChallengeStatsCalculator() {
    }

    /** 기록 목록에서 지표를 계산한다. {@code records} 는 그 챌린지의 amount 전체. */
    public static ChallengeStats from(Collection<Amount> records, LocalDate endDate, LocalDate today) {
        Set<LocalDate> daysWithAnyRecord = new TreeSet<>();
        Set<LocalDate> daysWithOnlyNoSpend = new TreeSet<>();
        Set<LocalDate> daysWithSpend = new TreeSet<>();

        for (Amount a : records) {
            LocalDate day = a.getSpentDt().toLocalDate();
            daysWithAnyRecord.add(day);
            if (a.isNoSpend()) {
                daysWithOnlyNoSpend.add(day);
            } else {
                daysWithSpend.add(day);
            }
        }
        // 같은 날 지출이 한 건이라도 있으면 그 날은 무지출로 치지 않는다.
        daysWithOnlyNoSpend.removeAll(daysWithSpend);

        int streak = consecutiveEndingOn(daysWithAnyRecord, endingOn(endDate, today));
        return new ChallengeStats(streak, daysWithOnlyNoSpend.size());
    }

    /** STREAK 이 끝나는 기준일 — 진행 중이면 today, 이미 종료됐으면 endDate. */
    public static LocalDate endingOn(LocalDate endDate, LocalDate today) {
        return today.isAfter(endDate) ? endDate : today;
    }

    /**
     * {@code endingOn} 에서 하루씩 거꾸로 세는 연속 일수.
     *
     * <p><b>오늘 기록이 없으면 어제 기준까지만 봐준다</b> — 이틀 이상 비면 0. 의도된 동작이고,
     * 아직 기록할 시간이 남은 오늘 하루 종일 "연속이 끊겼다" 고 말하지 않으려는 것이다.
     */
    public static int consecutiveEndingOn(Set<LocalDate> daysWithAnyRecord, LocalDate endingOn) {
        if (daysWithAnyRecord.isEmpty()) return 0;
        int streak = 0;
        LocalDate cursor = endingOn;
        while (daysWithAnyRecord.contains(cursor)) {
            streak++;
            cursor = cursor.minusDays(1);
        }
        if (streak == 0 && daysWithAnyRecord.contains(endingOn.minusDays(1))) {
            cursor = endingOn.minusDays(1);
            while (daysWithAnyRecord.contains(cursor)) {
                streak++;
                cursor = cursor.minusDays(1);
            }
        }
        return streak;
    }
}
