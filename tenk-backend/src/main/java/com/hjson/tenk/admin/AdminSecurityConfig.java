package com.hjson.tenk.admin;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.http.HttpMethod;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;

/**
 * 관리자 패널 전용 보안 체인. <b>앱 인증({@code SecurityConfig})과 완전히 분리돼 있다.</b>
 *
 * <p>{@code securityMatcher("/admin/**")} 로 이 체인이 받는 경로를 못박고 {@link Order}(1) 로
 * 먼저 평가되게 한다. 나머지 요청은 전부 기존 체인이 <b>지금 그대로</b> 처리한다 —
 * STATELESS + JWT + CSRF 비활성. <b>둘을 한 체인에 합치지 말 것</b>: 세션·CSRF·폼 로그인은
 * 브라우저에 필요한 것이고, 그걸 전역으로 켜면 Flutter 앱의 인증 계약이 통째로 바뀐다.
 *
 * <p>차이가 나는 지점 세 곳:
 * <ul>
 *   <li><b>세션</b> — 브라우저는 요청마다 토큰을 붙일 수 없다. AT 는 1시간 만료라 화면을 쓰는 내내
 *       다시 로그인해야 하고, 브라우저에 JWT 를 두면 XSS 노출면이 는다.</li>
 *   <li><b>CSRF 활성</b> — 폼 POST 를 받으므로 반드시 켠다. 앱 체인이 꺼도 되는 건 JWT 를
 *       {@code Authorization} 헤더로 받아 브라우저가 자동으로 실어 보내지 않기 때문이다.</li>
 *   <li><b>인증 실패 시 로그인 화면으로 리다이렉트</b> — 앱 체인은 JSON envelope 을 내린다.</li>
 * </ul>
 *
 * <p>{@code tenk.admin.enabled=false} 면 이 체인 자체가 등록되지 않는다. 그러면 {@code /admin/**}
 * 은 기존 체인의 {@code anyRequest().authenticated()} 에 걸려 <b>401</b> 로 끊긴다 —
 * 컨트롤러까지 가지 않으므로 패널이 없는 것과 같다 (local/test 기본값).
 */
@Configuration
@ConditionalOnProperty(prefix = "tenk.admin", name = "enabled", havingValue = "true")
public class AdminSecurityConfig {

    public static final String LOGIN_PATH = "/admin/login";

    @Bean
    @Order(1)
    public SecurityFilterChain adminSecurityFilterChain(HttpSecurity http) throws Exception {
        http
                .securityMatcher("/admin/**")
                .authorizeHttpRequests(req -> req
                        .requestMatchers(LOGIN_PATH).permitAll()
                        .anyRequest().hasAuthority(AdminUserDetailsService.ROLE_ADMIN))
                .formLogin(form -> form
                        .loginPage(LOGIN_PATH)
                        .loginProcessingUrl(LOGIN_PATH)
                        .defaultSuccessUrl("/admin", true)
                        .failureUrl(LOGIN_PATH + "?error")
                        .permitAll())
                .logout(logout -> logout
                        // 로그아웃은 상태를 바꾸므로 POST 로만 받는다 (GET 이면 <img> 하나로 남을 로그아웃시킬 수 있다).
                        .logoutRequestMatcher(PathPatternRequestMatcher.withDefaults()
                                .matcher(HttpMethod.POST, "/admin/logout"))
                        .logoutSuccessUrl(LOGIN_PATH + "?logout")
                        .invalidateHttpSession(true)
                        .deleteCookies("JSESSIONID"))
                // 세션 고정 공격 방어(로그인 시 세션 id 교체)는 기본값이라 명시하지 않는다.
                // CSRF 도 기본 활성 — 여기서 끄지 말 것.
                .headers(headers -> headers
                        .frameOptions(frame -> frame.deny()));
        return http.build();
    }
}
