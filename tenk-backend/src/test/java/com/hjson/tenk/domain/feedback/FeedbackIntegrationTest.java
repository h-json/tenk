package com.hjson.tenk.domain.feedback;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
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
 * 의견 보내기의 HTTP E2E.
 *
 * <p>회귀 가드 포인트:
 * <ul>
 *   <li><b>인증은 필요하지만 계정은 저장하지 않는다</b> — 토큰은 스팸 차단용 통과 조건일 뿐이다.
 *       {@code feedback} 에 user 를 가리키는 컬럼이 생기면 익명성이 무너진다.</li>
 *   <li><b>회신 이메일은 선택</b> — 안 적어도 보내진다. 필수가 되면 개인정보를 강제 수집하는 셈이다.</li>
 *   <li>내용·유형이 없으면 400 (500 이 아니라).</li>
 * </ul>
 */
@AutoConfigureMockMvc
class FeedbackIntegrationTest extends IntegrationTestBase {

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;
    @Autowired FeedbackRepository feedbackRepository;
    @Autowired FeedbackService feedbackService;

    @Test
    @DisplayName("의견이 저장된다 — 회신 이메일 없이도 보내진다")
    void submitsWithoutReplyEmail() throws Exception {
        Long userId = saveUser("kakao-fb-1");

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"SUGGESTION","content":"  주간 통계가 있으면 좋겠어요  ",
                                 "appVersion":"1.0.0","platform":"android","osVersion":"Android 14"}"""))
                .andExpect(status().isOk());

        List<Feedback> saved = feedbackRepository.findAll();
        assertThat(saved).hasSize(1);
        assertThat(saved.getFirst().getType()).isEqualTo(FeedbackType.SUGGESTION);
        assertThat(saved.getFirst().getContent()).isEqualTo("주간 통계가 있으면 좋겠어요");
        assertThat(saved.getFirst().getReplyEmail()).isNull();
        assertThat(saved.getFirst().getAppVersion()).isEqualTo("1.0.0");
        assertThat(saved.getFirst().getCreatedDt()).isNotNull();
    }

    @Test
    @DisplayName("회신 이메일을 적으면 함께 저장되지만, 계정과는 연결되지 않는다")
    void storesReplyEmailButNeverTheAccount() throws Exception {
        Long userId = saveUser("kakao-fb-2");

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"PROBLEM","content":"영상이 저장되지 않아요","replyEmail":"me@example.com"}"""))
                .andExpect(status().isOk());

        assertThat(feedbackRepository.findAll().getFirst().getReplyEmail()).isEqualTo("me@example.com");

        // 익명성 가드: 어떤 컬럼도 user 를 가리키지 않아야 한다.
        // handler_note 는 관리자 패널의 처리 메모다 — 운영자가 스스로 쓰는 칸이라 신원이 안 들어가는
        // 게 전제이고, 화면에도 그 취지를 안내한다. 여기에 user 참조 컬럼이 늘면 이 단언이 먼저 깨진다.
        assertThat(columnNamesOfFeedbackTable()).containsExactlyInAnyOrder(
                "feedback_id", "type", "content", "reply_email",
                "app_version", "platform", "os_version", "handler_note", "created_dt");
    }

    @Test
    @DisplayName("인증 없이는 보낼 수 없다 — 토큰이 유일한 스팸 차단 장치다")
    void requiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/feedback")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"익명 스팸\"}"))
                .andExpect(status().isUnauthorized());

        assertThat(feedbackRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("빈 내용·유형 누락·잘못된 이메일은 400 으로 거부한다")
    void invalidRequestsAreRejectedWith400() throws Exception {
        Long userId = saveUser("kakao-fb-3");
        String token = bearer(userId);

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"   \"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"유형이 없어요\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"ETC\",\"content\":\"내용\",\"replyEmail\":\"broken\"}"))
                .andExpect(status().isBadRequest());

        assertThat(feedbackRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("보관 기간이 지나면 회신 이메일만 지워지고 의견 본문은 남는다")
    void expiredReplyEmailsArePurgedButContentSurvives() throws Exception {
        Long userId = saveUser("kakao-fb-4");

        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"ETC","content":"오래된 의견","replyEmail":"old@example.com"}"""))
                .andExpect(status().isOk());

        // @CreatedDate 는 코드로 못 바꾸므로 SQL 로 보관 기간 밖으로 밀어낸다.
        tx.executeWithoutResult(status -> em.createNativeQuery(
                        "update feedback set created_dt = date_sub(now(), interval 400 day)")
                .executeUpdate());

        assertThat(feedbackService.purgeExpiredReplyEmails()).isEqualTo(1);

        Feedback survived = feedbackRepository.findAll().getFirst();
        assertThat(survived.getReplyEmail()).isNull();
        assertThat(survived.getContent()).isEqualTo("오래된 의견");
    }

    private List<String> columnNamesOfFeedbackTable() {
        @SuppressWarnings("unchecked")
        List<String> names = em.createNativeQuery(
                        "select column_name from information_schema.columns"
                                + " where table_schema = database() and table_name = 'feedback'")
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
