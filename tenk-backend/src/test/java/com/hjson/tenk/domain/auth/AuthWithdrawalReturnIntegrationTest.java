package com.hjson.tenk.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.UserService;
import com.hjson.tenk.security.KakaoTokenVerifier;
import com.hjson.tenk.security.KakaoTokenVerifier.KakaoUser;
import com.hjson.tenk.support.IntegrationTestBase;
import java.time.LocalDate;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 탈퇴 유예 기간 중 돌아온 사용자의 두 갈래(철회 / 재가입) HTTP E2E.
 *
 * <p>돌아온 사람은 <b>기록을 되찾으러 온 사람</b>과 <b>리셋하러 온 사람</b>으로 갈리고, 어느 한쪽을 강요하면
 * 나머지 절반에게는 서비스가 방해가 된다. 그래서 세 계약을 회귀 가드한다.
 * <ul>
 *   <li><b>로그인이 선택 신호를 줘야 한다</b> — U0007 대신 U0002 로 돌아가면 클라이언트가 선택 화면을
 *       못 띄우고 사용자는 유예 기간이 끝날 때까지 아무것도 못 한다.</li>
 *   <li><b>철회는 데이터를 건드리지 않아야 한다</b> — 되살렸는데 챌린지가 비어 있거나 동의·연령 확인이
 *       초기화되면 철회의 의미가 없다.</li>
 *   <li><b>재가입은 유예를 기다리지 않아야 한다</b> — 옛 계정을 즉시 파기해 곧바로 새 계정이 서야 한다.
 *       여기가 깨지면 "탈퇴 후 한 달간 재가입 불가" 라는, 애초에 피하려던 UX 가 된다.</li>
 * </ul>
 *
 * <p>카카오 서버 왕복은 {@link KakaoTokenVerifier} 를 {@link MockitoBean} 으로 끊는다 — 여기서 보려는 건
 * 카카오 검증이 아니라 우리 계정 상태 전이다.
 */
@AutoConfigureMockMvc
class AuthWithdrawalReturnIntegrationTest extends IntegrationTestBase {

    private static final String KAKAO_ID = "kakao-return-1";

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired UserService userService;

    @MockitoBean KakaoTokenVerifier kakaoTokenVerifier;

    @Test
    @DisplayName("탈퇴 계정으로 카카오 로그인하면 철회 가능 신호(U0007)를 준다")
    void loginOnWithdrawnAccountSignalsRestorable() throws Exception {
        seedWithdrawnUser();

        mockMvc.perform(kakaoRequest("/api/auth/kakao/login"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("U0007"));
    }

    @Test
    @DisplayName("철회하면 계정이 되살아나고 기록·동의·연령 확인이 그대로 유지된다")
    void restoreRevivesAccountWithDataIntact() throws Exception {
        Long userId = seedWithdrawnUser();

        mockMvc.perform(kakaoRequest("/api/auth/kakao/restore"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.userId").value(userId))
                // 복구지 신규 가입이 아니다 — true 면 클라가 닉네임 설정 화면을 띄운다
                .andExpect(jsonPath("$.data.isNewUser").value(false))
                // 이미 마친 게이트를 다시 태우지 않는다
                .andExpect(jsonPath("$.data.consentRequired").value(false))
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(false));

        User restored = userRepository.findById(userId).orElseThrow();
        assertThat(restored.isDeleted()).isFalse();
        assertThat(restored.getDeletedDt()).isNull();
        assertThat(restored.getNickname()).isEqualTo("돌아온사람");
        assertThat(challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(restored)).hasSize(1);
    }

    @Test
    @DisplayName("철회 후에는 평소처럼 로그인된다")
    void loginWorksAgainAfterRestore() throws Exception {
        seedWithdrawnUser();
        mockMvc.perform(kakaoRequest("/api/auth/kakao/restore")).andExpect(status().isOk());

        mockMvc.perform(kakaoRequest("/api/auth/kakao/login"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.isNewUser").value(false));
    }

    @Test
    @DisplayName("재가입은 옛 계정을 파기하고 완전히 새 계정을 만든다")
    void rejoinPurgesOldAccountAndStartsFresh() throws Exception {
        Long oldUserId = seedWithdrawnUser();

        mockMvc.perform(kakaoRequest("/api/auth/kakao/rejoin"))
                .andExpect(status().isOk())
                // 새 계정이므로 온보딩을 전부 다시 탄다
                .andExpect(jsonPath("$.data.isNewUser").value(true))
                .andExpect(jsonPath("$.data.consentRequired").value(true))
                .andExpect(jsonPath("$.data.ageVerificationRequired").value(true))
                .andExpect(jsonPath("$.data.userId").value(org.hamcrest.Matchers.not(oldUserId)));

        assertThat(userRepository.findById(oldUserId)).isEmpty();
        User fresh = userRepository
                .findByProviderAndProviderUserId(AuthProvider.KAKAO, KAKAO_ID).orElseThrow();
        assertThat(fresh.isDeleted()).isFalse();
        assertThat(fresh.getNickname()).isEqualTo("카카오닉네임"); // 옛 닉네임이 아니라 카카오 프로필로 새로 만든다
        assertThat(fresh.hasVerifiedAge()).isFalse();
        assertThat(challengeRepository.findByUserAndDeletedFalseOrderByStartDateDesc(fresh)).isEmpty();
    }

    @Test
    @DisplayName("재가입 직후 다시 로그인하면 방금 만든 계정으로 들어간다")
    void loginAfterRejoinUsesTheNewAccount() throws Exception {
        seedWithdrawnUser();
        mockMvc.perform(kakaoRequest("/api/auth/kakao/rejoin")).andExpect(status().isOk());

        // 재가입 경로가 유예 기간을 남겨두면 여기서 다시 U0007 이 나온다 — 그게 바로 막으려던 "재가입 불가" 상태
        mockMvc.perform(kakaoRequest("/api/auth/kakao/login"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.isNewUser").value(false));
    }

    @Test
    @DisplayName("탈퇴하지 않은 계정은 철회할 수 없다")
    void restoreRejectsActiveAccount() throws Exception {
        seedUser();

        mockMvc.perform(kakaoRequest("/api/auth/kakao/restore"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("U0008"));
    }

    @Test
    @DisplayName("이미 파기돼 사라진 계정은 철회 대상이 없다")
    void restoreRejectsPurgedAccount() throws Exception {
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser(KAKAO_ID, "돌아온사람"));

        mockMvc.perform(kakaoRequest("/api/auth/kakao/restore"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("U0001"));
    }

    // --- fixtures ------------------------------------------------------------

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder kakaoRequest(String path) {
        return post(path)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"accessToken\":\"kakao-AT\"}");
    }

    /** 카카오 검증을 통과시키고, 챌린지 1개 + 동의·연령 확인까지 마친 사용자를 만든다. */
    private Long seedUser() {
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser(KAKAO_ID, "카카오닉네임"));
        return tx.execute(status -> {
            User user = User.create(AuthProvider.KAKAO, KAKAO_ID, "돌아온사람");
            user.agreeToRequiredConsents(LocalDateTime.now());
            user.verifyAge(LocalDate.now().minusYears(30));
            userRepository.save(user);
            challengeRepository.save(Challenge.create(
                    user, "철회 테스트", LocalDate.now(), LocalDate.now().plusDays(3), 10_000));
            return user.getId();
        });
    }

    private Long seedWithdrawnUser() {
        Long userId = seedUser();
        tx.executeWithoutResult(status -> userService.withdraw(userId, null, null));
        return userId;
    }
}
