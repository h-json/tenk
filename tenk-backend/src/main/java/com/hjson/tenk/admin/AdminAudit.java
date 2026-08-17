package com.hjson.tenk.admin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * 관리자 접속기록. <b>계정 · 일시 · 접속지 · 수행업무</b>를 남긴다 —
 * 「개인정보의 안전성 확보조치 기준」이 요구하는 접속기록 항목에 맞춘 것이고,
 * 개인정보처리방침 §8 에 <b>1년 이상 보관</b>으로 고지돼 있다.
 *
 * <p>패널은 이용자 개인정보(문의 본문·닉네임·회신 이메일)를 열람하고 권한까지 바꾸므로 기록이
 * 필요하다. 예전처럼 SSH 로 DB 에 붙어 {@code UPDATE} 를 치던 시절엔 <b>아무 흔적도 안 남았다</b> —
 * 패널로 옮기면서 오히려 좋아진 부분이다.
 *
 * <p><b>변경뿐 아니라 열람도 남긴다.</b> 고시의 '수행업무'에는 조회가 포함되고, 실제로 유출은
 * 변경이 아니라 열람에서 일어난다. 관리자가 한 명이라 양도 문제되지 않는다.
 *
 * <p><b>전용 로거({@code TENK_ADMIN_AUDIT})가 핵심이다</b> — 애플리케이션 로그와 섞이면 보관 기간을
 * 따로 가져갈 수 없다. logback 이 이 이름으로 별도 파일에 1년 롤링 보관하고, 그 파일은 컨테이너
 * 볼륨에 있어 <b>재배포에도 살아남는다</b>({@code logback-spring.xml} + {@code docker-compose.yml}).
 *
 * <p>⚠️ <b>여기에 본문·이메일 같은 내용을 적지 말 것.</b> 기록의 목적은 "무엇을 건드렸나"이지
 * 내용의 사본이 아니다 — 내용을 적으면 로그가 <b>또 하나의 개인정보 보관소</b>가 되고, 그러면
 * 로그 자체가 수집표·보관기간의 대상이 된다.
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
        record(currentActor(), action, target, detail);
    }

    /**
     * 행위자를 직접 지정하는 형태. 로그인 <b>실패</b>는 인증이 없어 {@code SecurityContext} 에서
     * 계정을 못 읽으므로 이 경로가 필요하다.
     */
    public void record(String actor, String action, String target, String detail) {
        AUDIT.info("actor={} ip={} action={} target={} detail={}",
                actor, currentIp(), action, target, detail);
    }

    private String currentActor() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth == null ? "anonymous" : auth.getName();
    }

    /**
     * 접속지 IP.
     *
     * <p>⚠️ <b>{@code X-Forwarded-For} 를 직접 읽지 말 것.</b> {@code server.forward-headers-strategy=framework}
     * 라서 Spring 의 {@code ForwardedHeaderFilter} 가 <b>XFF 헤더를 떼어낸 뒤</b> 넘기고, 대신
     * {@code getRemoteAddr()} 을 XFF 첫 값으로 <b>바꿔치기</b>한다. 즉 헤더를 먼저 보는 분기는
     * <b>영원히 null 이라 죽은 코드</b>가 된다(2026-08-17 까지 실제로 그 상태였고, 결과를 내던 것은
     * 폴백 쪽이었다).
     *
     * <p>prod 에서 이 값이 실제 클라이언트 IP 인 것은 <b>맥의 HAProxy 가 PROXY protocol 로 넘긴
     * 덕분</b>이다(#28 D2). 그 앞단이 없으면 Colima 의 SSH 포트 포워더가 IP 를 지워 모든 접속이
     * 같은 게이트웨이 IP 로 찍힌다 — docker-deployment.md §2·§8 참고.
     *
     * <p>스케줄러 등 요청 밖에서 불리면 요청 자체가 없으므로 {@code -} 를 남긴다.
     */
    private String currentIp() {
        if (!(RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attrs)) {
            return "-";
        }
        return attrs.getRequest().getRemoteAddr();
    }
}
