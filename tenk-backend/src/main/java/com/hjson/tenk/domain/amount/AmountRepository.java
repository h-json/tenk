package com.hjson.tenk.domain.amount;

import com.hjson.tenk.domain.challenge.Challenge;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AmountRepository extends JpaRepository<Amount, Long> {

    /** 챌린지 상세 화면용. 사용자 지정 시각(spentDt) 기준으로 정렬, 동시각이면 입력 순. */
    List<Amount> findByChallengeOrderBySpentDtAscCreatedDtAsc(Challenge challenge);

    /// 계정 파기 배치용 — 해당 유저의 모든 amount row 벌크 삭제. media_file 삭제 후, challenge 삭제 전에 호출.
    @Modifying
    @Query("delete from Amount a where a.challenge.id in "
            + "(select c.id from Challenge c where c.user.id = :userId)")
    void deleteByUserId(@Param("userId") Long userId);

    @Query("""
            select coalesce(sum(a.amount), 0)
            from Amount a
            where a.challenge = :challenge
            """)
    long sumByChallenge(@Param("challenge") Challenge challenge);

    /**
     * 배지 연속일 계산용. spentDt가 [from, toExclusive) 구간.
     * 호출자가 날짜 경계를 LocalDateTime(자정 기준)으로 변환해서 넘긴다.
     */
    @Query("""
            select a from Amount a
            where a.challenge.user.id = :userId
              and a.spentDt >= :from
              and a.spentDt < :toExclusive
            order by a.spentDt asc
            """)
    List<Amount> findUserAmountsBetween(@Param("userId") Long userId,
                                        @Param("from") LocalDateTime from,
                                        @Param("toExclusive") LocalDateTime toExclusive);

    /// 같은 챌린지 + 같은 날(spentDt 의 DATE 부분) 의 무지출 row. DB 의 uk_amount_no_spend_day 인덱스 덕에
    /// 정상 흐름에선 최대 1건이지만 동시 요청 대비 List 로 받는다. 지출 등록 시 자동 삭제, 무지출 등록 시
    /// 중복 차단 양쪽에서 사용.
    @Query("""
            select a from Amount a
            where a.challenge = :challenge
              and a.noSpend = true
              and a.spentDt >= :from
              and a.spentDt < :toExclusive
            """)
    List<Amount> findNoSpendInChallengeOnDay(@Param("challenge") Challenge challenge,
                                             @Param("from") LocalDateTime from,
                                             @Param("toExclusive") LocalDateTime toExclusive);
}
