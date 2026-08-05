package com.hjson.tenk.domain.inquiry;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.WithdrawnUserPurgeService;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.support.IntegrationTestBase;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 문의하기의 HTTP E2E.
 *
 * <p>회귀 가드 포인트 — <b>전부 '의견 보내기와 반대'인 지점들이다</b>:
 * <ul>
 *   <li><b>계정과 연결해 저장한다</b>({@code user_id}). 이게 없으면 열람·삭제 요구를 처리할 수 없다.</li>
 *   <li><b>회신 이메일이 필수</b> — 없으면 400. 답변할 수 없는 문의는 받지 않는다.</li>
 *   <li><b>계정 파기 시 함께 지워진다</b> — 개인정보이므로 익명 테이블처럼 살아남으면 안 된다.</li>
 *   <li><b>보관은 회원 탈퇴 시까지</b> — 답변을 마쳐도 사라지지 않고 리마인드에서만 빠진다.</li>
 * </ul>
 *
 * <p>알림({@code AdminNotifier})은 test 프로파일에서 {@code enabled=false} 라 실제 발송이 없다.
 */
@AutoConfigureMockMvc
class InquiryIntegrationTest extends IntegrationTestBase {

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;
    @Autowired InquiryRepository inquiryRepository;
    @Autowired InquiryService inquiryService;
    @Autowired WithdrawnUserPurgeService purgeService;

    @Test
    @DisplayName("문의가 계정과 함께 저장된다 — 익명이 아니라는 게 이 창구의 핵심이다")
    void storesInquiryWithTheAccount() throws Exception {
        Long userId = saveUser("kakao-iq-1");

        mockMvc.perform(post("/api/inquiry")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"PRIVACY","content":"  제 기록을 지워주세요  ",
                                 "replyEmail":"me@example.com"}"""))
                .andExpect(status().isOk());

        List<Inquiry> saved = inquiryRepository.findAll();
        assertThat(saved).hasSize(1);
        assertThat(saved.getFirst().getType()).isEqualTo(InquiryType.PRIVACY);
        assertThat(saved.getFirst().getContent()).isEqualTo("제 기록을 지워주세요");
        assertThat(saved.getFirst().getReplyEmail()).isEqualTo("me@example.com");
        assertThat(saved.getFirst().getStatus()).isEqualTo(InquiryStatus.PENDING);
        assertThat(saved.getFirst().getUser().getId()).isEqualTo(userId);

        // 의견 테이블의 익명성 가드와 정반대의 가드 — user_id 가 빠지면 이 창구는 성립하지 않는다.
        assertThat(columnNamesOfInquiryTable()).contains("user_id");
    }

    @Test
    @DisplayName("회신 이메일이 없으면 400 — 답변할 수 없는 문의는 받지 않는다 (의견과 갈리는 지점)")
    void rejectsMissingReplyEmail() throws Exception {
        String token = bearer(saveUser("kakao-iq-2"));

        mockMvc.perform(post("/api/inquiry")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"답변 주세요\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/inquiry")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"답변 주세요\",\"replyEmail\":\"broken\"}"))
                .andExpect(status().isBadRequest());

        assertThat(inquiryRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("인증 없이는 보낼 수 없다")
    void requiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/inquiry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"내용\",\"replyEmail\":\"me@example.com\"}"))
                .andExpect(status().isUnauthorized());

        assertThat(inquiryRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("계정이 파기되면 문의도 함께 지워진다 — 익명 테이블과 정반대다")
    void purgedWithTheAccount() throws Exception {
        Long userId = saveUser("kakao-iq-3");
        submit(userId, "ETC", "지워질 문의");

        assertThat(inquiryRepository.findAll()).hasSize(1);

        purgeService.purge(userId);

        assertThat(inquiryRepository.findAll()).isEmpty();
        assertThat(userRepository.findById(userId)).isEmpty();
    }

    @Test
    @DisplayName("미처리가 있으면 건수를 알리고, 없으면 아무것도 보내지 않는다")
    void remindsOnlyWhenSomethingIsPending() throws Exception {
        assertThat(inquiryService.remindPendingInquiries()).isZero();

        Long userId = saveUser("kakao-iq-4");
        submit(userId, "PRIVACY", "열람 요청");
        submit(userId, "ACCOUNT", "로그인이 안 돼요");

        assertThat(inquiryService.remindPendingInquiries()).isEqualTo(2);
    }

    @Test
    @DisplayName("처리 완료 표시는 리마인드만 멈추고 문의는 계정과 함께 남는다")
    void handledInquiriesSurviveButStopReminding() throws Exception {
        Long userId = saveUser("kakao-iq-5");
        submit(userId, "ETC", "답변을 마친 오래된 문의");
        submit(userId, "ETC", "아직 답변 안 한 문의");

        Long handledId = inquiryRepository.findAll().getFirst().getId();
        // 처리 표시는 운영에서도 SQL 로 한다 (관리자 UI 없음). 한참 전에 답변한 것으로 밀어낸다.
        tx.executeWithoutResult(status -> em.createNativeQuery(
                        "update inquiry set status='DONE',"
                                + " handled_dt = date_sub(now(), interval 400 day)"
                                + " where inquiry_id = :id")
                .setParameter("id", handledId)
                .executeUpdate());

        // 보관 기간은 "회원 탈퇴 시까지" 라 오래됐다고 사라지지 않는다.
        assertThat(inquiryRepository.findAll()).hasSize(2);
        // 리마인드 대상에서는 빠진다.
        assertThat(inquiryService.remindPendingInquiries()).isEqualTo(1);
    }

    private void submit(Long userId, String type, String content) throws Exception {
        mockMvc.perform(post("/api/inquiry")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"%s","content":"%s","replyEmail":"me@example.com"}"""
                                .formatted(type, content)))
                .andExpect(status().isOk());
    }

    private List<String> columnNamesOfInquiryTable() {
        @SuppressWarnings("unchecked")
        List<String> names = em.createNativeQuery(
                        "select column_name from information_schema.columns"
                                + " where table_schema = database() and table_name = 'inquiry'")
                .getResultList();
        return names;
    }

    private Long saveUser(String providerUserId) {
        return tx.execute(status -> userRepository.save(
                User.create(AuthProvider.KAKAO, providerUserId, "tester")).getId());
    }

    private String bearer(Long userId) {
        return "Bearer " + jwtTokenProvider.issueAccessToken(userId);
    }
}
