package com.hjson.tenk.common.logging;

import jakarta.servlet.DispatcherType;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

/**
 * {@link AccessLogFilter} 를 <b>서블릿 필터 체인의 정확한 자리</b>에 끼운다.
 *
 * <pre>
 * ForwardedHeaderFilter (HIGHEST_PRECEDENCE)   ← getRemoteAddr() 을 진짜 클라이언트 IP 로 바꿔치기
 *    └─ AccessLogFilter (HIGHEST_PRECEDENCE+10)   ★ 이 자리여야 한다
 *         └─ Spring Security (-100)                ← 401 로 끊어도 위에서 잡힌다
 *              └─ JwtAuthenticationFilter → 컨트롤러
 * </pre>
 *
 * <p>⚠️ <b>{@code @Component} 로 등록하면 안 된다.</b> 그러면 기본 순서가
 * {@code LOWEST_PRECEDENCE} 라 Spring Security <b>뒤</b>로 가는데, 인증 실패는 Security 가
 * 체인을 끊어버리므로 <b>필터가 실행조차 되지 않아 401 이 한 줄도 안 남는다.</b>
 * 정작 조사하고 싶은 요청이 안 남는 셈이라, 순서를 잃으면 기능 자체가 무의미해진다.
 *
 * <p>⚠️ 반대로 {@code ForwardedHeaderFilter} 보다 앞이면 {@code getRemoteAddr()} 이
 * 프록시 IP 를 주므로 <b>모든 접속이 같은 값</b>이 된다 — #28 이 고친 바로 그 증상이다.
 * 그래서 <b>둘 사이</b>라는 것이 중요하고, 두 상수를 임의로 바꾸지 말 것.
 *
 * <p>{@code DispatcherType.REQUEST} 로 한정하는 이유: 에러 페이지 재디스패치({@code ERROR})나
 * 비동기 재진입({@code ASYNC})까지 받으면 <b>한 요청이 두 줄로 기록</b>된다.
 */
@Configuration
public class AccessLogConfig {

    /** ForwardedHeaderFilter(HIGHEST_PRECEDENCE) 뒤, Spring Security(-100) 앞. */
    static final int ORDER = Ordered.HIGHEST_PRECEDENCE + 10;

    @Bean
    public FilterRegistrationBean<AccessLogFilter> accessLogFilterRegistration() {
        FilterRegistrationBean<AccessLogFilter> registration = new FilterRegistrationBean<>(new AccessLogFilter());
        registration.setDispatcherTypes(DispatcherType.REQUEST);
        registration.setOrder(ORDER);
        return registration;
    }
}
