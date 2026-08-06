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
 *
 * <p>값은 <b>재배포 없이</b> 바꾼다 — 그게 이 테이블의 존재 이유다. 갱신 경로는 관리자 패널
 * ({@code /admin/app-config})이고, 2026-08-06 이전에는 {@code UPDATE} 를 직접 쳤다.
 */
@Getter
@Entity
@Table(name = "app_config")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AppConfig {

    /** 단일 행이라 id 가 고정이다. 행을 늘리지 말 것 — 정책이 둘이 되면 어느 쪽이 진짜인지 알 수 없다. */
    public static final Long SINGLETON_ID = 1L;

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

    /**
     * 정책 갱신 (관리자 패널). 버전 문자열의 유효성은 {@code SemanticVersion} 이 읽을 때 판정하고,
     * <b>이상하면 서버가 {@code LATEST} 를 주는 fail-open</b> 이라 여기서 막지 않는다 —
     * 잘못된 값 때문에 앱이 잠기는 일은 구조적으로 없다.
     *
     * <p>스토어 URL 은 비우면 {@code null} 로 되돌린다 (iOS 는 출시 전까지 NULL 이 정상).
     */
    public void updatePolicy(String minSupportedVersion, String latestVersion,
                             String androidStoreUrl, String iosStoreUrl) {
        this.minSupportedVersion = minSupportedVersion.trim();
        this.latestVersion = latestVersion.trim();
        this.androidStoreUrl = blankToNull(androidStoreUrl);
        this.iosStoreUrl = blankToNull(iosStoreUrl);
    }

    private static String blankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
