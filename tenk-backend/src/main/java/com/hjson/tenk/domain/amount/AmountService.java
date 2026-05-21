package com.hjson.tenk.domain.amount;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.amount.dto.AmountCreateRequest;
import com.hjson.tenk.domain.amount.dto.AmountRecordResult;
import com.hjson.tenk.domain.amount.dto.AmountResponse;
import com.hjson.tenk.domain.amount.event.AmountRecordedEvent;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeService;
import com.hjson.tenk.domain.media.LocalFileStorage;
import com.hjson.tenk.domain.media.LocalFileStorage.StoredFile;
import com.hjson.tenk.domain.media.MediaFile;
import com.hjson.tenk.domain.media.MediaFileRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AmountService {

    private final AmountRepository amountRepository;
    private final MediaFileRepository mediaFileRepository;
    private final ChallengeService challengeService;
    private final LocalFileStorage storage;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public AmountRecordResult record(Long userId, Long challengeId,
                                     AmountCreateRequest request, MultipartFile video) {
        Challenge challenge = challengeService.loadOwned(userId, challengeId);
        LocalDateTime now = LocalDateTime.now();
        LocalDate today = now.toLocalDate();
        if (challenge.isFinished(today)) {
            throw new BusinessException(ErrorCode.CHALLENGE_ALREADY_FINISHED);
        }
        if (!challenge.isStarted(today)) {
            throw new BusinessException(ErrorCode.CHALLENGE_NOT_STARTED);
        }

        boolean noSpend = Boolean.TRUE.equals(request.noSpend());
        LocalDateTime spentDt;
        int removedNoSpendCount = 0;

        if (noSpend) {
            // 무지출은 일시 입력 불가 — 클라이언트가 보낸 dateTime 은 의도적으로 무시한다.
            // (도메인: "오늘 하루 지출이 없다" 만 의미 있는 행위이므로 과거/미래 무지출 자체가 성립 X)
            spentDt = now;
            // 1차 방어선: 서비스 검증으로 친절한 에러. 2차 방어선: DB uk_amount_no_spend_day 인덱스.
            if (!findNoSpendOn(challenge, today).isEmpty()) {
                throw new BusinessException(ErrorCode.AMOUNT_NO_SPEND_ALREADY_EXISTS);
            }
        } else {
            spentDt = request.dateTime() != null ? request.dateTime() : now;
            // 지출 등록 시 같은 날 이미 무지출이 있으면 → 무지출 row + 첨부 영상 까지 자동 삭제.
            // "그 날이 무지출이냐 아니냐" 가 데이터상 모호해지지 않도록.
            List<Amount> sameDayNoSpend = findNoSpendOn(challenge, spentDt.toLocalDate());
            for (Amount old : sameDayNoSpend) {
                deleteAmountWithMedia(old);
            }
            removedNoSpendCount = sameDayNoSpend.size();
        }

        Amount amount = noSpend
                ? Amount.noSpend(challenge, spentDt)
                : Amount.spend(challenge, request.category(), request.content(),
                        request.amount() == null ? -1 : request.amount(), spentDt);
        amountRepository.save(amount);

        List<MediaFile> savedFiles = Collections.emptyList();
        if (!noSpend) {
            if (video == null || video.isEmpty()) {
                throw new BusinessException(ErrorCode.AMOUNT_VIDEO_REQUIRED);
            }
            StoredFile stored = storage.store(video, "amounts/" + challengeId);
            MediaFile media = mediaFileRepository.save(
                    MediaFile.create(amount, stored.relativePath(), stored.originalName()));
            savedFiles = List.of(media);
        } else if (video != null && !video.isEmpty()) {
            StoredFile stored = storage.store(video, "amounts/" + challengeId);
            MediaFile media = mediaFileRepository.save(
                    MediaFile.create(amount, stored.relativePath(), stored.originalName()));
            savedFiles = List.of(media);
        }

        eventPublisher.publishEvent(new AmountRecordedEvent(amount.getId(), userId, challengeId));
        return AmountRecordResult.of(amount, savedFiles, removedNoSpendCount);
    }

    public List<AmountResponse> listByChallenge(Long userId, Long challengeId) {
        Challenge challenge = challengeService.loadOwned(userId, challengeId);
        return amountRepository.findByChallengeOrderBySpentDtAscCreatedDtAsc(challenge).stream()
                .map(a -> AmountResponse.of(a, mediaFileRepository.findByAmount(a)))
                .toList();
    }

    @Transactional
    public void delete(Long userId, Long challengeId, Long amountId) {
        Amount amount = amountRepository.findById(amountId)
                .orElseThrow(() -> new BusinessException(ErrorCode.AMOUNT_NOT_FOUND));
        Challenge challenge = challengeService.loadOwned(userId, challengeId);
        if (!amount.getChallenge().getId().equals(challenge.getId())) {
            throw new BusinessException(ErrorCode.AMOUNT_NOT_FOUND);
        }
        deleteAmountWithMedia(amount);
    }

    private List<Amount> findNoSpendOn(Challenge challenge, LocalDate day) {
        LocalDateTime from = day.atStartOfDay();
        LocalDateTime toExclusive = day.plusDays(1).atStartOfDay();
        return amountRepository.findNoSpendInChallengeOnDay(challenge, from, toExclusive);
    }

    private void deleteAmountWithMedia(Amount amount) {
        List<MediaFile> mediaFiles = mediaFileRepository.findByAmount(amount);
        for (MediaFile mediaFile : mediaFiles) {
            storage.deleteQuietly(mediaFile.getFilePath());
        }
        mediaFileRepository.deleteByAmount(amount);
        amountRepository.delete(amount);
    }
}
