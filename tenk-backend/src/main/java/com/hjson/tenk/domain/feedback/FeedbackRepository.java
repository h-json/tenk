package com.hjson.tenk.domain.feedback;

import java.time.LocalDateTime;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 의견 저장소. 계정과 연결되지 않은 데이터라 계정 파기 배치
 * ({@code WithdrawnUserPurgeService})의 삭제 대상이 아니다 — 지우지 말 것.
 *
 * <p>쌓인 의견은 <b>관리자 패널</b>({@code /admin/feedbacks})에서 훑는다. 의견에는 처리 상태가
 * 없으므로 목록은 <b>최신순 한 줄기</b>뿐이다 — 즉시 처리해야 하는 큐가 아니라 모아서 보는
 * 데이터라는 성격은 그대로다.
 */
public interface FeedbackRepository extends JpaRepository<Feedback, Long> {

    /**
     * 보관 기간이 지난 회신용 이메일만 지우고 <b>의견 본문은 남긴다</b> — 개인정보만 떨어내면
     * 나머지는 익명 정보라 계속 보관할 수 있다. 개인정보처리방침 §3 에 고지한 동작이다.
     *
     * @return 지워진 건수
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Feedback f set f.replyEmail = null"
            + " where f.replyEmail is not null and f.createdDt < :threshold")
    int clearReplyEmailsCreatedBefore(@Param("threshold") LocalDateTime threshold);
}
