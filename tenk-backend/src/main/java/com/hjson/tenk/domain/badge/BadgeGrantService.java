package com.hjson.tenk.domain.badge;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 배지 지급 정책 — <b>한 챌린지 안에서만</b> 계산.
 * <ul>
 *   <li>STREAK : 그 챌린지 안에서 매일(지출+무지출 포함) 기록한 연속 일수</li>
 *   <li>NO_SPEND : 그 챌린지 안에서 "지출 0원" 만 기록된 연속 일수 (같은 날 지출이 끼면 끊김)</li>
 *   <li>CHALLENGE_SUCCESS : 챌린지가 성공으로 확정될 때 1회 지급</li>
 * </ul>
 * 단계 (condition_value): 3 / 7 / 14 / 30.
 *
 * <p>유저 단위 누적(여러 챌린지를 가로지르는 "업적")은 이 서비스의 책임이 아니다. 업적 시스템은
 * 별도 테이블/서비스로 추후 추가 예정.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BadgeGrantService {

    private final AmountRepository amountRepository;
    private final BadgeRepository badgeRepository;
    private final ChallengeBadgeRepository challengeBadgeRepository;
    private final ChallengeRepository challengeRepository;

    /**
     * 한 챌린지의 STREAK / NO_SPEND 배지를 재평가한다. CHALLENGE_SUCCESS 는 별도
     * {@link #grantChallengeSuccess} 가 담당.
     */
    @Transactional
    public void evaluateForChallenge(Long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId).orElse(null);
        if (challenge == null || challenge.isDeleted()) return;

        // 챌린지 내부 amount 만 로드 (사용자 단위가 아님). spentDt 의 날짜 부분만 사용.
        List<Amount> records = amountRepository
                .findByChallengeOrderBySpentDtAscCreatedDtAsc(challenge);

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
        daysWithOnlyNoSpend.removeAll(daysWithSpend);

        // 챌린지가 진행 중이면 today 기준, 종료됐다면 endDate 기준. 진행 중인데 오늘 기록이 없으면
        // 어제 기준으로 fallback 하는 기존 동작은 consecutiveStreakEndingOn 안에서 유지.
        LocalDate today = LocalDate.now();
        LocalDate endingOn = today.isAfter(challenge.getEndDate())
                ? challenge.getEndDate()
                : today;

        int streak = consecutiveStreakEndingOn(daysWithAnyRecord, endingOn);
        int noSpendStreak = consecutiveStreakEndingOn(daysWithOnlyNoSpend, endingOn);

        grantLadderUpTo(challenge, BadgeType.STREAK, streak);
        grantLadderUpTo(challenge, BadgeType.NO_SPEND, noSpendStreak);
    }

    @Transactional
    public void grantChallengeSuccess(Long challengeId, ChallengeResult result) {
        if (result != ChallengeResult.SUCCESS) return;
        Challenge challenge = challengeRepository.findById(challengeId).orElse(null);
        if (challenge == null || challenge.isDeleted()) return;
        badgeRepository.findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1)
                .ifPresent(badge -> grantIfAbsent(challenge, badge));
    }

    /** 미확정 + 활성(soft-delete 아님) 챌린지 모두 재평가. 스케줄러가 호출. */
    @Transactional
    public void evaluateAllActive() {
        challengeRepository.findAll().stream()
                .filter(c -> !c.isDeleted())
                .forEach(c -> {
                    try {
                        evaluateForChallenge(c.getId());
                    } catch (Exception e) {
                        log.warn("[Badge] evaluation failed challengeId={}", c.getId(), e);
                    }
                });
    }

    private void grantLadderUpTo(Challenge challenge, BadgeType type, int currentStreak) {
        if (currentStreak <= 0) return;
        List<Badge> ladder = badgeRepository.findByTypeOrderByConditionValueAsc(type);
        for (Badge badge : ladder) {
            if (currentStreak >= badge.getConditionValue()) {
                grantIfAbsent(challenge, badge);
            }
        }
    }

    private void grantIfAbsent(Challenge challenge, Badge badge) {
        if (!challengeBadgeRepository.existsByChallengeAndBadge(challenge, badge)) {
            challengeBadgeRepository.save(ChallengeBadge.create(challenge, badge));
            log.info("[Badge] granted challengeId={} badgeId={} type={} value={}",
                    challenge.getId(), badge.getId(), badge.getType(), badge.getConditionValue());
        }
    }

    private static int consecutiveStreakEndingOn(Set<LocalDate> days, LocalDate endingOn) {
        if (days.isEmpty()) return 0;
        int streak = 0;
        LocalDate cursor = endingOn;
        while (days.contains(cursor)) {
            streak++;
            cursor = cursor.minusDays(1);
        }
        if (streak == 0 && days.contains(endingOn.minusDays(1))) {
            cursor = endingOn.minusDays(1);
            while (days.contains(cursor)) {
                streak++;
                cursor = cursor.minusDays(1);
            }
        }
        return streak;
    }
}
