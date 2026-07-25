package com.hjson.tenk.domain.app;

/** 클라 버전을 서버 정책과 비교한 결과. */
public enum AppVersionStatus {
    /** 최신 (또는 판정 불가로 fail-open). */
    LATEST,
    /** 권장 업데이트 — latest 미만이지만 min 이상. 안내만 하고 계속 사용 가능. */
    UPDATE_AVAILABLE,
    /** 강제 업데이트 — min_supported 미만. 앱 사용 차단. */
    UPDATE_REQUIRED
}
