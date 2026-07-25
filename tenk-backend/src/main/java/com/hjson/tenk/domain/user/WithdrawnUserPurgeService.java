package com.hjson.tenk.domain.user;

import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.auth.RefreshTokenRepository;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.media.LocalFileStorage;
import com.hjson.tenk.domain.media.MediaFileRepository;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 탈퇴(soft delete) 후 보관 기간이 지난 계정을 물리 삭제(hard delete)한다.
 *
 * <p>개인정보처리방침상 <b>탈퇴 후 {@link #RETENTION} 보관 후 파기</b>. 배치 트리거는
 * {@link UserRetentionScheduler}. 삭제 대상은 계정 본인 데이터 전부 — challenge/amount/media_file
 * row 와 <b>디스크에 저장된 영상 파일</b>, 그리고 refresh_token. soft delete 된 challenge 도 함께 파기.
 *
 * <p>삭제 순서는 FK 제약을 지켜 자식 → 부모로: 디스크 영상 → media_file → challenge_badge →
 * amount → challenge → refresh_token → user. 유저 1명 단위로 트랜잭션을 끊어 한 계정 실패가
 * 다른 계정 파기를 막지 않는다 (스케줄러가 유저별로 {@link #purge(Long)} 를 외부 호출).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WithdrawnUserPurgeService {

    /** 탈퇴 후 보관 기간. 지나면 파기. 추후 환경별 조정이 필요하면 @ConfigurationProperties 로 승격. */
    static final Period RETENTION = Period.ofMonths(3);

    private final UserRepository userRepository;
    private final ChallengeRepository challengeRepository;
    private final AmountRepository amountRepository;
    private final MediaFileRepository mediaFileRepository;
    private final ChallengeBadgeRepository challengeBadgeRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final LocalFileStorage storage;

    /** 보관 기간이 지난(=deletedDt 가 기준 시점보다 이른) 탈퇴 계정 id 목록. */
    public List<Long> findPurgeableUserIds() {
        LocalDateTime cutoff = LocalDateTime.now().minus(RETENTION);
        return userRepository.findIdsToPurge(cutoff);
    }

    /**
     * 계정 1명의 모든 데이터를 물리 삭제. 유저 단위 트랜잭션.
     *
     * <p>디스크 파일은 먼저 상대경로를 모아 삭제(트랜잭션 롤백돼도 파일은 되돌아오지 않으므로
     * row 삭제가 확정될 순서 마지막이 이상적이나, 배치라 재실행 시 고아 row 를 다시 처리하는 게
     * 아니라 이미 삭제된 계정이므로 파일 우선 삭제로 단순화한다). 이후 row 를 FK 순서로 벌크 삭제.
     */
    @Transactional
    public void purge(Long userId) {
        deleteEverythingOf(userId);
    }

    /**
     * 보관 기간 없이 즉시 파기. 연령 확인에서 <b>만 14세 미만</b>으로 판명된 계정처럼 애초에 이용
     * 대상이 아니어서 데이터를 남길 근거가 없는 경우에만 쓴다.
     *
     * <p>{@code REQUIRES_NEW} 인 이유: 호출자({@link UserService#verifyAge})가 파기 직후
     * {@code USER_UNDER_MINIMUM_AGE} 예외를 던져 자기 트랜잭션을 롤백시킨다. 같은 트랜잭션에서
     * 지우면 그 롤백에 삭제까지 함께 되돌아가 계정이 살아남는다.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void purgeImmediately(Long userId) {
        deleteEverythingOf(userId);
    }

    private void deleteEverythingOf(Long userId) {
        List<String> filePaths = mediaFileRepository.findFilePathsByUserId(userId);
        for (String path : filePaths) {
            storage.deleteQuietly(path);
        }

        mediaFileRepository.deleteByUserId(userId);
        challengeBadgeRepository.deleteByUserId(userId);
        amountRepository.deleteByUserId(userId);
        challengeRepository.deleteByUserId(userId);
        refreshTokenRepository.deleteByUserId(userId);
        userRepository.deleteById(userId);
    }
}
