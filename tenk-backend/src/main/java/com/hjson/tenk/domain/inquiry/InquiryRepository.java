package com.hjson.tenk.domain.inquiry;

import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 문의 저장소. <b>조회 화면은 없다</b> — 의견과 마찬가지로 DB 에서 직접 훑고
 * ({@code SELECT * FROM inquiry WHERE status='PENDING' ORDER BY created_dt;}),
 * 처리 표시도 {@code UPDATE} 한 줄로 한다.
 *
 * <p>의견 테이블과 달리 <b>계정 파기 배치의 삭제 대상</b>이다 ({@code user_id} 를 들고 있으므로).
 */
public interface InquiryRepository extends JpaRepository<Inquiry, Long> {

    long countByStatus(InquiryStatus status);

    /** 미처리 중 가장 오래된 것의 접수 시각 — 리마인드 문구의 "N일 경과" 계산에 쓴다. */
    @Query("select min(i.createdDt) from Inquiry i where i.status = :status")
    Optional<LocalDateTime> findOldestCreatedDt(@Param("status") InquiryStatus status);

    /// 계정 파기 배치용 — 해당 유저의 모든 inquiry row 벌크 삭제. user 삭제 전에 호출.
    ///
    /// **문의를 지우는 경로는 이것 하나뿐이다.** 답변 여부로 파기하는 배치를 다시 만들지 말 것 —
    /// 보관 기간이 "회원 탈퇴 시까지"라 계정 생명주기에 위임돼 있다.
    @Modifying
    @Query("delete from Inquiry i where i.user.id = :userId")
    void deleteByUserId(@Param("userId") Long userId);
}
