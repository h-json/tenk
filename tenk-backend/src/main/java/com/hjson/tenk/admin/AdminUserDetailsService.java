package com.hjson.tenk.admin;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 패널 로그인용 {@link UserDetailsService}. <b>{@code admin_user} 테이블만 본다</b> —
 * 이용자({@code user})는 여기로 로그인할 수 없고, 반대로 관리자는 앱에 로그인할 수 없다.
 *
 * <p>이 빈이 있으면 Spring Boot 의 기본 인메모리 계정(부팅 로그에 임시 비밀번호가 찍히는 그것)이
 * 만들어지지 않는다 — 부수 효과가 아니라 <b>바라던 결과</b>다.
 */
@Service
@RequiredArgsConstructor
public class AdminUserDetailsService implements UserDetailsService {

    /** 패널 접근 권한. {@code UserRole.ADMIN}(이용자 권한)과는 별개 축이다. */
    public static final String ROLE_ADMIN = "ROLE_ADMIN";

    private final AdminUserRepository adminUserRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 저장은 소문자로 정규화돼 있으므로 조회도 맞춘다 (대문자로 입력해도 로그인되게).
        String email = username == null ? "" : username.trim().toLowerCase();
        AdminUser admin = adminUserRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("admin not found"));

        return User.withUsername(admin.getEmail())
                .password(admin.getPasswordHash())
                .authorities(List.of(new SimpleGrantedAuthority(ROLE_ADMIN)))
                .build();
    }
}
