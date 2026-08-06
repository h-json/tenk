package com.hjson.tenk.admin;

import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.event.EventListener;
import org.springframework.security.authentication.event.AbstractAuthenticationFailureEvent;
import org.springframework.security.authentication.event.AuthenticationSuccessEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 로그인 성공·실패를 접속기록에 남긴다.
 *
 * <p>「안전성 확보조치 기준」의 접속기록은 <b>'접속'</b> 자체를 포함한다 — 무엇을 했는지만 남기고
 * 언제 들어왔는지를 안 남기면 절반이다. <b>실패도 남기는 게 핵심</b>인데, 대입 공격의 유일한
 * 탐지 수단이기 때문이다(패널 로그인 폼이 공개 인터넷에 노출돼 있다).
 *
 * <p>Spring Security 가 발행하는 인증 이벤트를 듣는다 — 로그인 처리는 필터가 하므로 컨트롤러에
 * 훅을 걸 자리가 없다. 실패 이벤트는 인증이 없어 {@code SecurityContext} 에서 계정을 못 읽으므로
 * 이벤트가 들고 있는 시도 계정을 그대로 넘긴다.
 *
 * <p>⚠️ <b>실패 로그에 입력된 비밀번호를 남기지 말 것</b> — 오타가 대개 진짜 비밀번호의 변형이라
 * 그 자체가 자격증명 유출이 된다. 계정과 IP 까지만 남긴다.
 */
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "tenk.admin", name = "enabled", havingValue = "true")
public class AdminLoginAuditor {

    private final AdminAudit audit;
    private final AdminUserRepository adminUserRepository;

    @EventListener
    @Transactional
    public void onSuccess(AuthenticationSuccessEvent event) {
        String email = event.getAuthentication().getName();
        audit.record(email, "LOGIN_SUCCESS", "admin", "-");
        // 계정이 실제로 쓰이는지, 낯선 시각에 로그인이 있었는지 보는 최소 단서.
        adminUserRepository.findByEmail(email)
                .ifPresent(admin -> admin.markLoggedIn(LocalDateTime.now()));
    }

    @EventListener
    public void onFailure(AbstractAuthenticationFailureEvent event) {
        Object principal = event.getAuthentication().getPrincipal();
        audit.record(principal == null ? "unknown" : principal.toString(),
                "LOGIN_FAILURE", "admin",
                event.getException().getClass().getSimpleName());
    }
}
