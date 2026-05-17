package com.hjson.manwon.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "manwon.auth")
public record AuthProperties(String loginSuccessRedirect, String logoutSuccessRedirect) {
}
