package com.hjson.tenk.admin;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * 패널 활성화 여부와 무관하게 항상 필요한 빈. {@code AdminAccountInitializer} 가 패널이 꺼져
 * 있어도 주입받기 때문에 {@link AdminSecurityConfig}(조건부)에 두면 안 된다.
 */
@Configuration
public class AdminConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
