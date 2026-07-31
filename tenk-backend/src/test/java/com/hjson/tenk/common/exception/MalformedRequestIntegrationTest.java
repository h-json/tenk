package com.hjson.tenk.common.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.support.IntegrationTestBase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 잘못된 <b>호출</b>(사용자 입력이 아니라 클라이언트 버그·크롤러)에 대한 상태 코드 계약.
 *
 * <p>왜 지키는가: 이 6종은 전부 {@code GlobalExceptionHandler.handleEtc} 로 떨어져
 * <b>500 + C0001</b> 로 나가고 있었다(2026-07-31 실측). 클라이언트 잘못이 서버 장애와 같은 신호로
 * 찍히면 로그·모니터링에서 진짜 장애를 못 찾고, 앱은 재시도해도 소용없는 요청을 재시도한다.
 *
 * <p>새 엔드포인트를 추가할 때 이 테스트가 깨지면 핸들러가 아니라 <b>그 엔드포인트</b>를 의심할 것.
 */
@AutoConfigureMockMvc
class MalformedRequestIntegrationTest extends IntegrationTestBase {

    @Autowired MockMvc mockMvc;
    @Autowired JwtTokenProvider jwtTokenProvider;
    @Autowired UserRepository userRepository;

    private String token;

    @BeforeEach
    void issueToken() {
        Long userId = tx.execute(status -> userRepository.save(
                User.create(AuthProvider.KAKAO, "kakao-malformed", "tester")).getId());
        token = "Bearer " + jwtTokenProvider.issueAccessToken(userId);
    }

    @Test
    @DisplayName("경로 변수 타입이 안 맞으면 400 (숫자 자리에 문자)")
    void pathVariableTypeMismatchIsBadRequest() throws Exception {
        mockMvc.perform(get("/api/challenges/abc").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("C0002"));
    }

    @Test
    @DisplayName("multipart 의 request part 가 빠지면 400 — 영상만 보낸 요청")
    void missingMultipartPartIsBadRequest() throws Exception {
        mockMvc.perform(multipart("/api/challenges/1/amounts")
                        .file(new MockMultipartFile("video", "v.mp4", "video/mp4", new byte[] {1}))
                        .header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("C0002"));
    }

    @Test
    @DisplayName("쿼리 파라미터 타입이 안 맞으면 400 (boolean 자리에 아무 문자열)")
    void queryParameterTypeMismatchIsBadRequest() throws Exception {
        mockMvc.perform(get("/api/challenges").param("activeOnly", "maybe")
                        .header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("C0002"));
    }

    @Test
    @DisplayName("없는 경로는 404 — 정적 파일 오타·favicon 요청이 500 으로 찍히지 않게")
    void unknownPathIsNotFound() throws Exception {
        mockMvc.perform(get("/api/nope").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("C0005"));
    }

    @Test
    @DisplayName("지원하지 않는 메서드는 405")
    void unsupportedMethodIsMethodNotAllowed() throws Exception {
        mockMvc.perform(delete("/api/feedback").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.error.code").value("C0006"));
    }

    @Test
    @DisplayName("Content-Type 이 안 맞으면 415")
    void unsupportedContentTypeIsUnsupportedMediaType() throws Exception {
        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("hello"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.error.code").value("C0007"));
    }

    @Test
    @DisplayName("깨진 JSON body 는 계속 400 — 먼저 막아둔 갈래가 그대로인지 확인")
    void brokenJsonBodyStaysBadRequest() throws Exception {
        mockMvc.perform(post("/api/feedback")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{broken"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("C0002"));
    }
}
