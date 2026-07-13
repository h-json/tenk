package com.hjson.tenk;

import com.hjson.tenk.common.config.AuthProperties;
import com.hjson.tenk.common.config.StorageProperties;
import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@ConfigurationPropertiesScan(basePackageClasses = {StorageProperties.class, AuthProperties.class})
@SpringBootApplication
public class TenkApplication {

    public static void main(String[] args) {
        // 서버 타임존을 KST 로 고정. LocalDate.now() 등이 JVM 기본 타임존을 따르는데,
        // Docker 컨테이너는 기본이 UTC 라 한국 자정~오전 9시 사이 날짜가 하루 밀려
        // "오늘 시작" 챌린지가 "시작 전" 으로 보이는 회귀가 있었다. 배포 환경(TZ env) 과
        // 무관하게 코드로도 고정해 어디서 돌려도 KST 를 쓰게 한다.
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"));
        SpringApplication.run(TenkApplication.class, args);
    }
}
