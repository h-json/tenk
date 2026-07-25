package com.hjson.tenk.domain.app;

import com.hjson.tenk.domain.app.dto.AppVersionResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 클라 버전을 서버 정책(app_config 단일 행)과 비교해 최신/권장/강제 상태를 판정한다.
 * 판정은 서버가 진실의 원천 — 정책(강제 기준선)을 재배포 없이 SQL 로 바꿀 수 있게 하려는 것.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AppVersionService {

    private static final Long CONFIG_ID = 1L;

    private final AppConfigRepository appConfigRepository;

    public AppVersionResponse resolve(String platform, String currentVersion) {
        AppConfig config = appConfigRepository.findById(CONFIG_ID).orElse(null);
        if (config == null) {
            // 설정 행이 없으면 게이트를 걸지 않는다(fail-open). 앱을 잠그는 것보다 안전.
            return new AppVersionResponse(AppVersionStatus.LATEST, currentVersion, currentVersion, null);
        }
        String storeUrl = isIos(platform) ? config.getIosStoreUrl() : config.getAndroidStoreUrl();
        return new AppVersionResponse(
                evaluate(currentVersion, config),
                config.getLatestVersion(),
                config.getMinSupportedVersion(),
                storeUrl);
    }

    private AppVersionStatus evaluate(String currentVersion, AppConfig config) {
        SemanticVersion current;
        try {
            current = SemanticVersion.parse(currentVersion);
        } catch (RuntimeException e) {
            // 클라 버전 문자열이 없거나 이상하면 게이트를 걸지 않는다(fail-open) — 사용자를 잠그지 않는다.
            return AppVersionStatus.LATEST;
        }
        if (current.compareTo(SemanticVersion.parse(config.getMinSupportedVersion())) < 0) {
            return AppVersionStatus.UPDATE_REQUIRED;
        }
        if (current.compareTo(SemanticVersion.parse(config.getLatestVersion())) < 0) {
            return AppVersionStatus.UPDATE_AVAILABLE;
        }
        return AppVersionStatus.LATEST;
    }

    private boolean isIos(String platform) {
        return platform != null && platform.trim().equalsIgnoreCase("ios");
    }
}
