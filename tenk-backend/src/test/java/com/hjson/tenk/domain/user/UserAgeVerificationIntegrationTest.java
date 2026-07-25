package com.hjson.tenk.domain.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.devtools.TestSupportService;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 연령 확인 게이트의 HTTP E2E.
 *
 * <p>Google Play 타겟층에 13~15세가 포함되면서 생긴 중립적 연령 심사 경로다. 두 가지가 깨지면
 * 정책 위반으로 직결되므로 여기서 못을 박는다:
 * <ul>
 *   <li>{@code ageVerificationRequired} 플래그 — 클라이언트 게이트(LoginScreen / SessionGate)가
 *       이 값 하나로 연령 화면 분기를 결정한다. 뒤집히면 미확인 사용자가 그냥 들어온다.</li>
 *   <li><b>만 14세 미만의 즉시 파기</b> — 거부만 하고 계정이 남으면 이용 대상이 아닌 미성년자의
 *       카카오 이메일·닉네임이 서버에 그대로 남는다. 파기는 REQUIRES_NEW 로 도는데 호출자가
 *       곧바로 예외를 던져 롤백하므로, 전파 설정이 틀어지면 조용히 되살아난다.</li>
 * </ul>
 */
@AutoConfigureMockMvc
class UserAgeVerificationIntegrationTest extends IntegrationTestBase {

    private static final String KEY = "test-integration-key"; // application-test.yaml 과 일치

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;
    @Autowired TestSupportService testSupportService;

    @Test
    @DisplayName("신규 카카오 유저는 ageVerificationRequired=true 로 시작한다")
    void newUserRequiresAgeVerification() throws Exception {
        Long userId = saveKakaoUser("kakao-age-1");

        mockMvc.perform(get("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(true));
    }

    @Test
    @DisplayName("만 14세 이상 생년월일을 보내면 저장되고 플래그가 내려간다")
    void adultBirthDateIsStoredAndClearsFlag() throws Exception {
        Long userId = saveKakaoUser("kakao-age-2");
        LocalDate birthDate = LocalDate.now().minusYears(20);

        mockMvc.perform(postBirthDate(userId, birthDate))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(false));

        // 응답만 false 이고 DB 엔 안 박히는 회귀 차단
        User persisted = userRepository.findById(userId).orElseThrow();
        assertThat(persisted.getBirthDate()).isEqualTo(birthDate);
        assertThat(persisted.hasVerifiedAge()).isTrue();
    }

    @Test
    @DisplayName("만 14세 생일 당일은 통과한다 (경계)")
    void exactlyFourteenPasses() throws Exception {
        Long userId = saveKakaoUser("kakao-age-3");

        mockMvc.perform(postBirthDate(userId, LocalDate.now().minusYears(14)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(false));
    }

    @Test
    @DisplayName("만 14세 미만은 U0006 으로 거부되고 계정이 즉시 파기된다")
    void underageIsRejectedAndPurged() throws Exception {
        Long userId = saveKakaoUser("kakao-age-4");
        // 생일 하루 전 = 아직 만 13세
        LocalDate birthDate = LocalDate.now().minusYears(14).plusDays(1);

        mockMvc.perform(postBirthDate(userId, birthDate))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("U0006"));

        // 예외로 호출자 트랜잭션이 롤백돼도 파기(REQUIRES_NEW)는 살아남아야 한다
        assertThat(userRepository.findById(userId)).isEmpty();
    }

    @Test
    @DisplayName("미래 날짜 등 말이 안 되는 생년월일은 U0005 로 거부된다")
    void invalidBirthDateIsRejected() throws Exception {
        Long userId = saveKakaoUser("kakao-age-5");

        mockMvc.perform(postBirthDate(userId, LocalDate.now().plusDays(1)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("U0005"));

        assertThat(userRepository.findById(userId)).isPresent(); // 잘못된 입력으로 계정이 날아가면 안 됨
    }

    @Test
    @DisplayName("인증 없이 연령을 기록할 수 없다")
    void birthDateEndpointRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/users/me/birth-date")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"birthDate\":\"2000-01-01\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("C0003"));
    }

    @Test
    @DisplayName("테스트 로그인 계정은 auto-verify 라 연령 화면을 안 탄다")
    void testAccountIsAutoVerified() throws Exception {
        Long userId = testSupportService.testLogin(KEY, "age").userId();

        mockMvc.perform(get("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(false));
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder postBirthDate(
            Long userId, LocalDate birthDate) {
        return post("/api/users/me/birth-date")
                .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"birthDate\":\"" + birthDate + "\"}");
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
