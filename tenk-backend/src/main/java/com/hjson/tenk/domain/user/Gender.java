package com.hjson.tenk.domain.user;

/**
 * 성별 — <b>선택 입력</b>. NULL(미입력)이 정상 상태이며, 서비스 기능은 이 값을 전혀 사용하지 않는다.
 * 수집 목적은 이용자 통계뿐이라 가입 흐름에서 받지 않고 '내 정보' 화면에서 본인이 원할 때만 입력한다.
 * 언제든 다시 미입력으로 되돌릴 수 있어야 한다 (개인정보 최소수집·철회 보장).
 */
public enum Gender {
    MALE,
    FEMALE,
    OTHER
}
