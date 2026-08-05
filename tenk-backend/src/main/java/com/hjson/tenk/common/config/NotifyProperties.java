package com.hjson.tenk.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 관리자(개발자) 알림 설정. 문의·의견이 도착했을 때 <b>메일과 텔레그램 두 갈래로</b> 알린다.
 *
 * <p>두 겹인 이유는 한쪽을 놓쳐도 다른 쪽이 남기 때문이고, 그래도 놓칠 수 있어서 미처리 문의는
 * {@code InquiryScheduler} 가 매일 다시 알린다.
 *
 * <p><b>{@code enabled} 는 프로파일마다 다르다</b> — local/test 는 false 라 테스트를 돌려도 실제
 * 메일·텔레그램이 나가지 않는다. 값이 아예 없어도 부팅은 되어야 하므로(알림은 부가 기능이다)
 * 컴팩트 생성자에서 null 을 꺼진 상태로 정규화한다.
 */
@ConfigurationProperties(prefix = "tenk.notify")
public record NotifyProperties(Mail mail, Telegram telegram) {

    public NotifyProperties {
        if (mail == null) {
            mail = new Mail(false, null, null);
        }
        if (telegram == null) {
            telegram = new Telegram(false, null, null);
        }
    }

    /**
     * @param to   알림을 받을 주소. 보내는 주소({@code spring.mail.username})와 같아도 된다.
     * @param from 발신 주소. 비우면 {@code spring.mail.username} 이 쓰인다.
     */
    public record Mail(boolean enabled, String to, String from) {
        public boolean isUsable() {
            return enabled && to != null && !to.isBlank();
        }
    }

    /**
     * @param botToken BotFather 가 발급한 HTTP API 토큰
     * @param chatId   알림을 받을 대화 id. 봇에게 먼저 말을 걸어야 생기며
     *                 {@code https://api.telegram.org/bot<TOKEN>/getUpdates} 로 확인한다.
     */
    public record Telegram(boolean enabled, String botToken, String chatId) {
        public boolean isUsable() {
            return enabled
                    && botToken != null && !botToken.isBlank()
                    && chatId != null && !chatId.isBlank();
        }
    }
}
