package com.hjson.tenk.common.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "C0001", "서버 내부 오류가 발생했습니다."),
    INVALID_INPUT(HttpStatus.BAD_REQUEST, "C0002", "잘못된 요청입니다."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "C0003", "인증이 필요합니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "C0004", "접근 권한이 없습니다."),
    // 아래 3개는 사용자가 마주칠 상황이 아니라 잘못된 호출(클라이언트 버그·크롤러)에 대한 응답이다.
    // 500 으로 나가면 서버 장애와 구분되지 않아 로그·모니터링이 오염되므로 정확한 상태로 내린다.
    NOT_FOUND(HttpStatus.NOT_FOUND, "C0005", "요청한 경로를 찾을 수 없습니다."),
    METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "C0006", "지원하지 않는 요청 방식입니다."),
    UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "C0007", "지원하지 않는 형식의 요청입니다."),

    USER_NOT_FOUND(HttpStatus.NOT_FOUND, "U0001", "사용자를 찾을 수 없습니다."),
    USER_ALREADY_WITHDRAWN(HttpStatus.BAD_REQUEST, "U0002", "이미 탈퇴한 사용자입니다."),
    USER_NICKNAME_INVALID(HttpStatus.BAD_REQUEST, "U0003", "사용할 수 없는 문자가 포함된 닉네임이에요."),
    USER_NICKNAME_CHANGE_TOO_FREQUENT(HttpStatus.BAD_REQUEST, "U0004", "닉네임은 24시간에 한 번만 변경할 수 있어요."),
    USER_BIRTH_DATE_INVALID(HttpStatus.BAD_REQUEST, "U0005", "생년월일이 올바르지 않아요."),
    USER_UNDER_MINIMUM_AGE(HttpStatus.FORBIDDEN, "U0006", "만 14세 미만은 서비스를 이용할 수 없어요. 계정과 입력하신 정보는 삭제되었습니다."),
    // 탈퇴했지만 보관 기간이라 계정이 살아 있는 상태. 클라이언트는 이 코드를 받으면 철회 확인 다이얼로그를 띄운다
    // (사용자가 수습할 수 있는 상황이므로 USER_ALREADY_WITHDRAWN 과 분리했다).
    USER_WITHDRAWAL_RESTORABLE(HttpStatus.BAD_REQUEST, "U0007", "탈퇴한 계정이에요. 탈퇴를 철회하면 이전 기록을 그대로 이어서 쓸 수 있어요."),
    USER_NOT_WITHDRAWN(HttpStatus.BAD_REQUEST, "U0008", "탈퇴하지 않은 계정이에요."),

    AUTH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "AU0001", "유효하지 않은 토큰입니다."),
    AUTH_TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "AU0002", "만료된 토큰입니다."),
    AUTH_REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "AU0003", "유효하지 않은 리프레시 토큰입니다."),
    AUTH_KAKAO_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "AU0004", "카카오 액세스 토큰이 유효하지 않습니다."),
    AUTH_KAKAO_APP_MISMATCH(HttpStatus.UNAUTHORIZED, "AU0005", "이 토큰은 다른 카카오 앱에서 발급된 토큰입니다."),
    AUTH_KAKAO_USERINFO_FAILED(HttpStatus.BAD_GATEWAY, "AU0006", "카카오 사용자 정보 조회에 실패했습니다."),

    CHALLENGE_NOT_FOUND(HttpStatus.NOT_FOUND, "CH0001", "챌린지를 찾을 수 없습니다."),
    CHALLENGE_PERIOD_INVALID(HttpStatus.BAD_REQUEST, "CH0002", "챌린지 기간은 오늘 이후 시작이고 시작일로부터 최대 30일까지 가능합니다."),
    CHALLENGE_NOT_OWNER(HttpStatus.FORBIDDEN, "CH0003", "본인 챌린지가 아닙니다."),
    CHALLENGE_ALREADY_FINISHED(HttpStatus.BAD_REQUEST, "CH0004", "이미 종료된 챌린지입니다."),
    CHALLENGE_NOT_STARTED(HttpStatus.BAD_REQUEST, "CH0005", "아직 시작하지 않은 챌린지입니다."),
    CHALLENGE_NAME_INVALID(HttpStatus.BAD_REQUEST, "CH0006", "챌린지 이름은 1~100자이며 제어 문자를 포함할 수 없습니다."),

    AMOUNT_NOT_FOUND(HttpStatus.NOT_FOUND, "A0001", "지출 기록을 찾을 수 없습니다."),
    AMOUNT_INVALID_SPEND_VALUE(HttpStatus.BAD_REQUEST, "A0003", "지출 금액은 0보다 커야 합니다."),
    AMOUNT_INVALID_NO_SPEND_VALUE(HttpStatus.BAD_REQUEST, "A0004", "무지출 기록의 금액은 0이어야 합니다."),
    AMOUNT_CATEGORY_CONTENT_REQUIRED(HttpStatus.BAD_REQUEST, "A0005", "지출 기록은 카테고리와 내용이 필요합니다."),
    AMOUNT_DATE_OUT_OF_RANGE(HttpStatus.BAD_REQUEST, "A0006", "기록 날짜는 챌린지 기간 안에 있어야 합니다."),
    AMOUNT_NO_SPEND_ALREADY_EXISTS(HttpStatus.BAD_REQUEST, "A0007", "오늘은 이미 무지출 기록이 있어요."),
    AMOUNT_CATEGORY_INVALID(HttpStatus.BAD_REQUEST, "A0008", "유효하지 않은 카테고리입니다."),

    MEDIA_UPLOAD_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "M0001", "파일 업로드에 실패했습니다."),
    MEDIA_NOT_FOUND(HttpStatus.NOT_FOUND, "M0002", "파일을 찾을 수 없습니다."),

    BADGE_NOT_FOUND(HttpStatus.NOT_FOUND, "B0001", "배지를 찾을 수 없습니다."),

    FEEDBACK_CONTENT_INVALID(HttpStatus.BAD_REQUEST, "F0001", "의견은 1~1000자로 써주세요."),
    FEEDBACK_TYPE_INVALID(HttpStatus.BAD_REQUEST, "F0002", "의견 유형을 골라주세요."),
    FEEDBACK_REPLY_EMAIL_INVALID(HttpStatus.BAD_REQUEST, "F0003", "이메일 형식이 올바르지 않아요."),

    // 문의하기. 의견(F....)과 달리 계정과 연결해 저장하고 답변이 전제되므로 회신 이메일이 필수다.
    INQUIRY_CONTENT_INVALID(HttpStatus.BAD_REQUEST, "IQ0001", "문의 내용은 1~1000자로 써주세요."),
    INQUIRY_TYPE_INVALID(HttpStatus.BAD_REQUEST, "IQ0002", "문의 유형을 골라주세요."),
    INQUIRY_REPLY_EMAIL_INVALID(HttpStatus.BAD_REQUEST, "IQ0003", "답변받을 이메일을 정확히 입력해주세요."),

    TEST_ONLY_OPERATION(HttpStatus.FORBIDDEN, "T0001", "테스트 데이터 기능을 사용할 권한이 없는 계정입니다.");

    private final HttpStatus status;
    private final String code;
    private final String message;
}
