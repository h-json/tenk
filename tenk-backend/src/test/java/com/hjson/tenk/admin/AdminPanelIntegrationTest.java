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

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.hjson.tenk.domain.inquiry.Inquiry;
import com.hjson.tenk.domain.inquiry.InquiryRepository;
import com.hjson.tenk.domain.inquiry.InquiryStatus;
import com.hjson.tenk.domain.inquiry.InquiryType;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.UserRole;
import com.hjson.tenk.support.IntegrationTestBase;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.slf4j.LoggerFactory;
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

    /**
     * <b>로컬·운영과 일부러 다른 전용 ID 다 — 실계정 ID 로 "통일" 하지 말 것</b> (2026-08-07 확인).
     *
     * <p>통합 테스트는 로컬 {@code tenk} 스키마를 그대로 쓰는데, {@link AdminAccountInitializer} 는
     * 부팅할 때마다 <b>설정된 이메일의 행을 찾아 비밀번호 해시를 yaml 값으로 맞춘다</b>. 그래서 ID 를
     * 실계정과 같게 두면 {@code ./gradlew test} 한 번에 <b>로컬 패널 비밀번호가
     * {@code test-admin-pw} 로 덮여</b> 백엔드를 재시작할 때까지 평소 비밀번호로 못 들어간다.
     *
     * <p>대가로 로컬 DB 에 이 계정 행이 하나 남는다(이니셜라이저는 이메일이 다른 행을 지우지 않는다).
     * <b>안 쓰는 행이 남는 쪽이 실계정 비밀번호가 흔들리는 것보다 낫다</b>는 판단이고, 근본 해법은
     * 테스트 전용 스키마 분리다({@code tenk_test}) — 지금은 하지 않기로 했다.
     */
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
    @DisplayName("로그인 성공이 접속기록에 남고 마지막 로그인 시각이 갱신된다")
    void recordsLoginInAuditTrail() throws Exception {
        List<String> lines = captureAuditLog(() ->
                mockMvc.perform(formLogin("/admin/login").user(ADMIN).password("test-admin-pw")));

        assertThat(lines).anyMatch(l -> l.contains("action=LOGIN_SUCCESS") && l.contains("actor=" + ADMIN));
        assertThat(adminUserRepository.findByEmail(ADMIN).orElseThrow().getLastLoginDt()).isNotNull();
    }

    @Test
    @DisplayName("로그인 실패도 남는다 — 대입 공격의 유일한 탐지 수단이다")
    void recordsFailedLoginAttempts() throws Exception {
        List<String> lines = captureAuditLog(() ->
                mockMvc.perform(formLogin("/admin/login").user(ADMIN).password("wrong")));

        assertThat(lines).anyMatch(l -> l.contains("action=LOGIN_FAILURE"));
        assertThat(lines)
                .as("입력된 비밀번호가 로그에 남으면 그 자체가 자격증명 유출이다")
                .noneMatch(l -> l.contains("wrong"));
    }

    @Test
    @DisplayName("개인정보를 여는 화면은 열람만 해도 기록된다 — 유출은 변경이 아니라 열람에서 난다")
    void recordsReadsOfPersonalData() throws Exception {
        Long inquiryId = saveInquiry();

        List<String> lines = captureAuditLog(() -> {
            mockMvc.perform(get("/admin/inquiries/{id}", inquiryId).with(adminUser()));
            mockMvc.perform(get("/admin/users").param("keyword", "문의자").with(adminUser()));
        });

        assertThat(lines).anyMatch(l -> l.contains("action=INQUIRY_VIEW"));
        assertThat(lines).anyMatch(l -> l.contains("action=USER_LIST_VIEW"));
        assertThat(lines)
                .as("검색어(닉네임)는 그 자체가 개인정보라 기록하지 않는다")
                .noneMatch(l -> l.contains("문의자"));
    }

    @Test
    @DisplayName("접속기록에 접속지 IP 가 들어간다 — 고시가 요구하는 항목이다")
    void recordsClientIp() throws Exception {
        List<String> lines = captureAuditLog(() ->
                mockMvc.perform(get("/admin/feedbacks")
                        .header("X-Forwarded-For", "203.0.113.9, 10.0.0.1")
                        .with(adminUser())));

        assertThat(lines)
                .as("Traefik 뒤라 X-Forwarded-For 의 첫 값이 실제 클라이언트다")
                .anyMatch(l -> l.contains("ip=203.0.113.9"));
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
    @DisplayName("문의 상세의 답장 초안에 원문이 인용된다 — 알림이 본문을 싣지 않는 대가다")
    void buildsReplyDraftWithQuotedOriginal() throws Exception {
        Long inquiryId = saveInquiry();

        String html = mockMvc.perform(get("/admin/inquiries/{id}", inquiryId).with(adminUser()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        assertThat(html)
                .as("mailto: 는 OS 로 넘어가며 잘린다 — 한글 본문은 인코딩되면 길이가 9배다")
                .contains("mail.google.com")
                .contains("view=cm");
        assertThat(html)
                .as("원문 인용이 빠지면 답장 스레드에 무엇에 대한 답인지가 남지 않는다")
                .contains("&gt; 기록이 안 돼요");
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

    /**
     * 실행 구간 동안 {@code TENK_ADMIN_AUDIT} 로거에 찍힌 줄을 모아 준다.
     *
     * <p>파일을 읽지 않고 <b>인메모리 appender 를 잠깐 붙였다 뗀다</b> — 파일 경로·롤링 설정은
     * 테스트의 관심사가 아니고(그건 logback-spring.xml 소관), 여기서 지키려는 건 <b>"무엇이 기록되고
     * 무엇이 기록되지 않는가"</b>다. 특히 비밀번호·검색어가 새지 않는지가 핵심이라 내용 단언이 중요하다.
     */
    private List<String> captureAuditLog(ThrowingRunnable action) throws Exception {
        Logger auditLogger = (Logger) LoggerFactory.getLogger("TENK_ADMIN_AUDIT");
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        auditLogger.addAppender(appender);
        try {
            action.run();
        } finally {
            auditLogger.detachAppender(appender);
            appender.stop();
        }
        return appender.list.stream().map(ILoggingEvent::getFormattedMessage).toList();
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }

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
