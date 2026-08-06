package com.hjson.tenk.domain.inquiry;

/**
 * 문의 유형. <b>일부러 굵게 잡은 4종</b>이다 — 국내 고객센터의 표준 분류가
 * 계정 / 결제 / 오류 / 기타인데, TenK 은 결제가 없어 그 자리를 개인정보가 대신한다.
 *
 * <p><b>'오류'를 따로 두지 않는 게 의도다.</b> 결제가 없어 {@link #SERVICE} 문의의 대부분이 곧
 * 오류이고, 순수한 버그 제보는 이미 익명 창구인 {@code FeedbackType.PROBLEM} 이 받는다.
 * 세분화하면 고르는 시간만 늘고 분류 정확도는 오히려 떨어진다 — <b>늘릴 땐 뺄 것을 같이 정할 것.</b>
 *
 * <p>항목을 바꾸면 Flutter 문의 화면의 라벨 목록도 같은 코드로 동시에 갱신할 것.
 * 이미 쌓인 값은 그대로 남으므로 <b>기존 상수를 지우거나 이름을 바꾸지 말 것</b>.
 *
 * <p><b>{@code label} 은 관리자 패널 표시용이다</b> ({@code SpendCategory} 와 같은 방식).
 * 사용자에게 보이는 <b>선택지 문구는 여전히 Flutter 가 소유</b>하고({@code inquiry_screen.dart}
 * 의 {@code _types}), 여기 라벨은 패널의 목록·상세에서 {@code PRIVACY} 같은 코드가 그대로
 * 노출되지 않게 하는 <b>짧은 분류명</b>이다. 문의 유형은 앱 쪽도 짧은 명사라 지금은 두 값이
 * 같지만, <b>둘을 하나로 합치려 들지 말 것</b> — 쓰이는 자리가 다르다(의견 유형은 실제로 다르다).
 *
 * <p><b>이 창구와 의견 보내기를 가르는 건 유형이 아니라 "답변을 원하는가" 하나다.</b>
 * 같은 오류라도 답을 원하면 여기로, 그냥 알려주는 거면 의견으로 간다.
 */
public enum InquiryType {

    /** 로그인이 안 되거나 계정 상태가 이상함. */
    ACCOUNT("계정·로그인"),

    /** 기능이 안 되거나 쓰는 방법을 모르겠음 — 오류 포함. */
    SERVICE("서비스 이용"),

    /** 개인정보 열람·정정·삭제·처리정지 등 정보주체의 권리 행사 (보호법 제35~37조). */
    PRIVACY("개인정보"),

    /** 그 밖의 문의. */
    ETC("기타");

    private final String label;

    InquiryType(String label) {
        this.label = label;
    }

    /** 관리자 패널 표시용 분류명. 사용자에게 보이는 선택지 문구는 Flutter 가 소유한다. */
    public String getLabel() {
        return label;
    }
}
