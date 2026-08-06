package com.hjson.tenk.admin;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminUserRepository extends JpaRepository<AdminUser, Long> {

    /** 이메일은 {@link AdminUser#of} 에서 소문자로 정규화되므로 조회도 소문자로 넘길 것. */
    Optional<AdminUser> findByEmail(String email);
}
