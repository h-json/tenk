package com.hjson.tenk.domain.app;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class AppVersionServiceTest {

    @Mock AppConfigRepository appConfigRepository;
    @InjectMocks AppVersionService service;

    private AppConfig config;

    @BeforeEach
    void setUp() {
        config = new AppConfig();
        ReflectionTestUtils.setField(config, "id", 1L);
        ReflectionTestUtils.setField(config, "minSupportedVersion", "1.0.0");
        ReflectionTestUtils.setField(config, "latestVersion", "1.2.0");
        ReflectionTestUtils.setField(config, "androidStoreUrl", "https://play/android");
        ReflectionTestUtils.setField(config, "iosStoreUrl", "https://apps/ios");
        lenient().when(appConfigRepository.findById(1L)).thenReturn(Optional.of(config));
    }

    @Test
    @DisplayName("min 미만이면 강제 업데이트")
    void belowMinIsRequired() {
        assertThat(service.resolve("android", "0.9.0").status()).isEqualTo(AppVersionStatus.UPDATE_REQUIRED);
    }

    @Test
    @DisplayName("min 이상 latest 미만이면 권장 업데이트 (경계 포함)")
    void betweenIsAvailable() {
        assertThat(service.resolve("android", "1.0.0").status()).isEqualTo(AppVersionStatus.UPDATE_AVAILABLE);
        assertThat(service.resolve("android", "1.1.9").status()).isEqualTo(AppVersionStatus.UPDATE_AVAILABLE);
    }

    @Test
    @DisplayName("latest 이상이면 최신")
    void atOrAboveLatestIsLatest() {
        assertThat(service.resolve("android", "1.2.0").status()).isEqualTo(AppVersionStatus.LATEST);
        assertThat(service.resolve("android", "1.3.0").status()).isEqualTo(AppVersionStatus.LATEST);
    }

    @Test
    @DisplayName("플랫폼에 따라 스토어 URL 을 고른다 (기본 android)")
    void picksStoreUrlByPlatform() {
        assertThat(service.resolve("android", "1.2.0").storeUrl()).isEqualTo("https://play/android");
        assertThat(service.resolve("ios", "1.2.0").storeUrl()).isEqualTo("https://apps/ios");
        assertThat(service.resolve(null, "1.2.0").storeUrl()).isEqualTo("https://play/android");
    }

    @Test
    @DisplayName("버전 문자열이 없거나 이상하면 게이트를 걸지 않는다 (fail-open)")
    void garbageVersionFailsOpen() {
        assertThat(service.resolve("android", null).status()).isEqualTo(AppVersionStatus.LATEST);
        assertThat(service.resolve("android", "not-a-version").status()).isEqualTo(AppVersionStatus.LATEST);
    }

    @Test
    @DisplayName("설정 행이 없으면 fail-open (LATEST)")
    void missingConfigFailsOpen() {
        when(appConfigRepository.findById(1L)).thenReturn(Optional.empty());
        assertThat(service.resolve("android", "0.1.0").status()).isEqualTo(AppVersionStatus.LATEST);
    }
}
