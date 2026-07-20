package com.hjson.tenk.domain.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.devtools.TestSupportService;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 필수 동의(이용약관 + 개인정보 수집·이용) 게이트의 HTTP E2E.
 *
 * <p>{@link UserServiceTest} 가 스탬프 규칙(멱등·부분 동의)을 단위로 덮으므로 여기서는
 * <b>엔드포인트 계약</b>만 본다 — 인증 필터를 지나 컨트롤러까지 도달하는지, 응답
 * {@code consentRequired} 가 DB 상태를 그대로 반영하는지, 커밋 후에도 유지되는지.
 *
 * <p>클라이언트 게이트(LoginScreen / SessionGate)가 이 플래그 하나로 동의 화면 분기를
 * 결정하므로, 플래그가 뒤집히면 신규 가입자가 동의 없이 서비스에 들어가거나 이미 동의한
 * 사용자가 매번 동의 화면에 갇힌다.
 */
@AutoConfigureMockMvc
class UserConsentIntegrationTest extends IntegrationTestBase {

    private static final String KEY = "test-integration-key"; // application-test.yaml 과 일치

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;
    @Autowired TestSupportService testSupportService;

    @Test
    @DisplayName("신규 카카오 유저는 consentRequired=true 로 시작한다")
    void newUserRequiresConsent() throws Exception {
        Long userId = saveKakaoUser("kakao-consent-1");

        mockMvc.perform(get("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.consentRequired").value(true));
    }

    @Test
    @DisplayName("POST /api/users/me/consent 는 두 항목을 스탬프하고 consentRequired 를 내린다")
    void consentEndpointStampsBothAndClearsFlag() throws Exception {
        Long userId = saveKakaoUser("kakao-consent-2");

        mockMvc.perform(post("/api/users/me/consent")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.consentRequired").value(false));

        // 커밋된 상태를 다시 읽어도 유지 — 응답만 false 이고 DB 는 안 박히는 회귀 차단
        User persisted = userRepository.findById(userId).orElseThrow();
        assertThat(persisted.getTermsAgreedDt()).isNotNull();
        assertThat(persisted.getPrivacyAgreedDt()).isNotNull();
        assertThat(persisted.hasAgreedToRequiredConsents()).isTrue();

        mockMvc.perform(get("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(jsonPath("$.data.consentRequired").value(false));
    }

    @Test
    @DisplayName("재호출해도 최초 동의 시각을 덮어쓰지 않는다 (멱등)")
    void consentEndpointIsIdempotent() throws Exception {
        Long userId = saveKakaoUser("kakao-consent-3");
        LocalDateTime earlier = LocalDateTime.now().minusDays(3).withNano(0);
        tx.executeWithoutResult(status -> {
            User user = userRepository.findById(userId).orElseThrow();
            ReflectionTestUtils.setField(user, "termsAgreedDt", earlier);
            ReflectionTestUtils.setField(user, "privacyAgreedDt", earlier);
            userRepository.save(user);
        });

        mockMvc.perform(post("/api/users/me/consent")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.consentRequired").value(false));

        User persisted = userRepository.findById(userId).orElseThrow();
        assertThat(persisted.getTermsAgreedDt()).isEqualTo(earlier);
        assertThat(persisted.getPrivacyAgreedDt()).isEqualTo(earlier);
    }

    @Test
    @DisplayName("인증 없이 동의를 기록할 수 없다 — 동의 게이트는 로그인 뒤 단계")
    void consentEndpointRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/users/me/consent"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("C0003"));
    }

    @Test
    @DisplayName("테스트 로그인 계정은 auto-consent 라 동의 화면을 안 탄다")
    void testAccountIsAutoConsented() throws Exception {
        Long userId = testSupportService.testLogin(KEY, "consent").userId();

        mockMvc.perform(get("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.consentRequired").value(false));
    }

    private Long saveKakaoUser(String providerUserId) {
        return tx.execute(status -> userRepository.save(
                User.create(AuthProvider.KAKAO, providerUserId, providerUserId + "@example.com", "tester"))
                .getId());
    }

    private String bearer(Long userId) {
        return "Bearer " + jwtTokenProvider.issueAccessToken(userId);
    }
}
