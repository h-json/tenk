package com.hjson.tenk.domain.amount;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;

/**
 * 지출 카테고리 (고정 9종). {@code amount.category} 컬럼에는 이 enum 의 {@code name()}(코드)이 저장된다.
 *
 * <p>저장·전송은 안정적인 코드({@code FOOD}), 표시는 한글 {@code label}(식비) — 라벨을 바꿔도 DB
 * 마이그레이션이 필요 없다. 클라이언트는 코드를 받아 라벨·아이콘으로 매핑한다
 * ({@code lib/presentation/amount/spend_category.dart}).
 *
 * <p>엔티티 컬럼은 {@code VARCHAR + @Enumerated(EnumType.STRING)} 이다 (2026-07-30 전환).
 * 예전엔 "쓰기는 엄격, 읽기는 관대" 로 String 필드를 뒀는데, 이는 카테고리 검증 도입(2026-07-11)
 * <b>이전에</b> 저장된 자유 텍스트 row 를 읽을 때 enum 매핑 크래시를 피하려던 것이었다. 그 레거시 row 를
 * {@code ETC} 로 접는 마이그레이션을 끝냈으므로 관대할 이유가 사라졌다.
 *
 * <p>외부 입력(JSON)을 enum 으로 바꾸는 지점은 {@link #from(String)} 이고, 호출은 엔티티의 정적 팩토리
 * 안에서만 한다 — 요청 DTO 필드를 이 타입으로 올리지 말 것. Jackson 이 먼저 파싱에 실패하면
 * {@link ErrorCode#AMOUNT_CATEGORY_INVALID}(한국어 메시지) 대신 범용 400 이 나간다.
 */
public enum SpendCategory {
    FOOD("식비"),
    TRANSPORT("교통비"),
    SHOPPING("쇼핑"),
    LEISURE("여가"),
    HEALTH("건강"),
    EDUCATION("교육"),
    EVENT("경조사"),
    LIVING("생활비"),
    ETC("기타");

    private final String label;

    SpendCategory(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static boolean isValidCode(String code) {
        if (code == null) {
            return false;
        }
        for (SpendCategory category : values()) {
            if (category.name().equals(code)) {
                return true;
            }
        }
        return false;
    }

    /// 코드 문자열 → enum. 9종 밖이면 {@link ErrorCode#AMOUNT_CATEGORY_INVALID}.
    ///
    /// null·공백은 예외가 아니라 **null 을 반환**한다 — "카테고리를 안 보냄"과 "이상한 값을 보냄"은
    /// 다른 에러(전자는 `AMOUNT_CATEGORY_CONTENT_REQUIRED`)라서, 미입력 판정은 호출자에게 남긴다.
    public static SpendCategory from(String code) {
        if (code == null || code.isBlank()) {
            return null;
        }
        for (SpendCategory category : values()) {
            if (category.name().equals(code)) {
                return category;
            }
        }
        throw new BusinessException(ErrorCode.AMOUNT_CATEGORY_INVALID);
    }
}
