package com.hjson.tenk.domain.inquiry;

import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 문의 저장소. 조회·처리는 <b>관리자 패널</b>({@code /admin/inquiries})이 담당한다 —
 * 2026-08-06 까지는 {@code SELECT}/{@code UPDATE} 를 직접 쳤고 그때의 흔적이 여러 주석에 남아 있다.
 *
 * <p>의견 테이블과 달리 <b>계정 파기 배치의 삭제 대상</b>이다 ({@code user_id} 를 들고 있으므로).
 */
public interface InquiryRepository extends JpaRepository<Inquiry, Long> {

    long countByStatus(InquiryStatus status);

    /// 패널 목록. **{@code user} 를 JOIN FETCH 한다** — 목록에 닉네임을 찍는데 {@code Inquiry.user} 가
    /// LAZY 라 화면 렌더 중에 초기화하면 N+1 이 나고, {@code open-in-view=false} 라 아예 터진다.
    @Query(value = "select i from Inquiry i join fetch i.user",
            countQuery = "select count(i) from Inquiry i")
    Page<Inquiry> findAllForAdmin(Pageable pageable);

    @Query(value = "select i from Inquiry i join fetch i.user where i.status = :status",
            countQuery = "select count(i) from Inquiry i where i.status = :status")
    Page<Inquiry> findAllForAdminByStatus(@Param("status") InquiryStatus status, Pageable pageable);

    /** 상세 화면용. 목록과 같은 이유로 user 를 함께 끌어온다. */
    @Query("select i from Inquiry i join fetch i.user where i.id = :id")
    Optional<Inquiry> findByIdForAdmin(@Param("id") Long id);

    /// 계정 파기 배치용 — 해당 유저의 모든 inquiry row 벌크 삭제. user 삭제 전에 호출.
    ///
    /// **문의를 지우는 경로는 이것 하나뿐이다.** 답변 여부로 파기하는 배치를 다시 만들지 말 것 —
    /// 보관 기간이 "회원 탈퇴 시까지"라 계정 생명주기에 위임돼 있다.
    @Modifying
    @Query("delete from Inquiry i where i.user.id = :userId")
    void deleteByUserId(@Param("userId") Long userId);
}
