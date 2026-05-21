package com.hjson.tenk.domain.challenge;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.badge.dto.AcquiredBadgeResponse;
import com.hjson.tenk.domain.challenge.dto.ChallengeCreateRequest;
import com.hjson.tenk.domain.challenge.dto.ChallengeResponse;
import com.hjson.tenk.domain.challenge.event.ChallengeFinishedEvent;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserService;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ChallengeService {

    private final ChallengeRepository challengeRepository;
    private final AmountRepository amountRepository;
    private final ChallengeBadgeRepository challengeBadgeRepository;
    private final UserService userService;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public ChallengeResponse create(Long userId, ChallengeCreateRequest request) {
        User user = userService.getActiveUser(userId);
        Challenge challenge = Challenge.create(user, request.startDate(), request.endDate(), request.targetAmount());
        Challenge saved = challengeRepository.save(challenge);
        // 새 챌린지엔 배지 없음 — 빈 리스트 인라인
        return ChallengeResponse.of(saved, 0L, LocalDate.now(), List.of());
    }

    public ChallengeResponse getOne(Long userId, Long challengeId) {
        Challenge challenge = loadOwned(userId, challengeId);
        return toResponse(challenge, LocalDate.now());
    }

    public List<ChallengeResponse> listMine(Long userId, boolean onlyActive) {
        User user = userService.getActiveUser(userId);
        LocalDate today = LocalDate.now();
        List<Challenge> challenges = onlyActive
                ? challengeRepository.findByUserAndDeletedFalseAndEndDateGreaterThanEqualOrderByStartDateAsc(user, today)
                : challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(user);
        return challenges.stream()
                .map(c -> toResponse(c, today))
                .toList();
    }

    @Transactional
    public void delete(Long userId, Long challengeId) {
        Challenge challenge = loadOwned(userId, challengeId);
        challenge.softDelete();
    }

    @Transactional
    public ChallengeResponse finalizeIfDue(Long userId, Long challengeId) {
        Challenge challenge = loadOwned(userId, challengeId);
        finalizeInternal(challenge);
        return toResponse(challenge, LocalDate.now());
    }

    @Transactional
    public int finalizeAllDue() {
        List<Challenge> dueChallenges = challengeRepository
                .findByDeletedFalseAndResultIsNullAndEndDateBefore(LocalDate.now());
        for (Challenge challenge : dueChallenges) {
            finalizeInternal(challenge);
        }
        return dueChallenges.size();
    }

    public Challenge loadOwned(Long userId, Long challengeId) {
        Challenge challenge = challengeRepository.findByIdAndDeletedFalse(challengeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.CHALLENGE_NOT_FOUND));
        if (!challenge.getUser().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.CHALLENGE_NOT_OWNER);
        }
        return challenge;
    }

    private ChallengeResponse toResponse(Challenge challenge, LocalDate today) {
        long total = amountRepository.sumByChallenge(challenge);
        List<AcquiredBadgeResponse> badges = challengeBadgeRepository
                .findByChallengeOrderByCreatedDtAsc(challenge)
                .stream()
                .map(AcquiredBadgeResponse::from)
                .toList();
        return ChallengeResponse.of(challenge, total, today, badges);
    }

    private void finalizeInternal(Challenge challenge) {
        if (challenge.getResult() != null) {
            return;
        }
        if (!challenge.isFinished(LocalDate.now())) {
            return;
        }
        long total = amountRepository.sumByChallenge(challenge);
        ChallengeResult result = total <= challenge.getTargetAmount()
                ? ChallengeResult.SUCCESS
                : ChallengeResult.FAIL;
        challenge.markResult(result);
        eventPublisher.publishEvent(new ChallengeFinishedEvent(
                challenge.getId(), challenge.getUser().getId(), result));
    }
}
