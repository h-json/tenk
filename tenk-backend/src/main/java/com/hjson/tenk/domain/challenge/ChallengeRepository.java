package com.hjson.tenk.domain.challenge;

import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChallengeRepository extends JpaRepository<Challenge, Long> {

    Optional<Challenge> findByIdAndDeletedFalse(Long id);

    List<Challenge> findByUserAndDeletedFalseOrderByStartDateDesc(User user);

    /**
     * "활성 챌린지" = 종료일이 오늘 이후이거나 같은 챌린지.
     * 시작 전 챌린지도 활성으로 포함한다 (정렬은 시작일 오름차순).
     */
    List<Challenge> findByUserAndDeletedFalseAndEndDateGreaterThanEqualOrderByStartDateAsc(User user, LocalDate today);

    /** 매일 새벽 배치에서 호출. 종료일이 어제까지인 미확정 챌린지. */
    List<Challenge> findByDeletedFalseAndResultIsNullAndEndDateBefore(LocalDate today);

    /// 계정 파기 배치용 — 해당 유저의 모든 challenge row 벌크 삭제 (soft delete 여부 무관).
    /// amount/challenge_badge 삭제 후에 호출.
    @Modifying
    @Query("delete from Challenge c where c.user.id = :userId")
    void deleteByUserId(@Param("userId") Long userId);
}
