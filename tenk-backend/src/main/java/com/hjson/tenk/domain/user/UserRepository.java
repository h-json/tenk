package com.hjson.tenk.domain.user;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByProviderAndProviderUserId(AuthProvider provider, String providerUserId);

    Optional<User> findByIdAndDeletedFalse(Long id);

    /// 탈퇴 후 보관 기간이 지난 계정 id. 새벽 파기 배치가 hard delete 대상으로 조회.
    @Query("select u.id from User u where u.deleted = true and u.deletedDt < :cutoff")
    List<Long> findIdsToPurge(@Param("cutoff") LocalDateTime cutoff);

    /// 관리자 패널의 사용자 검색. 닉네임 부분 일치 또는 **공급자 회원번호 정확 일치** —
    /// 후자가 TESTER 승격의 실제 사용 경로다(카카오 회원번호로 특정 계정을 찾는다).
    /// 검색어가 비면 전체를 최신 가입순으로 준다.
    ///
    /// **탈퇴한 계정도 포함한다** — 승격 대상은 아니지만 "왜 로그인이 안 되나" 문의를 볼 때
    /// 탈퇴 여부가 곧 답인 경우가 많아 목록에서 사라지면 오히려 헷갈린다.
    @Query("""
            select u from User u
            where :keyword is null
               or lower(u.nickname) like lower(concat('%', :keyword, '%'))
               or u.providerUserId = :keyword
            """)
    Page<User> searchForAdmin(@Param("keyword") String keyword, Pageable pageable);
}
