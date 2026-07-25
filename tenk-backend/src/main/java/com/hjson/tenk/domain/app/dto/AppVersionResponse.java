package com.hjson.tenk.domain.app.dto;

import com.hjson.tenk.domain.app.AppVersionStatus;

/**
 * 앱 버전 상태 응답.
 *
 * @param status             최신 / 권장 업데이트 / 강제 업데이트
 * @param latestVersion      서버가 아는 최신 버전
 * @param minSupportedVersion 이 버전 미만은 강제 업데이트
 * @param storeUrl           플랫폼별 스토어 딥링크 (없으면 null)
 */
public record AppVersionResponse(
        AppVersionStatus status,
        String latestVersion,
        String minSupportedVersion,
        String storeUrl
) {
}
