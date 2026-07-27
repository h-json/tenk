package com.hjson.tenk.domain.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
 * 탈퇴 사유 수집의 HTTP E2E.
 *
 * <p>이 기능의 설계는 "사유는 남기되 <b>누가 남겼는지는 남기지 않는다</b>" 한 줄에 걸려 있다.
 * 그래서 다음 셋을 회귀 가드한다.
 * <ul>
 *   <li><b>사유는 선택</b> — body 없이 호출해도 탈퇴가 되어야 한다. 필수가 되는 순간 탈퇴가
 *       가입보다 어려워진다.</li>
 *   <li><b>계정과 연결되지 않는다</b> — {@code withdrawal_feedback} 에 user 를 가리키는 컬럼이
 *       생기면 익명정보가 아니게 되어 개인정보처리방침 수집표·보관 기간 문제가 되살아난다.</li>
 *   <li><b>계정 파기 후에도 남는다</b> — 통계로 쓰려고 모으는 값이라 계정과 함께 사라지면 의미가 없다.</li>
 * </ul>
 */
@AutoConfigureMockMvc
class WithdrawalFeedbackIntegrationTest extends IntegrationTestBase {

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;
    @Autowired WithdrawalFeedbackRepository feedbackRepository;
    @Autowired WithdrawnUserPurgeService purgeService;

    @Test
    @DisplayName("사유 없이 탈퇴해도 정상 처리되고 아무것도 기록되지 않는다")
    void withdrawWithoutReasonRecordsNothing() throws Exception {
        Long userId = saveUser("kakao-feedback-1");

        mockMvc.perform(delete("/api/users/me").header(HttpHeaders.AUTHORIZATION, bearer(userId)))
                .andExpect(status().isOk());

        assertThat(userRepository.findById(userId).orElseThrow().isDeleted()).isTrue();
        assertThat(feedbackRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("사유와 자유 서술이 기록되지만 계정과는 연결되지 않는다")
    void withdrawWithReasonRecordsAnonymously() throws Exception {
        Long userId = saveUser("kakao-feedback-2");

        mockMvc.perform(delete("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"ETC\",\"detail\":\"  쓰다 보니 손이 안 가요  \"}"))
                .andExpect(status().isOk());

        List<WithdrawalFeedback> saved = feedbackRepository.findAll();
        assertThat(saved).hasSize(1);
        assertThat(saved.getFirst().getReason()).isEqualTo(WithdrawalReason.ETC);
        assertThat(saved.getFirst().getDetail()).isEqualTo("쓰다 보니 손이 안 가요");
        assertThat(saved.getFirst().getCreatedDt()).isNotNull();

        // 익명성 가드: 어떤 컬럼도 user 를 가리키지 않아야 한다
        assertThat(columnNamesOfFeedbackTable())
                .containsExactlyInAnyOrder("withdrawal_feedback_id", "reason_code", "detail", "created_dt");
    }

    @Test
    @DisplayName("알 수 없는 사유 코드는 400 으로 거부한다")
    void unknownReasonCodeIsRejected() throws Exception {
        Long userId = saveUser("kakao-feedback-3");

        mockMvc.perform(delete("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"WHATEVER\"}"))
                .andExpect(status().isBadRequest());

        assertThat(userRepository.findById(userId).orElseThrow().isDeleted()).isFalse();
    }

    @Test
    @DisplayName("계정이 파기돼도 사유는 남는다 — 통계로 쓰려고 모으는 값이다")
    void feedbackSurvivesAccountPurge() throws Exception {
        Long userId = saveUser("kakao-feedback-4");

        mockMvc.perform(delete("/api/users/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"GOAL_MISMATCH\"}"))
                .andExpect(status().isOk());

        purgeService.purge(userId);

        assertThat(userRepository.findById(userId)).isEmpty();
        assertThat(feedbackRepository.findAll()).hasSize(1);
    }

    private List<String> columnNamesOfFeedbackTable() {
        @SuppressWarnings("unchecked")
        List<String> names = em.createNativeQuery(
                        "select column_name from information_schema.columns"
                                + " where table_schema = database() and table_name = 'withdrawal_feedback'")
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
