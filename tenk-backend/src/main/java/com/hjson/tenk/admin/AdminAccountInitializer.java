package com.hjson.tenk.admin;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.ApplicationArguments;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * 부팅 시 관리자 계정 1개를 보장한다 ({@code tenk.admin.account} 기준).
 *
 * <p>없으면 만들고, 있으면 <b>비밀번호 해시만 yaml 값에 다시 맞춘다</b> — yaml 이 진실의 원천이라는
 * 규칙의 구현체다 ({@link AdminProperties} 주석 참고). 이메일이 다른 행은 건드리지 않으므로
 * 손으로 추가한 계정은 그대로 남는다.
 *
 * <p>매 부팅마다 해시를 새로 만드는 대신 <b>기존 해시와 일치하는지 먼저 확인</b>한다 — BCrypt 는
 * salt 가 매번 달라 무조건 갱신하면 값이 바뀐 적 없어도 UPDATE 가 나가고, 로그만 봐선
 * 비밀번호가 실제로 바뀌었는지 알 수 없게 된다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AdminAccountInitializer implements ApplicationRunner {

    private final AdminProperties properties;
    private final AdminUserRepository adminUserRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!properties.enabled()) {
            return;
        }
        AdminProperties.Account account = properties.account();
        if (!account.isUsable()) {
            log.warn("[Admin] panel enabled but tenk.admin.account 가 비어 있어 계정을 만들지 않았습니다.");
            return;
        }

        String email = account.email().trim().toLowerCase();
        adminUserRepository.findByEmail(email).ifPresentOrElse(
                existing -> syncPassword(existing, account.password()),
                () -> {
                    adminUserRepository.save(
                            AdminUser.of(email, passwordEncoder.encode(account.password())));
                    // ⚠️ 로그인 ID 를 찍지 말 것 — 공개된 로그인 폼의 ID 라 그 자체가 자격증명의 절반이다.
                    //    어떤 계정인지는 yaml 이 진실의 원천이므로 로그로 확인할 이유도 없다.
                    log.info("[Admin] 관리자 계정을 생성했습니다.");
                });
    }

    private void syncPassword(AdminUser existing, String rawPassword) {
        if (passwordEncoder.matches(rawPassword, existing.getPasswordHash())) {
            return;
        }
        existing.changePasswordHash(passwordEncoder.encode(rawPassword));
        log.info("[Admin] 관리자 계정 비밀번호를 yaml 값으로 갱신했습니다.");
    }
}
