package com.hjson.tenk.domain.challenge;

import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChallengeRepository extends JpaRepository<Challenge, Long> {

    Optional<Challenge> findByIdAndDeletedFalse(Long id);

    /** 기본 이름 "챌린지 N" 의 N 산정용 — 삭제분 제외 현재 챌린지 수. */
    long countByUserAndDeletedFalse(User user);

    List<Challenge> findByUserAndDeletedFalseOrderByStartDateDesc(User user);

    /**
     * "활성 챌린지" = 종료일이 오늘 이후이거나 같은 챌린지.
     * 시작 전 챌린지도 활성으로 포함한다 (정렬은 시작일 오름차순).
     */
    List<Challenge> findByUserAndDeletedFalseAndEndDateGreaterThanEqualOrderByStartDateAsc(User user, LocalDate today);

    /** 매일 새벽 배치에서 호출. 종료일이 어제까지인 미확정 챌린지. */
    List<Challenge> findByDeletedFalseAndResultIsNullAndEndDateBefore(LocalDate today);
}
