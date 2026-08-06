package com.hjson.tenk;

import com.hjson.tenk.admin.AdminProperties;
import com.hjson.tenk.common.config.AuthProperties;
import com.hjson.tenk.common.config.StorageProperties;
import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

// @EnableAsync 는 AdminNotifier(문의·의견 도착 알림) 전용이다. SMTP·텔레그램 외부 호출이
// 사용자 응답 시간에 붙지 않게 하려는 것 — 알림이 늦는 건 괜찮지만 저장이 느려지면 안 된다.
@EnableAsync
@EnableScheduling
// ⚠️ 스캔 범위가 basePackageClasses 로 못박혀 있다 — 새 패키지에 @ConfigurationProperties 를
// 만들면 여기에 그 패키지의 클래스를 하나 추가해야 한다. 안 그러면 부팅이 "No qualifying bean of
// type ...Properties" 로 죽는다 (AdminProperties 가 실제로 그랬다).
@ConfigurationPropertiesScan(basePackageClasses = {
        StorageProperties.class, AuthProperties.class, AdminProperties.class})
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
