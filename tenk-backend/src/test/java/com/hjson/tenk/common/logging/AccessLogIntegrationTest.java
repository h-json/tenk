package com.hjson.tenk.common.logging;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.hjson.tenk.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
// ⚠️ Spring Boot 4 에서 패키지가 이동했다 (구 org.springframework.boot.test.autoconfigure.web.servlet 아님).
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * 이용자 접속기록({@link AccessLogFilter}) 회귀 가드.
 *
 * <p>지키는 것이 둘이다:
 * <ul>
 *   <li><b>인증 실패(401)가 기록되는가</b> — 필터가 Spring Security 보다 <b>앞</b>에 있어야만
 *       남는다. {@code @Component} 로 잘못 등록하면 Security 가 체인을 끊어 <b>한 줄도 안 남는데</b>,
 *       정작 조사하고 싶은 요청이 그것이다. 순서가 깨진 걸 잡아내는 유일한 장치.</li>
 *   <li><b>담지 말아야 할 것이 안 담기는가</b> — 쿼리스트링 · {@code Authorization} 헤더 · 본문.
 *       {@code feedback}·{@code inquiry} 의 컬럼 목록 검사와 같은 결의 가드다.</li>
 * </ul>
 */
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        // prod 와 같게 — 이게 있어야 ForwardedHeaderFilter 가 붙어 getRemoteAddr 이 XFF 첫 값이 된다.
        "server.forward-headers-strategy=framework"
})
class AccessLogIntegrationTest extends IntegrationTestBase {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("인증 실패(401)도 기록된다 — 필터가 Spring Security 보다 앞이어야만 남는다")
    void recordsUnauthenticatedRequests() throws Exception {
        List<String> lines = captureAccessLog(() ->
                mockMvc.perform(get("/api/users/me")));

        assertThat(lines)
                .as("Security 가 체인을 끊어도 바깥의 필터는 실행된다")
                .anyMatch(l -> l.contains("path=/api/users/me") && l.contains("status=401"));
    }

    @Test
    @DisplayName("메서드·경로·상태·소요시간·IP 가 남는다")
    void recordsTheAgreedFields() throws Exception {
        List<String> lines = captureAccessLog(() ->
                mockMvc.perform(get("/api/app/version")
                        .param("platform", "android")
                        .param("currentVersion", "1.2.0")
                        .header("X-Forwarded-For", "203.0.113.9, 10.0.0.1")));

        assertThat(lines).anyMatch(l ->
                l.contains("ip=203.0.113.9")
                        && l.contains("method=GET")
                        && l.contains("path=/api/app/version")
                        && l.contains("status=200")
                        && l.contains("dur="));
    }

    @Test
    @DisplayName("쿼리스트링은 남기지 않는다 — 지금은 무해해도 그 성질은 조용히 바뀐다")
    void doesNotRecordQueryString() throws Exception {
        List<String> lines = captureAccessLog(() ->
                mockMvc.perform(get("/api/app/version")
                        .param("platform", "android")
                        .param("currentVersion", "1.2.0")));

        assertThat(lines).isNotEmpty();
        assertThat(lines)
                .as("경로만 남기고 쿼리는 버린다 (getRequestURI)")
                .noneMatch(l -> l.contains("platform=android") || l.contains("currentVersion"));
    }

    @Test
    @DisplayName("Authorization 헤더와 요청 본문은 남기지 않는다 — 로그가 개인정보 보관소가 되면 안 된다")
    void doesNotRecordCredentialsOrBody() throws Exception {
        List<String> lines = captureAccessLog(() ->
                mockMvc.perform(post("/api/feedback")
                        .header("Authorization", "Bearer super-secret-token")
                        .contentType("application/json")
                        .content("{\"type\":\"ETC\",\"content\":\"비밀 의견 본문\",\"replyEmail\":\"me@example.com\"}")));

        assertThat(lines).isNotEmpty();
        assertThat(lines).noneMatch(l -> l.contains("super-secret-token"));
        assertThat(lines).noneMatch(l -> l.contains("비밀 의견 본문"));
        assertThat(lines).noneMatch(l -> l.contains("me@example.com"));
    }

    private List<String> captureAccessLog(ThrowingRunnable action) throws Exception {
        Logger accessLogger = (Logger) LoggerFactory.getLogger("TENK_ACCESS_LOG");
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        accessLogger.addAppender(appender);
        try {
            action.run();
        } finally {
            accessLogger.detachAppender(appender);
            appender.stop();
        }
        return appender.list.stream().map(ILoggingEvent::getFormattedMessage).toList();
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
