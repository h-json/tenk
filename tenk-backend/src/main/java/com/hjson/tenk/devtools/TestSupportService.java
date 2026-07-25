package com.hjson.tenk.devtools;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.badge.BadgeGrantService;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.challenge.ChallengeResult;
import com.hjson.tenk.domain.media.LocalFileStorage;
import com.hjson.tenk.domain.media.MediaFileRepository;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import java.lang.reflect.Field;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.ReflectionUtils;

/**
 * 테스트 전용 지원 서비스 — 상태별 챌린지 시딩.
 *
 * <p>날짜 기반 앱이라 "완료/확정 대기" 같은 상태는 현실 날짜가 지나야만 자연 발생한다. 이 서비스는
 * 챌린지의 start/end 를 <b>reflection 으로 과거로 backdate</b> 해서 그 상태를 즉시 만든다
 * ({@link Challenge#create} 의 {@code validatePeriod} 는 미래 시작만 허용하므로 우회 필요).
 * 반면 금액·배지는 챌린지 기간 기준으로만 검증되므로 실제 팩토리/배지 로직을 그대로 재사용한다.
 *
 * <p>시딩은 호출자의 {@code role} 이 {@link com.hjson.tenk.domain.user.UserRole#TESTER} 일 때만
 * 허용 — 일반 사용자의 데이터는 절대 건드리지 않는다. 테스터 승격은 DB 에서 직접 하며 앱엔 경로가 없다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TestSupportService {

    private static final int TARGET = 10_000;

    private static final Field CHALLENGE_START_DATE = accessibleField("startDate");
    private static final Field CHALLENGE_END_DATE = accessibleField("endDate");

    private final UserRepository userRepository;
    private final ChallengeRepository challengeRepository;
    private final AmountRepository amountRepository;
    private final MediaFileRepository mediaFileRepository;
    private final ChallengeBadgeRepository challengeBadgeRepository;
    private final BadgeGrantService badgeGrantService;
    private final LocalFileStorage storage;

    /** 호출한 테스터 계정의 기존 데이터를 전부 지우고 5종 상태 챌린지를 시딩. */
    @Transactional
    public void reseed(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        if (!user.getRole().canUseTestTools()) {
            throw new BusinessException(ErrorCode.TEST_ONLY_OPERATION);
        }
        wipe(userId);
        seedAll(user);
    }

    /** 계정 파기 배치와 동일한 FK 순서로 그 유저 데이터만 벌크 삭제 (user/refresh_token 은 유지). */
    private void wipe(Long userId) {
        for (String path : mediaFileRepository.findFilePathsByUserId(userId)) {
            storage.deleteQuietly(path);
        }
        mediaFileRepository.deleteByUserId(userId);
        challengeBadgeRepository.deleteByUserId(userId);
        amountRepository.deleteByUserId(userId);
        challengeRepository.deleteByUserId(userId);
    }

    private void seedAll(User user) {
        LocalDate today = LocalDate.now();

        // 1) 시작 전 — 기록 없음.
        newChallenge(user, "시작 전 챌린지", today.plusDays(3), today.plusDays(12), null);

        // 2) 진행 중 — 5일 연속 기록(STREAK 3) + 무지출 3일(NO_SPEND 3). 총지출 < 목표.
        Challenge ongoing = newChallenge(user, "진행 중 챌린지", today.minusDays(4), today.plusDays(5), null);
        spend(ongoing, "FOOD", "점심 김밥", 3_000, today.minusDays(4));
        spend(ongoing, "TRANSPORT", "버스", 1_200, today.minusDays(3));
        noSpend(ongoing, today.minusDays(2));
        noSpend(ongoing, today.minusDays(1));
        noSpend(ongoing, today);
        evaluate(ongoing);

        // 3) 확정 대기 — 종료됐지만 미확정. finalize 누르면 SUCCESS (총지출 < 목표). 배지도 미리 형성.
        Challenge pending = newChallenge(user, "확정 대기 챌린지", today.minusDays(12), today.minusDays(2), null);
        spend(pending, "SHOPPING", "양말", 3_000, today.minusDays(12));
        noSpend(pending, today.minusDays(4));
        noSpend(pending, today.minusDays(3));
        noSpend(pending, today.minusDays(2));
        evaluate(pending);

        // 4) 완료-성공 — 총지출 5,500 ≤ 목표. CHALLENGE_SUCCESS + STREAK/NO_SPEND 배지.
        Challenge success = newChallenge(user, "성공 완료 챌린지", today.minusDays(25), today.minusDays(15), ChallengeResult.SUCCESS);
        spend(success, "FOOD", "커피", 2_000, today.minusDays(25));
        spend(success, "LIVING", "세제", 1_500, today.minusDays(24));
        spend(success, "TRANSPORT", "지하철", 2_000, today.minusDays(23));
        noSpend(success, today.minusDays(17));
        noSpend(success, today.minusDays(16));
        noSpend(success, today.minusDays(15));
        evaluate(success);
        badgeGrantService.grantChallengeSuccess(success.getId(), ChallengeResult.SUCCESS);

        // 5) 완료-실패 — 총지출 12,000 > 목표.
        Challenge fail = newChallenge(user, "실패 완료 챌린지", today.minusDays(25), today.minusDays(15), ChallengeResult.FAIL);
        spend(fail, "SHOPPING", "신발", 6_000, today.minusDays(25));
        spend(fail, "FOOD", "저녁", 6_000, today.minusDays(24));
        evaluate(fail);
    }

    /**
     * 챌린지 1개 생성. today 로 유효하게 만든 뒤 start/end 를 reflection 으로 backdate 하고,
     * result 가 있으면 확정 상태로 마킹한다. 저장은 IDENTITY 라 즉시 insert → id 확보.
     */
    private Challenge newChallenge(User user, String name, LocalDate start, LocalDate end, ChallengeResult result) {
        LocalDate today = LocalDate.now();
        Challenge challenge = Challenge.create(user, name, today, today, TARGET);
        ReflectionUtils.setField(CHALLENGE_START_DATE, challenge, start);
        ReflectionUtils.setField(CHALLENGE_END_DATE, challenge, end);
        challengeRepository.save(challenge);
        if (result != null) {
            challenge.markResult(result);
        }
        return challenge;
    }

    private void spend(Challenge challenge, String category, String content, int amount, LocalDate day) {
        amountRepository.save(Amount.spend(challenge, category, content, amount, null, day.atTime(12, 0)));
    }

    private void noSpend(Challenge challenge, LocalDate day) {
        amountRepository.save(Amount.noSpend(challenge, null, day.atTime(12, 0)));
    }

    private void evaluate(Challenge challenge) {
        badgeGrantService.evaluateForChallenge(challenge.getId());
    }

    private static Field accessibleField(String name) {
        Field field = ReflectionUtils.findField(Challenge.class, name);
        if (field == null) {
            throw new IllegalStateException("Challenge." + name + " 필드를 찾을 수 없습니다 (test seeding).");
        }
        ReflectionUtils.makeAccessible(field);
        return field;
    }
}
