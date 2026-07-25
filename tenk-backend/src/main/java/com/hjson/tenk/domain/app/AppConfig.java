package com.hjson.tenk.domain.app;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 앱 버전 정책 단일 행 (app_config, id=1). 강제/권장 업데이트 게이트가 읽는다.
 * 값은 재배포 없이 SQL 로 갱신하는 운영 방식 (관리자 UI 없음 — TESTER 승격과 동일). schema.sql 주석 참고.
 */
@Getter
@Entity
@Table(name = "app_config")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AppConfig {

    @Id
    @Column(name = "app_config_id")
    private Long id;

    @Column(name = "min_supported_version", nullable = false, length = 20)
    private String minSupportedVersion;

    @Column(name = "latest_version", nullable = false, length = 20)
    private String latestVersion;

    @Column(name = "android_store_url", length = 255)
    private String androidStoreUrl;

    @Column(name = "ios_store_url", length = 255)
    private String iosStoreUrl;
}
