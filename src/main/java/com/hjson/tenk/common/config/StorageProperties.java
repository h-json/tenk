package com.hjson.manwon.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "manwon.upload")
public record StorageProperties(String baseDir) {
}
