package com.hjson.tenk.domain.user;

/**
 * 탈퇴 사유 (선택 입력). 이탈 원인을 분류하기 위한 코드이며 서비스 기능에는 쓰이지 않는다.
 *
 * <p>항목을 바꾸면 Flutter 의 탈퇴 화면 라벨 목록도 같은 코드로 동시에 갱신할 것
 * (표시 문구는 클라이언트가 들고 있고, 여기엔 안정적인 코드만 둔다 — 지출 카테고리와 같은 방식).
 * 이미 쌓인 값은 그대로 남으므로 <b>기존 상수를 지우거나 이름을 바꾸지 말 것</b>.
 */
public enum WithdrawalReason {

    /** 기록하는 것 자체가 번거로움 — 온보딩·입력 흐름 문제. */
    RECORDING_BURDEN,

    /** 챌린지 목표·난이도가 안 맞음. */
    GOAL_MISMATCH,

    /** 쓸 일이 없어졌음 (목표 달성 포함). */
    NO_LONGER_NEEDED,

    /** 오류·불안정. */
    BUGS,

    /** 개인정보가 걱정됨. */
    PRIVACY_CONCERN,

    /** 그 밖의 사유 — 자유 서술이 함께 올 수 있다. */
    ETC
}
