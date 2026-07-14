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
 * <p>엔티티 컬럼은 {@code @Enumerated} 가 아니라 String 으로 두고 여기서 코드 유효성만 검증한다
 * (쓰기는 엄격, 읽기는 관대) — 검증 도입 이전에 저장된 자유 텍스트 카테고리 row 를 읽을 때
 * enum 매핑 크래시가 나지 않게 하기 위함. 유효하지 않은 값 쓰기는 {@link #requireValidCode(String)} 이 막는다.
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

    /// 지출 카테고리 코드가 9종 중 하나인지 검증. 아니면 {@link ErrorCode#AMOUNT_CATEGORY_INVALID}.
    public static void requireValidCode(String code) {
        if (!isValidCode(code)) {
            throw new BusinessException(ErrorCode.AMOUNT_CATEGORY_INVALID);
        }
    }
}
