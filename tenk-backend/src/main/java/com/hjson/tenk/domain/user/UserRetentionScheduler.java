package com.hjson.tenk.domain.user;

import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 매일 새벽 1시 30분: 탈퇴 후 보관 기간이 지난 계정 물리 삭제.
 *
 * <p>{@link WithdrawnUserPurgeService#purge(Long)} 를 유저별로 <b>외부 호출</b>해 유저 단위
 * 트랜잭션 경계를 살린다 (self-invocation 이면 @Transactional 프록시가 안 걸림). 한 계정 파기가
 * 실패해도 나머지는 계속 진행한다. 배지 재평가 배치(1시)와 겹치지 않게 30분 뒤로 둔다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class UserRetentionScheduler {

    private final WithdrawnUserPurgeService purgeService;

    @Scheduled(cron = "0 30 1 * * *", zone = "Asia/Seoul")
    public void purgeWithdrawnUsers() {
        List<Long> ids = purgeService.findPurgeableUserIds();
        if (ids.isEmpty()) {
            return;
        }
        log.info("[UserRetentionScheduler] purge start, count={}", ids.size());
        int purged = 0;
        for (Long userId : ids) {
            try {
                purgeService.purge(userId);
                purged++;
            } catch (Exception e) {
                log.error("[UserRetentionScheduler] purge failed for userId={}", userId, e);
            }
        }
        log.info("[UserRetentionScheduler] purge done, purged={}/{}", purged, ids.size());
    }
}
