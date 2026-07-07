package com.hjson.tenk.domain.auth;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Query("update RefreshToken rt set rt.revoked = true where rt.user.id = :userId and rt.revoked = false")
    int revokeAllByUserId(@Param("userId") Long userId);

    /// 계정 파기 배치용 — 해당 유저의 모든 refresh_token row 벌크 삭제 (revoke 가 아니라 물리 삭제).
    @Modifying
    @Query("delete from RefreshToken rt where rt.user.id = :userId")
    void deleteByUserId(@Param("userId") Long userId);
}
