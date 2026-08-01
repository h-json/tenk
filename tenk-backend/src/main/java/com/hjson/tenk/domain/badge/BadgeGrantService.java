package com.hjson.tenk.domain.badge;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import com.hjson.tenk.domain.challenge.ChallengeStats;
import com.hjson.tenk.domain.challenge.ChallengeStatsCalculator;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 배지 지급 정책 — <b>한 챌린지 안에서만</b> 계산.
 * <ul>
 *   <li>STREAK : 그 챌린지 안에서 매일(지출+무지출 포함) 기록한 <b>연속 일수</b></li>
 *   <li>NO_SPEND : 그 챌린지 안에서 "지출 0원" 만 기록된 <b>누적 일수</b>
 *       (연속이 아님 — 끊겼다가 다시 무지출해도 합산. 같은 날 지출이 끼면 그 날은 카운트되지 않음.)</li>
 *   <li>CHALLENGE_SUCCESS : 챌린지가 성공으로 확정될 때 1회 지급</li>
 * </ul>
 * 단계 (condition_value): 3 / 7 / 14 / 30.
 *
 * <p><b>revoke 정책</b>: 재평가 결과 현재 값이 조건 미달이면 이미 지급된 challenge_badge 도 삭제한다.
 * 예: 무지출 3일로 NO_SPEND 3 받았는데 그 중 하루에 지출이 추가돼서 무지출 row 가 자동 삭제되면,
 * 누적이 2일이 되므로 NO_SPEND 3 도 회수. STREAK 도 마찬가지로 연속이 깨지면 회수.
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
     * 한 챌린지의 STREAK / NO_SPEND 배지를 재평가한다 (grant + revoke 양방향).
     * CHALLENGE_SUCCESS 는 별도 {@link #grantChallengeSuccess} 가 담당.
     */
    @Transactional
    public void evaluateForChallenge(Long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId).orElse(null);
        if (challenge == null || challenge.isDeleted()) return;

        // 챌린지 내부 amount 만 로드 (사용자 단위가 아님). spentDt 의 날짜 부분만 사용.
        List<Amount> records = amountRepository
                .findByChallengeOrderBySpentDtAscCreatedDtAsc(challenge);

        // 계산은 ChallengeStatsCalculator 하나에만 둔다 — 응답의 currentStreak/noSpendDays 와
        // 같은 함수를 써야 "하루만 더 기록하면 배지" 알림과 실제 지급이 어긋나지 않는다.
        ChallengeStats stats = ChallengeStatsCalculator.from(
                records, challenge.getEndDate(), LocalDate.now());

        applyLadder(challenge, BadgeType.STREAK, stats.currentStreak());
        applyLadder(challenge, BadgeType.NO_SPEND, stats.noSpendDays());
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

    /**
     * 사다리(3/7/14/30 등)를 따라 현재 값보다 작거나 같은 단계는 grant, 큰 단계는 revoke 한다.
     * 한 메서드에 묶은 이유 = grant 와 revoke 가 동일한 ladder 를 단일 패스로 처리하면 충분하고,
     * 분리하면 ladder 를 두 번 fetch 하게 된다.
     */
    private void applyLadder(Challenge challenge, BadgeType type, int currentValue) {
        List<Badge> ladder = badgeRepository.findByTypeOrderByConditionValueAsc(type);
        for (Badge badge : ladder) {
            if (currentValue >= badge.getConditionValue()) {
                grantIfAbsent(challenge, badge);
            } else {
                revokeIfPresent(challenge, badge);
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

    private void revokeIfPresent(Challenge challenge, Badge badge) {
        int removed = challengeBadgeRepository.deleteByChallengeAndBadge(challenge, badge);
        if (removed > 0) {
            log.info("[Badge] revoked challengeId={} badgeId={} type={} value={}",
                    challenge.getId(), badge.getId(), badge.getType(), badge.getConditionValue());
        }
    }

}
