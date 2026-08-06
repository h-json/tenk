package com.hjson.tenk.admin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * 관리자 액션 기록. <b>누가 · 언제 · 무엇을 했는지</b>를 남긴다.
 *
 * <p>패널은 이용자 개인정보(문의 본문·닉네임·회신 이메일)를 열람하고 권한까지 바꾸므로,
 * 접근 기록을 남기는 게 개인정보 안전성 확보조치의 기본이다. 예전처럼 DB 에 직접 붙어
 * {@code UPDATE} 를 치던 시절엔 아무 흔적도 안 남았다 — 패널로 옮기면서 생긴 이점이다.
 *
 * <p><b>전용 로거 이름({@code TENK_ADMIN_AUDIT})을 쓰는 게 의도다</b> — 애플리케이션 로그와 섞이면
 * 보관 기간을 따로 가져갈 수 없다. 파일로 분리해야 하면 logback 설정에서 이 이름으로 appender 를 건다.
 *
 * <p>⚠️ <b>여기에 본문·이메일 같은 내용을 적지 말 것.</b> 기록의 목적은 "무엇을 건드렸나"이지
 * 내용의 사본이 아니다 — 내용을 적으면 로그가 또 하나의 개인정보 보관소가 된다.
 */
@Component
public class AdminAudit {

    private static final Logger AUDIT = LoggerFactory.getLogger("TENK_ADMIN_AUDIT");

    /**
     * @param action 동사형 짧은 코드 (예: {@code INQUIRY_HANDLE}, {@code USER_ROLE_CHANGE})
     * @param target 대상 식별자 (예: {@code inquiry#37})
     * @param detail 무엇이 어떻게 바뀌었는지. <b>개인정보를 담지 말 것</b>
     */
    public void record(String action, String target, String detail) {
        AUDIT.info("actor={} action={} target={} detail={}", currentActor(), action, target, detail);
    }

    private String currentActor() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth == null ? "anonymous" : auth.getName();
    }
}
