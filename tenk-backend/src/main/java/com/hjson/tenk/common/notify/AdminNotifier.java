package com.hjson.tenk.common.notify;

import com.hjson.tenk.common.config.NotifyProperties;
import java.time.Duration;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 개발자에게 가는 알림 발송기. 문의·의견이 도착했을 때, 그리고 미처리 문의가 남아 있을 때 호출된다.
 *
 * <p><b>규칙 1 — best-effort.</b> 발송이 실패해도 <b>저장은 성공해야 한다</b>. 그래서 모든 예외를
 * 여기서 삼키고 로그만 남긴다. 알림이 안 가는 것보다 사용자의 문의가 유실되는 게 훨씬 나쁘다.
 *
 * <p><b>규칙 2 — 비동기.</b> SMTP·텔레그램은 외부 호출이라 수 초가 걸릴 수 있는데, 그 시간이 사용자
 * 응답에 붙으면 안 된다. {@code @Async} 라 호출자는 곧바로 반환된다 —
 * <b>같은 빈 안에서 부르면 프록시를 안 타 동기 실행되니</b> 반드시 다른 빈에서 주입받아 호출할 것.
 *
 * <p><b>규칙 3 — 설정이 없으면 조용히 넘어간다.</b> local/test 프로파일에는 자격증명이 없고
 * {@code enabled=false} 라 아무것도 보내지 않는다. 알림 미설정이 부팅·테스트를 깨뜨리면 안 된다.
 */
@Slf4j
@Component
public class AdminNotifier {

    private static final String TELEGRAM_API = "https://api.telegram.org/bot%s/sendMessage";

    /** 외부 서비스가 느릴 때 스레드를 오래 잡지 않도록 짧게 끊는다. 알림은 늦느니 포기하는 편이 낫다. */
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(5);

    private final NotifyProperties properties;
    /** JavaMailSender 는 {@code spring.mail.host} 가 있을 때만 자동 구성된다 — 없을 수 있다. */
    private final ObjectProvider<JavaMailSender> mailSender;
    private final RestClient restClient;

    public AdminNotifier(NotifyProperties properties, ObjectProvider<JavaMailSender> mailSender) {
        this.properties = properties;
        this.mailSender = mailSender;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(CONNECT_TIMEOUT);
        factory.setReadTimeout(READ_TIMEOUT);
        this.restClient = RestClient.builder().requestFactory(factory).build();
    }

    /**
     * 두 갈래로 알린다. 한쪽이 실패해도 다른 쪽은 시도한다.
     *
     * @param subject 메일 제목. 텔레그램에서는 본문 첫 줄로 붙는다.
     * @param body    본문
     */
    @Async
    public void notifyAdmin(String subject, String body) {
        sendMail(subject, body);
        sendTelegram(subject, body);
    }

    private void sendMail(String subject, String body) {
        NotifyProperties.Mail config = properties.mail();
        if (!config.isUsable()) {
            return;
        }
        JavaMailSender sender = mailSender.getIfAvailable();
        if (sender == null) {
            log.warn("[AdminNotifier] mail enabled but JavaMailSender is absent (spring.mail.host 미설정)");
            return;
        }
        String from = resolveFrom(config, sender);
        if (from == null) {
            log.warn("[AdminNotifier] mail enabled but no sender address (tenk.notify.mail.from / spring.mail.username)");
            return;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(from);
            message.setTo(config.to());
            message.setSubject(subject);
            message.setText(body);
            sender.send(message);
        } catch (Exception e) {
            log.warn("[AdminNotifier] mail send failed: {}", e.toString());
        }
    }

    /**
     * 발신 주소를 정한다. 설정이 없으면 <b>SMTP 인증 계정({@code spring.mail.username})으로 폴백</b>한다.
     *
     * <p>⚠️ 이 폴백이 없으면 실제로 메일이 안 나간다 — {@code spring.mail.username} 은 <b>인증용일 뿐
     * From 헤더가 되지 않아</b> JavaMail 이 {@code can't determine local email address} 로 실패한다
     * (에뮬레이터 검증에서 실제로 걸렸다). <b>이 폴백을 지우지 말 것.</b>
     *
     * <p>보내는 주소와 받는 주소는 다르다 — 발신은 서비스 계정, 수신은 고지된 문의처다.
     */
    private String resolveFrom(NotifyProperties.Mail config, JavaMailSender sender) {
        if (config.from() != null && !config.from().isBlank()) {
            return config.from();
        }
        if (sender instanceof JavaMailSenderImpl impl
                && impl.getUsername() != null && !impl.getUsername().isBlank()) {
            return impl.getUsername();
        }
        return null;
    }

    private void sendTelegram(String subject, String body) {
        NotifyProperties.Telegram config = properties.telegram();
        if (!config.isUsable()) {
            return;
        }
        try {
            restClient.post()
                    .uri(TELEGRAM_API.formatted(config.botToken()))
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "chat_id", config.chatId(),
                            "text", subject + "\n\n" + body))
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            log.warn("[AdminNotifier] telegram send failed: {}", e.toString());
        }
    }
}
