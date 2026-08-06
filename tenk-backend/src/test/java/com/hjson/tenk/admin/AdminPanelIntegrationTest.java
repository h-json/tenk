package com.hjson.tenk.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestBuilders.formLogin;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.authenticated;
import static org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.unauthenticated;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.domain.inquiry.Inquiry;
import com.hjson.tenk.domain.inquiry.InquiryRepository;
import com.hjson.tenk.domain.inquiry.InquiryStatus;
import com.hjson.tenk.domain.inquiry.InquiryType;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.UserRole;
import com.hjson.tenk.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 관리자 패널의 HTTP E2E.
 *
 * <p><b>이 테스트의 제일 중요한 가드는 마지막 두 건 — "앱 인증이 안 바뀌었다"</b>이다. 패널을 위해
 * 세션·폼 로그인·CSRF 를 켰는데, 그게 전역으로 새면 Flutter 앱의 인증 계약이 통째로 바뀐다
 * (401 JSON envelope 대신 로그인 화면으로 리다이렉트되고, POST 는 CSRF 토큰을 요구하게 된다).
 * 두 체인이 정말로 갈라져 있는지는 <b>단위 테스트로는 확인할 수 없다</b>.
 *
 * <p>패널은 기본 꺼짐이라 여기서만 {@code tenk.admin.enabled=true} 로 켠다.
 */
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "tenk.admin.enabled=true",
        "tenk.admin.account.email=admin@test",
        "tenk.admin.account.password=test-admin-pw",
        "tenk.admin.base-url=https://example.test"
})
class AdminPanelIntegrationTest extends IntegrationTestBase {

    private static final String ADMIN = "admin@test";

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired InquiryRepository inquiryRepository;
    @Autowired AdminUserRepository adminUserRepository;

    // ── 인증 ────────────────────────────────────────────────────

    @Test
    @DisplayName("부팅 시 yaml 계정이 만들어지고 비밀번호는 해시로만 저장된다")
    void bootstrapsAdminAccountWithHashedPassword() {
        AdminUser admin = adminUserRepository.findByEmail(ADMIN).orElseThrow();

        assertThat(admin.getPasswordHash())
                .as("평문이 그대로 저장되면 안 된다")
                .isNotEqualTo("test-admin-pw")
                .startsWith("$2");
    }

    @Test
    @DisplayName("미인증으로 패널에 들어가면 로그인 화면으로 보낸다")
    void redirectsAnonymousToLogin() throws Exception {
        mockMvc.perform(get("/admin"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/admin/login"));
    }

    @Test
    @DisplayName("올바른 자격증명이면 로그인되고, 틀리면 인증되지 않는다")
    void authenticatesOnlyWithCorrectCredentials() throws Exception {
        mockMvc.perform(formLogin("/admin/login").user(ADMIN).password("test-admin-pw"))
                .andExpect(authenticated());

        mockMvc.perform(formLogin("/admin/login").user(ADMIN).password("wrong"))
                .andExpect(unauthenticated());
    }

    @Test
    @DisplayName("이용자 계정으로는 패널에 로그인할 수 없다 — admin_user 만 본다")
    void appUserCannotLogIntoPanel() throws Exception {
        saveUser("kakao-admin-1", "앱유저");

        mockMvc.perform(formLogin("/admin/login").user("앱유저").password("anything"))
                .andExpect(unauthenticated());
    }

    @Test
    @DisplayName("CSRF 토큰이 없는 POST 는 거부된다")
    void rejectsPostWithoutCsrf() throws Exception {
        Long inquiryId = saveInquiry();

        mockMvc.perform(post("/admin/inquiries/{id}/handle", inquiryId).with(user(ADMIN).authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                AdminUserDetailsService.ROLE_ADMIN))))
                .andExpect(status().isForbidden());

        assertThat(inquiryRepository.findById(inquiryId).orElseThrow().getStatus())
                .isEqualTo(InquiryStatus.PENDING);
    }

    // ── 기능 ────────────────────────────────────────────────────

    @Test
    @DisplayName("문의를 처리 완료로 표시하면 리마인드에서 빠지고 메모가 남는다")
    void handlesInquiry() throws Exception {
        Long inquiryId = saveInquiry();

        mockMvc.perform(post("/admin/inquiries/{id}/handle", inquiryId)
                        .param("note", "  메일로 답변함  ")
                        .with(adminUser()).with(csrf()))
                .andExpect(status().is3xxRedirection());

        Inquiry handled = inquiryRepository.findById(inquiryId).orElseThrow();
        assertThat(handled.getStatus()).isEqualTo(InquiryStatus.DONE);
        assertThat(handled.getHandledDt()).isNotNull();
        assertThat(handled.getHandlerNote()).isEqualTo("메일로 답변함");
    }

    @Test
    @DisplayName("처리 표시를 되돌리면 다시 미처리가 되고 메모는 남는다")
    void reopensInquiry() throws Exception {
        Long inquiryId = saveInquiry();
        mockMvc.perform(post("/admin/inquiries/{id}/handle", inquiryId)
                .param("note", "답변함").with(adminUser()).with(csrf()));

        mockMvc.perform(post("/admin/inquiries/{id}/reopen", inquiryId)
                        .with(adminUser()).with(csrf()))
                .andExpect(status().is3xxRedirection());

        Inquiry reopened = inquiryRepository.findById(inquiryId).orElseThrow();
        assertThat(reopened.getStatus()).isEqualTo(InquiryStatus.PENDING);
        assertThat(reopened.getHandledDt()).isNull();
        assertThat(reopened.getHandlerNote())
                .as("되돌려도 무엇을 했었는지는 남아야 한다")
                .isEqualTo("답변함");
    }

    @Test
    @DisplayName("TESTER 승격이 패널에서 된다 — 예전의 UPDATE user SET role 을 대체한다")
    void promotesUserToTester() throws Exception {
        Long userId = saveUser("kakao-admin-2", "승격대상");

        mockMvc.perform(post("/admin/users/{id}/role", userId)
                        .param("role", "TESTER").with(adminUser()).with(csrf()))
                .andExpect(status().is3xxRedirection());

        assertThat(userRepository.findById(userId).orElseThrow().getRole())
                .isEqualTo(UserRole.TESTER);
    }

    @Test
    @DisplayName("패널에서 ADMIN 으로는 올릴 수 없다 — 권한 상승 경로를 만들지 않는다")
    void refusesToGrantAdminRole() throws Exception {
        Long userId = saveUser("kakao-admin-3", "승격금지");

        mockMvc.perform(post("/admin/users/{id}/role", userId)
                .param("role", "ADMIN").with(adminUser()).with(csrf()));

        assertThat(userRepository.findById(userId).orElseThrow().getRole())
                .isEqualTo(UserRole.USER);
    }

    // ── 앱 인증 무회귀 (이 파일의 핵심) ──────────────────────────

    @Test
    @DisplayName("앱 API 는 여전히 401 JSON 을 준다 — 로그인 화면으로 리다이렉트되면 안 된다")
    void appApiStillAnswersWithJsonUnauthorized() throws Exception {
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("C0003"));
    }

    @Test
    @DisplayName("앱 API 의 POST 는 CSRF 토큰 없이도 통과한다 — 앱 체인은 CSRF 를 쓰지 않는다")
    void appApiDoesNotRequireCsrf() throws Exception {
        // 인증 실패(401)로 끊기는 게 정상이다. CSRF 가 전역으로 켜졌다면 그 앞에서 403 이 난다.
        mockMvc.perform(post("/api/auth/logout"))
                .andExpect(status().isUnauthorized());
    }

    // ── 헬퍼 ────────────────────────────────────────────────────

    private static org.springframework.test.web.servlet.request.RequestPostProcessor adminUser() {
        return user(ADMIN).authorities(
                new org.springframework.security.core.authority.SimpleGrantedAuthority(
                        AdminUserDetailsService.ROLE_ADMIN));
    }

    private Long saveUser(String providerUserId, String nickname) {
        return tx.execute(status ->
                userRepository.save(User.create(AuthProvider.KAKAO, providerUserId, nickname)).getId());
    }

    private Long saveInquiry() {
        Long userId = saveUser("kakao-admin-inq", "문의자");
        return tx.execute(status -> {
            User user = userRepository.findById(userId).orElseThrow();
            return inquiryRepository.save(
                    Inquiry.of(user, InquiryType.SERVICE, "기록이 안 돼요", "me@example.com")).getId();
        });
    }
}
