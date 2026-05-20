package com.hjson.tenk.security;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.common.config.AuthProperties;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserController;
import com.hjson.tenk.domain.user.UserService;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Swagger 인증 시나리오 1·2·3 자동화.
 *
 * <p>{@link JwtAuthenticationFilter} 와 {@link SecurityConfig} 의 조합이 보호된 엔드포인트
 * ({@code GET /api/users/me}) 에 대해 아래를 보장하는지 검증한다.
 * <ul>
 *   <li>Authorization 헤더가 없으면 401 + {@code C0003 UNAUTHORIZED}
 *       — {@link SecurityConfig} 의 {@code AuthenticationEntryPoint} 가 응답.</li>
 *   <li>Bearer 토큰이 만료됐으면 401 + {@code AU0002 AUTH_TOKEN_EXPIRED}
 *       — {@link JwtAuthenticationFilter} 가 응답 (Entry point 까지 안 감).</li>
 *   <li>Bearer 토큰이 서명·포맷 깨졌으면 401 + {@code AU0001 AUTH_TOKEN_INVALID}.</li>
 *   <li>정상 토큰이면 컨트롤러가 호출돼 200.</li>
 * </ul>
 *
 * <p>{@link com.hjson.tenk.support.IntegrationTestBase} 의 풀 스프링 부트 부팅을 거치지
 * 않으므로 DB 없이 가볍게 돈다. 그래서 {@link UserService} / {@link RefreshTokenRepository} 등
 * 컨트롤러 협력자는 {@link MockitoBean} 으로 끊는다.
 */
@WebMvcTest(UserController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtTokenProvider.class})
@EnableConfigurationProperties(AuthProperties.class)
@TestPropertySource(properties = {
        // 통합 테스트와 동일한 dummy 키 (32바이트 이상 HS256 base64)
        "tenk.auth.jwt.secret=dGVuay10ZXN0LWp3dC1zZWNyZXQta2V5LWZvci1pbnRlZ3JhdGlvbi10ZXN0LTEy",
        "tenk.auth.jwt.access-token-ttl=PT1H",
        "tenk.auth.jwt.refresh-token-ttl=P14D",
        "tenk.auth.jwt.issuer=tenk",
        "tenk.auth.kakao.app-id=1"
})
class JwtAuthenticationFilterWebMvcTest {

    private static final String SECRET_BASE64 =
            "dGVuay10ZXN0LWp3dC1zZWNyZXQta2V5LWZvci1pbnRlZ3JhdGlvbi10ZXN0LTEy";

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @MockitoBean UserService userService;

    @Test
    @DisplayName("Authorization 헤더 없으면 401 + C0003 (AuthenticationEntryPoint 응답)")
    void missingHeaderReturns401() throws Exception {
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("C0003"));
    }

    @Test
    @DisplayName("정상 AT 면 컨트롤러 호출까지 도달해 200")
    void validTokenReachesController() throws Exception {
        Long userId = 42L;
        User stub = User.create(AuthProvider.KAKAO, "k-42", "u42@example.com", "tester");
        ReflectionTestUtils.setField(stub, "id", userId);
        given(userService.getActiveUser(eq(userId))).willReturn(stub);

        String at = jwtTokenProvider.issueAccessToken(userId);

        mockMvc.perform(get("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + at))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.userId").value(userId));
    }

    @Test
    @DisplayName("만료 AT 는 401 + AU0002 (JwtAuthenticationFilter 가 직접 응답)")
    void expiredTokenReturns401WithAU0002() throws Exception {
        String expired = buildAccessTokenWithExpiry(123L, Instant.now().minusSeconds(60));

        mockMvc.perform(get("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("AU0002"));
    }

    @Test
    @DisplayName("서명·포맷이 깨진 토큰은 401 + AU0001")
    void malformedTokenReturns401WithAU0001() throws Exception {
        mockMvc.perform(get("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-real-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("AU0001"));
    }

    /**
     * {@link JwtTokenProvider#issueAccessToken} 은 TTL 기반이라 "이미 만료된" 토큰을 못 만든다.
     * 같은 secret 키로 직접 빌더를 돌려 expiration 만 과거로 박는다.
     */
    private static String buildAccessTokenWithExpiry(Long userId, Instant expiry) {
        SecretKey key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(SECRET_BASE64));
        return Jwts.builder()
                .issuer("tenk")
                .subject(String.valueOf(userId))
                .issuedAt(Date.from(expiry.minusSeconds(60)))
                .expiration(Date.from(expiry))
                .signWith(key)
                .compact();
    }
}
