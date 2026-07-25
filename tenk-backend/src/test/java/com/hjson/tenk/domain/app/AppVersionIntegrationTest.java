package com.hjson.tenk.domain.app;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.hjson.tenk.support.IntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 앱 버전 게이트 엔드포인트 E2E. 로직 단위는 {@link AppVersionServiceTest} 가 덮으므로 여기서는
 * <b>보안(PERMIT_ALL — 인증 없이 접근)</b> + DB 설정 행 반영 + 응답 계약만 본다.
 * 클라 부팅 게이트가 이 응답으로 강제/권장 업데이트를 결정하므로 계약이 깨지면 사용자를 잘못 잠글 수 있다.
 */
@AutoConfigureMockMvc
class AppVersionIntegrationTest extends IntegrationTestBase {

    @Autowired MockMvc mockMvc;

    @BeforeEach
    void seedConfig() {
        // app_config 는 IntegrationTestBase 가 지우지 않는 마스터 성격 행 — 테스트가 값을 확정해 둔다.
        tx.executeWithoutResult(status -> em.createNativeQuery("""
                INSERT INTO app_config
                    (app_config_id, min_supported_version, latest_version, android_store_url, ios_store_url)
                VALUES (1, '1.0.0', '1.2.0', 'https://play/android', 'https://apps/ios')
                ON DUPLICATE KEY UPDATE
                    min_supported_version = VALUES(min_supported_version),
                    latest_version        = VALUES(latest_version),
                    android_store_url     = VALUES(android_store_url),
                    ios_store_url         = VALUES(ios_store_url)
                """).executeUpdate());
    }

    @AfterEach
    void restoreConfig() {
        // 통합 테스트는 공유 로컬 DB 의 싱글턴 app_config 행을 덮어쓴다. 원복하지 않으면 dev/앱이
        // 테스트용 더미 값(latest=1.2.0, https://play/android)을 읽어 가짜 "업데이트 있어요" 가 뜬다.
        // schema.sql 시드값(최신=1.0.0, 실 Play URL)으로 되돌린다.
        tx.executeWithoutResult(status -> em.createNativeQuery("""
                UPDATE app_config SET
                    min_supported_version = '1.0.0',
                    latest_version        = '1.0.0',
                    android_store_url     = 'https://play.google.com/store/apps/details?id=com.hjson.tenk_app',
                    ios_store_url         = NULL
                WHERE app_config_id = 1
                """).executeUpdate());
    }

    @Test
    @DisplayName("인증 없이 호출 가능하고, min 미만이면 강제 업데이트를 돌려준다")
    void belowMinIsRequiredWithoutAuth() throws Exception {
        mockMvc.perform(get("/api/app/version")
                        .param("platform", "android")
                        .param("currentVersion", "0.9.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("UPDATE_REQUIRED"))
                .andExpect(jsonPath("$.data.latestVersion").value("1.2.0"))
                .andExpect(jsonPath("$.data.minSupportedVersion").value("1.0.0"))
                .andExpect(jsonPath("$.data.storeUrl").value("https://play/android"));
    }

    @Test
    @DisplayName("min 이상 latest 미만이면 권장 업데이트 + ios 스토어 URL")
    void betweenIsAvailable() throws Exception {
        mockMvc.perform(get("/api/app/version")
                        .param("platform", "ios")
                        .param("currentVersion", "1.1.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("UPDATE_AVAILABLE"))
                .andExpect(jsonPath("$.data.storeUrl").value("https://apps/ios"));
    }

    @Test
    @DisplayName("latest 이상이면 최신")
    void atLatestIsLatest() throws Exception {
        mockMvc.perform(get("/api/app/version")
                        .param("platform", "android")
                        .param("currentVersion", "1.2.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("LATEST"));
    }

    @Test
    @DisplayName("currentVersion 이 없으면 게이트를 걸지 않는다 (fail-open)")
    void missingVersionFailsOpen() throws Exception {
        mockMvc.perform(get("/api/app/version").param("platform", "android"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("LATEST"));
    }
}
