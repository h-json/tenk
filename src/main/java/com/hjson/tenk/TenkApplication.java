package com.hjson.manwon;

import com.hjson.manwon.common.config.AuthProperties;
import com.hjson.manwon.common.config.StorageProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@ConfigurationPropertiesScan(basePackageClasses = {StorageProperties.class, AuthProperties.class})
@SpringBootApplication
public class ManwonApplication {

    public static void main(String[] args) {
        SpringApplication.run(ManwonApplication.class, args);
    }
}
