package com.hjson.tenk.domain.badge;

import com.hjson.tenk.domain.challenge.Challenge;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChallengeBadgeRepository extends JpaRepository<ChallengeBadge, Long> {

    boolean existsByChallengeAndBadge(Challenge challenge, Badge badge);

    /// `Badge`를 JOIN FETCH 로 같이 끌어와 lazy 초기화 예외를 차단한다.
    /// challenge 응답 매핑 시점이 트랜잭션 밖일 수 있고, 그때 badge.type 등을 건드리면
    /// derived query 는 LazyInitializationException 으로 터진다.
    @Query("SELECT cb FROM ChallengeBadge cb JOIN FETCH cb.badge "
            + "WHERE cb.challenge = :challenge ORDER BY cb.createdDt ASC")
    List<ChallengeBadge> findByChallengeOrderByCreatedDtAsc(@Param("challenge") Challenge challenge);
}
