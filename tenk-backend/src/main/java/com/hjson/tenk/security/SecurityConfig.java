package com.hjson.tenk.security;

import tools.jackson.databind.ObjectMapper;
import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.common.api.ApiResponse.ApiError;
import com.hjson.tenk.common.exception.ErrorCode;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private static final String[] PERMIT_ALL = {
            "/",
            "/error",
            "/privacy.html",        // 개인정보처리방침 정적 페이지 (Play Console·앱에서 링크)
            "/terms.html",          // 이용약관 정적 페이지 (가입 동의 화면에서 링크)
            "/delete-account.html", // 계정·데이터 삭제 안내 (Play Console '데이터 삭제' URL — 앱 밖에서도 요청 가능해야 함)
            "/api/auth/kakao/login",
            // 탈퇴 유예 기간 중 돌아온 사용자의 두 갈래. 로그인 전 경로라 인증 불가 — 카카오 토큰 재검증으로 본인 확인
            "/api/auth/kakao/restore", // 철회 (기록 유지)
            "/api/auth/kakao/rejoin",  // 재가입 (옛 계정 즉시 파기)
            "/api/auth/refresh",
            "/api/app/version",     // 앱 버전 게이트 — 로그인 전 부팅 시점에 호출되므로 인증 불필요
            // /api/dev/seed 는 인증 유지 (TESTER 권한 검증은 서비스에서)

            "/swagger-ui.html",
            "/swagger-ui/**",
            "/v3/api-docs/**"
    };

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ObjectMapper objectMapper;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                // 클라이언트는 Flutter 네이티브 앱(iOS/Android)만. 브라우저가 호출하지 않으므로 CORS 불필요.
                // Flutter Web 등 브라우저 클라이언트를 도입하면 CorsConfigurationSource 빈으로 명시 설정할 것.
                .cors(cors -> cors.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .formLogin(form -> form.disable())
                .httpBasic(basic -> basic.disable())
                .logout(logout -> logout.disable())
                .authorizeHttpRequests(req -> req
                        .requestMatchers(PERMIT_ALL).permitAll()
                        .anyRequest().authenticated())
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) ->
                                writeError(res, HttpServletResponse.SC_UNAUTHORIZED,
                                        ErrorCode.UNAUTHORIZED.getCode(), ErrorCode.UNAUTHORIZED.getMessage()))
                        .accessDeniedHandler((req, res, ex) ->
                                writeError(res, HttpServletResponse.SC_FORBIDDEN,
                                        ErrorCode.FORBIDDEN.getCode(), ErrorCode.FORBIDDEN.getMessage())));
        return http.build();
    }

    private void writeError(HttpServletResponse response, int status, String code, String message) throws java.io.IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        objectMapper.writeValue(response.getWriter(), ApiResponse.fail(new ApiError(code, message)));
    }
}
