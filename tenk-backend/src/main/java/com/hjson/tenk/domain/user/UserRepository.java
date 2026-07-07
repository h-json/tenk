package com.hjson.tenk.domain.user;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByProviderAndProviderUserId(AuthProvider provider, String providerUserId);

    Optional<User> findByIdAndDeletedFalse(Long id);

    /// 탈퇴 후 보관 기간이 지난 계정 id. 새벽 파기 배치가 hard delete 대상으로 조회.
    @Query("select u.id from User u where u.deleted = true and u.deletedDt < :cutoff")
    List<Long> findIdsToPurge(@Param("cutoff") LocalDateTime cutoff);
}
