package com.hjson.tenk.common.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 이용자 HTTP 접속기록. <b>시각 · 접속지 IP · 메서드 · 경로 · 상태코드 · 소요시간</b>만 남긴다 —
 * 개인정보처리방침 §1 의 '자동 생성 정보'이고 §3 에 <b>3개월 보관</b>으로 고지돼 있다.
 *
 * <p>왜 필요한가 — 이게 없으면 <i>"어제 저녁에 저장이 안 됐다"</i>는 문의가 왔을 때 조사할 수단이
 * 없다. 서버에 남는 것이 {@code [UnhandledException]} 스택트레이스뿐이라 <b>500 이 아닌 실패
 * (400·404·인증 실패·아예 요청이 안 온 경우)는 흔적이 하나도 없기 때문</b>이다.
 *
 * <p>⚠️ <b>여기에 아래를 담지 말 것</b> — 담는 순간 로그가 또 하나의 개인정보 보관소가 되고,
 * 그러면 로그 자체가 수집표·보관기간의 대상이 된다. 규칙은 CLAUDE.md "로그 위생".
 * <ul>
 *   <li><b>쿼리스트링</b> — 지금은 개인정보가 안 들어가지만 <b>그 성질은 조용히 바뀐다</b>.
 *       {@code getRequestURI()} 는 쿼리를 제외한 경로만 준다({@code getRequestURL} 로 바꾸지 말 것).</li>
 *   <li><b>{@code Authorization} 헤더 · 쿠키 · 요청/응답 본문</b></li>
 *   <li><b>{@code userId}</b> — 넣으면 "누가·언제·무엇을 했다"의 완전한 행동 기록이 되어 성격이
 *       달라진다. 조사에는 IP + 시각이면 충분히 좁혀진다.</li>
 * </ul>
 *
 * <p>⚠️ <b>필터 순서가 이 기능의 핵심이다</b>({@link AccessLogConfig} 참고). Spring Security 보다
 * <b>앞</b>이어야 인증 실패(401)가 기록된다 — 뒤에 있으면 Security 가 체인을 끊어 <b>실행조차
 * 되지 않는다</b>.
 */
public class AccessLogFilter extends OncePerRequestFilter {

    private static final Logger ACCESS = LoggerFactory.getLogger("TENK_ACCESS_LOG");

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long startedAt = System.nanoTime();
        try {
            chain.doFilter(request, response);
        } finally {
            // finally 라서 예외로 끝난 요청도 남는다 — 그런 요청일수록 조사 대상이다.
            record(request, response, startedAt);
        }
    }

    private void record(HttpServletRequest request, HttpServletResponse response, long startedAt) {
        try {
            long tookMs = (System.nanoTime() - startedAt) / 1_000_000;
            ACCESS.info("ip={} method={} path={} status={} dur={}ms",
                    request.getRemoteAddr(),
                    request.getMethod(),
                    request.getRequestURI(),
                    response.getStatus(),
                    tookMs);
        } catch (Exception e) {
            // ⚠️ 기록 실패가 요청을 깨뜨리면 안 된다 — 로그가 안 남는 것보다 사용자의 요청이
            //    실패하는 게 훨씬 나쁘다 (AdminNotifier 의 best-effort 와 같은 원칙).
            //    여기서 예외를 다시 던지지 말 것.
        }
    }
}
