package com.hjson.tenk.domain.feedback;

/**
 * 의견 유형. 쌓인 의견을 훑을 때 분류하기 위한 코드이며 서비스 기능에는 쓰이지 않는다.
 *
 * <p>항목을 바꾸면 Flutter 의견 보내기 화면의 라벨 목록도 같은 코드로 동시에 갱신할 것.
 * 이미 쌓인 값은 그대로 남으므로 <b>기존 상수를 지우거나 이름을 바꾸지 말 것</b>.
 *
 * <p><b>{@code label} 은 관리자 패널 표시용이고 앱의 선택지 문구와 일부러 다르다.</b> 앱은 고르는
 * 화면이라 해요체 문장({@code "불편하거나 오류가 있어요"})이지만, 패널은 목록 한 칸에 들어가야 해
 * <b>짧은 분류명</b>({@code "불편·오류"})이 맞다. 사용자에게 보이는 문구의 소유자는 계속 Flutter
 * ({@code feedback_screen.dart} 의 {@code _types})다 — <b>둘을 같은 값으로 맞추려 들지 말 것.</b>
 *
 * <p><b>유형으로 "답변이 필요한가"를 판정하지 말 것.</b> 그 판정은 회신용 이메일을 적었는지
 * 하나로 한다 — 같은 {@link #PROBLEM} 이라도 답을 원하는 사람과 그냥 알려주는 사람이 갈린다.
 */
public enum FeedbackType {

    /** 불편하거나 오류가 있음. */
    PROBLEM("불편·오류"),

    /** 이런 기능이 있으면 좋겠다는 제안. */
    SUGGESTION("기능 제안"),

    /** 좋았던 점. */
    PRAISE("좋았던 점"),

    /** 그 밖의 이야기. */
    ETC("기타");

    private final String label;

    FeedbackType(String label) {
        this.label = label;
    }

    /** 관리자 패널 표시용 분류명. 앱의 선택지 문구(해요체 문장)와 다른 게 의도다. */
    public String getLabel() {
        return label;
    }
}
