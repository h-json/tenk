package com.hjson.tenk.domain.user;

/**
 * 성별 — <b>선택 입력</b>. NULL(미입력)이 정상 상태이며, 서비스 기능은 이 값을 전혀 사용하지 않는다.
 * 수집 목적은 이용자 통계뿐이라 가입 흐름에서 받지 않고 '내 정보' 화면에서 본인이 원할 때만 입력한다.
 * 언제든 다시 미입력으로 되돌릴 수 있어야 한다 (개인정보 최소수집·철회 보장).
 *
 * <p><b>상수는 둘뿐이고 '기타'는 두지 않는다</b> (2026-07-29). 입력 UI 가 남성·입력 안 함·여성
 * 3칸 토글이라 값이 들어갈 자리가 없다. 상수를 되살리려면 토글부터 다시 설계할 것.
 *
 * <p>⚠️ {@code @Enumerated(EnumType.STRING)} 이라 <b>여기 없는 문자열이 DB 에 있으면 그 유저 조회가 예외로 죽는다.</b>
 * 상수를 지울 때는 반드시 {@code UPDATE user SET gender=NULL WHERE gender='<지운 값>';} 을 짝으로 칠 것.
 */
public enum Gender {
    MALE,
    FEMALE
}
